#!/bin/bash -e

if [[ $(id -u $USER) = 0 ]]; then
    # If we are running as root, then we don't need (and may not have) sudo
    echo "Userid=$(id -u $USER)"
    SUDO=
else
    SUDO=sudo
fi

# https://gist.github.com/Cartexius/4c437c084d6e388288201aadf9c8cdd5
$SUDO apt install -y libgtest-dev lcov
cd /usr/src/googletest/googletest/
$SUDO cmake CMakeLists.txt
$SUDO make
$SUDO cp lib/*.a /usr/lib

$SUDO mkdir /usr/local/lib/googletest
$SUDO ln -s /usr/lib/libgtest.a /usr/local/lib/googletest/libgtest.a
$SUDO ln -s /usr/lib/libgtest_main.a /usr/local/lib/googletest/libgtest_main.a
