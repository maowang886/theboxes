#文件目录结构

selective-install/
├── selective_install.sh          # 主脚本
├── modules/
│   ├── komari.sh                 # Komari 探针模块
│   ├── npm.sh                    # Nginx Proxy Manager 模块 (Docker)
│   ├── easyimage.sh              # EasyImage 图床模块
│   ├── qbittorrent.sh            # qBittorrent 模块
│   ├── alist.sh                  # Alist 模块
│   └── firewall.sh               # 端口开放模块 (iptables)
├── show_credentials.sh           # 查看凭证独立脚本
├── README.md                     # 项目说明文档
└── .gitignore                    # Git 忽略文件

## 模块化选择性安装脚本

一键安装 Docker 和多种常用服务（Komari、NPM、EasyImage、qBittorrent、Alist），支持端口开放配置，自动记录凭证。

### 快速开始

```bash
git clone https://github.com/maowang886/selective-install.git
cd selective-install
sudo bash selective_install.sh
