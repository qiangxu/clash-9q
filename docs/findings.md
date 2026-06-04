# V-Ninja 落地过程中的关键发现

迁移 clash → V-Ninja 过程中踩到的非显然的点，按时间线汇总。

## 1. `bin/ninja-mihomo` 是必需的，不能换成标准 mihomo

V-Ninja 本质是 Clash Verge 的 fork (`Provides: clash-ninja`，依赖 `libayatana-appindicator3` / `libwebkit2gtk` —— 桌面 GUI)。但 deb 包里捎带了一份自家的 mihomo 内核 `ninja-mihomo`（19MB ELF，静态链接 amd64，跟 metacubex/mihomo 同根）。

关键差异：**标准 mihomo 不识别 `type: ninja` 协议**。V-Ninja 自家节点形态：

```yaml
- name: ...
  type: ninja
  method: aes-128-gcm
  password: ...
  node_password: ...
  udp-over-tcp: true
  udp-over-tcp-version: 2
  tls: true
```

—— 只有 `ninja-mihomo` 能解析。曾试着复用仓库里已有的 `mihomo-linux-amd64-v1.19.11`，日志直接 `unknown proxy type: ninja` 起不来。

`bin/clash-ninja` (Tauri GUI 主进程) 和 `bin/clash-ninja-service` (特权 helper) 在 headless server 上用不到，所以**只抽 `ninja-mihomo`，不 `dpkg -i` 整个包**。

## 2. 订阅 URL 不能裸 IP 拉

订阅地址 `https://45.137.181.195/222/ninja/<token>` 用 mihomo `proxy-providers` 拉返回 `403 Forbidden`，body 是 `{"error":"Access denied."}`。换各种 User-Agent (clash、mihomo、clash-verge、Clash Verge Ninja) 同 403 —— 不是 UA 反爬。

GUI 自己的 yaml 顶部头是 `#!MANAGED-CONFIG https://xn--usw99d.net/222/ninja/<token>` —— 走的是 IDN 域名（Punycode `xn--usw99d.net`）。**服务端校验 SNI/Host**，IP 直访不放行。

我们没修这个，而是改抓 GUI 渲染后的 yaml（见 §5）。

## 3. 节点 server 域名有新旧两套，连通性完全不同

机场后端在迭代节点命名方案：

| 模式 | 例子 | 公网 DNS 解析 | 工作机制 |
|---|---|---|---|
| 旧版 | `cname01b-igsg7vdk98w8tm8oc6zt3g8qpjxruakn.cdn.cnameip.xyz` | **NXDOMAIN** (authoritative SOA 是 dnspod 但没注册子域名) | GUI 用 yaml 顶部 `#!PASS-INFO` 那串 base64 解码出真实 CDN IP，注入到内核 |
| 新版 | `static-tun-auto-mnphft.cdn.cnameip.xyz`、`static-iepl-{auto,cu,ct,cm}-mndwpc.cdn.cnameip.xyz` | 直接解到 `113.96.24.109` / `113.96.24.115` 等真实 CDN IP | 标准 DNS 流程，任何 mihomo fork 都能跑 |

用户最初手动复制贴过来的 yaml 是**旧版**（含 PASS-INFO，server 是 cname01x-）—— 在 server 上直接喂给 ninja-mihomo 会因 NXDOMAIN 节点连不上。但 GUI 当前实际正在跑的 yaml（在 `/var/folders/.../T/<random>`）已经是新版。

**结论**：只要 GUI 拉到的最新 yaml 走新域名方案，server 就能完全独立运行，不再依赖 PASS-INFO 解码。`scripts/sync-from-gui.sh` 就建立在这个前提之上。

## 4. mihomo RESTful API 不暴露节点 server

`GET /proxies` 返回的 proxy 对象含 `name / alive / history / type / udp`，但**没有 `server / port / password / method`** 字段（隐私设计；`type` 字段在外部观察者眼里甚至会显示成 `"Unknown"`）。指望通过 API 反查节点真实地址行不通。

`GET /providers/proxies` 也是一样的过滤。

## 5. GUI 渲染后的真实配置在哪

V-Ninja GUI 启动 ninja-mihomo 时把渲染后的最终 yaml 写到 mac 临时目录：

```
ps -axo command= | grep ninja-mihomo
/Applications/.../ninja-mihomo -d <APP_SUPPORT> -f /var/folders/.../T/<RANDOM>
```

文件名是 mktemp 风格的 11 字符随机串（每次 GUI 启动 / 配置切换都重生成），但权限是 `qiangxu:staff`，无需 sudo 就能读。

另一个候选目录 `~/Library/Application Support/io.github.clash-verge-ninja.clash-verge-ninja/profiles/` 下放的是订阅原文 + 用户合并脚本，但**节点 server 在这里还是旧版占位域名**（GUI 渲染前的状态），不能直接用。要用的是 ninja-mihomo 进程 `-f` 指向的那个 tmp 文件。

`scripts/sync-from-gui.sh` 用 `ps` 抓 `-f` 参数定位。

## 6. HTTP 测试可能"假成功"，要以 HTTPS 为准

切到 ninja-mihomo 跑旧版 yaml 时观察到：

| 测试 | 结果 |
|---|---|
| `curl -x localhost:7890 -I http://www.gstatic.com/generate_204` | HTTP 204 (55ms) — 看上去成功 |
| `curl -x localhost:7890 -I https://www.google.com` | 立刻失败 (0.0002s)，SSL handshake unexpected EOF |
| `curl -x localhost:7890 https://ifconfig.co/json` | 同上失败 |

HTTPS 通过代理需要 mihomo 先 dial `节点 server:port` 才能建 CONNECT 隧道；节点 server 是 NXDOMAIN 时 dial 失败。HTTP 那次反而像巧合 —— 命中了某条 DIRECT 规则、或者 HTTP 请求路径在 mihomo 早期阶段就被 sniffer 短路了。

**经验**：永远以 `curl https://ifconfig.co/json` 看到正确的国外 exit IP 为准。HTTP 头部测试可能误导。

## 7. server 上别开 fake-ip + TUN + dns.listen:53

GUI 的 yaml 顶部默认：

```yaml
dns:
  enable: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  listen: :53
tun:
  enable: true
  device: utun1024
  dns-hijack: [any:53]
  stack: gvisor
```

在 mac 上配合 utun 设备做全局透明代理。但 headless server 上：

- TUN 需要 NET_ADMIN，且服务器没什么入站流量要劫持，做了也没意义
- `dns.listen: :53` 会跟 systemd-resolved 抢端口（`/run/systemd/resolve/stub-resolv.conf` 上的 127.0.0.53）
- `fake-ip` 没了 TUN 配合就只是脏数据

所以 `sync-from-gui.sh` 把 `dns:` / `tun:` / `external-controller-cors:` 整段删掉，mihomo 走系统 DNS（resolv.conf → 系统 resolver → 公网 DNS）就够。
