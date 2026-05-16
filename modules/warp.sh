#!/bin/bash
# ============================================
# WARP 一键管理模块
# 基于 Misaka-blog/warp-script 设计
# 功能: WGCF/WARP-GO/WARP-Cli 安装、账户切换、刷流量
# 版本: v1.0
# ============================================

MODULE_NAME="CloudFlare WARP"
MODULE_DESC="WARP 一键管理脚本"
MODULE_PORT=""

# WARP 配置文件路径
WGCF_DIR="/etc/wireguard"
WARP_GO_DIR="/opt/warp-go"
WARP_CLI_DIR="/opt/warp-cli"

# ============================================
# 主安装函数
# ============================================
install() {
    print_step "CloudFlare WARP 一键管理"

    # 检查是否已安装
    if check_warp_installed; then
        print_warning "检测到已安装 WARP"
        echo ""
        echo "请选择操作："
        echo "  1. 管理已安装的 WARP"
        echo "  2. 重新安装"
        echo "  0. 返回"
        read -p "请选择: " choice
        case $choice in
            1) manage_warp ;;
            2) install_warp ;;
            0) return 0 ;;
            *) print_error "无效选择" ;;
        esac
    else
        install_warp
    fi
}

# ============================================
# 检查 WARP 是否已安装
# ============================================
check_warp_installed() {
    # 检查 WGCF
    if [ -f "$WGCF_DIR/wgcf.conf" ] && command -v wg-quick &> /dev/null; then
        return 0
    fi
    # 检查 WARP-GO
    if [ -f "$WARP_GO_DIR/warp-go" ] && systemctl is-active --quiet warp-go 2>/dev/null; then
        return 0
    fi
    # 检查 WARP-Cli
    if command -v warp-cli &> /dev/null; then
        return 0
    fi
    return 1
}

# ============================================
# 安装 WARP 主菜单
# ============================================
install_warp() {
    print_step "选择 WARP 客户端类型"

    echo ""
    echo "WARP 客户端说明："
    echo "  WGCF     - WireGuard 客户端，性能好，香港/美西等区域可能被限制"
    echo "  WARP-GO  - 第三方客户端，适合被限制的区域"
    echo "  WARP-Cli - CloudFlare 官方客户端，仅支持 AMD64 架构"
    echo ""
    echo "请选择："
    echo "  1. WGCF (推荐，非限制区域)"
    echo "  2. WARP-GO (适合香港/美西等限制区域)"
    echo "  3. WARP-Cli (官方客户端，仅 AMD64)"
    echo "  0. 返回"
    read -p "请选择: " warp_choice

    case $warp_choice in
        1) install_wgcf ;;
        2) install_warp_go ;;
        3) install_warp_cli ;;
        0) return 0 ;;
        *) print_error "无效选择" ;;
    esac
}

# ============================================
# 安装 WGCF (WireGuard 客户端)
# ============================================
install_wgcf() {
    print_step "安装 WGCF"

    # 检查架构支持
    local arch=$(uname -m)
    case $arch in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)
            print_error "WGCF 不支持当前架构: $arch"
            return 1
            ;;
    esac

    # 安装 WireGuard 工具
    print_info "安装 WireGuard 工具..."
    apt update -qq
    apt install -y wireguard-tools wireguard-dkms

    # 下载 wgcf
    print_info "下载 wgcf..."
    local wgcf_url="https://github.com/ViRb3/wgcf/releases/latest/download/wgcf_${ARCH}_linux"
    curl -L -o /usr/local/bin/wgcf "$wgcf_url"
    chmod +x /usr/local/bin/wgcf

    # 注册账户
    print_info "注册 WARP 账户..."
    cd /tmp
    echo "yes" | wgcf register

    # 生成配置文件
    print_info "生成 WireGuard 配置..."
    wgcf generate

    # 移动配置文件
    mkdir -p "$WGCF_DIR"
    mv wgcf-profile.conf "$WGCF_DIR/wgcf.conf"

    # 修改配置（启用 NAT 转发）
    sed -i 's/Table = off/Table = auto/g' "$WGCF_DIR/wgcf.conf"

    # 获取 Endpoint IP（针对 IPv6 Only 机器优化）
    if [ ! -f /proc/sys/net/ipv4/ip_forward ] || [ "$(cat /proc/sys/net/ipv4/ip_forward)" -eq 0 ]; then
        echo 1 > /proc/sys/net/ipv4/ip_forward
    fi

    # 启动 WARP
    print_info "启动 WARP..."
    wg-quick up wgcf

    # 设置开机自启
    systemctl enable wg-quick@wgcf 2>/dev/null

    # 健康检查
    sleep 3
    if check_wgcf_status; then
        local warp_ip=$(curl -s --interface wgcf --max-time 5 ifconfig.me 2>/dev/null || echo "获取失败")
        print_success "WGCF 安装成功"
        record_credential "WARP (WGCF)" "" "" \
            "WARP IP: $warp_ip\n  配置文件: $WGCF_DIR/wgcf.conf\n  管理命令: wg-quick up/down wgcf"
    else
        print_error "WGCF 启动失败"
        return 1
    fi
}

