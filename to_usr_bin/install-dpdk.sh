#!/bin/bash -e
mkdir -p ~/tools && cd ~/tools
if [ ! -d dpdk-stable ] ; then
    git clone git@github.com:swxtchio/dpdk-stable.git
    cd dpdk-stable
    git checkout swxtch-24.11
    echo "Starting DPDK build"
    ./build-dpdk.sh release generic
else
    echo "Bypassing DPDK build because ~/tools/dpdk-stable alread exists."
fi

