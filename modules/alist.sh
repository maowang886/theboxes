#!/bin/bash
# ============================================
# Alist 模块 - 网盘聚合工具
# 方式：直接下载 GitHub 预编译二进制，手动配置 systemd
# ============================================

MODULE_NAME="Alist"
MODULE_DESC="网盘聚合工具"

install() {
    print_step "安装 Alist"

    if check_port_in_use 5244; then
        print_error "端口 5244 已被占用"
        return 1
    fi

    # 安装依赖
    apt update -qq && apt install -y wget tar >/dev/null 2>&1

    # 创建目录
    local ALIST_DIR="/opt/alist"
    mkdir -p "$ALIST_DIR"
    cd "$ALIST_DIR"

    # 检测架构
    local arch=$(uname -m)
    local alist_arch=""
    case $arch in
        x86_64|amd64) alist_arch="amd64" ;;
        aarch64|arm64) alist_arch="arm64" ;;
        armv7l) alist_arch="armv7" ;;
        *) print_error "不支持的架构: $arch"; return 1 ;;
    esac

    # 获取最新版本号
    print_info "获取最新版本..."
    local latest_version=$(curl -s https://api.github.com/repos/alist-org/alist/releases/latest | grep -oP '"tag_name": "\K[^"]+' | sed 's/v//')
    if [ -z "$latest_version" ]; then
        latest_version="3.40.0"
        print_warning "版本获取失败，使用默认版本 $latest_version"
    else
        print_info "最新版本: $latest_version"
    fi

    # 下载
    local download_url="https://github.com/alist-org/alist/releases/download/v${latest_version}/alist-linux-${alist_arch}.tar.gz"
    print_info "下载地址: $download_url"

    local retry=0
    while [ $retry -lt 3 ]; do
        if wget -q --show-progress "$download_url" -O alist.tar.gz; then
            break
        fi
        retry=$((retry+1))
        print_warning "下载失败，重试 $retry/3"
        sleep 3
    done

    if [ ! -f alist.tar.gz ]; then
        print_error "下载失败"
        return 1
    fi

    # 解压
    tar -xzf alist.tar.gz
    chmod +x alist

    # 创建 systemd 服务
    cat > /etc/systemd/system/alist.service << 'EOF'
[Unit]
Description=Alist
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/alist
ExecStart=/opt/alist/alist server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable alist
    systemctl start alist

    sleep 3

    if systemctl is-active --quiet alist; then
        local server_ip=$(get_server_ip)
        # 获取 admin 密码
        local admin_password=$(/opt/alist/alist admin 2>/dev/null | grep -oE '[a-zA-Z0-9]{8,}' | head -1)
        if [ -z "$admin_password" ]; then
            admin_password="请手动运行 /opt/alist/alist admin 查看"
        fi

        print_success "Alist 安装完成"
        record_credential "Alist" "admin" "$admin_password" "http://${server_ip}:5244"
        echo ""
        print_info "连接信息："
        echo "  地址: http://${server_ip}:5244"
        echo "  用户名: admin"
        echo "  密码: $admin_password"
    else
        print_error "Alist 启动失败"
        journalctl -u alist -n 20 --no-pager
        return 1
    fi
}

uninstall() {
    print_warning "卸载 Alist 将删除所有配置和数据"
    read -p "确认？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl stop alist 2>/dev/null
        systemctl disable alist 2>/dev/null
        rm -rf /opt/alist
        rm -f /etc/systemd/system/alist.service
        systemctl daemon-reload
        print_success "Alist 已卸载"
    fi
}
