#!/bin/bash -e

# Prevent script from being run as root
if [[ "$(id -u)" == 0 ]]; then
  echo "ERROR: This script must NOT be run as root. Please run it as a normal user."
  exit 1
fi

Distro=$(awk -F= '/^NAME/{print tolower($2)}' /etc/os-release)
VersionID=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release)
MajorVersionID=$(echo "$VersionID" | cut -d. -f1 | tr -d '"')
ARCH=$(uname -m)

if [[ ! $Distro =~ "ubuntu" ]]; then
  echo "Ubuntu distribution NOT detected. Found $Distro:$VersionID"
  echo "This script only works with Ubuntu"
  exit 1
fi

sudo apt update -qq -y
# Install common build packages
sudo apt -y install build-essential ninja-build libtool autoconf pkg-config libibverbs-dev libnuma-dev libssl-dev libcurl4-openssl-dev meson
sudo apt -y install postgresql postgresql-contrib libpcap-dev python3-pyelftools gettext libsystemd-dev
sudo apt -y install dh-make clang clang-format ripgrep zip unzip flex byacc libdw-dev libbfd-dev libdwarf-dev
sudo apt -y install googletest googlemock libgtest-dev libgmock-dev libarchive-dev
sudo apt -y install libxdp-dev libbpf-dev python3-msgpack

# ----------------------------
# Install latest CMake version
# ----------------------------
LATEST_CMAKE_VERSION=$(curl -s https://api.github.com/repos/Kitware/CMake/releases/latest | grep tag_name | cut -d '"' -f4 | tr -d 'v')
CUR_CMAKE_VER=$(cmake --version 2>/dev/null | {
  read _ _ v _
  echo ${v#go}
})

if [[ ${LATEST_CMAKE_VERSION} != ${CUR_CMAKE_VER} ]]; then
  echo "----------------------------------------------------------------------"
  echo "cmake either not installed or not the latest version. Found '$CUR_CMAKE_VER'"
  echo "Installing latest version ${LATEST_CMAKE_VERSION}"
  sudo apt -y remove cmake
  mkdir -p ~/tools
  rm -rf ~/tools/cmake
  pushd ~/tools

  mkdir -p cmake
  if [[ "$ARCH" == "x86_64" ]]; then
    CMAKE_SCRIPT=cmake-${LATEST_CMAKE_VERSION}-linux-x86_64.sh
  elif [[ "$ARCH" == "aarch64" ]]; then
    CMAKE_SCRIPT=cmake-${LATEST_CMAKE_VERSION}-linux-aarch64.sh
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi

  wget -q https://github.com/Kitware/CMake/releases/download/v${LATEST_CMAKE_VERSION}/${CMAKE_SCRIPT}
  chmod +x ${CMAKE_SCRIPT}
  ./${CMAKE_SCRIPT} --skip-license --prefix=$(realpath ~)/tools/cmake
  rm -f ${CMAKE_SCRIPT}
  popd
  sudo ln -sf $(realpath ~)/tools/cmake/bin/cmake /usr/local/bin/cmake
  echo "----------------------------------------------------------------------"
fi

# ----------------------------
# Install latest Go version
# ----------------------------
LATEST_GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1 | cut -c3-)
CUR_GOVER=$(go version 2>/dev/null | {
  read _ _ v _
  echo ${v#go}
})

if [[ ${LATEST_GO_VERSION} != ${CUR_GOVER} ]]; then
  echo "----------------------------------------------------------------------"
  echo "Go either not installed or not the latest version. Found '$CUR_GOVER'"
  echo "Installing latest version ${LATEST_GO_VERSION}"
  sudo apt -y remove golang
  mkdir -p ~/tools
  pushd ~/tools

  if [[ "$ARCH" == "x86_64" ]]; then
    GODOWNLOAD=go${LATEST_GO_VERSION}.linux-amd64.tar.gz
  elif [[ "$ARCH" == "aarch64" ]]; then
    GODOWNLOAD=go${LATEST_GO_VERSION}.linux-arm64.tar.gz
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi

  wget -q https://golang.org/dl/${GODOWNLOAD}
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf $GODOWNLOAD >/dev/null
  rm -f $GODOWNLOAD
  sudo tee /etc/profile.d/go.sh >/dev/null <<EOF
export PATH=\$PATH:/usr/local/go/bin
EOF
  sudo chmod 644 /etc/profile.d/go.sh
  popd
  echo "----------------------------------------------------------------------"
fi
