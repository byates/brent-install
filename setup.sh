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

#------------------------------------------------------------
# gstack + gbrain (knowledge brain / agent tooling)
#
# Both are PUBLIC repos (clone over HTTPS, no SSH key needed). gbrain installs
# from its git repo via bun — NOT from npm (the npm "gbrain" is an unrelated
# package). The DB credential is never committed; it's hydrated from Azure KV.
# These steps are best-effort: a transient failure warns but doesn't abort setup.
#------------------------------------------------------------

# bun runtime (required by gbrain + gstack)
if ! command -v bun &>/dev/null; then
  echo "Installing bun..."
  curl -fsSL https://bun.sh/install | bash || echo "WARN: bun install failed"
fi
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# gbrain CLI (from the public git repo, via bun global)
if command -v bun &>/dev/null && ! command -v gbrain &>/dev/null; then
  echo "Installing gbrain..."
  bun add -g github:garrytan/gbrain || echo "WARN: gbrain install failed"
fi

# gstack (public; clone over HTTPS, then run its setup)
GSTACK_DIR="$HOME/.claude/skills/gstack"
if [ ! -d "$GSTACK_DIR/.git" ]; then
  echo "Installing gstack..."
  mkdir -p "$(dirname "$GSTACK_DIR")"
  if git clone -q https://github.com/garrytan/gstack.git "$GSTACK_DIR"; then
    (cd "$GSTACK_DIR" && ./setup) || echo "WARN: gstack ./setup failed"
  else
    echo "WARN: gstack clone failed"
  fi
else
  echo "gstack already installed at $GSTACK_DIR"
fi

# Hydrate the gbrain DB URL from Azure Key Vault (no-op if already present;
# needs `az login` first — warns rather than failing the provision).
if [ -x "$HOME/.gbrain/refresh-gbrain-db-url.sh" ]; then
  "$HOME/.gbrain/refresh-gbrain-db-url.sh" \
    || echo "WARN: could not hydrate gbrain DB URL — run 'az login' then '~/.gbrain/refresh-gbrain-db-url.sh --force'"
fi

# Register gbrain as an MCP server for Claude Code, with the connection-pool cap.
# Conditional: claude isn't installed by this package. Idempotent (re-add).
if command -v claude &>/dev/null; then
  echo "Registering gbrain MCP server (GBRAIN_POOL_SIZE=2)..."
  claude mcp remove gbrain -s user &>/dev/null || true
  claude mcp add gbrain -s user -e GBRAIN_POOL_SIZE=2 -- "$(command -v gbrain || echo gbrain)" serve \
    || echo "WARN: 'claude mcp add gbrain' failed — register manually later"
else
  echo "claude not found; skipping gbrain MCP registration (run it after installing Claude Code)."
fi

# Apply the systemd pool-size drop-ins shipped in to_home_dir (best-effort:
# user systemd may be unavailable during package install — they apply on login).
systemctl --user daemon-reload &>/dev/null || true

echo ""
echo "gstack/gbrain step done. To finish gbrain: ensure 'az login', run"
echo "  ~/.gbrain/refresh-gbrain-db-url.sh --force && gbrain doctor"
echo "and reconnect the gbrain MCP server in Claude Code (/mcp) so the pool cap takes effect."
