#!/bin/bash
# ============================================
# Swap 虚拟内存管理模块
# 功能: 查看、创建、调整、删除 Swap
# 适用: 低配服务器（甲骨文免费机、轻量云等）
# 版本: v1.0
# ============================================

MODULE_NAME="Swap 虚拟内存"
MODULE_DESC="管理 Swap 分区/文件，优化内存使用"
MODULE_PORT=""

# ============================================
# 主安装函数（管理入口）
# ============================================
install() {
    print_step "Swap 虚拟内存管理"

    echo ""
    echo "请选择操作："
    echo "  1. 查看当前 Swap 状态"
    echo "  2. 创建/调整 Swap"
    echo "  3. 删除 Swap"
    echo "  4. 优化 Swap 参数（swappiness）"
    echo "  0. 返回"
    echo ""
    read -p "请选择: " swap_choice

    case $swap_choice in
        1) show_swap_status ;;
        2) create_swap ;;
        3) delete_swap ;;
        4) optimize_swappiness ;;
        0) return 0 ;;
        *) print_error "无效选择" ;;
    esac
}

# ============================================
# 查看 Swap 状态
# ============================================
show_swap_status() {
    print_step "当前 Swap 状态"

    echo ""
    echo "=== Swap 总体信息 ==="
    swapon --show 2>/dev/null || echo "未启用任何 Swap"
    echo ""
    echo "=== 内存使用情况 ==="
    free -h
    echo ""
    echo "=== Swap 详细参数 ==="
    cat /proc/sys/vm/swappiness 2>/dev/null | xargs echo "swappiness ="
    cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null | xargs echo "vfs_cache_pressure ="
    echo ""
    
    # 检查是否有 swapfile
    if [ -f /swapfile ]; then
        local swap_size=$(du -h /swapfile | cut -f1)
        echo "Swap 文件: /swapfile (大小: $swap_size)"
    fi
    
    read -p "按回车键返回菜单..."
}

# ============================================
# 计算推荐的 Swap 大小
# ============================================
calculate_swap_size() {
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local recommended=0
    
    if [ $total_mem -le 2048 ]; then
        # 内存 ≤ 2GB: Swap = 内存 × 2
        recommended=$((total_mem * 2))
    elif [ $total_mem -le 8192 ]; then
        # 内存 2-8GB: Swap = 内存 × 1.5
        recommended=$((total_mem * 3 / 2))
    elif [ $total_mem -le 16384 ]; then
        # 内存 8-16GB: Swap = 内存 × 1
        recommended=$total_mem
    else
        # 内存 ≥ 16GB: Swap = 8GB 足够
        recommended=8192
    fi
    
    # 设置最小和最大限制
    if [ $recommended -lt 512 ]; then
        recommended=512
    elif [ $recommended -gt 16384 ]; then
        recommended=16384
    fi
    
    echo "$recommended"
}

# ============================================
# 创建/调整 Swap
# ============================================
create_swap() {
    print_step "创建/调整 Swap"

    # 显示当前状态
    local current_swap=$(swapon --show --noheadings 2>/dev/null | wc -l)
    if [ $current_swap -gt 0 ]; then
        print_warning "检测到已有 Swap"
        swapon --show
        echo ""
        read -p "是否删除现有 Swap 并重新创建？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            delete_swap true
        else
            return 0
        fi
    fi

    # 获取内存大小并推荐 Swap 大小
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local recommended=$(calculate_swap_size)
    
    echo ""
    print_info "检测到内存: ${total_mem}MB"
    print_info "推荐 Swap 大小: ${recommended}MB"
    echo ""
    
    echo "请选择 Swap 大小："
    echo "  1. 推荐大小: ${recommended}MB"
    echo "  2. 自定义大小"
    echo "  3. 2GB (2048MB) - 轻量使用"
    echo "  4. 4GB (4096MB) - 一般使用"
    echo "  5. 8GB (8192MB) - 重度使用"
    read -p "请选择 (1-5): " size_choice

    local swap_size_mb=0
    case $size_choice in
        1) swap_size_mb=$recommended ;;
        2) 
            read -p "请输入 Swap 大小 (MB): " swap_size_mb
            if ! [[ "$swap_size_mb" =~ ^[0-9]+$ ]] || [ $swap_size_mb -lt 128 ]; then
                print_error "请输入有效的数字（最小 128MB）"
                return 1
            fi
            ;;
        3) swap_size_mb=2048 ;;
        4) swap_size_mb=4096 ;;
        5) swap_size_mb=8192 ;;
        *) print_error "无效选择" ; return 1 ;;
    esac

    print_info "将创建 ${swap_size_mb}MB 的 Swap"

    # 检查磁盘空间
    local available_space=$(df -m / | awk 'NR==2 {print $4}')
    if [ $available_space -lt $((swap_size_mb + 512)) ]; then
        print_error "磁盘空间不足！可用: ${available_space}MB，需要: ${swap_size_mb}MB"
        return 1
    fi

    # 创建 Swap 文件
    print_info "创建 Swap 文件中..."
    fallocate -l ${swap_size_mb}M /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=$swap_size_mb status=progress

    # 设置权限
    chmod 600 /swapfile

    # 格式化为 Swap
    mkswap /swapfile

    # 启用 Swap
    swapon /swapfile

    # 写入 fstab（持久化）
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi

    # 显示结果
    print_success "Swap 创建完成！"
    echo ""
    free -h
    
    # 记录凭证
    record_credential "Swap 虚拟内存" "" "" \
        "Swap 大小: ${swap_size_mb}MB\n  Swap 文件: /swapfile\n  已写入 /etc/fstab 确保开机自启"
    
    read -p "按回车键返回菜单..."
}

