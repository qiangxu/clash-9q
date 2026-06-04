#!/usr/bin/env bash
# Push the active Clash V-Ninja GUI config (on this Mac) to the remote
# ninja@<instance> service. Run after the GUI pulls a fresh subscription
# so the headless server picks up the new node list.
#
# Usage: scripts/sync-from-gui.sh [instance]   # default instance: ninja
#
# Prerequisites:
#   - Clash V-Ninja GUI running locally (ninja-mihomo process must be alive)
#   - SSH agent forwarding to the remote (through the jump host)
#   - Remote user has NOPASSWD sudo for systemctl

set -euo pipefail

JUMP="qiangxu@112.124.26.131:48425"
REMOTE="qiangxu@192.168.3.180"
REMOTE_CONFIG_PATH="Projects/clash-9q/config/ninja.yaml"
INSTANCE="${1:-ninja}"
MIXED_PORT=7890
EXTERNAL_CONTROLLER="0.0.0.0:9090"            # LAN-reachable so a SOCKS-into-180 browser can hit it
EXTERNAL_CONTROLLER_SECRET="9q-ninja-local"   # also required by yacd login form

RUNTIME_YAML=$(ps -axo command= 2>/dev/null \
  | grep -m1 -E '/ninja-mihomo .* -f /' \
  | sed -nE 's/.* -f ([^ ]+).*/\1/p' || true)

if [[ -z "${RUNTIME_YAML}" || ! -r "${RUNTIME_YAML}" ]]; then
  echo "ERROR: could not locate the V-Ninja GUI runtime yaml." >&2
  echo "  (inspected the -f arg of the ninja-mihomo process)" >&2
  echo "Is Clash V-Ninja GUI running?" >&2
  exit 1
fi
echo "source : ${RUNTIME_YAML}"

DEPLOY_YAML=$(mktemp -t clash-9q-ninja-deploy)
trap 'rm -f "${DEPLOY_YAML}"' EXIT

python3 - "${RUNTIME_YAML}" "${DEPLOY_YAML}" "${MIXED_PORT}" "${EXTERNAL_CONTROLLER}" "${EXTERNAL_CONTROLLER_SECRET}" <<'PY'
import re, sys
src, dst, port, ec, secret = sys.argv[1:6]
txt = open(src).read()
def strip_top_section(text, key):
    return re.sub(rf"^{re.escape(key)}:\n(?:[ \t-].*\n)+", "", text, flags=re.M)
txt = re.sub(r"^mixed-port: \d+", f"mixed-port: {port}", txt, flags=re.M)
txt = re.sub(r"^external-controller: \S+", f"external-controller: {ec}", txt, flags=re.M)
if re.search(r"^secret: ", txt, flags=re.M):
    txt = re.sub(r"^secret: .*", f"secret: {secret}", txt, flags=re.M)
else:
    txt = re.sub(r"^(external-controller: \S+)$", rf"\1\nsecret: {secret}", txt, flags=re.M)
for k in ("dns", "tun", "external-controller-cors"):
    txt = strip_top_section(txt, k)
open(dst, "w").write(txt)
PY
echo "rewrote: $(wc -l < "${DEPLOY_YAML}") lines"

echo "scp -> ${REMOTE}:${REMOTE_CONFIG_PATH}"
scp -q -o LogLevel=QUIET -o ForwardAgent=yes -o BatchMode=yes -J "${JUMP}" \
  "${DEPLOY_YAML}" "${REMOTE}:${REMOTE_CONFIG_PATH}"

ssh -o LogLevel=QUIET -o ForwardAgent=yes -o BatchMode=yes -J "${JUMP}" "${REMOTE}" "
set -e
sudo systemctl restart ninja@${INSTANCE}
sleep 5
echo '=== status ==='
systemctl is-active ninja@${INSTANCE}
echo '=== https proxy test ==='
curl -sS -x http://127.0.0.1:${MIXED_PORT} -o /dev/null -w 'HTTP %{http_code} time=%{time_total}s\n' -I https://www.google.com --max-time 15 || echo 'proxy curl FAILED'
echo '=== exit IP ==='
curl -sS -x http://127.0.0.1:${MIXED_PORT} --max-time 15 https://ifconfig.co/json | grep -E '\"(ip|country)\"' || true
"
