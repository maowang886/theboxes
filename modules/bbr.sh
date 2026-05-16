#!/bin/bash
# ============================================
# BBR 一键开启/管理模块
# 功能: 启用/禁用 BBR 拥塞控制算法
# 版本: v1.0
# ============================================

MODULE_NAME="BBR 网络加速"
MODULE_DESC="启用 BBR 拥塞控制算法，提升网络性能"
MODULE_PORT=""

# ============================================
# 主安装函数
# ============================================
install() {
    print_step "BBR 网络加速管理"

    # 检查内核版本
    local kernel_version=$(uname -r | cut -d'-' -f1)
    local kernel_major=$(echo "$kernel_version" | cut -d'.' -f1)
    local kernel_minor=$(echo "$kernel_version" | cut -d'.' -f2)

    print_info "当前内核版本: $kernel_version"

    if [ "$kernel_major" -lt 4 ] || ([ "$kernel_major" -eq 4 ] && [ "$kernel_minor" -lt 9 ]); then
        print_error "BBR 需要内核版本 >= 4.9"
        echo "当前内核版本过低，请先升级内核后再试"
        echo "升级命令: apt update && apt install -y linux-image-amd64"
        return 1
    fi

    # 检测当前状态
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    
    echo ""
    print_info "当前状态："
    echo "  TCP 拥塞控制算法: $current_cc"
    echo "  默认队列算法: $current_qdisc"
    echo ""

    # 判断 BBR 是否已启用
    if [ "$current_cc" = "bbr" ] && [ "$current_qdisc" = "fq" ]; then
        print_success "BBR 已启用"
        echo ""
        print_info "可执行操作："
        echo "  1. 禁用 BBR (恢复默认算法)"
        echo "  2. 检查 BBR 运行状态"
        echo "  3. 查看 BBR 相关信息"
        echo "  0. 返回"
        read -p "请选择: " action
        case $action in
            1) disable_bbr ;;
            2) check_bbr_status ;;
            3) show_bbr_info ;;
            0) return 0 ;;
            *) print_error "无效选择" ;;
        esac
    else
        # BBR 未启用，询问是否启用
        print_warning "BBR 未启用"
        read -p "是否启用 BBR？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            enable_bbr
        else
            print_info "已取消"
        fi
    fi
}

# ============================================
# 启用 BBR
# ============================================
enable_bbr() {
    print_step "启用 BBR"

    # 备份当前 sysctl 配置
    local backup_file="/etc/sysctl.conf.bak.$(date +%Y%m%d_%H%M%S)"
    cp /etc/sysctl.conf "$backup_file"
    print_info "已备份系统参数: $backup_file"

    # 检查是否已有相关配置，避免重复添加
    if ! grep -q "net.core.default_qdisc" /etc/sysctl.conf; then
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
        print_info "添加 net.core.default_qdisc = fq"
    else
        sed -i 's/^#\?net.core.default_qdisc.*/net.core.default_qdisc = fq/' /etc/sysctl.conf
    fi

    if ! grep -q "net.ipv4.tcp_congestion_control" /etc/sysctl.conf; then
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
        print_info "添加 net.ipv4.tcp_congestion_control = bbr"
    else
        sed -i 's/^#\?net.ipv4.tcp_congestion_control.*/net.ipv4.tcp_congestion_control = bbr/' /etc/sysctl.conf
    fi

    # 应用配置
    print_info "应用 sysctl 配置..."
    sysctl -p > /dev/null 2>&1

    # 验证是否生效
    local new_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    local new_qdisc=$(sysctl -n net.core.default_qdisc)

    if [ "$new_cc" = "bbr" ] && [ "$new_qdisc" = "fq" ]; then
        print_success "BBR 已成功启用"
        record_credential "BBR 网络加速" "" "" \
            "TCP 算法: bbr\n  队列算法: fq\n  配置生效无需重启"
        
        # 显示当前可用的拥塞算法
        echo ""
        print_info "当前系统支持的其他 TCP 算法："
        sysctl net.ipv4.tcp_available_congestion_control
        echo ""
        print_warning "注意：BBR 已生效，无需重启服务器"
    else
        print_error "BBR 启用失败"
        echo "当前 TCP 算法: $new_cc"
        echo "当前队列算法: $new_qdisc"
        return 1
    fi
}

