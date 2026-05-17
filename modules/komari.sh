#!/bin/bash
# Komari 探针模块 - Docker Compose 部署版本

MODULE_NAME="Komari"
MODULE_DESC="服务器监控探针 (Docker Compose)"

# 检查端口是否被占用的函数 (需依赖主脚本的 common.sh)
# check_port_in_use 由 lib/common.sh 提供

install() {
    print_step "安装 Komari 探针 (Docker Compose)"

    # 1. 检查端口占用
    if check_port_in_use 25774; then
        print_error "端口 25774 已被占用，无法安装 Komari"
        return 1
    fi

    # 2. 创建目录和 docker-compose.yml
    local KOMARI_DIR="/opt/komari"
    mkdir -p "$KOMARI_DIR"
    cd "$KOMARI_DIR" || return 1

    print_info "创建 docker-compose.yml 配置文件..."
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  komari:
    image: ghcr.io/komari-monitor/komari:latest
    container_name: komari
    restart: unless-stopped
    ports:
      - "25774:25774"
    volumes:
      - ./data:/app/data
    environment:
      - TZ=Asia/Shanghai
EOF

    # 3. 拉取镜像并启动容器
    print_info "正在拉取镜像并启动 Komari..."
    docker compose up -d

    # 4. 等待容器启动并检查状态
    print_info "等待服务启动..."
    sleep 10

    if ! docker ps | grep -q komari; then
        print_error "Komari 容器启动失败"
        docker compose logs --tail 30
        return 1
    fi

    # 5. 从日志中获取初始密码
    local admin_password=$(docker logs komari 2>&1 | grep -oP '(?<=password: ).*')

    if [ -z "$admin_password" ]; then
        admin_password="请使用 'docker logs komari' 查看初始密码"
        print_warning "未能自动获取密码"
    fi

    # 6. 记录凭证并输出信息
    local server_ip=$(get_server_ip)
    record_credential "Komari" "admin" "$admin_password" "访问地址: http://${server_ip}:25774"

    print_success "Komari 安装成功！"
    echo ""
    print_info "访问地址: http://${server_ip}:25774"
    print_info "用户名: admin"
    print_info "密码: $admin_password"
    echo ""
    print_warning "请登录后立即修改默认密码"

    return 0
}

# 卸载函数
uninstall() {
    print_step "卸载 Komari"

    local KOMARI_DIR="/opt/komari"
    if [ -d "$KOMARI_DIR" ]; then
        cd "$KOMARI_DIR" || return 1
        docker compose down -v
        cd .. && rm -rf "$KOMARI_DIR"
        print_success "Komari 及其数据已卸载。"
    else
        print_warning "未找到 Komari 安装目录，可能已被卸载。"
    fi
}
