#!/bin/bash
# Alist 模块
# 版本: v2.0

install() {
    print_info "安装 Alist (原生一键脚本)"

    # 检查端口冲突
    if check_port_in_use 5244; then
        print_error "端口 5244 已被占用"
        return 1
    fi

    curl -fsSL "https://alist.nn.ci/v3.sh" | bash -s install
    sleep 3

    if health_check_systemd "alist"; then
        health_check_tcp "localhost" 5244 10 2
        
        local server_ip=$(get_server_ip)
        local ALIST_PWD=$(alist admin random 2>&1 | grep -oP '密码：\K.*' || echo "请运行 'alist admin random' 获取")
        
        record_credential "Alist" "admin" "$ALIST_PWD" \
            "访问地址: http://${server_ip}:5244\n  使用 'alist admin random' 可重置密码"
        
        print_success "Alist 安装完成"
        return 0
    else
        print_error "Alist 启动失败"
        journalctl -u alist -n 20 --no-pager
        return 1
    fi
}
# ============================================
# 卸载函数
# ============================================
uninstall() {
    print_warning "卸载 Alist 将删除所有配置和数据"
    read -p "确认卸载？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl stop alist 2>/dev/null
        systemctl disable alist 2>/dev/null
        rm -f /etc/systemd/system/alist.service
        rm -rf /opt/alist
        curl -fsSL "https://alist.nn.ci/v3.sh" | bash -s uninstall 2>/dev/null
        systemctl daemon-reload
        print_success "Alist 已卸载"
        write_log "$LOG_LEVEL_INFO" "Alist 已卸载"
    fi
}
