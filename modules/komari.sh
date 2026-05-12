#!/bin/bash
# Komari 探针模块

install() {
    print_info "安装 Komari 探针 (原生二进制)"
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
    print_success "Komari 已启动，端口 8008"
    record_credential "Komari 探针" "" "" "访问地址: http://$(curl -s ifconfig.me):8008 (无默认密码)"
}
