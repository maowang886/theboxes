#!/bin/bash
# ============================================
# 模块化选择性安装脚本
# 版本: v2.0 (优化版)
# ============================================

set -e

# 捕获中断信号，安全退出
trap 'echo ""; print_warning "用户中断，正在退出..."; exit 130' INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

# ========== 优化后的基础依赖安装 ==========
install_base_deps() {
    print_step "安装基础依赖"
    
    # 1. 清理 apt 环境
    print_info "清理 apt 环境..."
    apt_clean
    
    # 2. 更新软件包列表（带重试）
    local max_retries=2
    local retry=0
    
    for retry in $(seq 1 $max_retries); do
        if apt_update; then
            break
        else
            if [ $retry -lt $max_retries ]; then
                print_warning "更新失败，5秒后重试..."
                sleep 5
                apt_clean
            else
                print_error "apt update 失败，请手动运行 'apt update'"
                exit 1
            fi
        fi
    done
    
    # 3. 安装基础工具
    local tools="curl wget git socat iptables-persistent"
    
    if apt_install "$tools"; then
        print_success "基础工具安装完成"
    else
        print_error "基础工具安装失败"
        print_info "请手动运行: apt install -y $tools"
        exit 1
    fi
}

# ========== 安装 Docker ==========
install_docker() {
    print_step "检查 Docker 环境"
    
    if ! check_command docker; then
        print_info "安装 Docker..."
        curl -fsSL https://get.docker.com | sh 2>&1 | tee -a "$LOG_FILE"
        print_success "Docker 安装完成"
    else
        print_success "Docker 已安装: $(docker --version)"
    fi
    
    if ! check_command docker-compose; then
        print_info "安装 Docker Compose..."
        local arch=$(uname -m)
        local compose_url=""
        
        case $arch in
            x86_64|amd64) compose_url="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" ;;
            aarch64|arm64) compose_url="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64" ;;
            *) print_error "不支持的架构: $arch" ; return 1 ;;
        esac
        
        curl -L "$compose_url" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        print_success "Docker Compose 安装完成"
    else
        print_success "Docker Compose 已安装"
    fi
}

# ========== 安装 acme.sh ==========
install_acme() {
    print_step "安装 acme.sh"
    
    if [ -f "/root/.acme.sh/acme.sh" ]; then
        print_success "acme.sh 已安装"
        return 0
    fi
    
    print_info "正在安装 acme.sh..."
    wget -qO- get.acme.sh | bash
    source ~/.bashrc
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    mkdir -p /etc/ssl
    
    print_success "acme.sh 安装完成"
}

# ========== 主函数 ==========
main() {
    check_root
    install_base_deps
    install_docker
    install_acme
    init_credentials
    
    # 打印成功信息
    print_step "基础环境安装完成"
    print_success "Docker 版本: $(docker --version 2>/dev/null || echo '未安装')"
    print_success "Docker Compose 版本: $(docker-compose --version 2>/dev/null || echo '未安装')"
    print_success "acme.sh 状态: $(/root/.acme.sh/acme.sh --version 2>/dev/null || echo '未安装')"
    
    echo ""
    print_info "日志文件: $LOG_FILE"
    print_info "凭证文件: $CREDENTIALS_FILE"
}

main "$@"
