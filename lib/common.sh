#!/bin/bash
# ============================================
# 公共函数库 - 颜色、日志、健康检查、凭证记录
# 版本: v2.0 (优化版)
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
mkdir -p "$LOG_DIR"

LOG_LEVEL_INFO="INFO"
LOG_LEVEL_SUCCESS="SUCCESS"
LOG_LEVEL_WARNING="WARNING"
LOG_LEVEL_ERROR="ERROR"

write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
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
    write_log "$LOG_LEVEL_INFO" "已记录凭证: $service"
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

# ========== 新增：清理 apt 锁和进程 ==========
apt_clean() {
    # 清理锁文件
    rm -f /var/lib/dpkg/lock-frontend 2>/dev/null
    rm -f /var/lib/dpkg/lock 2>/dev/null
    rm -f /var/cache/apt/archives/lock 2>/dev/null
    
    # 修复 dpkg
    dpkg --configure -a 2>/dev/null
    
    # 杀掉残留进程
    pkill -9 apt 2>/dev/null
    pkill -9 dpkg 2>/dev/null
    
    sleep 1
}

# ========== 新增：带超时的 apt 更新 ==========
apt_update() {
    print_info "更新软件包列表..."
    write_log "$LOG_LEVEL_INFO" "apt update"
    
    # 超时 60 秒
    timeout 60 apt update -y 2>&1 | tee -a "$LOG_FILE"
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        print_success "软件包列表更新成功"
        return 0
    elif [ $exit_code -eq 124 ]; then
        print_error "apt update 超时 (60秒)"
        return 1
    else
        print_warning "apt update 返回码: $exit_code"
        return 1
    fi
}

# ========== 新增：带超时的 apt 安装 ==========
apt_install() {
    local packages="$1"
    
    print_info "正在安装: $packages"
    write_log "$LOG_LEVEL_INFO" "apt install: $packages"
    
    # 超时 120 秒，禁用交互
    DEBIAN_FRONTEND=noninteractive timeout 120 apt install -y -qq $packages 2>&1 | tee -a "$LOG_FILE"
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        print_success "安装完成: $packages"
        return 0
    elif [ $exit_code -eq 124 ]; then
        print_error "apt install 超时 (120秒): $packages"
        return 1
    else
        print_error "安装失败: $packages"
        return 1
    fi
}
