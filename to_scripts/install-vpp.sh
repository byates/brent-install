#!/bin/bash

set -euo pipefail

# Prevent script from being run as root
if [[ "$(id -u)" == 0 ]]; then
  echo "ERROR: This script must NOT be run as root. Please run it as a normal user."
  exit 1
fi

cd ~ || {
  echo "ERROR: Failed to change to home directory"
  exit 1
}

# Check for existing vpp directory
if [ -d vpp ]; then
  echo "VPP directory already exists in HOME. Skipping vpp repo install."
else
  # Clone VPP and install dependencies
  if ! git clone --quiet --progress https://github.com/FDio/vpp.git vpp; then
    echo "ERROR: Failed to clone VPP repository."
    exit 1
  fi
  if ! make -C vpp install-deps; then
    echo "ERROR: Failed to install VPP dependencies."
    exit 1
  fi
  echo "Building libmemif..."
  cd ~/vpp/extras/libmemif || {
    echo "ERROR: Failed to enter libmemif directory"
    exit 1
  }
  BUILD_LOG=~/libmemif-build.log
  # Run cmake silently
  if ! cmake -S . -B build -DCMAKE_BUILD_TYPE="Release" >"$BUILD_LOG" 2>&1; then
    echo "ERROR: CMake configuration failed. See $BUILD_LOG for details."
    exit 1
  fi
  # Run make silently
  if ! make -j"$(nproc)" -C build >>"$BUILD_LOG" 2>&1; then
    echo "ERROR: Build failed. See $BUILD_LOG for details."
    exit 1
  fi
  echo "libmemif build completed successfully."
  rm $BUILD_LOG
fi

# Create group 'vpp' if it doesn't exist, and add current user
if ! getent group vpp >/dev/null; then
  sudo groupadd vpp || {
    echo "ERROR: Failed to create vpp group"
    exit 1
  }
  sudo usermod -a -G vpp "$USER" || {
    echo "ERROR: Failed to add user to vpp group"
    exit 1
  }
  # Apply new group immediately if the shell supports it
  if command -v newgrp >/dev/null; then
    newgrp vpp <<EOF
echo "New group vpp activated."
EOF
  else
    echo "NOTE: You must log out and log back in for group changes to take effect."
  fi
fi

# Handle vpp-scripts
cd ~
if [ ! -d vpp-scripts ]; then
  if ! git clone --quiet --progress https://github.com/byates/vpp-scripts.git; then
    echo "ERROR: Failed to clone vpp-scripts repo."
    exit 1
  fi
  cp vpp-scripts/startup.conf.example startup.conf
  # Replace USER placeholder with actual username
  sed -i "s/\bUSER\b/$USER/g" startup.conf || {
    echo "ERROR: Failed to replace USER in startup.conf"
    exit 1
  }
else
  echo "Bypassing vpp-scripts because it already exists."
fi

if [ ! -f ~/vppctl ]; then
  ln -sf ~/vpp/build-root/build-vpp_debug-native/vpp/bin/vppctl vppctl
fi

if [ ! -f /etc/vpp/vcl.conf ]; then
  sudo mkdir -p /etc/vpp
  sudo ln -sf ~/vpp-scripts/vcl.conf /etc/vpp/vcl.conf
fi

# must create this or vpp throws and error
sudo mkdir -p /var/log/vpp

echo "-----------------------------------------"
echo "VPP installed"
echo "-----------------------------------------"
