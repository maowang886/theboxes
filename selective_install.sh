#!/bin/bash
# ============================================
# 模块化选择性安装脚本
# 版本: v2.1 (修复版)
# 功能: 基础环境安装 + 模块化应用部署
# 使用方法: sudo bash selective_install.sh
# ============================================

set -e

# 捕获中断信号
trap 'echo ""; print_warning "用户中断，正在退出..."; exit 130' INT TERM

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共库
source "$SCRIPT_DIR/lib/common.sh"

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

# ========== 基础环境安装（修复版）==========
install_base_deps() {
    print_step "安装基础依赖"
    
    # 1. 清理 apt 环境
    apt_clean
    
    # 2. 更新软件包列表
    apt_update
    
    # 3. 安装基础工具
    local tools="curl wget git socat iptables-persistent"
    
    # 检查哪些已安装
    local missing=""
    for tool in $tools; do
        if ! check_command $tool; then
            missing="$missing $tool"
        fi
    done
    
    if [ -n "$missing" ]; then
        apt_install "$missing"
    else
        print_success "所有基础工具已安装"
    fi
}

# 安装 Docker
install_docker() {
    print_step "检查 Docker 环境"
    
    if ! check_command docker; then
        print_info "安装 Docker..."
        curl -fsSL https://get.docker.com | sh 2>&1 | tee -a "$LOG_FILE"
        print_success "Docker 安装完成"
        write_log "$LOG_LEVEL_INFO" "Docker 已安装"
    else
        print_success "Docker 已安装: $(docker --version)"
    fi
    
    if ! check_command docker-compose; then
        print_info "安装 Docker Compose..."
        local arch=$(uname -m)
        local compose_url=""
        
        case $arch in
            x86_64|amd64)
                compose_url="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64"
                ;;
            aarch64|arm64)
                compose_url="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64"
                ;;
            *)
                print_error "不支持的架构: $arch"
                return 1
                ;;
        esac
        
        curl -L "$compose_url" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        print_success "Docker Compose 安装完成"
        write_log "$LOG_LEVEL_INFO" "Docker Compose 已安装"
    else
        print_success "Docker Compose 已安装: $(docker-compose --version)"
    fi
}

# 安装 acme.sh
install_acme() {
    print_step "安装 acme.sh"
    
    if [ -f "/root/.acme.sh/acme.sh" ]; then
        print_success "acme.sh 已安装"
        return 0
    fi
    
    print_info "正在安装 acme.sh..."
    wget -qO- get.acme.sh | bash
    source ~/.bashrc 2>/dev/null || true
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt 2>/dev/null || true
    mkdir -p /etc/ssl
    
    print_success "acme.sh 安装完成"
    write_log "$LOG_LEVEL_INFO" "acme.sh 已安装"
}

# 扫描模块
scan_modules() {
    local modules=()
    if [ -d "$SCRIPT_DIR/modules" ]; then
        for module in "$SCRIPT_DIR/modules"/*.sh; do
            if [ -f "$module" ]; then
                local name=$(basename "$module" .sh)
                modules+=("$name:$module")
            fi
        done
    fi
    printf '%s\n' "${modules[@]}"
}

# 安装模块
install_module() {
    local module_path="$1"
    local module_name=$(basename "$module_path" .sh)
    
    print_step "安装模块: $module_name"
    write_log "$LOG_LEVEL_INFO" "开始安装模块: $module_name"
    
    local start_time=$(date +%s)
    
    source "$module_path"
    if declare -f install > /dev/null; then
        if install; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_success "模块 $module_name 安装完成 (耗时 ${duration}秒)"
            write_log "$LOG_LEVEL_INFO" "模块 $module_name 安装成功"
            return 0
        else
            print_error "模块 $module_name 安装失败"
            write_log "$LOG_LEVEL_ERROR" "模块 $module_name 安装失败"
            return 1
        fi
    else
        print_error "模块 $module_name 缺少 install 函数"
        return 1
    fi
}

# 运行防火墙模块
run_firewall_module() {
    local firewall_path="$SCRIPT_DIR/modules/firewall.sh"
    if [ -f "$firewall_path" ]; then
        print_step "运行防火墙模块"
        source "$firewall_path"
        if declare -f install > /dev/null; then
            install
        fi
    else
        print_warning "防火墙模块不存在"
    fi
}

# 显示最终摘要
show_summary() {
    print_step "部署完成 - 汇总"
    
    echo ""
    echo "日志文件位置: $LOG_FILE"
    echo "凭证文件位置: $CREDENTIALS_FILE"
    echo ""
    
    if [ -f "$CREDENTIALS_FILE" ]; then
        echo "已安装服务凭证："
        echo "=================="
        cat "$CREDENTIALS_FILE"
    fi
    
    local server_ip=$(get_server_ip)
    echo ""
    echo "快速访问地址："
    echo "=================="
    
    if docker ps --format 'table' 2>/dev/null | grep -q "nginx-proxy-manager"; then
        echo "NPM WebUI  : http://$server_ip:81"
    fi
    if [ -f "/usr/local/bin/komari" ]; then
        echo "Komari     : http://$server_ip:8008"
    fi
    if docker ps --format 'table' 2>/dev/null | grep -q "easyimg"; then
        echo "EasyImg    : http://$server_ip:3000"
    fi
    if docker ps --format 'table' 2>/dev/null | grep -q "qbittorrent"; then
        echo "qBittorrent: http://$server_ip:8080"
    fi
    if systemctl is-active --quiet alist 2>/dev/null; then
        echo "Alist      : http://$server_ip:5244"
    fi
}

# 主函数
main() {
    check_root
    install_base_deps
    install_docker
    install_acme
    init_credentials
    
    while true; do
        print_step "选择要安装的应用"
        
        # 获取模块列表
        local modules_list=$(scan_modules)
        local modules_count=$(echo "$modules_list" | grep -c ':' 2>/dev/null || echo "0")
        
        if [ "$modules_count" -eq 0 ]; then
            print_error "未找到任何模块，请确保 modules/ 目录下有 .sh 文件"
            exit 1
        fi
        
        # 显示菜单
        echo ""
        local i=1
        declare -A module_map
        while IFS=: read -r name path; do
            echo "  $i. $name"
            module_map["$i"]="$path"
            ((i++))
        done <<< "$modules_list"
        echo "  f. 配置防火墙"
        echo "  u. 卸载已安装的应用"
        echo "  0. 退出"
        echo ""
        
        read -p "请输入选择: " choice
        
        case $choice in
            0)
                print_info "退出"
                exit 0
                ;;
            [fF])
                run_firewall_module
                ;;
            [uU])
                if [ -f "$SCRIPT_DIR/utils/uninstall.sh" ]; then
                    bash "$SCRIPT_DIR/utils/uninstall.sh"
                else
                    print_warning "卸载脚本不存在: utils/uninstall.sh"
                fi
                ;;
            *)
                if [[ -n "${module_map[$choice]}" ]]; then
                    install_module "${module_map[$choice]}"
                    
                    echo ""
                    read -p "是否配置防火墙？(y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        run_firewall_module
                    fi
                else
                    print_error "无效选择"
                fi
                ;;
        esac
        
        echo ""
        read -p "按回车键返回主菜单..."
    done
}

# 运行主函数
main "$@"
