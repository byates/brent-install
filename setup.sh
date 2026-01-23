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

# Install node via nvm (fetch latest version)
NVM_LATEST=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)
echo "Installing nvm ${NVM_LATEST}..."
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST}/install.sh" | bash

# Load nvm and install latest LTS node
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# Install global npm packages
npm install -g prettier
npm install -g @abdo-el-mobayad/claude-code-fast-permission-hook
echo "Run 'cf-approve install && cf-approve config' to set the permission hook (after claude install)"
echo "Run 'npx ccstatusline@latest' to set the claude status line"
echo "Run 'cp /usr/share/brent-install/to_scripts/ccstatusline/settings.json ~/.config/ccstatusline/'"
echo "    to set the claude status line"

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
FZF_PATH=$HOME/.local/.fzf
mkdir -p $FZF_PATH
if [ ! -d "$FZF_PATH" ]; then
  git clone -q --depth 1 https://github.com/junegunn/fzf.git ${FZF_PATH}
  yes | ${FZF_PATH}/install --all # Accept all options: keybindings, completion, update shell rc
else
  echo "fzf already installed at ${FZF_PATH}"
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

# Build and install nvim from source
NVIM_DIR="${HOME}/tools/neovim"
if [ ! -d "${NVIM_DIR}" ]; then
  echo "Cloning and building Neovim from source..."
  mkdir -p "${HOME}/tools"
  git clone -q https://github.com/neovim/neovim "${NVIM_DIR}"
  cd "${NVIM_DIR}"
  make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="${HOME}/.local"
  make install
  cd "${SCRIPT_DIR}"
else
  echo "Neovim source already exists at ${NVIM_DIR}"
fi

# Set up nvim config
if [ ! -d "${HOME}/.config/nvim" ]; then
  git clone -q https://github.com/LazyVim/starter ${HOME}/.config/nvim
fi
# Copy our custom config files to the nvim setup directory (always update)
cp ${SCRIPT_DIR}/nvim_lua_config_options.lua ${HOME}/.config/nvim/lua/config/options.lua
cp ${SCRIPT_DIR}/nvim_lua_config_keymaps.lua ${HOME}/.config/nvim/lua/config/keymaps.lua
cp ${SCRIPT_DIR}/nvim_lua_plugins_grug-keymaps.lua ${HOME}/.config/nvim/lua/plugins/grug-keymap.lua
cp ${SCRIPT_DIR}/nvim_lua_plugins_theme.lua ${HOME}/.config/nvim/lua/plugins/theme.lua
cp ${SCRIPT_DIR}/nvim_lua_plugins_themery.lua ${HOME}/.config/nvim/lua/plugins/themery.lua
cp ${SCRIPT_DIR}/nvim_lua_plugins_bufferline.lua ${HOME}/.config/nvim/lua/plugins/bufferline.lua
cp ${SCRIPT_DIR}/nvim_lua_plugins_cmp.lua ${HOME}/.config/nvim/lua/plugins/cmp.lua
cp ${SCRIPT_DIR}/nvim_lua_plugins_formatting.lua ${HOME}/.config/nvim/lua/plugins/formatting.lua
cp ${SCRIPT_DIR}/nvim_lua_plugins_git.lua ${HOME}/.config/nvim/lua/plugins/git.lua
cp ${SCRIPT_DIR}/nvim_lua_plugins_image.lua ${HOME}/.config/nvim/lua/plugins/image.lua

# UV Manages python environments
curl -LsSf https://astral.sh/uv/install.sh | sh

# Startship makes our terminal prompts flashy
curl -sS https://starship.rs/install.sh | sh -s -- -b ~/.local/bin
