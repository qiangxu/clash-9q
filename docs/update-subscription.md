# 更新订阅链接

适用场景：旧 URL 失效 / 续费换地址 / 换机场。

> 日常订阅"内容"更新（同一 URL 后端节点列表变了）不走这里 —— 直接在 mac 上跑 `./scripts/sync-from-gui.sh` 即可，V-Ninja GUI 会按 interval 自动拉新版。

## 步骤

1. **mac 上 V-Ninja GUI**：打开「订阅 / Profile」页，删除旧的，添加新订阅 URL，把"当前 Profile"切到新的（图标变成 Active 状态）。
2. **等 GUI 拉取**：节点列表会刷新成新机场的列表，proxy-groups 也跟着变。
3. **本机先验**：在 GUI 的看板里点几个节点测速，确认能跑（这一步是为了排除新订阅本身有问题）。
4. **同步到远端**：
   ```bash
   ./scripts/sync-from-gui.sh
   ```
5. **远端验证**：
   ```bash
   ssh -J qiangxu@112.124.26.131:48425 qiangxu@192.168.3.180 \
     'curl -sS -x http://127.0.0.1:7890 --max-time 15 https://ifconfig.co/json'
   ```
   看到国外 exit IP 即成功。

## 同步前必须先看一眼：节点 `server` 形态

新订阅 yaml 里的 `server:` 字段直接决定 server 能不能独立跑。在 mac 上找到 GUI 当前用的 runtime yaml（路径定位见 [`findings.md` §5](findings.md#5-gui-渲染后的真实配置在哪)），grep 一下：

```bash
RUNTIME=$(ps -axo command= | grep -m1 -E '/ninja-mihomo .* -f /' | sed -nE 's/.* -f ([^ ]+).*/\1/p')
grep -E '^  server:' "$RUNTIME" | head -3
```

| 看到的形态 | 远端能跑吗 |
|---|---|
| `static-*.cdn.cnameip.xyz` / 真实公网域名 / 直接 IP | ✅ 公网 DNS 可解，sync 后直接 OK |
| `cname01x-*.cdn.cnameip.xyz` 等旧版混淆域名 | ❌ NXDOMAIN，节点连接靠 GUI 内部解码（详见 [`findings.md` §3](findings.md#3-节点-server-域名有新旧两套连通性完全不同)） |

发现是旧版混淆域名：联系机场客服要"新格式订阅链接"，或者考虑换机场。`sync-from-gui.sh` 推过去的 yaml 会跑起来但所有节点都连不上，故障排查时会看到 `dns resolve failed: couldn't find ip`。

## 跑完 sync 后做什么

- 流量验证：上面步骤 5 的 `curl ifconfig.co`
- 选节点：浏览器开 yacd 看板（[`runbook.md` §5](runbook.md#5-本地访问-dashboard选节点--看流量)）
- 出错排查：[`runbook.md` §6 故障排查清单](runbook.md#6-故障排查清单)

## 多实例并存（可选）

要同时保留两套订阅各跑一个 systemd 实例（如 `ninja@hk` 和 `ninja@jp`）：参 [`runbook.md` §7 从零部署一份新实例](runbook.md#7-从零部署一份新实例)。注意每个实例的 `mixed-port` 和 `external-controller` 端口都要错开。
