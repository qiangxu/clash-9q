# clash-9q — agent guide

跑在远端 Ubuntu 上的 V-Ninja (`ninja-mihomo`) 代理服务，systemd template 模式；mac 上的 V-Ninja GUI 是订阅入口，远端是 GUI 配置的下游静态拷贝。

## 任务路由 — 用户提到什么，先打开什么

| 用户提到 | 入口 |
|---|---|
| 远端服务挂了 / 重启 / 看日志 / 查状态 | [`docs/runbook.md`](docs/runbook.md) §2-§3 |
| 不知道为什么 X 这么设计 / 历史根因 | [`docs/findings.md`](docs/findings.md) |
| 换订阅 URL / 换机场 | [`docs/update-subscription.md`](docs/update-subscription.md) |
| 拉新一版节点（同一个 URL，机场自己更新） | 直接跑 `scripts/sync-from-gui.sh` |
| 浏览器看 dashboard 选节点 | [`docs/runbook.md`](docs/runbook.md) §5 |
| 让远端命令行走代理 (curl / git / apt / docker / npm / pip) | [`docs/runbook.md`](docs/runbook.md) §8 |
| 多实例 / 加 `ninja@<其他>` | [`docs/runbook.md`](docs/runbook.md) §7 |
| 紧急回滚 | [`docs/runbook.md`](docs/runbook.md) §9 |

## 不变量（改动前必须保持，否则会破坏现有部署）

- **远端**：`qiangxu@192.168.3.180`，跳板 `qiangxu@112.124.26.131:48425`；远端 `qiangxu` 有 NOPASSWD sudo
- **远端 mihomo 监听**：
  - `7890` 是 mixed-port (HTTP + SOCKS5)，bind `127.0.0.1`
  - `9090` 是 RESTful API + dashboard，bind `0.0.0.0`（**必须 LAN 可达**，浏览器走 SOCKS 进 180 时默认绕过 loopback，只有 LAN IP 才解得开）
- **Dashboard secret**：`9q-ninja-local`，**同时**存在于 `scripts/sync-from-gui.sh` 的 `EXTERNAL_CONTROLLER_SECRET` 和远端 yaml 的 `secret:` 行
- **远端 alias**：`tkk` 开代理 / `sgg` 关代理（`~/.bashrc` 第 140-141 行）
- **真实节点配置只能从一个地方拿**：mac V-Ninja GUI 启动的 `ninja-mihomo` 进程的 `-f` 参数指向的 tmpfile —— 订阅原文里的 `server:` 是占位域名（参 [findings.md §3 + §5](docs/findings.md)）
- **不入 git**：`config/*.yaml`、`config/providers/`、`config/cache.db`、`.DS_Store`（`.gitignore` 已挡）

## 别做

- ❌ 把 `secret:` 留空 — yacd 表单要求非空，登录页会卡死
- ❌ 把 `external-controller` 改回 `127.0.0.1:9090` — Chrome / Safari 默认绕过 loopback，浏览器走 SOCKS 也打不开 dashboard
- ❌ 把仓库里旧的 `mihomo-linux-amd64-v1.19.11` / `clash-linux-amd64` 拿来跑 `type: ninja` 节点 — 只有 `bin/ninja-mihomo`（V-Ninja fork）能识别这个协议
- ❌ 从 `~/Library/Application Support/.../profiles/*.yaml` 抽节点 — 那里的 server 字段是 GUI 渲染前的占位域名
- ❌ 把含 token / 节点密码的 yaml commit 进仓库

## 操作约定

- **远端改动要幂等**：用户网络不稳定（偶有 socket failure），多步流水线中途断了不能留半残状态。`sync-from-gui.sh` 的设计原则也是 — 重跑一次等价于跑过。
- **网络类失败默认重试一次**：git push、scp、ssh 偶发 `sideband disconnect` / `connection closed` 时，先重试再排查
- **改 systemd unit / yaml 后**：远端要 `daemon-reload` + `restart`，否则 systemd 用旧版

## 当前部署状态（截至最近 commit，agent 不必每次重新发现）

- 唯一在线 systemd 实例：`ninja@ninja`（HTTPS proxy 验证过出香港）
- 旧 `clash@.service` template 已从 systemd 卸载
- 旧 mac-on-180 桌面 GUI `clash-verge`（自启）已清掉 autostart 并 kill 进程；apt 包未卸
- `bin/V-Ninja_2.3.1_*.deb` 留在仓库作可追溯，`ninja-mihomo` 已从 amd64 deb 抽出
