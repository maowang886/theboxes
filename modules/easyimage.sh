#!/bin/bash
# EasyImg 图床模块 (chaos-zhu/easyimg)
# 功能：一站式图床服务，支持公共上传、AI 鉴黄、数据统计等

install() {
    print_info "开始安装 EasyImg 图床 (Docker 部署)"

    # 1. 定义安装目录和版本
    EASYIMG_DIR="/opt/easyimg"
    local compose_url="https://git.221022.xyz/https://raw.githubusercontent.com/chaos-zhu/easyimg/refs/heads/main/docker-compose.yml"

    # 2. 创建目录并下载 docker-compose.yml
    print_info "创建目录: ${EASYIMG_DIR}"
    mkdir -p "${EASYIMG_DIR}"
    cd "${EASYIMG_DIR}"

    if [ -f "docker-compose.yml" ]; then
        print_warning "发现已有 docker-compose.yml，将进行备份"
        cp docker-compose.yml "docker-compose.yml.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    print_info "下载 docker-compose.yml..."
    if ! wget -q --show-progress "${compose_url}" -O docker-compose.yml; then
        print_error "下载 docker-compose.yml 失败，请检查网络连接"
        return 1
    fi

    # 3. (可选) 微调 compose 文件，确保数据持久化目录
    print_info "准备数据目录..."
    mkdir -p data/uploads

    # 4. 启动容器
    print_info "正在拉取镜像并启动 EasyImg 容器..."
    if ! docker compose up -d; then
        print_error "Docker Compose 启动失败，请检查 Docker 服务和网络"
        return 1
    fi

    # 5. 等待服务就绪
    print_info "等待服务启动 (约 10 秒)..."
    sleep 10

    # 6. 输出访问信息与默认凭证
    local server_ip=$(curl -s ifconfig.me)
    print_success "EasyImg 部署成功！"
    record_credential "EasyImg 图床" "easyimg" "easyimg" \
        "访问地址: http://${server_ip}:3000\n  首次登录后请务必修改默认密码！数据目录: ${EASYIMG_DIR}"
    
    # 额外提示
    echo ""
    print_info "额外命令："
    echo "  查看日志: docker logs -f easyimg"
    echo "  重启服务: cd ${EASYIMG_DIR} && docker compose restart"
    echo "  停止服务: cd ${EASYIMG_DIR} && docker compose down"
    echo "  更新服务: cd ${EASYIMG_DIR} && docker compose pull && docker compose up -d"
}
