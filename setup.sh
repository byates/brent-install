#!/bin/bash
set -e

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  PLATFORM="x86_64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  PLATFORM="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "Running setup as: $(whoami) @ $HOME on $PLATFORM"
mkdir -p "$HOME/.config"

# Clone TPM and config files
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone -q https://github.com/tmux-plugins/tpm ${HOME}/.tmux/plugins/tpm
fi

# Append custom bashrc line if not present
TARGET_FILE="$HOME/.bashrc"
LINE='if [ -f ${HOME}/.jby_bashrc.sh ]; then . ${HOME}/.jby_bashrc.sh; fi'
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
FZF_PATH=$HOME/.local/
mkdir -p $FZF_PATH
if [ ! -d "$FZF_PATH/.fzf" ]; then
  git clone -q --depth 1 https://github.com/junegunn/fzf.git ${FZF_PATH}/.fzf
  yes | ${FZF_PATH}/.fzf/install --all # Accept all options: keybindings, completion, update shell rc
else
  echo "fzf already installed at ${FZF_PATH}/.fzf"
fi

# Install lazygit
if ! command -v lazygit &>/dev/null; then
  echo "Installing lazygit..."
  VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep tag_name | cut -d '"' -f 4)
  URL="https://github.com/jesseduffield/lazygit/releases/download/${VERSION}/lazygit_${VERSION#v}_Linux_${PLATFORM}.tar.gz"
  wget -q "$URL" -O /tmp/lazygit.tar.gz
  tar -C /tmp -xzf /tmp/lazygit.tar.gz lazygit
  mkdir -p ${HOME}/.local/bin
  mv /tmp/lazygit ${HOME}/.local/bin
else
  echo "lazygit already installed"
fi

# Set up nvim
if [ ! -d "${HOME}/.config/nvim" ]; then
  git clone -q https://github.com/LazyVim/starter ${HOME}/.config/nvim
  # Copy our customer config files to the nvim setup directory
  cp ${SCRIPT_DIR}/nvim_lua_config_options.lua ${HOME}/.config/nvim/lua/config/options.lua
  cp ${SCRIPT_DIR}/nvim_lua_plugins_grug-keymaps.lua ${HOME}/.config/nvim/lua/plugins/gurg-keymap.lua
fi