# ============================================
# 安装 WARP-GO
# ============================================
install_warp_go() {
    print_step "安装 WARP-GO"

    local arch=$(uname -m)
    case $arch in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)
            print_error "WARP-GO 不支持当前架构: $arch"
            return 1
            ;;
    esac

    # 创建目录
    mkdir -p "$WARP_GO_DIR"
    cd "$WARP_GO_DIR"

    # 下载 WARP-GO
    print_info "下载 WARP-GO..."
    local warp_go_url="https://gitlab.com/ProjectWARP/warp-go/-/releases/latest/download/warp-go_linux_${ARCH}.tar.gz"
    curl -L -o warp-go.tar.gz "$warp_go_url"
    tar -xzf warp-go.tar.gz
    chmod +x warp-go

    # 安装 WARP-GO
    print_info "安装 WARP-GO..."
    ./warp-go install

    # 启动服务
    systemctl start warp-go
    systemctl enable warp-go

    # 健康检查
    sleep 3
    if systemctl is-active --quiet warp-go; then
        local warp_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "获取失败")
        print_success "WARP-GO 安装成功"
        record_credential "WARP (WARP-GO)" "" "" \
            "WARP IP: $warp_ip\n  管理命令: systemctl start/stop warp-go"
    else
        print_error "WARP-GO 启动失败"
        return 1
    fi
}

# ============================================
# 安装 WARP-Cli (官方客户端)
# ============================================
install_warp_cli() {
    print_step "安装 WARP-Cli"

    # 检查架构 (仅支持 amd64)
    local arch=$(uname -m)
    if [ "$arch" != "x86_64" ] && [ "$arch" != "amd64" ]; then
        print_error "WARP-Cli 仅支持 AMD64 架构，当前架构: $arch"
        return 1
    fi

    # 添加 CloudFlare 官方仓库
    print_info "添加 CloudFlare 官方仓库..."
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list

    # 安装
    apt update -qq
    apt install -y cloudflare-warp

    # 注册并连接
    print_info "注册 WARP 客户端..."
    warp-cli register
    warp-cli connect

    # 设置开机自启
    warp-cli enable-always-on

    # 健康检查
    sleep 3
    local status=$(warp-cli status 2>/dev/null | grep -i "Status" | awk '{print $2}')
    if [ "$status" = "Connected" ]; then
        local warp_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "获取失败")
        print_success "WARP-Cli 安装成功"
        record_credential "WARP (WARP-Cli)" "" "" \
            "WARP IP: $warp_ip\n  管理命令: warp-cli status/connect/disconnect"
    else
        print_error "WARP-Cli 启动失败"
        return 1
    fi
}

# ============================================
# 管理已安装的 WARP
# ============================================
manage_warp() {
    print_step "WARP 管理"

    # 检测已安装的客户端类型
    local warp_type=""
    if [ -f "$WGCF_DIR/wgcf.conf" ] && wg-quick show wgcf &>/dev/null; then
        warp_type="wgcf"
    elif systemctl is-active --quiet warp-go 2>/dev/null; then
        warp_type="warp-go"
    elif command -v warp-cli &> /dev/null; then
        warp_type="warp-cli"
    fi

    if [ -z "$warp_type" ]; then
        print_error "未检测到已安装的 WARP 客户端"
        return 1
    fi

    echo ""
    echo "当前 WARP 状态："
    case $warp_type in
        wgcf)
            wg-quick show wgcf | head -5
            echo ""
            echo "WARP IP: $(curl -s --interface wgcf --max-time 5 ifconfig.me 2>/dev/null || echo '无法获取')"
            ;;
        warp-go)
            systemctl status warp-go --no-pager | grep -E "Active|Main"
            ;;
        warp-cli)
            warp-cli status
            ;;
    esac

    echo ""
    echo "请选择操作："
    echo "  1. 重启 WARP"
    echo "  2. 停止 WARP"
    echo "  3. 启动 WARP"
    echo "  4. 切换账户类型 (免费/WARP+/Teams)"
    echo "  5. 刷 WARP+ 流量"
    echo "  6. 提取配置文件"
    echo "  7. 卸载 WARP"
    echo "  0. 返回"
    read -p "请选择: " manage_choice

    case $manage_choice in
        1) restart_warp "$warp_type" ;;
        2) stop_warp "$warp_type" ;;
        3) start_warp "$warp_type" ;;
        4) switch_account "$warp_type" ;;
        5) add_warp_plus_traffic "$warp_type" ;;
        6) extract_config "$warp_type" ;;
        7) uninstall ;;
        0) return 0 ;;
        *) print_error "无效选择" ;;
    esac
}

# ============================================
# WARP 控制函数
# ============================================
restart_warp() {
    local type=$1
    case $type in
        wgcf) wg-quick down wgcf && wg-quick up wgcf ;;
        warp-go) systemctl restart warp-go ;;
        warp-cli) warp-cli disconnect && warp-cli connect ;;
    esac
    print_success "WARP 已重启"
}

