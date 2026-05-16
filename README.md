markdown
# 百宝箱 - 服务器一键安装脚本

无需任何技术基础，复制粘贴一行命令即可使用。

## 📦 一键安装

**在服务器上复制粘贴以下命令，按回车：**

```bash
apt update && apt install curl -y && bash <(curl -fsSL https://raw.githubusercontent.com/maowang886/theboxes/main/install.sh)
如果上面的命令不行，试试这个：

bash
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
warp	CloudFlare WARP 网络加速	-
ssl_cert	SSL 证书申请工具	-
firewall	防火墙端口管理	-
🌐 WARP 功能详解
WARP 模块提供完整的 CloudFlare WARP 管理功能，有效提升服务器网络体验。

支持的客户端
客户端	说明	适用场景
WGCF	WireGuard 官方客户端，性能好	非限制区域（非香港/美西）
WARP-GO	第三方客户端，兼容性强	香港、美西等限制区域
WARP-Cli	CloudFlare 官方客户端	AMD64 架构服务器
管理功能
安装 WARP 后，可通过管理菜单执行以下操作：

功能	说明
重启/停止/启动	控制 WARP 服务状态
切换账户类型	免费版 / WARP+ / Teams
刷 WARP+ 流量	为 WARP+ 账户增加流量
提取配置文件	导出 WireGuard / Sing-box 配置
Endpoint 优选	测试最优接入点，提升奈飞解锁效果
卸载	完整移除 WARP
Endpoint 优选（刷奈飞 IP）
优选功能将测试 CloudFlare 各地 Endpoint IP：

找到延迟最低的接入点

绕过被限制的 IP 段

提升奈飞等流媒体解锁成功率

使用步骤：

选择 WARP 模块进入管理菜单

选择 8. EndPoint 优选

等待测试完成，记录最优 IP

修改 /etc/wireguard/wgcf.conf 中的 Endpoint

重启 WARP 服务

🗑️ 卸载功能
方式一：通过主菜单卸载
bash
cd /root/theboxes
sudo bash selective_install.sh
# 选择 u 进入卸载界面
方式二：直接运行卸载脚本
bash
sudo bash /root/theboxes/utils/uninstall.sh
卸载界面预览
text
========================================
== 百宝箱卸载工具
========================================

[INFO] 检测到以下已安装的服务：
  1. Komari 探针
  2. Nginx Proxy Manager
  3. WARP (WGCF)
  4. qBittorrent
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

# WARP 专属命令（如果已安装）
wg-quick up wgcf      # 启动 WARP
wg-quick down wgcf    # 停止 WARP
wg-quick show wgcf    # 查看状态
warp-cli status       # WARP-Cli 状态（如适用）
systemctl status warp-go  # WARP-GO 状态（如适用）
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
│   ├── warp.sh               # CloudFlare WARP 管理
│   ├── ssl_cert.sh           # SSL 证书申请
│   └── firewall.sh           # 防火墙管理
└── utils/
    ├── show_credentials.sh   # 查看凭证
    └── uninstall.sh          # 统一卸载工具
❓ 遇到问题？
常见问题
问题	解决方法
WGCF 无法连接	所在区域可能被限制，尝试安装 WARP-GO
奈飞无法解锁	运行 Endpoint 优选功能，更换接入点
端口被占用	安装前检查端口冲突，或修改配置
安装失败	查看日志: cat /var/log/theboxes/install.log
获取帮助
截屏或复制错误信息

查看日志: cat /var/log/theboxes/install.log

提交 Issue: https://github.com/maowang886/theboxes/issues

📝 系统要求
操作系统: Ubuntu 20.04+ / Debian 11+

架构: x86_64 / ARM64

权限: root（安装器会自动申请）

⭐ 支持项目
如果觉得好用，给个 Star ⭐
