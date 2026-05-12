#!/bin/bash
# EasyImg 图床模块
# 版本: v2.0

install() {
    print_info "安装 EasyImg 图床 (Docker Compose)"

    EASYIMG_DIR="/opt/easyimg"
    
    # 检查端口冲突
    if check_port_in_use 3000; then
        print_error "端口 3000 已被占用，EasyImg 需要此端口"
        return 1
    fi

    mkdir -p "${EASYIMG_DIR}"
    cd "${EASYIMG_DIR}"

    cat > docker-compose.yml << 'EOF'
services:
  easyimg:
    image: ghcr.io/chaos-zhu/easyimg:latest
    container_name: easyimg
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./db:/app/db
      - ./uploads:/app/uploads
    environment:
      - TZ=Asia/Shanghai
EOF

    docker compose up -d

    if health_check_docker "easyimg" 15 3; then
        health_check_http "http://localhost:3000" 200 10 3
        
        local server_ip=$(get_server_ip)
        record_credential "EasyImg 图床" "easyimg" "easyimg" \
            "访问地址: http://${server_ip}:3000\n  首次登录后请立即修改密码"
        
        print_success "EasyImg 安装完成"
        return 0
    else
        print_error "EasyImg 启动失败"
        return 1
    fi
}
