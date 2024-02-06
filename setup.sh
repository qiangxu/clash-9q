#!/bin/bash
##############################################################
# CREATED DATE: 2024年02月06日 星期二 12时55分14秒
# CREATED BY: qiangxu, toxuqiang@gmail.com
##############################################################

echo "MAKE SURE THE FOLLOWING SETUP"
cat resources/clash.service
echo "sudo ./bin/clash-linux-amd64 -d config/ -ext-ui ./ui/ -f config/config.yaml"


#sudo cp ./clash.service/clash.service /etc/systemd/system/clash.service
#sudo systemctl enable clash 
#sudo systemctl start clash 
#sudo systemctl status clash

#alias tkk="export https_proxy=http://127.0.0.1:7890; export http_proxy=http://127.0.0.1:7890; export all_proxy=socks5://127.0.0.1:7890;"
#alias sgg="unset http_proxy; unset https_proxy; unset all_proxy;"
