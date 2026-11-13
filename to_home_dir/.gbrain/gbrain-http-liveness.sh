#!/usr/bin/env bash
# Liveness probe for gbrain-http.service (run by gbrain-http-liveness.timer).
# Only acts on a server systemd believes is running: if it is active but
# /health doesn't answer within 10s, twice in a row, restart it.
set -u
PORT="${GBRAIN_HTTP_PORT:-8787}"
systemctl --user is-active --quiet gbrain-http.service || exit 0
for _ in 1 2; do
  curl -fsS --max-time 10 -o /dev/null "http://127.0.0.1:${PORT}/health" && exit 0
  sleep 5
done
echo "gbrain-http not answering /health on :${PORT}; restarting" >&2
systemctl --user restart gbrain-http.service
