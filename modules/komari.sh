#!/bin/bash
# Komari 探针模块
# 版本: v2.0

install() {
    print_info "安装 Komari 探针 (原生二进制)"

    # 检查端口冲突
    if check_port_in_use 8008; then
        print_error "端口 8008 已被占用"
        return 1
    fi

    curl -L https://github.com/1Panel-dev/komari/releases/latest/download/komari-linux-amd64 -o /usr/local/bin/komari
    chmod +x /usr/local/bin/komari
    
    cat > /etc/systemd/system/komari.service << EOF
[Unit]
Description=Komari Monitor
After=network.target

[Service]
ExecStart=/usr/local/bin/komari server
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable komari
    systemctl start komari

    if health_check_systemd "komari"; then
        health_check_tcp "localhost" 8008 10 2
        
        local server_ip=$(get_server_ip)
        record_credential "Komari 探针" "" "" \
            "访问地址: http://${server_ip}:8008 (无默认密码)"
        
        print_success "Komari 安装完成"
        return 0
    else
        print_error "Komari 启动失败"
        journalctl -u komari -n 20 --no-pager
        return 1
    fi
}
