#!/bin/bash -e

# Prevent script from being run as root
if [[ "$(id -u)" == 0 ]]; then
  echo "ERROR: This script must NOT be run as root. Please run it as a normal user."
  exit 1
fi

mkdir -p ~/tools && cd ~/tools
if [ ! -d dpdk-stable ]; then
  git clone git@github.com:swxtchio/dpdk-stable.git
  cd dpdk-stable
  git checkout swxtch-24.11
  echo "Starting DPDK build"
  ./build-dpdk.sh release generic
else
  echo "Bypassing DPDK build because ~/tools/dpdk-stable alread exists."
fi
