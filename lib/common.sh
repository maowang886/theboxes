#!/bin/bash
# ============================================
# 公共函数库 - 颜色、日志、健康检查、凭证记录
# 版本: v1.0
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

# 日志级别
LOG_LEVEL_INFO="INFO"
LOG_LEVEL_SUCCESS="SUCCESS"
LOG_LEVEL_WARNING="WARNING"
LOG_LEVEL_ERROR="ERROR"

# 写入日志文件
write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# ---------- 打印函数（同时输出到屏幕和日志）----------
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
        print_info "凭证文件已创建: $CREDENTIALS_FILE"
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

# ---------- 通用工具函数 ----------
# 获取服务器 IP（带缓存）
get_server_ip() {
    if [ -z "$CACHED_IP" ]; then
        CACHED_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "未知")
    fi
    echo "$CACHED_IP"
}

# 检查命令是否存在
check_command() { 
    command -v "$1" &> /dev/null
}

# 检查端口是否已开放
check_port_open() { 
    iptables -L INPUT -n 2>/dev/null | grep -q "dpt:$1"
}

# 检查端口是否被占用
check_port_in_use() {
    ss -tlnp 2>/dev/null | grep -q ":$1 " || netstat -tlnp 2>/dev/null | grep -q ":$1 "
}

# 生成随机端口（避开常用端口和已占用端口）
generate_random_port() {
    local min=${1:-10000}
    local max=${2:-60000}
    local common_ports=(22 80 443 8080 3000 5244 8008 8083 4837 6881 8081 8082)
    local port
    
    for attempt in {1..50}; do
        port=$((RANDOM % (max - min + 1) + min))
        # 避开常用端口
        if [[ " ${common_ports[@]} " =~ " ${port} " ]]; then
            continue
        fi
        # 避开已开放端口
        if check_port_open "$port"; then
            continue
        fi
        # 避开已占用端口
        if check_port_in_use "$port"; then
            continue
        fi
        echo "$port"
        return 0
    done
    # 降级：返回一个基础随机端口
    echo $((RANDOM % 50000 + 10000))
}

# ---------- 健康检查函数 ----------
# HTTP 健康检查
health_check_http() {
    local url="$1"
    local expected_code="${2:-200}"
    local max_retries="${3:-10}"
    local retry_interval="${4:-3}"
    
    print_info "健康检查: $url"
    
    for i in $(seq 1 $max_retries); do
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
        if [ "$status_code" = "$expected_code" ]; then
            print_success "健康检查通过: $url (HTTP $status_code)"
            write_log "$LOG_LEVEL_INFO" "健康检查通过: $url"
            return 0
        fi
        print_info "等待服务就绪... ($i/$max_retries) HTTP $status_code"
        sleep $retry_interval
    done
    
    print_error "健康检查失败: $url (超时)"
    write_log "$LOG_LEVEL_ERROR" "健康检查失败: $url"
    return 1
}

# TCP 端口健康检查
health_check_tcp() {
    local host="$1"
    local port="$2"
    local max_retries="${3:-10}"
    local retry_interval="${4:-2}"
    
    print_info "健康检查: $host:$port (TCP)"
    
    for i in $(seq 1 $max_retries); do
        if timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            print_success "健康检查通过: $host:$port 端口可连接"
            write_log "$LOG_LEVEL_INFO" "健康检查通过: $host:$port"
            return 0
        fi
        print_info "等待服务就绪... ($i/$max_retries)"
        sleep $retry_interval
    done
    
    print_error "健康检查失败: $host:$port (超时)"
    write_log "$LOG_LEVEL_ERROR" "健康检查失败: $host:$port"
    return 1
}

# Docker 容器健康检查
health_check_docker() {
    local container_name="$1"
    local max_retries="${2:-10}"
    local retry_interval="${3:-2}"
    
    print_info "健康检查: Docker 容器 $container_name"
    
    for i in $(seq 1 $max_retries); do
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
        if [ "$status" = "running" ]; then
            print_success "健康检查通过: 容器 $container_name 运行中"
            write_log "$LOG_LEVEL_INFO" "健康检查通过: 容器 $container_name"
            return 0
        fi
        print_info "等待容器启动... ($i/$max_retries) 状态: $status"
        sleep $retry_interval
    done
    
    print_error "健康检查失败: 容器 $container_name 未运行"
    write_log "$LOG_LEVEL_ERROR" "健康检查失败: 容器 $container_name"
    return 1
}

# systemd 服务健康检查
health_check_systemd() {
    local service_name="$1"
    
    print_info "健康检查: systemd 服务 $service_name"
    
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        print_success "健康检查通过: 服务 $service_name 运行中"
        write_log "$LOG_LEVEL_INFO" "健康检查通过: 服务 $service_name"
        return 0
    else
        print_error "健康检查失败: 服务 $service_name 未运行"
        write_log "$LOG_LEVEL_ERROR" "健康检查失败: 服务 $service_name"
        return 1
    fi
}

# ---------- 错误处理和回滚 ----------
# 记录错误并退出（带可选回滚命令）
error_exit() {
    local message="$1"
    local rollback_cmd="$2"
    
    print_error "$message"
    write_log "$LOG_LEVEL_ERROR" "致命错误: $message"
    
    if [ -n "$rollback_cmd" ]; then
        print_info "执行回滚: $rollback_cmd"
        eval "$rollback_cmd"
        write_log "$LOG_LEVEL_INFO" "已执行回滚: $rollback_cmd"
    fi
    
    exit 1
}

# 执行命令并检查返回值
run_with_check() {
    local cmd="$1"
    local error_msg="$2"
    
    print_info "执行: $cmd"
    write_log "$LOG_LEVEL_INFO" "执行命令: $cmd"
    
    if eval "$cmd"; then
        print_success "命令执行成功"
        return 0
    else
        print_error "命令执行失败: $error_msg"
        write_log "$LOG_LEVEL_ERROR" "命令失败: $cmd"
        return 1
    fi
}