stop_warp() {
    local type=$1
    case $type in
        wgcf) wg-quick down wgcf ;;
        warp-go) systemctl stop warp-go ;;
        warp-cli) warp-cli disconnect ;;
    esac
    print_success "WARP 已停止"
}

start_warp() {
    local type=$1
    case $type in
        wgcf) wg-quick up wgcf ;;
        warp-go) systemctl start warp-go ;;
        warp-cli) warp-cli connect ;;
    esac
    print_success "WARP 已启动"
}

# ============================================
# 切换账户类型
# ============================================
switch_account() {
    local type=$1
    print_info "切换账户类型"

    echo ""
    echo "支持的账户类型："
    echo "  1. 免费版 (WARP Free)"
    echo "  2. WARP+ (需要 License Key)"
    echo "  3. Teams (需要 Token)"
    read -p "请选择: " account_type

    case $type in
        wgcf)
            print_warning "WGCF 切换账户需要重新生成配置"
            read -p "是否重新注册？(y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                wg-quick down wgcf
                rm -f /tmp/wgcf-account.toml
                cd /tmp
                echo "yes" | wgcf register
                wgcf generate
                cp wgcf-profile.conf "$WGCF_DIR/wgcf.conf"
                wg-quick up wgcf
                print_success "账户已切换"
            fi
            ;;
        warp-go)
            cd "$WARP_GO_DIR"
            ./warp-go update-license
            systemctl restart warp-go
            ;;
        warp-cli)
            warp-cli disconnect
            warp-cli delete
            warp-cli register
            if [ "$account_type" = "2" ]; then
                read -p "请输入 WARP+ License Key: " license_key
                warp-cli set-license "$license_key"
            fi
            warp-cli connect
            ;;
    esac
}

# ============================================
# 刷 WARP+ 流量
# ============================================
add_warp_plus_traffic() {
    local type=$1
    print_info "为 WARP+ 账户刷流量"

    read -p "请输入设备 ID (Device ID): " device_id
    if [ -z "$device_id" ]; then
        print_error "设备 ID 不能为空"
        return 1
    fi

    print_info "开始刷流量..."
    for i in {1..30}; do
        curl -s -o /dev/null "https://api.cloudflareclient.com/v0a1809/reg/${device_id}"
        if [ $((i % 10)) -eq 0 ]; then
            print_info "已执行 $i 次请求..."
        fi
        sleep 0.5
    done
    print_success "刷流量完成 (共30次请求)"
}

# ============================================
# 提取配置文件
# ============================================
extract_config() {
    local type=$1
    local config_dir="/root/warp_config_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$config_dir"

    print_info "提取 WARP 配置文件到: $config_dir"

    case $type in
        wgcf)
            cp "$WGCF_DIR/wgcf.conf" "$config_dir/wgcf.conf"
            print_success "WireGuard 配置文件已导出: $config_dir/wgcf.conf"
            echo "可用于 Sing-box、Xray 等客户端"
            ;;
        warp-go)
            if [ -f "$WARP_GO_DIR/warp-go.conf" ]; then
                cp "$WARP_GO_DIR/warp-go.conf" "$config_dir/"
            fi
            print_success "WARP-GO 配置已导出: $config_dir/"
            ;;
        warp-cli)
            warp-cli settings > "$config_dir/warp-cli-settings.txt"
            print_success "WARP-Cli 配置已导出: $config_dir/warp-cli-settings.txt"
            ;;
    esac
}

# ============================================
# 检查 WGCF 状态
# ============================================
check_wgcf_status() {
    if command -v wg-quick &> /dev/null && wg-quick show wgcf &>/dev/null; then
        return 0
    fi
    return 1
}

# ============================================
# 卸载函数
# ============================================
uninstall() {
    print_warning "卸载 WARP 将删除所有配置"

    # 检测已安装的客户端类型
    local warp_type=""
    if [ -f "$WGCF_DIR/wgcf.conf" ]; then
        warp_type="wgcf"
    elif [ -f "$WARP_GO_DIR/warp-go" ]; then
        warp_type="warp-go"
    elif command -v warp-cli &> /dev/null; then
        warp_type="warp-cli"
    fi

    read -p "确认卸载？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi

    case $warp_type in
        wgcf)
            wg-quick down wgcf 2>/dev/null
            systemctl disable wg-quick@wgcf 2>/dev/null
            rm -rf "$WGCF_DIR"
            apt remove -y wireguard-tools 2>/dev/null
            ;;
        warp-go)
            systemctl stop warp-go 2>/dev/null
            systemctl disable warp-go 2>/dev/null
            rm -rf "$WARP_GO_DIR"
            ;;
        warp-cli)
            warp-cli disconnect 2>/dev/null
            warp-cli disable-always-on 2>/dev/null
            apt remove -y cloudflare-warp 2>/dev/null
            ;;
    esac

    print_success "WARP 已卸载"
    write_log "$LOG_LEVEL_INFO" "WARP 已卸载"
}
