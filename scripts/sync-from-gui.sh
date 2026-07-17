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
# Re-inject a server-side TUN (system stack) + fake-ip DNS so 透明代理 survives
# every sync. Programs that don't honour HTTP(S)_PROXY get caught by the TUN.
# NOTE: node/Claude Code should still use the HTTP(S)_PROXY env (127.0.0.1:7890,
# loopback -> mixed-port, ~9/10). The system-stack TUN path is weaker for node.js
# TLS (~6/10); gVisor stack was ~0/10 — do NOT use gVisor here.
txt += """
tun:
  enable: true
  stack: system
  auto-route: true
  auto-redirect: true
  auto-detect-interface: true
  dns-hijack:
    - any:53
  mtu: 1500
dns:
  enable: true
  listen: 0.0.0.0:1053          # NOT :53 — avoid clashing with systemd-resolved stub
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 28.0.0.1/8
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "+.internal"
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
    - https://1.1.1.1/dns-query
  fallback:
    - 8.8.8.8
    - 1.1.1.1
"""
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
