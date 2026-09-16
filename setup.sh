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

# Seed the machine-local override file. This is the sanctioned place for
# host-specific config; it is sourced from .jby_bashrc.sh and never overwritten
# by this package, so it survives reinstall.
LOCAL_RC="$HOME/.jby_bashrc.local.sh"
if [ ! -f "$LOCAL_RC" ]; then
  cat >"$LOCAL_RC" <<'EOF'
# Machine-local shell config. Sourced from ~/.jby_bashrc.sh; never overwritten
# by the brent-install package. Put host-specific things here — API-key
# sourcing, per-box paths, editor choice — rather than appending to ~/.bashrc,
# where they land AFTER .jby_bashrc.sh is sourced and silently override it.
EOF
  echo "Created $LOCAL_RC for host-specific shell config"
fi

# Warn about ~/.bashrc lines that override variables .jby_bashrc.sh owns.
#
# Only the source line above is managed; the rest of ~/.bashrc accumulates
# hand-edits. Anything appended after that line wins, because it runs later.
# That is not hypothetical: an `export SSH_AUTH_SOCK=~/.ssh/agent.sock` added
# by hand pointed at a symlink whose agent was long gone, and broke ssh-agent
# in every shell on the box (2026-09-16). Report the conflicts; don't rewrite
# the user's file.
check_bashrc_overrides() {
  local jby="$HOME/.jby_bashrc.sh"
  [ -f "$jby" ] || return 0

  local src_line
  src_line=$(grep -n 'jby_bashrc\.sh' "$TARGET_FILE" | head -1 | cut -d: -f1) || return 0
  [ -n "$src_line" ] || return 0

  # Variables .jby_bashrc.sh exports, so we know what it owns.
  local owned
  owned=$(grep -oP '^\s*export \K[A-Za-z_][A-Za-z0-9_]*' "$jby" | sort -u)
  [ -n "$owned" ] || return 0

  local found=0 var hit
  while IFS= read -r var; do
    # Only lines AFTER the source line can override it.
    hit=$(awk -v start="$src_line" -v v="$var" \
      'NR > start && $0 ~ ("^[[:space:]]*export[[:space:]]+" v "=") { print NR": "$0 }' \
      "$TARGET_FILE")
    if [ -n "$hit" ]; then
      [ "$found" = 0 ] && {
        echo ""
        echo "WARNING: ~/.bashrc overrides variables that ~/.jby_bashrc.sh sets."
        echo "These run after it is sourced (line $src_line), so they win:"
        found=1
      }
      echo "  $hit"
    fi
  done <<<"$owned"

  if [ "$found" = 1 ]; then
    echo ""
    echo "Move them to ~/.jby_bashrc.local.sh, which is sourced from inside"
    echo ".jby_bashrc.sh and overrides it deliberately rather than by accident."
    echo ""
  fi
}
check_bashrc_overrides || true

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

# Starship makes our terminal prompts flashy.
# --yes is REQUIRED: postinst runs this with no controlling terminal, and the
# installer's confirmation prompt then dies with "cannot open /dev/tty", which
# under `set -e` aborts the whole package install. Skip entirely if starship is
# already on PATH so a reinstall doesn't re-download it.
if command -v starship >/dev/null 2>&1; then
  echo "starship already installed at $(command -v starship); skipping."
else
  curl -sS https://starship.rs/install.sh | sh -s -- --yes -b "$HOME/.local/bin"
fi

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

# Register gbrain as an MCP server for Claude Code.
#
# This used to unconditionally `claude mcp remove gbrain` then re-add it as a
# stdio server. That is destructive: a box running gbrain as an HTTP service
# (gbrain-http.service, `gbrain serve --http`) has an http registration whose
# bearer token exists ONLY in ~/.claude.json — nothing under ~/.gbrain can
# reconstruct it. Re-running setup.sh silently replaced that registration and
# there was no way to put it back.
#
# So: an existing registration is never touched. Mode is selectable for fresh
# installs via GBRAIN_MCP_MODE:
#   auto  (default) keep any existing registration; otherwise probe for a live
#         HTTP endpoint and use it when GBRAIN_MCP_TOKEN is available; else stdio
#   stdio force a stdio server (`gbrain serve`) — self-contained, no service
#   http  force http; requires GBRAIN_MCP_TOKEN, optional GBRAIN_MCP_URL
#   none  skip MCP registration entirely
GBRAIN_MCP_MODE="${GBRAIN_MCP_MODE:-auto}"
GBRAIN_MCP_URL="${GBRAIN_MCP_URL:-http://127.0.0.1:8787/mcp}"

