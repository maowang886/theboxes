#!/bin/bash
# 端口开放模块 (iptables)

install() {
    print_info "检测并开放常用端口"
    
    COMMON_PORTS=(22 80 81 443 4837 8008 8082 8083 5244)
    MISSING_PORTS=()
    
    for port in "${COMMON_PORTS[@]}"; do
        if ! iptables -L INPUT -n 2>/dev/null | grep -q "dpt:$port"; then
            MISSING_PORTS+=("$port")
        fi
    done
    
    if [ ${#MISSING_PORTS[@]} -eq 0 ]; then
        print_success "所有常用端口均已开放"
        return
    fi
    
    print_warning "以下端口未开放：${MISSING_PORTS[@]}"
    read -p "是否开放这些端口？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "跳过端口开放"
        return
    fi
    
    for port in "${MISSING_PORTS[@]}"; do
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
    done
    
    # 确保持久化工具已安装
    if ! dpkg -l | grep -q iptables-persistent; then
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
        apt-get install -y iptables-persistent
    fi
    
    netfilter-persistent save
    netfilter-persistent reload
    print_success "端口 ${MISSING_PORTS[@]} 已开放并持久化"
}
