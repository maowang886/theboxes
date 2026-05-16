#!/bin/bash
# ============================================
# 公共函数库 - 修复版
# 版本: v2.1 (稳定版)
# ============================================

# ---------- 颜色定义 ----------
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# ---------- 日志配置 ----------
LOG_DIR="/var/log/theboxes"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR" 2>/dev/null

LOG_LEVEL_INFO="INFO"
LOG_LEVEL_SUCCESS="SUCCESS"
LOG_LEVEL_WARNING="WARNING"
LOG_LEVEL_ERROR="ERROR"

write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
}

# ---------- 打印函数 ----------
print_info() { 
    echo -e "${BLUE}[INFO]${NC} $1"
    write_log "$LOG_LEVEL_INFO" "$1"
}
print_success() { 
    echo -e "${GREEN}[✓]${NC} $1"
    write_log "$LOG_LEVEL_SUCCESS" "$1"
}
print_warning() { 
    echo -e "${YELLOW}[!]${NC} $1"
    write_log "$LOG_LEVEL_WARNING" "$1"
}
print_error() { 
    echo -e "${RED}[✗]${NC} $1"
    write_log "$LOG_LEVEL_ERROR" "$1"
}
print_step() { 
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}== $1${NC}"
    echo -e "${CYAN}========================================${NC}"
    write_log "$LOG_LEVEL_INFO" "========== $1 =========="
}

# ---------- 凭证记录 ----------
CREDENTIALS_FILE="/root/.deploy_credentials.txt"

init_credentials() {
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        echo "=========================================" > "$CREDENTIALS_FILE"
        echo "部署服务凭证记录 (生成时间: $(date))" >> "$CREDENTIALS_FILE"
        echo "=========================================" >> "$CREDENTIALS_FILE"
        echo "" >> "$CREDENTIALS_FILE"
    fi
}

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

# ---------- 通用工具 ----------
get_server_ip() {
    if [ -z "$CACHED_IP" ]; then
        CACHED_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "未知")
    fi
    echo "$CACHED_IP"
}

check_command() { 
    command -v "$1" &> /dev/null
}

# ========== 修复后的 apt 函数（所有错误都被捕获）==========

# 清理 apt 环境（不会导致脚本退出）
apt_clean() {
    print_info "清理 apt 环境..."
    
    # 所有命令都加上 || true，避免 set -e 导致退出
    rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
    rm -f /var/lib/dpkg/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    dpkg --configure -a 2>/dev/null || true
    pkill -9 apt 2>/dev/null || true
    pkill -9 dpkg 2>/dev/null || true
    
    sleep 1
    print_success "apt 环境清理完成"
    return 0
}

# 更新软件包列表
apt_update() {
    print_info "更新软件包列表..."
    write_log "$LOG_LEVEL_INFO" "apt update"
    
    # 禁用 set -e 的影响
    set +e
    apt update -y 2>&1 | tee -a "$LOG_FILE"
    local exit_code=$?
    set -e
    
    if [ $exit_code -eq 0 ]; then
        print_success "软件包列表更新成功"
        return 0
    else
        print_warning "apt update 返回码: $exit_code"
        return 1
    fi
}

# 安装软件包
apt_install() {
    local packages="$1"
    
    print_info "正在安装: $packages"
    write_log "$LOG_LEVEL_INFO" "apt install: $packages"
    
    set +e
    DEBIAN_FRONTEND=noninteractive apt install -y $packages 2>&1 | tee -a "$LOG_FILE"
    local exit_code=$?
    set -e
    
    if [ $exit_code -eq 0 ]; then
        print_success "安装完成: $packages"
        return 0
    else
        print_error "安装失败: $packages"
        return 1
    fi
}

# 检查并安装基础工具
ensure_base_tools() {
    local missing_tools=""
    
    for tool in curl wget git socat; do
        if ! check_command $tool; then
            missing_tools="$missing_tools $tool"
        fi
    done
    
    if [ -n "$missing_tools" ]; then
        print_info "缺少以下工具: $missing_tools"
        apt_clean
        apt_update || true
        apt_install "$missing_tools"
    else
        print_success "所有基础工具已安装"
    fi
}
