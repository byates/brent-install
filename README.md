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

### CLI Tools (installed by setup script)

- **Neovim** - Built from source (`~/tools/neovim`), installed to `~/.local`, with LazyVim starter config
- **fzf** - Fuzzy finder
- **lazygit** - Terminal UI for git
- **nvm + Node.js** - Latest nvm with LTS Node.js
- **Prettier** - Code formatter (installed globally via npm)
- **rustup** - Rust toolchain installer (installed via snap)
- **uv** - Fast Python package manager
- **Starship** - Cross-shell prompt
- **TPM** - Tmux Plugin Manager

### Dotfiles

- `.tmux.conf` - Tmux configuration
- `.vimrc` - Vim configuration
- `.gitconfig.inc` - Git aliases and settings
- `.jby_bashrc.sh` - Custom bash functions and aliases

## Installation

Download and install the latest release:

```bash
wget https://github.com/byates/brent-install/releases/download/v1.0.0/brent-install_1.0.0.deb
sudo apt install ./brent-install_1.0.0.deb
```

The post-install script runs automatically to configure your environment.

## Building from Source

```bash
git clone https://github.com/byates/brent-install.git
cd brent-install
make build
sudo apt install ./brent-install_1.0.0.deb
```

### Make Targets

- `make build` - Build the .deb package
- `make clean` - Remove generated files
- `make update` - Download latest config files from gists

## Included Helper Scripts

Scripts installed to `/usr/share/brent-install/scripts/`:

| Script                   | Description                   |
| ------------------------ | ----------------------------- |
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
