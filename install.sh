#!/bin/bash
# ============================================
# 百宝箱一键安装器（零依赖）
# 使用方法: bash <(curl -fsSL https://raw.githubusercontent.com/maowang886/theboxes/main/install.sh)
# 或者: apt update && apt install curl -y && curl -sSL https://raw.githubusercontent.com/maowang886/theboxes/main/install.sh | bash
# ============================================

set -e

# 颜色（简单兼容）
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 打印函数（不依赖外部库）
print_green() { echo -e "${GREEN}>>>${NC} $1"; }
print_yellow() { echo -e "${YELLOW}>>>${NC} $1"; }
print_red() { echo -e "${RED}>>>${NC} $1"; }

clear
echo ""
print_green "========================================="
print_green "        百宝箱一键安装器"
print_green "========================================="
echo ""

# ========== 1. 检查并安装基础工具 ==========
print_yellow "[1/5] 检查基础工具..."

# 检查包管理器
if ! command -v apt &> /dev/null; then
    print_red "错误: 本脚本仅支持 Debian/Ubuntu 系统"
    exit 1
fi

# 更新源（静默）
apt update -qq 2>/dev/null

# 安装必要工具
MISSING_TOOLS=""
for tool in git curl wget; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    print_yellow "正在安装依赖工具: $MISSING_TOOLS"
    apt install -y $MISSING_TOOLS > /dev/null 2>&1
fi

print_green "基础工具检查完成"

# ========== 2. 获取服务器 IP ==========
print_yellow "[2/5] 获取服务器信息..."
SERVER_IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || curl -s --max-time 3 ip.sb 2>/dev/null || echo "未知")
print_green "服务器 IP: $SERVER_IP"

# ========== 3. 克隆或更新仓库 ==========
print_yellow "[3/5] 准备百宝箱程序..."

REPO_URL="https://github.com/maowang886/theboxes.git"
REPO_DIR="/root/theboxes"

if [ -d "$REPO_DIR" ]; then
    print_yellow "检测到已有安装，正在更新..."
    cd "$REPO_DIR"
    git pull --quiet
    print_green "更新完成"
else
    print_yellow "正在下载百宝箱..."
    git clone --quiet "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
    print_green "下载完成"
fi

# ========== 4. 设置权限 ==========
print_yellow "[4/5] 设置执行权限..."
chmod +x selective_install.sh 2>/dev/null
chmod +x utils/*.sh 2>/dev/null
chmod +x modules/*.sh 2>/dev/null
print_green "权限设置完成"

# ========== 5. 启动主脚本 ==========
print_yellow "[5/5] 启动百宝箱..."
echo ""
sleep 1

# 运行主脚本
cd "$REPO_DIR"
sudo bash selective_install.sh

# ========== 安装完成 ==========
print_green "========================================="
print_green "百宝箱安装完成！"
print_green "下次运行: cd /root/theboxes && sudo bash selective_install.sh"
print_green "========================================="
