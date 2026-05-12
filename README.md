# 百宝箱 - 服务器一键安装脚本

无需任何技术基础，复制粘贴一行命令即可使用。

## 📦 一键安装

**在服务器上复制粘贴以下命令，按回车：**

```bash
apt update && apt install curl -y && bash <(curl -fsSL https://raw.githubusercontent.com/maowang886/theboxes/main/install.sh)
如果上面的命令不行，试试这个：
apt update && apt install wget -y && wget -qO- https://raw.githubusercontent.com/maowang886/theboxes/main/install.sh | bash
🎯 然后做什么？
安装器会自动：

安装必要的工具（git、curl、wget）

下载百宝箱程序

自动启动选择菜单

你只需要用键盘上下键选择想安装的功能，按回车确认即可。

📱 可安装的应用
模块	说明	端口
komari	Komari 服务器探针	8008
npm	Nginx Proxy Manager (反向代理)	80,81,443
easyimg	EasyImg 图床	3000
qbittorrent	BT 下载工具	8080
alist	Alist 网盘聚合	5244
ssl_cert	SSL 证书申请工具	-
firewall	防火墙端口管理	-
🗑️ 卸载功能
方式一：通过主菜单卸载
bash
cd /root/theboxes
sudo bash selective_install.sh
# 选择 u 进入卸载界面
方式二：直接运行卸载脚本
bash
sudo bash /root/theboxes/utils/uninstall.sh
卸载界面
text
========================================
== 百宝箱卸载工具
========================================

[INFO] 检测到以下已安装的服务：
  1. Komari 探针
  2. Nginx Proxy Manager
  3. qBittorrent
  a. 全部卸载
  0. 退出

请选择要卸载的服务编号:
🔧 常用命令
bash
# 再次运行百宝箱
cd /root/theboxes && sudo bash selective_install.sh

# 查看已安装服务的密码
cat /root/.deploy_credentials.txt

# 查看日志
cat /var/log/theboxes/install.log

# 实时监控日志
tail -f /var/log/theboxes/install.log

# 卸载服务
sudo bash /root/theboxes/utils/uninstall.sh
📁 项目结构
text
theboxes/
├── selective_install.sh      # 主脚本
├── install.sh                # 极简安装器
├── README.md
├── lib/
│   └── common.sh             # 公共函数库
├── modules/
│   ├── komari.sh             # Komari 探针
│   ├── npm.sh                # Nginx Proxy Manager
│   ├── easyimg.sh            # EasyImg 图床
│   ├── qbittorrent.sh        # qBittorrent
│   ├── alist.sh              # Alist
│   ├── ssl_cert.sh           # SSL 证书申请
│   └── firewall.sh           # 防火墙管理
└── utils/
    ├── show_credentials.sh   # 查看凭证
    └── uninstall.sh          # 统一卸载工具
❓ 遇到问题？
截屏或复制错误信息

查看日志: cat /var/log/theboxes/install.log

提交 Issue: https://github.com/maowang886/theboxes/issues

📝 系统要求
操作系统: Ubuntu 20.04+ / Debian 11+

架构: x86_64 / ARM64

权限: root（安装器会自动申请）

⭐ 支持项目
如果觉得好用，给个 Star ⭐

