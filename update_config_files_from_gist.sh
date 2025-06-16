#!/bin/bash
set -e

wget https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/.tmux.conf -O ./dotfiles/.tmux.conf
wget https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/.vimrc -O ./dotfiles/.vimrc
wget https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/jby_bashrc.sh -O ./dotfiles/jby_bashrc.sh
wget https://gist.githubusercontent.com/byates/dd4f8dc9069c15f7cb2179df4dca78bc/raw/.gitconfig.inc -O ./dotfiles/.gitconfig.inc
wget https://gist.githubusercontent.com/byates/d049f99a8e24cdcaf87752be414a18de/raw/force-clean-repo.sh -O ./dotfiles/force-clean-repo.sh
chmod +x ./dotfiles/force-clean-repo.sh
wget https://gist.githubusercontent.com/byates/b6ded34f2c7436cac9898d92abb8a0d1/raw/test-24-bit-color.sh -O ./dotfiles/test-24-bit-color.sh
chmod +x ./dotfiles/test-24-bit-color.sh
