# A clash setup for the ubuntu system.
  
  
  
1. 开机自启动:

在`/etc/systemd/system`下新建`clash@.service`文件：`sudo vi /etc/systemd/system/clash@.service`，填入：

```
[Unit]
Description=Clash daemon for %i
After=network.target

[Service]
Type=simple
User=root
# %i 会被替换为 @ 符号后的实例名 (例如 "0809")
ExecStart=/home/qiangxu/Projects/clash-9q/bin/clash-linux-amd64 -d /home/qiangxu/Projects/clash-9q/config/ -ext-ui /home/qiangxu/Projects/clash-9q/ui/ -f /home/qiangxu/Projects/clash-9q/config/%i.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
```


2. 完成开机自启:

```
sudo systemctl start clash@0809
sudo systemctl start clash@igg5

sudo systemctl enable clash@0809.service
sudo systemctl enable clash@igg5.service

sudo systemctl status clash@0809.service
sudo systemctl status clash@igg5.service

```


3. 代理链proxychains安装配置:

3.1. 使用 apt 进行安装：`sudo apt-get install proxychains`

3.2. 打开`/etc/proxychains.conf`文件：`sudo vi /etc/proxychains.conf`，在文件最后改成相应的代理方式、地址和端口，配置代理：`http://127.0.0.1:7890`

3.3. 测试是否成功：`proxychains curl -kIsS https://www.google.com`



4. 常见命令行

4.1. 查看服务配置文件的完整路径: `systemctl show clash.service | grep FragmentPath`

4.2. 或者使用这个命令: `systemctl cat clash.service`

4.3. 重新加载systemd配置: `sudo systemctl daemon-reload`

4.4. 重启服务: `sudo systemctl restart clash.service`
