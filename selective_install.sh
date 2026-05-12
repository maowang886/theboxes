#!/bin/bash

# ============================================
# 模块化选择性安装脚本
# 基础功能：更新系统依赖、安装 Docker
# 其他应用：通过 modules/ 目录下的独立脚本提供
# 使用方法：sudo bash selective_install.sh
# 版本: v1.0 (2026-05-12)
# ============================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_step() { echo ""; echo -e "${CYAN}========================================${NC}"; echo -e "${CYAN}== $1${NC}"; echo -e "${CYAN}========================================${NC}"; }

if [ "$EUID" -ne 0 ]; then
    print_error "请使用 root 用户运行"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# 凭证文件
CREDENTIALS_FILE="/root/.deploy_credentials.txt"
> "$CREDENTIALS_FILE"
echo "=========================================" >> "$CREDENTIALS_FILE"
echo "部署服务凭证记录 (生成时间: $(date))" >> "$CREDENTIALS_FILE"
echo "=========================================" >> "$CREDENTIALS_FILE"
echo "" >> "$CREDENTIALS_FILE"

# 记录凭证函数（供模块调用）
record_credential() {
    local service="$1"
    local username="$2"
    local password="$3"
    local extra="$4"
    echo "【$service】" >> "$CREDENTIALS_FILE"
    [ -n "$username" ] && echo "  用户名: $username" >> "$CREDENTIALS_FILE"
    [ -n "$password" ] && echo "  密码: $password" >> "$CREDENTIALS_FILE"
    [ -n "$extra" ] && echo "  说明: $extra" >> "$CREDENTIALS_FILE"
    echo "" >> "$CREDENTIALS_FILE"
}
export -f record_credential

# ========== 基础环境安装 ==========
print_step "安装基础环境 (系统更新 + Docker)"

print_info "更新软件包列表..."
apt update

print_info "安装基础依赖 (curl, wget, git, iptables-persistent)..."
apt install -y curl wget git iptables-persistent

# 安装 Docker
if ! command -v docker &> /dev/null; then
    print_info "安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    print_success "Docker 安装完成"
else
    print_success "Docker 已安装"
fi

# 安装 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_info "安装 Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    print_success "Docker Compose 安装完成"
else
    print_success "Docker Compose 已安装"
fi

# ========== 模块化菜单 ==========
print_step "加载应用模块"

if [ ! -d "$MODULES_DIR" ]; then
    print_error "未找到 modules 目录，请确保 $MODULES_DIR 存在并包含模块脚本"
    exit 1
fi

# 扫描模块
declare -a MODULE_NAMES
declare -a MODULE_FILES
for module_file in "$MODULES_DIR"/*.sh; do
    [ -f "$module_file" ] || continue
    module_id=$(basename "$module_file" .sh)
    MODULE_NAMES+=("$module_id")
    MODULE_FILES+=("$module_file")
done

if [ ${#MODULE_NAMES[@]} -eq 0 ]; then
    print_warning "没有找到任何模块，退出"
    exit 0
fi

echo ""
echo "可用的应用模块："
for i in "${!MODULE_NAMES[@]}"; do
    idx=$((i+1))
    echo "  $idx. ${MODULE_NAMES[$i]}"
done
echo "  0. 退出"
echo ""
read -p "请输入要安装的模块编号（可多选，空格分隔）: " -a choices

# ========== 执行模块安装 ==========
for choice in "${choices[@]}"; do
    if [[ "$choice" == "0" ]]; then
        print_info "退出"
        exit 0
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#MODULE_NAMES[@]} ]; then
        idx=$((choice-1))
        module_id="${MODULE_NAMES[$idx]}"
        module_file="${MODULE_FILES[$idx]}"
        print_step "安装模块: $module_id"
        source "$module_file"
        if declare -f install > /dev/null; then
            install
        else
            print_error "模块 $module_id 中未定义 install 函数"
        fi
    else
        print_warning "无效选择: $choice"
    fi
done

print_step "安装完成"
echo ""
echo "所有服务的凭证已保存至: $CREDENTIALS_FILE"
cat "$CREDENTIALS_FILE"

SERVER_IP=$(curl -s ifconfig.me)
echo ""
echo "========================================="
echo "快速访问提示：请查看上方凭证文件中的具体地址和密码"
echo "========================================="
