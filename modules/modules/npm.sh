#!/bin/bash
# Nginx Proxy Manager 模块

install() {
    print_info "安装 Nginx Proxy Manager (Docker)"
    NPM_DIR="/opt/nginx-proxy-manager"
    mkdir -p "$NPM_DIR"
    cd "$NPM_DIR"
    if [ ! -f docker-compose.yml ]; then
        cat > docker-compose.yml << 'EOF'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    environment:
      TZ: "Australia/Brisbane"
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF
    fi
    docker-compose up -d
    print_success "NPM 已启动，WebUI 端口 81"
    record_credential "Nginx Proxy Manager" "admin@example.com" "changeme" "首次登录请修改密码，WebUI端口81"
}
