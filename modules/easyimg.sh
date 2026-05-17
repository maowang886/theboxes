#!/bin/bash
# ============================================
# EasyImg 图床模块 - Docker Compose 部署版本
# 使用官方 docker-compose.yml 文件
# 默认账户：easyimg / easyimg
# ============================================

MODULE_NAME="EasyImg"
MODULE_DESC="图床服务 (Docker Compose)"

# 检查端口是否被占用的函数 (需依赖主脚本的 common.sh)
# check_port_in_use 由 lib/common.sh 提供

install() {
    print_step "安装 EasyImg 图床"

    # 1. 检查端口占用
    if check_port_in_use 3000; then
        print_error "端口 3000 已被占用，无法安装 EasyImg"
        return 1
    fi

    # 2. 创建目录和下载 docker-compose.yml
    local EASYIMG_DIR="/opt/easyimg"
    mkdir -p "$EASYIMG_DIR"
    cd "$EASYIMG_DIR" || return 1

    print_info "下载 docker-compose.yml 配置文件..."
    if ! wget -q --show-progress https://git.221022.xyz/https://raw.githubusercontent.com/chaos-zhu/easyimg/refs/heads/main/docker-compose.yml -O docker-compose.yml; then
        print_error "下载 docker-compose.yml 失败，请检查网络连接"
        return 1
    fi

    # 3. 拉取镜像并启动容器
    print_info "正在拉取镜像并启动 EasyImg..."
    docker compose up -d

    # 4. 等待容器启动并检查状态
    print_info "等待服务启动..."
    sleep 10

    if ! docker ps | grep -q easyimg; then
        print_error "EasyImg 容器启动失败"
        docker compose logs --tail 30
        return 1
    fi

    # 5. 记录凭证并输出信息
    local server_ip=$(get_server_ip)
    record_credential "EasyImg 图床" "easyimg" "easyimg" "访问地址: http://${server_ip}:3000"

    print_success "EasyImg 安装成功！"
    echo ""
    print_info "访问地址: http://${server_ip}:3000"
    print_info "用户名: easyimg"
    print_info "密码: easyimg"
    echo ""
    print_warning "请登录后立即修改默认用户名和密码"

    return 0
}

# 卸载函数
uninstall() {
    print_step "卸载 EasyImg"

    local EASYIMG_DIR="/opt/easyimg"
    if [ -d "$EASYIMG_DIR" ]; then
        cd "$EASYIMG_DIR" || return 1
        docker compose down -v
        cd .. && rm -rf "$EASYIMG_DIR"
        print_success "EasyImg 及其数据已卸载。"
    else
        print_warning "未找到 EasyImg 安装目录，可能已被卸载。"
    fi
}
