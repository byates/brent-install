#!/bin/bash

set -e

# Function to install Clang 20 using the official LLVM script
install_clang20() {
  echo "Installing Clang 20 using the official LLVM install script..."

  # Download and run the LLVM install script
  wget -q --show-progress https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh
  chmod +x /tmp/llvm.sh
  sudo /tmp/llvm.sh 20
  sudo apt update
  sudo apt install clang-tidy-20 clang-format-20 clang-tools-20 llvm-20-dev lld-20 lldb-20 llvm-20-tools libomp-20-dev libc++-20-dev libc++abi-20-dev libclang-common-20-dev libclang-20-dev libclang-cpp20-dev liblldb-20-dev libunwind-20-dev
  echo "Setting Clang 20 as default..."
  sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 50
  sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-20 50
  sudo update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-20 50
  sudo update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-20 50
  sudo update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-20 50
  rm /tmp/llvm.sh
  echo "Clang 20 installation complete."
}

# Check if clang is installed
if command -v clang >/dev/null 2>&1; then
  CLANG_VERSION=$(clang --version | head -n1 | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1)
  CLANG_MAJOR_VERSION=$(echo "$CLANG_VERSION" | cut -d. -f1)

  if [ "$CLANG_MAJOR_VERSION" -eq 20 ]; then
    echo "Clang version 20 is already installed."
    exit 0
  else
    echo "Clang version $CLANG_MAJOR_VERSION found. Installing version 20..."
    install_clang20
  fi
else
  echo "Clang is not installed. Installing Clang 20..."
  install_clang20
fi
