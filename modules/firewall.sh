#!/bin/bash
# 端口开放模块 (iptables)
# 功能1: 自动检测已安装服务或已知服务端口并开放
# 功能2: 手动输入端口开放（可多选）

install() {
    print_step "端口开放管理"

    echo ""
    echo "请选择端口开放方式："
    echo "  1. 检测并开放服务端口（自动识别已安装/常用服务端口）"
    echo "  2. 自定义开放端口（手动输入）"
    echo "  0. 返回"
    echo ""
    read -p "请输入选择 (1/2/0): " port_choice

    case $port_choice in
        1)
            auto_open_service_ports
            ;;
        2)
            manual_open_ports
            ;;
        0)
            print_info "返回上级菜单"
            return 0
            ;;
        *)
            print_warning "无效选择"
            ;;
    esac
}

# ========== 功能1: 自动检测服务端口 ==========
auto_open_service_ports() {
    print_step "自动检测服务端口"

    # 定义已知服务及其端口（可扩展）
    declare -A SERVICE_PORTS
    SERVICE_PORTS=(
        ["SSH"]="22"
        ["HTTP"]="80"
        ["HTTPS"]="443"
        ["Nginx Proxy Manager"]="80 81 443"
        ["Komari 探针"]="8008"
        ["EasyImg 图床"]="3000"
        ["qBittorrent"]="8083"
        ["Alist"]="5244"
        ["Trojan/Xray"]="4837"
    )

    # 检测已安装的服务（通过文件/进程/容器）
    local installed_services=()
    local all_ports=()

    # 检查 SSH（通常都装）
    installed_services+=("SSH")
    all_ports+=("22")

    # 检查 Nginx Proxy Manager (Docker)
    if docker ps --format 'table' 2>/dev/null | grep -q "nginx-proxy-manager"; then
        installed_services+=("Nginx Proxy Manager")
        all_ports+=("80" "81" "443")
    fi

    # 检查 Komari
    if [ -f "/usr/local/bin/komari" ] || systemctl is-active --quiet komari 2>/dev/null; then
        installed_services+=("Komari 探针")
        all_ports+=("8008")
    fi

    # 检查 EasyImg
    if docker ps --format 'table' 2>/dev/null | grep -q "easyimg"; then
        installed_services+=("EasyImg 图床")
        all_ports+=("3000")
    fi

    # 检查 qBittorrent
    if systemctl is-active --quiet qbittorrent-nox 2>/dev/null; then
        installed_services+=("qBittorrent")
        all_ports+=("8083")
    fi

    # 检查 Alist
    if systemctl is-active --quiet alist 2>/dev/null; then
        installed_services+=("Alist")
        all_ports+=("5244")
    fi

    # 检查 Xray
    if systemctl is-active --quiet xray 2>/dev/null; then
        installed_services+=("Trojan/Xray")
        all_ports+=("4837")
    fi

    if [ ${#installed_services[@]} -eq 0 ]; then
        print_warning "未检测到已安装的服务"
        echo ""
        read -p "是否仍要开放常用端口 (22,80,443)？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open_ports "22" "80" "443"
        fi
        return
    fi

    # 显示检测到的服务
    echo ""
    print_info "检测到以下已安装的服务："
    for svc in "${installed_services[@]}"; do
        echo "  - ${svc} (端口: ${SERVICE_PORTS[$svc]})"
    done

    # 去重端口列表
    local unique_ports=($(echo "${all_ports[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    echo ""
    print_info "即将开放的端口: ${unique_ports[@]}"

    read -p "是否开放这些端口？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open_ports "${unique_ports[@]}"
    else
        print_info "跳过端口开放"
    fi
}

# ========== 功能2: 手动开放端口 ==========
manual_open_ports() {
    print_step "自定义开放端口"

    echo "请输入要开放的端口（多个端口用空格隔开）"
    echo "示例: 22 80 443 3000 8080"
    echo ""
    read -p "端口: " -a manual_ports

    if [ ${#manual_ports[@]} -eq 0 ]; then
        print_warning "未输入任何端口"
        return
    fi

    # 验证端口格式（简单检查是否为数字）
    local valid_ports=()
    for port in "${manual_ports[@]}"; do
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
            valid_ports+=("$port")
        else
            print_warning "忽略无效端口: $port"
        fi
    done

    if [ ${#valid_ports[@]} -eq 0 ]; then
        print_error "没有有效的端口"
        return
    fi

    echo ""
    print_info "即将开放端口: ${valid_ports[@]}"
    read -p "确认开放？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open_ports "${valid_ports[@]}"
    else
        print_info "取消操作"
    fi
}

# ========== 通用端口开放函数 ==========
open_ports() {
    local ports_to_open=("$@")
    
    if [ ${#ports_to_open[@]} -eq 0 ]; then
        print_warning "没有需要开放的端口"
        return
    fi

    # 检查当前已开放的端口
    local existing_ports=""
    if command -v iptables &> /dev/null; then
        existing_ports=$(iptables -L INPUT -n 2>/dev/null | grep -oP 'dpt:\K[0-9]+' | sort -u)
    fi

    local new_ports=()
    for port in "${ports_to_open[@]}"; do
        if echo "$existing_ports" | grep -q "^${port}$"; then
            print_info "端口 ${port} 已开放，跳过"
        else
            new_ports+=("$port")
        fi
    done

    if [ ${#new_ports[@]} -eq 0 ]; then
        print_success "所有端口均已开放"
        return
    fi

    # 开放新端口
    for port in "${new_ports[@]}"; do
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
        print_success "已开放端口 ${port}"
    done

    # 安装持久化工具（如果需要）
    if ! dpkg -l | grep -q iptables-persistent 2>/dev/null; then
        print_info "安装 iptables-persistent..."
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
        apt-get install -y iptables-persistent
    fi

    # 保存规则
    netfilter-persistent save
    netfilter-persistent reload

    print_success "端口开放完成，已持久化保存"
    
    # 显示当前规则
    echo ""
    print_info "当前 INPUT 链规则："
    iptables -L INPUT -n --line-numbers | grep -E "(Chain|dpt:)"
}
