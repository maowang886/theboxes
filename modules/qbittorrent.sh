#!/bin/bash
# qBittorrent 模块

install() {
    print_info "安装 qBittorrent (原生 nox)"
    apt update
    apt install -y qbittorrent-nox
    cat > /etc/systemd/system/qbittorrent-nox.service << EOF
[Unit]
Description=qBittorrent-nox
After=network.target

[Service]
User=root
ExecStart=/usr/bin/qbittorrent-nox --webui-port=8083
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable qbittorrent-nox
    systemctl start qbittorrent-nox
    print_success "qBittorrent 已启动，WebUI 端口 8083"
    record_credential "qBittorrent" "admin" "adminadmin" "WebUI端口8083，首次登录建议修改密码"
}