# ============================================
# 禁用 BBR（恢复默认 Cubic + pfifo_fast）
# ============================================
disable_bbr() {
    print_step "禁用 BBR"

    read -p "确认禁用 BBR 并恢复默认算法？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi

    # 备份当前配置
    local backup_file="/etc/sysctl.conf.bak.$(date +%Y%m%d_%H%M%S)"
    cp /etc/sysctl.conf "$backup_file"
    print_info "已备份系统参数: $backup_file"

    # 移除或注释 BBR 相关行
    sed -i 's/^net.core.default_qdisc = fq/#net.core.default_qdisc = fq/' /etc/sysctl.conf
    sed -i 's/^net.ipv4.tcp_congestion_control = bbr/#net.ipv4.tcp_congestion_control = bbr/' /etc/sysctl.conf

    # 也可以显式设置默认值
    echo "net.core.default_qdisc = pfifo_fast" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = cubic" >> /etc/sysctl.conf

    # 应用配置
    sysctl -p > /dev/null 2>&1

    local new_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    local new_qdisc=$(sysctl -n net.core.default_qdisc)

    if [ "$new_cc" = "cubic" ] && [ "$new_qdisc" = "pfifo_fast" ]; then
        print_success "BBR 已禁用，已恢复默认 Cubic 算法"
    else
        print_warning "当前算法: $new_cc / $new_qdisc"
    fi
}

# ============================================
# 检查 BBR 运行状态
# ============================================
check_bbr_status() {
    print_step "BBR 运行状态"

    local cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    local qdisc=$(sysctl -n net.core.default_qdisc)
    local tcp_info=$(sysctl net.ipv4.tcp_congestion_control)

    echo "TCP 拥塞控制算法: $cc"
    echo "默认队列算法: $qdisc"
    echo ""
    
    if [ "$cc" = "bbr" ]; then
        print_success "BBR 已启用"
        # 可选：检查 tcp_bbr 模块是否加载
        if lsmod | grep -q tcp_bbr; then
            echo "tcp_bbr 内核模块已加载"
        else
            echo "tcp_bbr 内核模块未加载（可能已编译进内核）"
        fi
    else
        print_warning "BBR 未启用，当前算法: $cc"
    fi

    echo ""
    print_info "所有可用 TCP 算法:"
    sysctl net.ipv4.tcp_available_congestion_control

    read -p "按回车键返回..."
}

# ============================================
# 显示 BBR 相关信息
# ============================================
show_bbr_info() {
    print_step "BBR 相关资料"

    echo "BBR (Bottleneck Bandwidth and RTT) 是 Google 开发的 TCP 拥塞控制算法。"
    echo ""
    echo "优点："
    echo "  - 提高网络吞吐量，尤其在高延迟、高丢包环境下"
    echo "  - 降低延迟，适合视频流、网页浏览"
    echo "  - 与锐速、腾讯 TCPA 等不同，开源且集成于内核"
    echo ""
    echo "内核要求: >= 4.9"
    echo "当前内核: $(uname -r)"
    echo ""
    echo "手动验证 BBR 是否生效:"
    echo "  sysctl net.ipv4.tcp_congestion_control"
    echo "  lsmod | grep bbr"
    echo ""
    echo "参考链接: https://github.com/google/bbr"

    read -p "按回车键返回..."
}

# ============================================
# 卸载函数（恢复默认配置）
# ============================================
uninstall() {
    print_step "恢复 BBR 配置"
    
    read -p "是否将 TCP 算法恢复为默认 (cubic)？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi

    disable_bbr
    print_success "已恢复默认网络配置"
}
