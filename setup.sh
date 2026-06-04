#!/bin/bash
##############################################################
# CREATED DATE: 2024年02月06日 星期二 12时55分14秒
# UPDATED:     2026-06-04 — switched from clash to ninja (mihomo core + ninja subscription)
# CREATED BY:  qiangxu, toxuqiang@gmail.com
##############################################################

# 一次性安装 / 切换流程（参考用，按需逐步执行）：
#
# 1) 准备实例配置（每个实例一份 yaml）
#    cp config/ninja.yaml.template config/ninja.yaml
#    # 编辑 config/ninja.yaml，把 __SUBSCRIPTION_URL__ 替换成你的订阅地址
#
# 2) 如果机器上还有旧的 clash@* 实例，先停掉并卸载旧 unit：
#    sudo systemctl list-units 'clash@*' --all
#    sudo systemctl disable --now clash@<instance>
#    sudo rm -f /etc/systemd/system/clash@.service
#    sudo systemctl daemon-reload
#
# 3) 安装新的 systemd 模板：
#    sudo cp system/ninja@.service /etc/systemd/system/
#    sudo systemctl daemon-reload
#
# 4) 启动 / 开机自启（实例名对应 config/<instance>.yaml）：
#    sudo systemctl enable --now ninja@ninja
#    sudo systemctl status ninja@ninja
#
# 5) 验证：
#    journalctl -u ninja@ninja -f
#    curl -x http://127.0.0.1:7890 -I https://www.google.com
