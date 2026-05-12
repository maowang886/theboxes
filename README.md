
## 项目结构

selective-install/
├── selective_install.sh          # 主脚本（安装 Docker + 基础依赖）
├── show_credentials.sh           # 查看已安装服务的凭证
├── modules/                      # 模块目录
│   ├── komari.sh                 # Komari 探针
│   ├── npm.sh                    # Nginx Proxy Manager (Docker)
│   ├── easyimage.sh              # EasyImage 图床
│   ├── qbittorrent.sh            # qBittorrent
│   ├── alist.sh                  # Alist
│   └── firewall.sh               # 端口开放 (iptables)
├── README.md                     # 项目说明
└── .gitignore                    # Git 忽略文件

## 模块化选择性安装脚本


一键安装 Docker 和多种常用服务，支持模块化扩展，自动记录凭证。

## 功能

- ✅ 自动安装 Docker + Docker Compose
- ✅ 支持多应用独立/批量安装
- ✅ 端口检测与开放 (iptables)
- ✅ 自动记录用户名/密码/访问地址
- ✅ 模块化设计，易于扩展

## 项目结构


### 快速开始

```bash
git clone https://github.com/maowang886/selective-install.git
cd selective-install
sudo bash selective_install.sh
