
#!/bin/bash
# ============================================
# Alist 模块 - 网盘聚合工具
# 修复：非交互式安装，自动绕过官方脚本菜单
# ============================================

MODULE_NAME="Alist"
MODULE_DESC="网盘聚合工具"

install() {
    print_step "安装 Alist"

    # 检查端口是否被占用
    if check_port_in_use 5244; then
        print_error "端口 5244 已被占用，无法安装 Alist"
        return 1
    fi

    print_info "正在静默安装 Alist（自动选择安装选项）..."

    # 关键修复：用 echo "1" 模拟用户输入，选择安装选项
    # 同时捕获输出，避免交互卡住
    echo "1" | curl -fsSL https://alist.nn.ci/v3.sh | bash

    # 等待服务文件生成
    sleep 3

    # 如果服务文件存在，则启动并启用
    if [ -f /etc/systemd/system/alist.service ]; then
        systemctl daemon-reload
        systemctl enable alist
        systemctl start alist
    elif [ -f /usr/lib/systemd/system/alist.service ]; then
        systemctl daemon-reload
        systemctl enable alist
        systemctl start alist
    else
        print_error "Alist 服务文件未创建，安装失败"
        return 1
    fi

    # 等待服务完全启动
    sleep 3

    # 健康检查
    if systemctl is-active --quiet alist; then
        local server_ip=$(get_server_ip)
        # 获取 admin 密码
        local admin_password=$(/opt/alist/alist admin 2>/dev/null | grep -oE '[a-zA-Z0-9]{8,}' | head -1)
        if [ -z "$admin_password" ]; then
            admin_password=$(/opt/alist/alist admin 2>/dev/null | grep -i "password" | awk '{print $NF}')
        fi
        if [ -z "$admin_password" ]; then
            admin_password="请手动运行 /opt/alist/alist admin 查看"
        fi

        print_success "Alist 安装完成"
        record_credential "Alist" "admin" "$admin_password" "http://${server_ip}:5244"

        echo ""
        print_info "连接信息："
        echo "  地址: http://${server_ip}:5244"
        echo "  用户名: admin"
        echo "  密码: $admin_password"
        echo ""
        print_warning "首次登录请立即修改密码"
    else
        print_error "Alist 启动失败"
        journalctl -u alist -n 20 --no-pager
        return 1
    fi
}

uninstall() {
    print_warning "卸载 Alist 将删除所有配置和数据"
    read -p "确认卸载？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl stop alist 2>/dev/null
        systemctl disable alist 2>/dev/null
        rm -rf /opt/alist
        rm -f /etc/systemd/system/alist.service
        rm -f /usr/lib/systemd/system/alist.service
        systemctl daemon-reload
        print_success "Alist 已卸载"
    fi
}
