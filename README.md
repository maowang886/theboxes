# 百宝箱 - 服务器一键安装脚本

无需任何技术基础，复制粘贴一行命令即可使用。

## 📦 一键安装

**在服务器上复制粘贴以下命令，按回车：**

```bash

apt update && apt install curl -y && bash <(curl -fsSL https://raw.githubusercontent.com/maowang886/theboxes/main/install.sh)

🔧 常用命令
bash
# 再次运行百宝箱

cd /root/theboxes && sudo bash selective_install.sh

# 查看已安装服务的密码

cat /root/.deploy_credentials.txt

# 查看日志

cat /var/log/theboxes/install.log

❓ 遇到问题？
截屏或复制错误信息

查看日志:
cat /var/log/theboxes/install.log

📝 系统要求
操作系统: Ubuntu 20.04+ / Debian 11+

架构: x86_64 / ARM64

权限: root（安装器会自动申请）

⭐ 支持项目
如果觉得好用，给个 Star ⭐
