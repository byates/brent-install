#!/bin/bash
# Install the Azure CLI (az) from Microsoft's apt repo.
#
# This is a separate script, not part of postinst, because it has to run
# apt-get. A postinst runs while the outer `apt install` / `dpkg -i` holds the
# dpkg lock, so any nested apt-get install fails with "Could not get lock",
# which used to abort the whole package configure. Run this one afterwards, as
# your normal user (it calls sudo itself), or pick it from ~/brent-install.sh.
#
# Wanted by ~/.gbrain/refresh-gbrain-db-url.sh to hydrate secrets from Key Vault.
set -euo pipefail

if [ -n "${DPKG_MAINTSCRIPT_NAME:-}" ]; then
  echo "install-azure-cli.sh cannot run from a dpkg maintainer script (dpkg lock is held)." >&2
  exit 1
fi

if command -v az >/dev/null 2>&1; then
  echo "Azure CLI already installed: $(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo present)"
  exit 0
fi

REPO_BASE="https://packages.microsoft.com/repos/azure-cli"
ARCH=$(dpkg --print-architecture)

# Prefer this release's own suite; fall back to the newest LTS Microsoft is
# known to publish, so a brand-new Ubuntu release isn't a hard failure.
. /etc/os-release
SUITE=""
for candidate in "${DIST_CODE:-}" "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}" noble jammy; do
  [ -n "$candidate" ] || continue
  if curl -fsSL -o /dev/null "$REPO_BASE/dists/$candidate/main/binary-$ARCH/Packages"; then
    SUITE="$candidate"
    break
  fi
done
if [ -z "$SUITE" ]; then
  echo "No azure-cli suite for $ARCH found under $REPO_BASE/dists/ (set DIST_CODE=<suite> to force one)." >&2
  exit 1
fi
echo "Using Microsoft azure-cli suite '$SUITE' ($ARCH)"

sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

sudo rm -f /etc/apt/sources.list.d/azure-cli.list
sudo tee /etc/apt/sources.list.d/azure-cli.sources >/dev/null <<EOF
Types: deb
URIs: $REPO_BASE/
Suites: $SUITE
Components: main
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y azure-cli
az version
