#!/bin/bash
set -e

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  PLATFORM="amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  PLATFORM="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "Running setup as: $(whoami) @ $HOME on $PLATFORM"
mkdir -p "$HOME/.config"