register_gbrain_mcp() {
  if ! command -v claude &>/dev/null; then
    echo "claude not found; skipping gbrain MCP registration (run it after installing Claude Code)."
    return 0
  fi

  if [ "$GBRAIN_MCP_MODE" = "none" ]; then
    echo "GBRAIN_MCP_MODE=none; skipping gbrain MCP registration."
    return 0
  fi

  # Never clobber what is already there.
  if claude mcp get gbrain &>/dev/null; then
    echo "gbrain MCP server already registered; leaving it untouched."
    echo "  (to change it: claude mcp remove gbrain -s user, then re-run with GBRAIN_MCP_MODE=stdio|http)"
    return 0
  fi

  local mode="$GBRAIN_MCP_MODE"
  if [ "$mode" = "auto" ]; then
    # Positive probe: only choose http if the endpoint actually answers AND we
    # have a token to talk to it with. Otherwise stdio, which needs neither.
    # NB: do NOT use `curl -f` here. The MCP endpoint answers a plain GET with
    # 405 Method Not Allowed, which -f treats as failure — so a perfectly
    # healthy service probed as dead. Any HTTP status means something answered;
    # only curl's own "000" (no response) means it did not.
    local code=""
    if [ -n "${GBRAIN_MCP_TOKEN:-}" ]; then
      # `|| code=000` (not `|| echo 000`): curl already prints 000 on a failed
      # connection, so echoing another would make $code the two-line "000\n000"
      # — which is not equal to "000" and would read as alive.
      code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "$GBRAIN_MCP_URL" 2>/dev/null) || code=000
    fi
    if [ -n "$code" ] && [ "$code" != "000" ]; then
      mode=http
    else
      mode=stdio
    fi
    echo "GBRAIN_MCP_MODE=auto resolved to '$mode'"
  fi

  case "$mode" in
    http)
      if [ -z "${GBRAIN_MCP_TOKEN:-}" ]; then
        echo "WARN: GBRAIN_MCP_MODE=http but GBRAIN_MCP_TOKEN is unset; skipping."
        echo "      Register manually: claude mcp add-json gbrain -s user '{\"type\":\"http\",...}'"
        return 0
      fi
      echo "Registering gbrain MCP server over HTTP ($GBRAIN_MCP_URL)..."
      claude mcp add-json gbrain -s user \
        "{\"type\":\"http\",\"url\":\"$GBRAIN_MCP_URL\",\"headers\":{\"Authorization\":\"Bearer $GBRAIN_MCP_TOKEN\"}}" \
        || echo "WARN: http registration failed — register manually later"
      ;;
    stdio)
      echo "Registering gbrain MCP server over stdio (GBRAIN_POOL_SIZE=2)..."
      claude mcp add gbrain -s user -e GBRAIN_POOL_SIZE=2 -- "$(command -v gbrain || echo gbrain)" serve \
        || echo "WARN: 'claude mcp add gbrain' failed — register manually later"
      ;;
    *)
      echo "WARN: unknown GBRAIN_MCP_MODE='$mode' (want auto|stdio|http|none); skipping."
      ;;
  esac
}
register_gbrain_mcp

# Apply the systemd pool-size drop-ins shipped in to_home_dir (best-effort:
# user systemd may be unavailable during package install — they apply on login).
systemctl --user daemon-reload &>/dev/null || true

echo ""
echo "gstack/gbrain step done. To finish gbrain: ensure 'az login', run"
echo "  ~/.gbrain/refresh-gbrain-db-url.sh --force && gbrain doctor"
echo "and reconnect the gbrain MCP server in Claude Code (/mcp) so the pool cap takes effect."
