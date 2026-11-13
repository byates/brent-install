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

# postinst invokes this script with dpkg's minimal PATH, which does NOT include
# the user bin dirs where previously-installed tools live. Every `command -v`
# guard below therefore reported "not installed" for things that were, and:
#   - bun was redundantly reinstalled, and ITS installer appended a duplicate
#     `export PATH="$BUN_INSTALL/bin:$PATH"` to ~/.bashrc (see the override
#     warning this script prints at the end)
#   - claude was declared missing, so the gbrain MCP step was skipped entirely
# Put the real locations on PATH first so the guards see the truth.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.cargo/bin:$PATH"

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
      printf '%s\n' "$hit" | sed 's/^/  /'
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
# (Checks for the clone, not the directory: the old `mkdir -p` right before a
# `[ ! -d ]` test meant fzf was never actually installed.)
FZF_PATH=$HOME/.local/.fzf
if [ ! -d "$FZF_PATH/.git" ]; then
  rm -rf "$FZF_PATH"
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

# Install gh (GitHub CLI) from its release tarball. Ubuntu's own package is far
# behind (2.46 on 26.04 vs 2.10x upstream), and GitHub's apt repo can't be used
# from here: postinst runs while dpkg holds its lock, so no apt-get.
if ! command -v gh &>/dev/null; then
  echo "Installing gh..."
  GH_ARCH=$([ "$PLATFORM" = x86_64 ] && echo amd64 || echo arm64)
  GH_VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)
  GH_TMP=$(mktemp -d)
  if curl -fsSL "https://github.com/cli/cli/releases/download/${GH_VERSION}/gh_${GH_VERSION#v}_linux_${GH_ARCH}.tar.gz" |
    tar -xz -C "$GH_TMP" --strip-components=1; then
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/man/man1"
    install -m 755 "$GH_TMP/bin/gh" "$HOME/.local/bin/gh"
    cp "$GH_TMP"/share/man/man1/* "$HOME/.local/share/man/man1/" 2>/dev/null || true
  else
    echo "WARN: gh install failed"
  fi
  rm -rf "$GH_TMP"
else
  echo "gh already installed at $(command -v gh)"
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
# gbrain (knowledge brain)
#
# On by default; INSTALL_GBRAIN=0 skips installing it, hydrating its DB
# credential and registering its MCP server (an existing install is left
# alone either way). gstack is deliberately NOT installed.
#
# gbrain is a PUBLIC repo and installs from git via bun — NOT from npm (the npm
# "gbrain" is an unrelated package). The DB credential is never committed; it's
# hydrated from Azure KV. These steps are best-effort: a transient failure
# warns but doesn't abort setup.
#------------------------------------------------------------

# bun runtime (required by gbrain)
if ! command -v bun &>/dev/null; then
  echo "Installing bun..."
  curl -fsSL https://bun.sh/install | bash || echo "WARN: bun install failed"
fi
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# How gbrain runs here: ONE local `gbrain serve --http` per host, as the
# systemd user service gbrain-http.service on 127.0.0.1:8787, talking straight
# to the shared Supabase brain. Agent sessions reach it over HTTP with a bearer
# token minted locally. Per-session stdio servers each opened their own DB pool
# and blew the Supabase session pooler's 15-client cap, so stdio is opt-in only.
GBRAIN_HTTP_URL="http://127.0.0.1:8787/mcp"
GBRAIN_HEALTH_URL="http://127.0.0.1:8787/health"

# Make `systemctl --user` work when postinst runs us via `sudo -u`, which leaves
# no XDG_RUNTIME_DIR / session bus. postinst enables linger first, so the user
# manager is running even if nobody is logged in.
user_systemd_ok() {
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
  systemctl --user show-environment &>/dev/null
}

gbrain_has_credentials() {
  jq -e '(.database_url // "" | length > 0) and (.openai_api_key // "" | length > 0)' \
    "$HOME/.gbrain/config.json" &>/dev/null
}

# Start (or restart, to pick up a new gbrain build or new credentials) the
# local server and its liveness timer, then wait for /health. Up to 90s (the
# unit's TimeoutStartSec): startup takes ~25s on a fresh host, more on a first
# start against a brain whose schema needs checking.
start_gbrain_http() {
  if ! user_systemd_ok; then
    echo "WARN: user systemd not reachable; start gbrain later with:"
    echo "  systemctl --user daemon-reload && systemctl --user enable --now gbrain-http gbrain-http-liveness.timer"
    return 1
  fi
  systemctl --user daemon-reload
  systemctl --user enable gbrain-http.service &>/dev/null
  systemctl --user restart gbrain-http.service
  systemctl --user enable --now gbrain-http-liveness.timer &>/dev/null
  echo -n "Waiting for gbrain-http on $GBRAIN_HEALTH_URL "
  local deadline=$((SECONDS + 90))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if curl -fsS --max-time 2 -o /dev/null "$GBRAIN_HEALTH_URL" 2>/dev/null; then
      echo "up."
      return 0
    fi
    echo -n "."
    sleep 2
  done
  echo " not answering."
  echo "WARN: gbrain-http didn't come up; see: journalctl --user -u gbrain-http -n 50"
  return 1
}

# Register gbrain as an MCP server for Claude Code.
#
# An existing registration is NEVER touched: an http registration's bearer
# token exists only in ~/.claude.json, so replacing it is unrecoverable.
# GBRAIN_MCP_MODE picks what a fresh install registers:
#   auto   (default) the local server: mint a token for this host with
#          `gbrain auth create`, then `gbrain connect --install`. Skipped (with
#          instructions) if the server isn't up.
#   http   an existing endpoint: GBRAIN_MCP_URL (default the local one) plus
#          GBRAIN_MCP_TOKEN
#   stdio  a per-session `gbrain serve` (not recommended; see above)
#   none   register nothing
GBRAIN_MCP_MODE="${GBRAIN_MCP_MODE:-auto}"

# `gbrain connect --install` registers the server, smoke-tests the token, and
# writes gbrain's brain-first block (~/.claude/CLAUDE.md) and turn hook. But it
# registers at Claude Code's default LOCAL scope — the directory it ran in only
# — and has no scope flag. So run it from $HOME, then move the entry to USER
# scope so every project sees it. The token travels by environment variable to
# gbrain; `claude mcp add` itself needs it as a header argument.
connect_gbrain_user_scope() {
  local url="$1" tok="$2"
  (
    cd "$HOME" || exit 1
    GBRAIN_REMOTE_TOKEN="$tok" gbrain connect "$url" --agent claude-code --install --yes || exit 1
    claude mcp remove gbrain -s local >/dev/null 2>&1 || true
    claude mcp add --scope user gbrain -t http "$url" -H "Authorization: Bearer $tok" >/dev/null
  )
}
GBRAIN_MCP_URL="${GBRAIN_MCP_URL:-$GBRAIN_HTTP_URL}"

register_gbrain_mcp() {
  local server_up="$1"
  if ! command -v claude &>/dev/null; then
    echo "claude not found; skipping gbrain MCP registration (re-run setup after installing Claude Code)."
    return 0
  fi
  if [ "$GBRAIN_MCP_MODE" = "none" ]; then
    echo "GBRAIN_MCP_MODE=none; skipping gbrain MCP registration."
    return 0
  fi
  # Checked from $HOME: `claude mcp get` also sees local-scope entries for the
  # current directory, which would make the answer depend on where we ran.
  if (cd "$HOME" && claude mcp get gbrain &>/dev/null); then
    echo "gbrain MCP server already registered; leaving it untouched."
    echo "  (to change it: claude mcp remove gbrain -s user, then re-run setup)"
    return 0
  fi

  case "$GBRAIN_MCP_MODE" in
    auto)
      if [ "$server_up" != 1 ]; then
        echo "gbrain-http isn't up, so no MCP registration yet. Once it is, re-run setup."
        return 0
      fi
      # Tokens live in the shared brain, so the name must be unique per host;
      # fall back to a timestamped name if this host already minted one.
      local name="claude-code-$(hostname -s)" out tok
      out=$(gbrain auth create "$name" 2>&1) ||
        { name="$name-$(date +%Y%m%d%H%M)"; out=$(gbrain auth create "$name" 2>&1); } ||
        { echo "WARN: gbrain auth create failed: $out"; return 0; }
      tok=$(printf '%s\n' "$out" | grep -oE 'gbrain_[A-Za-z0-9_-]{16,}' | head -1)
      if [ -z "$tok" ]; then
        echo "WARN: couldn't find the token in 'gbrain auth create' output; revoke '$name' and register manually."
        return 0
      fi
      echo "Minted gbrain token '$name'; registering $GBRAIN_HTTP_URL with Claude Code..."
      connect_gbrain_user_scope "$GBRAIN_HTTP_URL" "$tok" ||
        echo "WARN: 'gbrain connect' failed. Revoke the token with: gbrain auth revoke \"$name\""
      ;;
    http)
      if [ -z "${GBRAIN_MCP_TOKEN:-}" ]; then
        echo "WARN: GBRAIN_MCP_MODE=http but GBRAIN_MCP_TOKEN is unset; skipping."
        return 0
      fi
      echo "Registering gbrain MCP server over HTTP ($GBRAIN_MCP_URL)..."
      connect_gbrain_user_scope "$GBRAIN_MCP_URL" "$GBRAIN_MCP_TOKEN" ||
        echo "WARN: http registration failed — register manually later"
      ;;
    stdio)
      echo "Registering gbrain MCP server over stdio (GBRAIN_POOL_SIZE=2)..."
      claude mcp add gbrain -s user -e GBRAIN_POOL_SIZE=2 -- "$(command -v gbrain || echo gbrain)" serve ||
        echo "WARN: 'claude mcp add gbrain' failed — register manually later"
      ;;
    *)
      echo "WARN: unknown GBRAIN_MCP_MODE='$GBRAIN_MCP_MODE' (want auto|http|stdio|none); skipping."
      ;;
  esac
}

# postinst can't put the token in sudo's argv (visible in `ps` for the whole
# run), so it hands it over in a 0600 file instead.
if [ -z "${GBRAIN_MCP_TOKEN:-}" ] && [ -r "${GBRAIN_MCP_TOKEN_FILE:-}" ]; then
  GBRAIN_MCP_TOKEN=$(cat "$GBRAIN_MCP_TOKEN_FILE")
fi

if [ "${INSTALL_GBRAIN:-1}" != 0 ]; then
  # gbrain CLI (from the public git repo, via bun global)
  if command -v bun &>/dev/null && ! command -v gbrain &>/dev/null; then
    echo "Installing gbrain..."
    bun add -g github:garrytan/gbrain || echo "WARN: gbrain install failed"
  fi

  # Credentials from Azure Key Vault (no-op if already present; needs `az login`).
  "$HOME/.gbrain/refresh-gbrain-db-url.sh" ||
    echo "WARN: could not hydrate gbrain credentials — run 'az login', then '~/.gbrain/refresh-gbrain-db-url.sh --force' and re-run setup"

  server_up=0
  if command -v gbrain &>/dev/null && gbrain_has_credentials; then
    start_gbrain_http && server_up=1
  else
    echo "gbrain-http not started: needs the gbrain CLI and credentials in ~/.gbrain/config.json."
  fi

  register_gbrain_mcp "$server_up"

  echo ""
  if [ "$server_up" = 1 ]; then
    echo "gbrain: local server up at $GBRAIN_HTTP_URL. Check with: gbrain doctor"
    echo "Reconnect gbrain in running Claude Code sessions with /mcp."
  else
    echo "gbrain: not running yet (see the warnings above)."
  fi
else
  echo ""
  echo "Skipping gbrain (INSTALL_GBRAIN=0)."
fi
