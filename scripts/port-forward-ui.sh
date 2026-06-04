#!/usr/bin/env bash
# Open an SSH tunnel from localhost:<port> to the remote mihomo RESTful API
# (and the bundled yacd dashboard at /ui/), so you can use the dashboard in
# your local browser. Ctrl-C closes the tunnel.
#
# Usage: scripts/port-forward-ui.sh [local_port]   # default 1234

set -euo pipefail

JUMP="qiangxu@112.124.26.131:48425"
REMOTE="qiangxu@192.168.3.180"
REMOTE_API="127.0.0.1:9090"
LOCAL_PORT="${1:-1234}"

URL="http://localhost:${LOCAL_PORT}/ui/"
echo "tunneling localhost:${LOCAL_PORT} -> ${REMOTE_API} via ${JUMP}"
echo "open:     ${URL}"
echo "(Ctrl-C to close)"

if command -v open >/dev/null 2>&1; then
  (sleep 1 && open "${URL}") &
fi

exec ssh -N -o LogLevel=QUIET -o ForwardAgent=yes -o BatchMode=yes \
  -o ExitOnForwardFailure=yes \
  -L "${LOCAL_PORT}:${REMOTE_API}" \
  -J "${JUMP}" "${REMOTE}"
