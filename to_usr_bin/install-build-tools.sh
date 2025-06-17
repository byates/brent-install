#!/bin/bash -e

Distro=$(awk -F= '/^NAME/{print tolower($2)}' /etc/os-release)
VersionID=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release)
MajorVersionID=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release | cut -d. -f1 | tr -d '"')

if [[ $(id -u $USER) = 0 ]]; then
    # If we are running as root, then we don't need (and may not have) sudo
    echo "Userid=$(id -u $USER)"
    SUDO=
else
    SUDO=sudo
fi

if [[ ! $Distro =~ "ubuntu" ]]; then
    echo "Ubuntu distribution NOT detected. Found $Distroy:$VersionID"
    echo "This script only works with Ubuntu"
    exit 1
fi

$SUDO apt update -y
# Install common build packages
$SUDO apt -y install build-essential ninja-build libtool autoconf pkg-config libibverbs-dev libnuma-dev libssl-dev libcurl4-openssl-dev meson
$SUDO apt -y install postgresql postgresql-contrib libpcap-dev python3-pyelftools gettext libsystemd-dev
$SUDO apt -y install dh-make clang clang-format ripgrep zip unzip flex byacc libdw-dev libbfd-dev libdwarf-dev

#cmake
cmake_version="3.29.6"
CUR_CMAKE_VER=`cmake --version | { read _ _ v _; echo ${v#go}; }`
if [[ ${cmake_version} != ${CUR_CMAKE_VER} ]]; then
    echo "----------------------------------------------------------------------"
    echo "cmake either not installed or not the correct version. Found '$CUR_CMAKE_VER'"
    echo "Installing version ${cmake_version}"
    $SUDO apt -y remove cmake
    mkdir -p ~/tools
    if [ -d ~/tools/cmake ] ; then
        rm -rf ~/tools/cmake
    fi
    pushd ~/tools
    mkdir -p cmake
    wget -q https://github.com/Kitware/CMake/releases/download/v${cmake_version}/cmake-${cmake_version}-linux-x86_64.sh
    chmod +x cmake-${cmake_version}-linux-x86_64.sh
    ./cmake-${cmake_version}-linux-x86_64.sh --skip-license --prefix=$(realpath ~)/tools/cmake
    rm -f ./cmake-${cmake_version}-linux-x86_64.sh
    popd
    sudo ln -sf $(realpath ~)/tools/cmake/bin/cmake /usr/local/bin/cmake
    echo "----------------------------------------------------------------------"
fi

# golang
GOVER=1.22.4
GODOWNLOAD=go${GOVER}.linux-amd64.tar.gz
CUR_GOVER=`go version | { read _ _ v _; echo ${v#go}; }`
if [[ ${GOVER} != ${CUR_GOVER} ]]; then
    echo "----------------------------------------------------------------------"
    echo "Go either not installed or not the correct version. Found '$CUR_GOVER'"
    echo "Installing version ${GOVER}"
    $SUDO apt -y remove golang
    mkdir -p ~/tools
    pushd ~/tools
    wget -q https://golang.org/dl/${GODOWNLOAD}
    $SUDO rm -rf /usr/local/go
    $SUDO tar -C /usr/local -xzf $GODOWNLOAD > /dev/null
    $SUDO rm -f $GODOWNLOAD
    $SUDO touch /etc/profile.d/go.sh
    $SUDO chmod 666 /etc/profile.d/go.sh
    $SUDO echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh
    $SUDO chmod 644 /etc/profile.d/go.sh
    popd
    echo "----------------------------------------------------------------------"
fi
