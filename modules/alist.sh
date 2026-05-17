cd /root/theboxes

cat > modules/alist.sh << 'EOF'
#!/bin/bash
# Alist 模块
# 下载源：GitHub Releases（统一）

MODULE_NAME="Alist"
MODULE_DESC="网盘聚合工具"

install() {
    print_step "安装 Alist"

    # 检查端口冲突
    if check_port_in_use 5244; then
        print_error "端口 5244 已被占用"
        return 1
    fi

    # 安装依赖
    apt install -y unzip wget tar 2>/dev/null

    # 创建目录
    local ALIST_DIR="/opt/alist"
    mkdir -p "$ALIST_DIR"
    cd "$ALIST_DIR"

    # 检测架构
    local arch=$(uname -m)
    local alist_arch=""
    
    case $arch in
        x86_64|amd64)
            alist_arch="amd64"
            ;;
        aarch64|arm64)
            alist_arch="arm64"
            ;;
        armv7l|armv8l)
            alist_arch="armv7"
            ;;
        *)
            print_error "不支持的架构: $arch"
            return 1
            ;;
    esac

    # 获取最新版本号
    print_info "获取最新版本信息..."
    local latest_version=$(curl -s https://api.github.com/repos/alist-org/alist/releases/latest | grep -oP '"tag_name": "\K[^"]+' | sed 's/v//')
    
    if [ -z "$latest_version" ]; then
        latest_version="3.40.0"
        print_warning "获取版本失败，使用默认版本: $latest_version"
    else
        print_info "最新版本: $latest_version"
    fi

    # 下载 Alist（优先使用普通版，失败则用 musl 版）
    local download_url="https://github.com/alist-org/alist/releases/download/v${latest_version}/alist-linux-${alist_arch}.tar.gz"
    print_info "下载地址: $download_url"

    local download_success=false
    
    for retry in $(seq 1 3); do
        print_info "下载尝试 $retry/3..."
        if wget -q --show-progress "$download_url" -O alist.tar.gz 2>&1; then
            if tar -tzf alist.tar.gz &>/dev/null; then
                download_success=true
                break
            fi
        fi
        print_warning "下载失败，重试中..."
        rm -f alist.tar.gz
        sleep 3
    done

    # 如果普通版失败，尝试 musl 版
    if [ "$download_success" = false ]; then
        print_info "尝试下载 musl 版本..."
        download_url="https://github.com/alist-org/alist/releases/download/v${latest_version}/alist-linux-musl-${alist_arch}.tar.gz"
        
        for retry in $(seq 1 3); do
            print_info "下载尝试 $retry/3..."
            if wget -q --show-progress "$download_url" -O alist.tar.gz 2>&1; then
                if tar -tzf alist.tar.gz &>/dev/null; then
                    download_success=true
                    break
                fi
            fi
            rm -f alist.tar.gz
            sleep 3
        done
    fi

    if [ "$download_success" = false ]; then
        print_error "下载失败，请检查网络"
        return 1
    fi

    # 解压
    print_info "解压 Alist..."
    tar -xzf alist.tar.gz
    chmod +x alist

    # 创建 systemd 服务
    print_info "创建 systemd 服务..."
    cat > /etc/systemd/system/alist.service << EOF
[Unit]
Description=Alist
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$ALIST_DIR
ExecStart=$ALIST_DIR/alist server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # 启动服务
    systemctl daemon-reload
    systemctl enable alist
    systemctl start alist

    sleep 3

    # 健康检查
    if systemctl is-active --quiet alist; then
        local server_ip=$(get_server_ip)
        
        # 获取管理员密码
        local admin_password=$(./alist admin 2>/dev/null | grep -oE '[a-zA-Z0-9]{8,}' | head -1)
        if [ -z "$admin_password" ]; then
            admin_password=$(./alist admin 2>/dev/null | grep -i "password" | awk '{print $NF}')
        fi
        if [ -z "$admin_password" ]; then
            admin_password="请运行 /opt/alist/alist admin 查看"
        fi
        
        print_success "Alist 安装完成"
        record_credential "Alist" "admin" "$admin_password" \
            "访问地址: http://${server_ip}:5244"
        
        echo ""
        print_info "连接信息："
        echo "  地址: http://${server_ip}:5244"
        echo "  用户名: admin"
        echo "  密码: $admin_password"
        echo ""
        print_warning "首次登录请立即修改密码"
        
        return 0
    else
        print_error "Alist 启动失败"
        journalctl -u alist -n 20 --no-pager
        return 1
    fi
}

uninstall() {
    print_warning "卸载 Alist 将删除所有配置和数据"
    read -p "确认卸载？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl stop alist 2>/dev/null
        systemctl disable alist 2>/dev/null
        rm -f /etc/systemd/system/alist.service
        rm -rf /opt/alist
        systemctl daemon-reload
        print_success "Alist 已卸载"
    fi
}
EOF

echo "Alist 模块已更新，统一使用 GitHub 下载"
