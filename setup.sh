#!/bin/bash
set -e

echo "Running setup as: $(whoami)"
echo "Target HOME: $HOME"
mkdir -p "$HOME/.config"

# Clone TPM and config files
git clone https://github.com/tmux-plugins/tpm ${HOME}/.tmux/plugins/tpm

wget https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/.tmux.conf -O ${HOME}/.tmux.conf
wget https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/.vimrc -O ${HOME}/.vimrc
wget https://gist.githubusercontent.com/byates/d04215a3dc88cf47015fea28d419e64e/raw/jby_bashrc.sh -O ${HOME}/jby_bashrc.sh
wget https://gist.githubusercontent.com/byates/dd4f8dc9069c15f7cb2179df4dca78bc/raw/.gitconfig.inc -O ${HOME}/.gitconfig.inc
wget https://gist.githubusercontent.com/byates/d049f99a8e24cdcaf87752be414a18de/raw/force-clean-repo.sh -O ${HOME}/force-clean-repo.sh
chmod +x ${HOME}/force-clean-repo.sh
wget https://gist.githubusercontent.com/byates/b6ded34f2c7436cac9898d92abb8a0d1/raw/test-24-bit-color.sh -O ${HOME}/test-24-bit-color.sh
chmod +x ${HOME}/test-24-bit-color.sh

# Append custom bashrc line if not present
TARGET_FILE="$HOME/.bashrc"
LINE='if [ -f ${HOME}/jby_bashrc.sh ]; then . ${HOME}/jby_bashrc.sh; fi'
if ! grep -Fxq "$LINE" "$TARGET_FILE"; then
  echo "$LINE" >>"$TARGET_FILE"
fi

# Initialize git config if empty
GITCONFIG="$HOME/.gitconfig"
if [ ! -s "$GITCONFIG" ]; then
  cat >"$GITCONFIG" <<EOF
[include]
    path = ${HOME}/.gitconfig.inc
[user]
    name = Brent Yates
    email = brent.yates@gmail.com
[init]
    defaultBranch = main
EOF
  echo "Git config initialized at $GITCONFIG"
else
  echo "$GITCONFIG already exists and is not empty. Skipping."
fi

# Install fzf using official install script
if [ ! -d "$HOME/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ${HOME}/.fzf
  yes | ${HOME}/.fzf/install --all # Accept all options: keybindings, completion, update shell rc
else
  echo "fzf already installed at ${HOME}/.fzf"
fi

# Install lazygit
if ! command -v lazygit &>/dev/null; then
  echo "Installing lazygit..."
  VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep tag_name | cut -d '"' -f 4)
  URL="https://github.com/jesseduffield/lazygit/releases/download/${VERSION}/lazygit_${VERSION#v}_Linux_${PLATFORM}.tar.gz"
  wget "$URL" -O /tmp/lazygit.tar.gz
  tar -C /tmp -xzf /tmp/lazygit.tar.gz lazygit
  sudo mv /tmp/lazygit /usr/local/bin
else
  echo "lazygit already installed"
fi

# Set up nvim
git clone https://github.com/LazyVim/starter ${HOME}/.config/nvim
