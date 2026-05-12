#!/bin/bash
# Nginx Proxy Manager 模块
# 版本: v2.0

install() {
    print_info "安装 Nginx Proxy Manager (Docker)"

    NPM_DIR="/opt/nginx-proxy-manager"
    
    # 检查端口冲突
    for port in 80 81 443; do
        if check_port_in_use $port; then
            print_error "端口 $port 已被占用，NPM 需要此端口"
            return 1
        fi
    done

    mkdir -p "$NPM_DIR"
    cd "$NPM_DIR"

    cat > docker-compose.yml << 'EOF'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    environment:
      TZ: "Asia/Shanghai"
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

    docker compose up -d

    if health_check_docker "nginx-proxy-manager" 15 3; then
        health_check_http "http://localhost:81" 200 10 3
        
        local server_ip=$(get_server_ip)
        record_credential "Nginx Proxy Manager" "admin@example.com" "changeme" \
            "WebUI: http://${server_ip}:81\n  首次登录请修改密码"
        
        print_success "NPM 安装完成"
        return 0
    else
        print_error "NPM 启动失败"
        return 1
    fi
}
# ============================================
# 卸载函数
# ============================================
uninstall() {
    print_warning "卸载 Nginx Proxy Manager 将删除所有配置数据"
    read -p "确认卸载？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd /opt/nginx-proxy-manager 2>/dev/null
        docker compose down -v 2>/dev/null
        rm -rf /opt/nginx-proxy-manager
        print_success "Nginx Proxy Manager 已卸载"
        write_log "$LOG_LEVEL_INFO" "Nginx Proxy Manager 已卸载"
    fi
}
