
# A clash setup for the ubuntu system.
  
  
  
1.开机自启动：

在/etc/systemd/system下新建clash.service文件：sudo gedit /etc/systemd/system/clash.service，填入：

[Unit]

Description=Clash - A rule-based tunnel in Go

Documentation=https://github.com/Dreamacro/clash/wiki

[Service]

OOMScoreAdjust=-1000

ExecStart=/usr/local/bin/clash -f /root/.config/clash/config.yaml

Restart=on-failure

RestartSec=5

[Install]

WantedBy=multi-user.target

在这里可以将.config/clash/config.yaml路经改为clash下的位置：/usr/local/bin/config.yaml（前提是该位置下要有这个.yaml文件）

2.最后输入：

sudo systemctl enable clash
sudo systemctl start clash
sudo systemctl status clash

完成开机自启

3. 打开clash网页控制台，长这样：

  ![image](https://user-images.githubusercontent.com/72930251/219658560-d83b2fbd-ebb5-4f68-8b3c-56b49446b295.png)
  
  点击设置，打开允许来自局域网的连接，这时就可以访问Google

4. 代理链Proxychains安装配置：

4.1. 使用 apt 进行安装：sudo apt-get install proxychains

4.2. 打开 /etc/proxychains.conf 文件：sudo gedit /etc/proxychains.conf，在文件最后改成相应的代理方式、地址和端口，配置代理：http	127.0.0.1 7890

4.3. 测试是否成功：proxychains curl -kIsS https://www.google.com
