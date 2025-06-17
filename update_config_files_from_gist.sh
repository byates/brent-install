#!/bin/bash
set -e

wget -q --show-progress https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/.tmux.conf -O ./to_home_dir/.tmux.conf
wget -q --show-progress https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/.vimrc -O ./to_home_dir/.vimrc
wget -q --show-progress https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/jby_bashrc.sh -O ./to_home_dir/.jby_bashrc.sh
wget -q --show-progress https://gist.githubusercontent.com/byates/dd4f8dc9069c15f7cb2179df4dca78bc/raw/.gitconfig.inc -O ./to_home_dir/.gitconfig.inc

wget -q --show-progress https://gist.githubusercontent.com/byates/d049f99a8e24cdcaf87752be414a18de/raw/force-clean-repo.sh -O ./to_usr_bin/force-clean-repo.sh
wget -q --show-progress https://gist.githubusercontent.com/byates/b6ded34f2c7436cac9898d92abb8a0d1/raw/test-24-bit-color.sh -O ./to_usr_bin/test-24-bit-color.sh
wget -q --show-progress https://gist.githubusercontent.com/byates/40ba3a7d1e2572b17b3b6616e77a288e/raw/install-build-tools.sh -O ./to_usr_bin/install-build-tools.sh
wget -q --show-progress https://gist.githubusercontent.com/byates/cbb356377ed4ba4988940595e4e7789c/raw/install_gtest.sh -O ./to_usr_bin/install_gtest.sh
wget -q --show-progress https://gist.githubusercontent.com/byates/9a41343ec02beb86fbdb22c7a4f8794e/raw/install-dpdk.sh -O ./to_usr_bin/install-dpdk.sh
wget -q --show-progress https://gist.githubusercontent.com/byates/4db079efc48db2e913ac75df5000d577/raw/assign-huge-pages.sh -O ./to_usr_bin/assign-huge-pages.sh

chmod +x ./to_usr_bin/force-clean-repo.sh
chmod +x ./to_usr_bin/test-24-bit-color.sh
chmod +x ./to_usr_bin/install-build-tools.sh
chmod +x ./to_usr_bin/install_gtest.sh
chmod +x ./to_usr_bin/install-dpdk.sh
chmod +x ./to_usr_bin/assign-huge-pages.sh
