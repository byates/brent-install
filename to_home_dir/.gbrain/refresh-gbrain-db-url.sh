#!/usr/bin/env bash
# Hydrate ~/.gbrain/config.json (0600) from Azure Key Vault: the shared brain's
# Supabase connection URL, the OpenAI key used for embeddings, and the pins that
# must match the brain. This is the single source of truth for gbrain's
# credentials, so a rotation is a one-place update: rotate the secret in KV,
# then run this with --force on each machine and restart gbrain-http.
#
# KV secrets (vault swx-mr-master-dev-kv):
#   gbrain-db-url         Supabase TRANSACTION pooler URL (:6543) — main traffic,
#                         written to config.json database_url
#   gbrain-direct-db-url  Supabase SESSION pooler URL (:5432) — DDL and
#                         session-scoped advisory locks (schema-init guard,
#                         doctor, autopilot). Written to ~/.gbrain/http.env as
#                         GBRAIN_DIRECT_DATABASE_URL for gbrain-http.service. Needed
#                         because the auto-derived direct db.<ref>.supabase.co
#                         endpoint is IPv6-only.
#   openai-api-key        OpenAI key for embeddings
#
# Usage:
#   ~/.gbrain/refresh-gbrain-db-url.sh           # write if config.json is missing either credential
#   ~/.gbrain/refresh-gbrain-db-url.sh --force   # always re-pull (use after a rotation)

set -euo pipefail

VAULT="swx-mr-master-dev-kv"
DB_SECRET="gbrain-db-url"
OPENAI_SECRET="openai-api-key"
DIRECT_SECRET="gbrain-direct-db-url"
# The brain's embedding pin. Every host writing to the shared brain must use
# the same model and dimensions, or its vectors are useless to the others.
EMBEDDING_MODEL="${GBRAIN_EMBEDDING_MODEL:-openai:text-embedding-3-large}"
EMBEDDING_DIMENSIONS="${GBRAIN_EMBEDDING_DIMENSIONS:-1536}"
OUT="$HOME/.gbrain/config.json"
HTTP_ENV="$HOME/.gbrain/http.env"

force=0
[ "${1:-}" = "--force" ] && force=1

has_key() { jq -e --arg k "$1" '(.[$k] // "") | length > 0' "$OUT" >/dev/null 2>&1; }

if [ "$force" = 0 ] && [ -f "$OUT" ] && has_key database_url && has_key openai_api_key &&
  grep -q '^GBRAIN_DIRECT_DATABASE_URL=.' "$HTTP_ENV" 2>/dev/null; then
  echo "config.json and http.env already hold gbrain's credentials — no refresh needed."
  echo "Re-pull after a rotation with: $0 --force"
  exit 0
fi

if ! command -v az >/dev/null 2>&1; then
  echo "ERROR: az CLI not on PATH. Install it with /usr/share/brent-install/scripts/install-azure-cli.sh" >&2
  exit 1
fi

# Probe az auth before clobbering the existing file.
if ! az account show >/dev/null 2>&1; then
  echo "ERROR: az not logged in. Run: az login --tenant 29fc2961-3afa-4f23-97fe-795c7749efdf" >&2
  [ -f "$OUT" ] && echo "Keeping existing $OUT (may be stale)." >&2
  exit 1
fi

umask 077
mkdir -p "$(dirname "$OUT")"

kv_get() {
  local name="$1" val
  if ! val="$(az keyvault secret show --vault-name "$VAULT" --name "$name" --query value -o tsv 2>&1)"; then
    echo "ERROR: Key Vault fetch of '$name' failed:" >&2
    echo "$val" >&2
    [ -f "$OUT" ] && echo "Keeping existing $OUT (may be stale)." >&2
    return 1
  fi
  printf '%s' "$val"
}

url="$(kv_get "$DB_SECRET")"
openai_key="$(kv_get "$OPENAI_SECRET")"
direct_url="$(kv_get "$DIRECT_SECRET")"

# Validate shapes without echoing the secrets.
for pair in "$DB_SECRET:$url" "$DIRECT_SECRET:$direct_url"; do
  if ! printf '%s' "${pair#*:}" | grep -qE '^postgres(ql)?://[^[:space:]]+@[^[:space:]]+/[^[:space:]]+$'; then
    echo "ERROR: ${pair%%:*} is not a postgres URL; aborting (nothing written)." >&2
    exit 1
  fi
done
if ! printf '%s' "$openai_key" | grep -qE '^sk-[A-Za-z0-9_-]{20,}$'; then
  echo "ERROR: $OPENAI_SECRET does not look like an OpenAI key; aborting (not written)." >&2
  exit 1
fi

tmp="$(mktemp "$OUT.tmp.XXXXXX")"
envtmp="$(mktemp "$HTTP_ENV.tmp.XXXXXX")"
trap 'rm -f "$tmp" "$envtmp"' EXIT

# Merge into any existing config so other keys survive. Secrets go to jq via
# the environment ($ENV), not argv, so they never show up in `ps`.
base='{}'
[ -f "$OUT" ] && base="$(cat "$OUT")"
printf '%s' "$base" |
  GB_URL="$url" GB_OPENAI="$openai_key" GB_MODEL="$EMBEDDING_MODEL" GB_DIMS="$EMBEDDING_DIMENSIONS" \
    jq '. + {
      engine: "postgres",
      database_url: $ENV.GB_URL,
      openai_api_key: $ENV.GB_OPENAI,
      embedding_model: $ENV.GB_MODEL,
      embedding_dimensions: ($ENV.GB_DIMS | tonumber)
    }' >"$tmp"

# systemd EnvironmentFile: KEY=value, no quoting needed for a URL.
printf 'GBRAIN_DIRECT_DATABASE_URL=%s\n' "$direct_url" >"$envtmp"

chmod 600 "$tmp" "$envtmp"
mv "$tmp" "$OUT"
mv "$envtmp" "$HTTP_ENV"
echo "OK: wrote gbrain credentials to $OUT and $HTTP_ENV (0600)."
echo "Restart the server to pick them up: systemctl --user restart gbrain-http"
