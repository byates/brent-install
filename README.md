# brent-install

A Debian package that bootstraps a development environment with dotfiles, Neovim, and essential CLI tools.

## What Gets Installed

### System Packages (via apt)

- `snapd` - Snap package manager
- `fd-find` - Fast file finder (aliased to `fd`)
- `ripgrep` - Fast grep alternative
- `tree` - Directory listing
- `build-essential`, `ninja-build`, `clang`, `clang-format`, `clangd` - C/C++ toolchain
- `cmake`, `gettext` - Build dependencies for Neovim
- `net-tools` - Network utilities (ifconfig, netstat, etc.)
- `luarocks` - Lua package manager (for Neovim plugins)

### CLI Tools (installed by setup script)

- **Neovim** - Built from source (`~/tools/neovim`), installed to `~/.local`, with LazyVim and custom plugins
- **fzf** - Fuzzy finder
- **lazygit** - Terminal UI for git
- **gh** - GitHub CLI, latest release tarball into `~/.local/bin` (Ubuntu's own package is far behind)
- **nvm + Node.js** - Latest nvm with LTS Node.js
- **Prettier** - Code formatter (installed globally via npm)
- **rustup** - Rust toolchain installer (installed via snap)
- **uv** - Fast Python package manager
- **Starship** - Cross-shell prompt
- **TPM** - Tmux Plugin Manager
- **bun** - JavaScript runtime (required by gbrain)
- **gbrain** - On by default (`INSTALL_GBRAIN=0` skips it, see below). Personal knowledge brain CLI (installed via bun from the public `garrytan/gbrain` repo — *not* the unrelated npm `gbrain`)
- **Azure CLI (`az`)** - *Not* installed by `postinst` (it needs apt, and the dpkg lock is held during configure). Run `/usr/share/brent-install/scripts/install-azure-cli.sh` after installing the package; used to hydrate secrets from Key Vault

### Dotfiles

- `.tmux.conf` - Tmux configuration
- `.vimrc` - Vim configuration
- `.gitconfig.inc` - Git aliases and settings
- `.jby_bashrc.sh` - Custom bash functions and aliases (also adds `~/.bun/bin` to PATH and sets `GBRAIN_POOL_SIZE=2`)
  - Bootstraps a single ssh-agent per user and exports `SSH_AUTH_SOCK=~/.ssh/agent.sock`,
    a symlink re-pointed at the live agent on each login so tmux panes and long-lived
    processes keep a working agent. Do **not** hardcode that path elsewhere in `.bashrc`
    without an `[ -S ... ]` guard — a stale symlink there breaks the agent in every shell.
- `.config/systemd/user/gbrain-*.service.d/pool-size.conf` - systemd drop-ins capping gbrain's DB pool (survive `/setup-gbrain` regeneration)
- `.gbrain/refresh-gbrain-db-url.sh` - Hydrates the gbrain DB URL from Azure Key Vault into `~/.gbrain/config.json`

## gbrain

gbrain is **on by default**. To skip it — no gbrain CLI, no DB credential
hydration, no MCP registration (an existing install is left alone) — install with:

```bash
sudo INSTALL_GBRAIN=0 apt install ./brent-install_*.deb
```

gstack is not installed by this package.

### MCP registration

With gbrain enabled, `setup.sh` registers it as an MCP server for Claude Code. It **never touches
an existing registration** — on a box running gbrain as an HTTP service the
bearer token lives only in `~/.claude.json` and cannot be reconstructed from
anything in `~/.gbrain`, so an unconditional re-register was unrecoverable.

Fresh installs pick a transport via `GBRAIN_MCP_MODE`:

| Mode | Behavior |
| --- | --- |
| `auto` (default) | Keep any existing registration. Otherwise use HTTP when `GBRAIN_MCP_TOKEN` is set *and* `GBRAIN_MCP_URL` actually answers; else stdio. |
| `stdio` | Force a stdio server (`gbrain serve`). Self-contained — no service, no token. |
| `http` | Force HTTP. Requires `GBRAIN_MCP_TOKEN`; `GBRAIN_MCP_URL` defaults to `http://127.0.0.1:8787/mcp`. |
| `none` | Skip MCP registration entirely. |

```bash
# fresh box, plain stdio (the simple default)
sudo dpkg -i brent-install_*.deb

# fresh box that should talk to a running gbrain-http.service
sudo GBRAIN_MCP_MODE=http GBRAIN_MCP_TOKEN=gbrain_xxx dpkg -i brent-install_*.deb
```

To change an existing registration, remove it first:
`claude mcp remove gbrain -s user`, then re-run with the mode you want.

### gbrain DB credential (one manual step, when enabled)

Secrets are never committed. The gbrain DB credential lives in Azure Key Vault
(`swx-mr-master-dev-kv`, secret `gbrain-db-url` — the full Supabase session-pooler
URL). After installing the package, authenticate once so the credential can be
hydrated:

```bash
az login --tenant 29fc2961-3afa-4f23-97fe-795c7749efdf
~/.gbrain/refresh-gbrain-db-url.sh --force   # writes ~/.gbrain/config.json
gbrain doctor                                # expect: connection Connected
```

After a DB password rotation, update the `gbrain-db-url` KV secret once, then run
`~/.gbrain/refresh-gbrain-db-url.sh --force` on each machine. Reconnect the gbrain
MCP server in Claude Code (`/mcp`) so the `GBRAIN_POOL_SIZE=2` cap takes effect.

> Why the pool cap: gbrain's postgres.js client defaults to 10 connections per
> process; with the MCP server, the daily sync timers, and the CLI all sharing one
> Supabase session pooler, bursts can trip Supavisor's circuit breaker. Capping at
> 2 (in `.jby_bashrc.sh`, the systemd drop-ins, and the MCP server env) prevents it.

## Installation

Download and install the latest release:

```bash
wget https://github.com/byates/brent-install/releases/download/v1.6.0/brent-install_1.6.0.deb
sudo apt install ./brent-install_1.6.0.deb
/usr/share/brent-install/scripts/install-azure-cli.sh   # if az isn't installed yet
```

The post-install script runs automatically to configure your environment.

## Building from Source

```bash
git clone https://github.com/byates/brent-install.git
cd brent-install
make build
sudo apt install ./brent-install_1.6.0.deb
```

### Make Targets

- `make build` - Build the .deb package
- `make clean` - Remove generated files
- `make update` - Download latest config files from gists

## Included Helper Scripts

Scripts installed to `/usr/share/brent-install/scripts/`:

| Script                   | Description                   |
| ------------------------ | ----------------------------- |
| `install-azure-cli.sh`   | Azure CLI from Microsoft apt  |
| `install-build-tools.sh` | Additional build tools        |
| `install-clang20.sh`     | Clang 20 from LLVM apt        |
| `install-gtest.sh`       | Google Test framework         |
| `install-dpdk.sh`        | Data Plane Development Kit    |
| `install-huge-pages.sh`  | Configure huge pages          |
| `install-vpp.sh`         | Vector Packet Processing      |
| `install-memif-lib.sh`   | Memif shared memory interface |
| `test-24-bit-color.sh`   | Test terminal color support   |

## Supported Architectures

- x86_64 (amd64)
- aarch64 / arm64
