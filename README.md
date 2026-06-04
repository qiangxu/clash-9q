# Ninja (mihomo) setup for Ubuntu

基于 mihomo 内核，跑 Ninja 订阅；支持多实例（systemd template）。

> - 远端运维 / 故障排查：[`docs/runbook.md`](docs/runbook.md)
> - 这套方案为什么这么搭：[`docs/findings.md`](docs/findings.md)

## 1. 实例配置

每个实例一份 yaml，文件名 = 实例名：

```bash
cp config/ninja.yaml.template config/ninja.yaml
# 编辑 config/ninja.yaml，把 __SUBSCRIPTION_URL__ 换成订阅地址
# 多实例：再来一份 cp config/ninja.yaml.template config/<other>.yaml，注意改 mixed-port / external-controller 端口避免冲突
```

> `config/*.yaml` 已在 `.gitignore` 里，订阅 URL 不会进 git。

## 2. systemd 模板

在 `/etc/systemd/system/` 安装 `ninja@.service`：

```bash
sudo cp system/ninja@.service /etc/systemd/system/
sudo systemctl daemon-reload
```

`ninja@<name>.service` 会读 `config/<name>.yaml` 作为配置。

## 3. 启动 / 开机自启

```bash
sudo systemctl enable --now ninja@ninja
sudo systemctl status ninja@ninja
journalctl -u ninja@ninja -f
```

## 4. 验证

```bash
curl -x http://127.0.0.1:7890 -I https://www.google.com
```

## 5. 机场更新后同步配置（mac 上跑）

V-Ninja GUI 在 mac 上会自动拉新订阅；要把同一份配置推到远端：

```bash
./scripts/sync-from-gui.sh           # 默认推 ninja@ninja
./scripts/sync-from-gui.sh other     # 推 ninja@other
```

脚本会：抓 GUI 内核（ninja-mihomo）正在用的 yaml → 去掉 tun/dns/secret/cors 段 + 改端口为 7890/9090 → scp 到远端 `config/ninja.yaml` → 重启 ninja@<instance> → 验证。

## 6. 本地访问 dashboard（选节点 / 看流量）

走 SSH SOCKS 进 180，再用浏览器直连远端 9090。详见 [`docs/runbook.md` §5](docs/runbook.md#5-本地访问-dashboard选节点--看流量)。

```bash
ssh -N -D 127.0.0.1:1234 \
    -J qiangxu@112.124.26.131:48425 qiangxu@192.168.3.180
# 浏览器走 SOCKS5 127.0.0.1:1234，访问 http://192.168.3.180:9090/ui/
# yacd 表单填 Host=192.168.3.180 Port=9090 Secret=9q-ninja-local
# （用 LAN IP 而不是 127.0.0.1，因为浏览器默认绕过 loopback）
```

## 7. 从旧 clash@* 实例迁移

```bash
sudo systemctl list-units 'clash@*' --all
sudo systemctl disable --now clash@<instance>
sudo rm -f /etc/systemd/system/clash@.service
sudo systemctl daemon-reload
```

## 8. 在 180 上让命令行走代理

`~/.bashrc` 里有 `tkk`（开） / `sgg`（关）alias，覆盖大多数工具。详见 [`docs/runbook.md` §8](docs/runbook.md#8-远端命令行让程序走代理)（含 git / apt / docker / npm / pip / proxychains 等特例）。

## 9. 常用命令

```bash
systemctl cat ninja@ninja.service           # 查看 unit 文件
sudo systemctl daemon-reload                # 改了 unit 后重新加载
sudo systemctl restart ninja@ninja.service  # 重启
```
