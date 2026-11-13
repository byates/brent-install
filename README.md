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
- `.config/systemd/user/gbrain-http.service` - The host's single local gbrain MCP server (`127.0.0.1:8787`), plus `gbrain-http-liveness.{service,timer}` and `.gbrain/gbrain-http-liveness.sh`, which restart it if `/health` stops answering
- `.gbrain/refresh-gbrain-db-url.sh` - Hydrates gbrain's credentials from Azure Key Vault into `~/.gbrain/config.json` and `~/.gbrain/http.env`

## gbrain

gbrain is **on by default**. To skip it — no gbrain CLI, no credentials, no
server, no MCP registration (an existing install is left alone) — install with:

```bash
sudo INSTALL_GBRAIN=0 apt install ./brent-install_*.deb
```

gstack is not installed by this package.

### How it runs

Each host runs **one** local gbrain server, `gbrain-http.service` (a systemd
*user* service, `gbrain serve --http` on `127.0.0.1:8787`), which talks straight
to the shared Supabase brain. Every Claude Code session on the host connects to
it over HTTP with a bearer token minted on that host. Don't use per-session
stdio servers: each one opens its own DB pool, and together they blew the
Supabase session pooler's 15-client cap (`EMAXCONNSESSION`).

An install with gbrain enabled:

1. installs the gbrain CLI (bun, from the public `garrytan/gbrain` repo);
2. hydrates credentials from Key Vault (below);
3. enables linger for the user (postinst, as root) so the service survives
   logout and reboot, then starts `gbrain-http` and its once-a-minute liveness
   timer and waits for `/health`;
4. if Claude Code has no `gbrain` MCP entry yet, mints a token with
   `gbrain auth create claude-code-<hostname>` and registers it at **user**
   scope via `gbrain connect --install`. That also writes gbrain's brain-first
   block into `~/.claude/CLAUDE.md` and a `UserPromptSubmit` hook.

Pool size is 3 per host (`GBRAIN_POOL_SIZE` in the unit; vm001 runs 6). All
hosts share one 15-client pooler, so check the total before raising it. To
change it on one host: `systemctl --user edit gbrain-http`.

### Credentials (Azure Key Vault)

Secrets are never committed. `~/.gbrain/refresh-gbrain-db-url.sh` reads three
secrets from `swx-mr-master-dev-kv`:

| Secret | What it is | Written to |
| --- | --- | --- |
| `gbrain-db-url` | Supabase **transaction** pooler URL (`:6543`), main traffic | `config.json` `database_url` |
| `gbrain-direct-db-url` | Supabase **session** pooler URL (`:5432`), DDL and advisory locks | `http.env` `GBRAIN_DIRECT_DATABASE_URL` |
| `openai-api-key` | OpenAI key for embeddings | `config.json` `openai_api_key` |

It also pins `engine: postgres` and `embedding_model: openai:text-embedding-3-large`
/ `embedding_dimensions: 1536`, which must match the brain. `az` has to be
installed and logged in first:

```bash
/usr/share/brent-install/scripts/install-azure-cli.sh
az login --tenant 29fc2961-3afa-4f23-97fe-795c7749efdf
sudo apt install --reinstall ./brent-install_*.deb   # or re-run setup.sh
gbrain doctor
```

After a rotation, update the KV secret once, then on each host run
`~/.gbrain/refresh-gbrain-db-url.sh --force && systemctl --user restart gbrain-http`.

### MCP registration modes

Setup **never touches an existing `gbrain` MCP entry**: its bearer token lives only
in `~/.claude.json`, so replacing it would be unrecoverable. To change one, run
`claude mcp remove gbrain -s user` and re-run setup. `GBRAIN_MCP_MODE` picks what
a fresh install registers:

| Mode | Behavior |
| --- | --- |
| `auto` (default) | The local `gbrain-http` server, with a token minted for this host. Skipped if the server isn't up. |
| `http` | Some other endpoint: `GBRAIN_MCP_URL` (default the local one) plus `GBRAIN_MCP_TOKEN`. |
| `stdio` | A per-session `gbrain serve`. Not recommended; see above. |
| `none` | Register nothing. |

```bash
sudo GBRAIN_MCP_MODE=http GBRAIN_MCP_URL=http://host:8787/mcp GBRAIN_MCP_TOKEN=gbrain_xxx apt install ./brent-install_*.deb
```

The token goes from postinst to setup in a 0600 temp file, and from setup to
gbrain through the environment, so it never sits in `ps` for the run. It does
land in your shell history if you type it as above.

## Installation

Download and install the latest release:

```bash
wget https://github.com/byates/brent-install/releases/download/v1.7.0/brent-install_1.7.0.deb
sudo apt install ./brent-install_1.7.0.deb
/usr/share/brent-install/scripts/install-azure-cli.sh   # if az isn't installed yet
```

The post-install script runs automatically to configure your environment.

## Building from Source

```bash
git clone https://github.com/byates/brent-install.git
cd brent-install
make build
sudo apt install ./brent-install_1.7.0.deb
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
