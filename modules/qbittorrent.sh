#!/bin/bash
# qBittorrent 模块 (Docker Compose 部署)
# 功能：WebUI 固定端口 8080，BT 流量端口随机生成

install() {
    print_info "安装 qBittorrent (Docker Compose)"

    # 定义安装目录
    QB_DIR="/opt/qbittorrent"
    WEBUI_PORT="8080"
    
    # 随机生成 BT 流量端口（范围 10000-60000）
    BT_PORT=$(shuf -i 10000-60000 -n 1)
    
    print_info "WebUI 端口: ${WEBUI_PORT}"
    print_info "随机生成的 BT 流量端口: ${BT_PORT} (TCP/UDP)"

    # 创建目录
    print_info "创建目录: ${QB_DIR}"
    mkdir -p "${QB_DIR}/config"
    mkdir -p "${QB_DIR}/downloads"

    cd "${QB_DIR}"

    # 检查是否已安装
    if docker ps --format 'table' 2>/dev/null | grep -q "qbittorrent"; then
        print_warning "qBittorrent 容器已在运行"
        read -p "是否重新部署？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "跳过安装"
            return 0
        fi
        # 停止并删除旧容器
        docker compose down 2>/dev/null
    fi

    # 创建 docker-compose.yml
    print_info "创建 docker-compose.yml..."
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
    print_info "拉取镜像并启动 qBittorrent..."
    docker compose up -d

    # 等待服务启动
    sleep 5

    # 检查容器状态
    if docker ps --format 'table' | grep -q "qbittorrent"; then
        print_success "qBittorrent 启动成功"
        
        local server_ip=$(curl -s ifconfig.me)
        record_credential "qBittorrent" "admin" "adminadmin" \
            "WebUI: http://${server_ip}:${WEBUI_PORT}\n  BT 流量端口: ${BT_PORT} (TCP/UDP)\n  默认密码请在首次登录后修改\n  下载目录: ${QB_DIR}/downloads"
        
        echo ""
        print_info "连接信息："
        echo "  WebUI: http://${server_ip}:${WEBUI_PORT}"
        echo "  用户名: admin"
        echo "  密码: adminadmin"
        echo "  BT 流量端口: ${BT_PORT} (TCP/UDP)"
        echo ""
        print_info "额外命令："
        echo "  查看日志: docker logs -f qbittorrent"
        echo "  重启服务: cd ${QB_DIR} && docker compose restart"
        echo "  停止服务: cd ${QB_DIR} && docker compose down"
        echo "  更新镜像: cd ${QB_DIR} && docker compose pull && docker compose up -d"
    else
        print_error "qBittorrent 启动失败"
        return 1
    fi
}
