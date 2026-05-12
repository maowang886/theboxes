#文件目录结构

selective-install/
├── selective_install.sh # 主脚本（安装 Docker + 基础依赖）
├── show_credentials.sh # 查看已安装服务的凭证
├── modules/ # 模块目录
│ ├── komari.sh # Komari 探针
│ ├── npm.sh # Nginx Proxy Manager (Docker)
│ ├── easyimage.sh # EasyImage 图床
│ ├── qbittorrent.sh # qBittorrent
│ ├── alist.sh # Alist
│ └── firewall.sh # 端口开放 (iptables)
├── README.md # 项目说明
└── .gitignore # Git 忽略文件
## 模块化选择性安装脚本

一键安装 Docker 和多种常用服务（Komari、NPM、EasyImage、qBittorrent、Alist），支持端口开放配置，自动记录凭证。

### 快速开始

```bash
git clone https://github.com/maowang886/selective-install.git
cd selective-install
sudo bash selective_install.sh
