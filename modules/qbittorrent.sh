#!/bin/bash
# qBittorrent 模块
# 版本: v2.0

MODULE_NAME="qBittorrent"
MODULE_PORT="8080"

install() {
    print_info "安装 qBittorrent (Docker Compose)"

    # 定义安装目录
    QB_DIR="/opt/qbittorrent"
    WEBUI_PORT="8080"
    
    # 检查端口冲突
    if check_port_in_use "$WEBUI_PORT"; then
        print_error "端口 $WEBUI_PORT 已被占用，请先停止占用该端口的服务"
        return 1
    fi
    
    # 生成随机 BT 流量端口
    BT_PORT=$(generate_random_port 10000 60000)
    print_info "WebUI 端口: ${WEBUI_PORT}"
    print_info "随机生成的 BT 流量端口: ${BT_PORT} (TCP/UDP)"

    # 创建目录
    mkdir -p "${QB_DIR}/config" "${QB_DIR}/downloads"
    cd "${QB_DIR}"

    # 检查是否已安装
    if docker ps --format 'table' 2>/dev/null | grep -q "qbittorrent"; then
        print_warning "qBittorrent 容器已在运行"
        read -p "是否重新部署？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        docker compose down 2>/dev/null
    fi

    # 创建 docker-compose.yml
    cat > docker-compose.yml << EOF
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - WEBUI_PORT=${WEBUI_PORT}
    ports:
      - "${WEBUI_PORT}:${WEBUI_PORT}"
      - "${BT_PORT}:6881"
      - "${BT_PORT}:6881/udp"
    volumes:
      - ./config:/config
      - ./downloads:/downloads
EOF

    # 启动容器
    docker compose up -d

    # 健康检查
    if health_check_docker "qbittorrent" 15 3; then
        local server_ip=$(get_server_ip)
        record_credential "qBittorrent" "admin" "adminadmin" \
            "WebUI: http://${server_ip}:${WEBUI_PORT}\n  BT 流量端口: ${BT_PORT} (TCP/UDP)\n  默认密码请在首次登录后修改"
        
        # WebUI 健康检查
        health_check_http "http://localhost:${WEBUI_PORT}" 200 5 2 || \
            print_warning "WebUI 健康检查失败，但容器运行正常"
        
        print_success "qBittorrent 安装完成"
        echo ""
        print_info "连接信息："
        echo "  WebUI: http://${server_ip}:${WEBUI_PORT}"
        echo "  用户名: admin"
        echo "  密码: adminadmin"
        echo "  BT 流量端口: ${BT_PORT} (TCP/UDP)"
        return 0
    else
        print_error "qBittorrent 启动失败"
        docker logs --tail 30 qbittorrent
        return 1
    fi
}

# 卸载函数
uninstall() {
    print_warning "卸载 qBittorrent 将删除所有配置和下载文件"
    read -p "确认卸载？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd /opt/qbittorrent 2>/dev/null
        docker compose down -v 2>/dev/null
        rm -rf /opt/qbittorrent
        print_success "qBittorrent 已卸载"
        write_log "$LOG_LEVEL_INFO" "qBittorrent 已卸载"
    fi
}