# ============================================
# 删除 Swap
# ============================================
delete_swap() {
    local silent=${1:-false}
    
    if [ "$silent" != "true" ]; then
        print_step "删除 Swap"
        read -p "确认删除所有 Swap？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    # 关闭所有 Swap
    swapoff -a

    # 删除 swapfile
    if [ -f /swapfile ]; then
        rm -f /swapfile
        print_success "已删除 /swapfile"
    fi

    # 删除 fstab 中的 swap 条目
    sed -i '/\/swapfile/d' /etc/fstab

    if [ "$silent" != "true" ]; then
        print_success "Swap 已全部删除"
        free -h
        read -p "按回车键返回菜单..."
    fi
}

# ============================================
# 优化 Swap 参数（swappiness）
# ============================================
optimize_swappiness() {
    print_step "优化 Swap 参数"

    local current=$(cat /proc/sys/vm/swappiness)
    
    echo ""
    print_info "当前 swappiness 值: $current"
    echo ""
    echo "swappiness 说明："
    echo "  0-10   : 尽量少用 Swap（推荐 SSD 服务器）"
    echo "  10-60  : 平衡模式"
    echo "  60-100 : 积极使用 Swap（推荐 HDD 或内存较小服务器）"
    echo "  默认值 : 60"
    echo ""
    
    echo "请选择预设方案："
    echo "  1. 极致性能 - swappiness=10（SSD 推荐）"
    echo "  2. 平衡模式 - swappiness=30"
    echo "  3. 默认模式 - swappiness=60"
    echo "  4. 保守模式 - swappiness=80（内存小推荐）"
    echo "  5. 自定义输入"
    read -p "请选择 (1-5): " opt_choice

    local new_value=0
    case $opt_choice in
        1) new_value=10 ;;
        2) new_value=30 ;;
        3) new_value=60 ;;
        4) new_value=80 ;;
        5) 
            read -p "请输入 swappiness 值 (0-100): " new_value
            if ! [[ "$new_value" =~ ^[0-9]+$ ]] || [ $new_value -lt 0 ] || [ $new_value -gt 100 ]; then
                print_error "无效输入，请输入 0-100 的数字"
                return 1
            fi
            ;;
        *) print_error "无效选择" ; return 1 ;;
    esac

    # 临时生效
    echo "$new_value" > /proc/sys/vm/swappiness
    
    # 永久生效（写入 sysctl.conf）
    if grep -q "^vm.swappiness" /etc/sysctl.conf; then
        sed -i "s/^vm.swappiness.*/vm.swappiness = $new_value/" /etc/sysctl.conf
    else
        echo "vm.swappiness = $new_value" >> /etc/sysctl.conf
    fi

    print_success "swappiness 已优化为 $new_value"
    print_info "当前值: $(cat /proc/sys/vm/swappiness)"
    
    read -p "按回车键返回菜单..."
}

# ============================================
# 卸载函数（删除 Swap）
# ============================================
uninstall() {
    delete_swap false
}
