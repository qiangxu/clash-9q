# 远程 ninja 服务运维 runbook

按场景汇总 SSH / sudo / 服务管理命令。背景见 [`findings.md`](findings.md)。

## 0. 连接

跳板机 → 内网机：

```
ssh -o LogLevel=QUIET -o ForwardAgent=yes -o ConnectTimeout=10 \
    -J qiangxu@112.124.26.131:48425 qiangxu@192.168.3.180
```

远端机器 `dolphin`，Ubuntu 22.04，kernel 6.8。远端 `qiangxu` 拥有 NOPASSWD sudo —— 所有命令都假设这个。

## 1. 关键路径

| 项 | 路径 |
|---|---|
| 仓库根 | `~/Projects/clash-9q/` |
| 内核二进制 | `~/Projects/clash-9q/bin/ninja-mihomo` |
| systemd 模板 | `/etc/systemd/system/ninja@.service` |
| 实例配置 | `~/Projects/clash-9q/config/<instance>.yaml` |
| GeoIP 数据 | `~/Projects/clash-9q/config/Country.mmdb` |
| dashboard 静态资源 | `~/Projects/clash-9q/ui/` |
| 默认监听 | `127.0.0.1:7890` (HTTP/SOCKS) + `127.0.0.1:9090` (RESTful API) |

实例名 `<instance>` 对应 `config/<instance>.yaml`，当前已上线：`ninja`。

## 2. 服务管理

```bash
# 状态
systemctl is-active ninja@ninja
systemctl status ninja@ninja --no-pager
sudo journalctl -u ninja@ninja -n 50 --no-pager   # 静态查
sudo journalctl -u ninja@ninja -f                 # 实时跟踪

# 控制
sudo systemctl restart ninja@ninja
sudo systemctl stop ninja@ninja
sudo systemctl enable --now ninja@ninja
sudo systemctl disable --now ninja@ninja

# 改 unit 文件后
sudo cp ~/Projects/clash-9q/system/ninja@.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart ninja@<instance>
```

## 3. 验证代理工作

从远端本机：

```bash
curl -sS -x http://127.0.0.1:7890 -o /dev/null \
     -w 'HTTP %{http_code} time=%{time_total}s\n' \
     -I https://www.google.com --max-time 15

# 出口 IP（看到机场归属地即正常）
curl -sS -x http://127.0.0.1:7890 --max-time 15 https://ifconfig.co/json
```

不要只测 HTTP，参见 [`findings.md` §6](findings.md#6-http-测试可能假成功要以-https-为准)。

## 4. 同步新订阅（在 mac 上跑）

V-Ninja GUI 在 mac 上会自动拉新订阅。要把同样的配置推到远端：

```bash
./scripts/sync-from-gui.sh           # 默认 ninja@ninja
./scripts/sync-from-gui.sh other     # ninja@other
```

脚本逻辑：抓 GUI 内核当前用的 yaml → 删 `tun:` / `dns:` / `secret:` / `external-controller-cors:` 段 → 改端口为 7890 / 9090 → scp 到远端 `config/<instance>.yaml` → 重启 `ninja@<instance>` → 验证。

**前提**：mac 上 Clash V-Ninja GUI 必须正在运行（脚本通过 ninja-mihomo 进程的 `-f` 参数定位 yaml 路径）。

## 5. 本地访问 dashboard（选节点 / 看流量）

远端 mihomo 在 `127.0.0.1:9090` 暴露 RESTful API + 内嵌 yacd UI（仅监听 loopback）。SSH 隧道映射到本机 1234：

```bash
./scripts/port-forward-ui.sh         # 默认本机 1234
./scripts/port-forward-ui.sh 5678    # 自定义端口
```

脚本会自动用 `open` 弹浏览器到 `http://localhost:1234/ui/`。Ctrl-C 关闭隧道。

手动等价命令：

```bash
ssh -N -L 1234:127.0.0.1:9090 \
    -J qiangxu@112.124.26.131:48425 qiangxu@192.168.3.180
```

dashboard 里可以：
- 在 `🚀 节点选择` group 手动切节点（覆盖 url-test 的自动判定）
- 看 connections 实时流量
- 看 logs 实时日志

## 6. 故障排查清单

按可能性从高到低：

1. **节点连不上**（exit IP 不对 / curl 超时 / SSL EOF）
   - `sudo journalctl -u ninja@ninja -n 100` 看有没有 `connect error` / `dns resolve failed`
   - 如果错误里的 server 名是 `cname01x-...cdn.cnameip.xyz`：订阅里塞的是旧版节点（不可用），需要在 mac 上让 V-Ninja GUI 重新拉订阅，然后跑 `scripts/sync-from-gui.sh`
   - 如果是 `static-...cdn.cnameip.xyz`：是新版节点，应该能解；如果还连不上多半是节点本身宕了，dashboard 里换一个

2. **DNS 解析失败**
   - 远端测：`dig +short <node_domain> @223.5.5.5`
   - 远端无外网时（防火墙、出口被封）所有节点都会超时

3. **端口冲突**
   - `ss -ltn '( sport = :7890 or sport = :9090 )'` 看谁在占
   - 旧 clash@* 实例可能没清干净：`systemctl list-units 'clash@*'`

4. **配置语法错**
   - `sudo journalctl -u ninja@<instance>` 启动阶段会有 yaml 解析错误
   - 改完 yaml 后 `sudo systemctl restart ninja@<instance>` 立即生效

5. **二进制权限**
   - `ls -la ~/Projects/clash-9q/bin/ninja-mihomo` 必须有 `+x`
   - 文件类型确认：`file ~/Projects/clash-9q/bin/ninja-mihomo` 应该是 `ELF 64-bit LSB executable, x86-64, statically linked`

## 7. 从零部署一份新实例

例如要再上 `ninja@hk`（独占一个端口）：

```bash
# 1. 在 mac 上为该实例准备 yaml（参考 GUI 当前 yaml，改端口）
#    - mixed-port: 7891 (跟 ninja@ninja 的 7890 错开)
#    - external-controller: 127.0.0.1:9091
#    然后 scp 到远端 config/hk.yaml

# 2. 远端启动
sudo systemctl enable --now ninja@hk
systemctl status ninja@hk
curl -sS -x http://127.0.0.1:7891 -I https://www.google.com --max-time 15

# 3. 想本地访问该实例的 dashboard：改 scripts/port-forward-ui.sh 里
#    REMOTE_API=127.0.0.1:9091 后跑（或临时手动 ssh -L 1235:127.0.0.1:9091 ...）
```

## 8. 紧急回滚

如果新配置把服务搞挂了又不想现场修：

```bash
ssh -J ... qiangxu@192.168.3.180
sudo systemctl stop ninja@ninja
# 此时本机所有走 7890 代理的应用断网。回到 mac 上 sync 一份已知好的 yaml 过去，
# 或者手动 vim ~/Projects/clash-9q/config/ninja.yaml 改回去：
sudo systemctl start ninja@ninja
```

如果连 ninja-mihomo 二进制都坏了：从仓库重新 scp 一份 `bin/ninja-mihomo` 上去（这个文件已入 git）。
