#!/bin/bash -e

# Prevent script from being run as root
if [[ "$(id -u)" == 0 ]]; then
  echo "ERROR: This script must NOT be run as root. Please run it as a normal user."
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
