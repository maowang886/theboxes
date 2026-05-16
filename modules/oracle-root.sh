#!/bin/bash
# ============================================
# 甲骨文云 - 启用 Root 登录脚本
# 功能: 修改 SSH 配置允许 Root 登录，并设置 Root 密码
# 适用: Oracle Cloud Ubuntu/Debian/CentOS 实例
# 版本: v1.0
# ============================================

MODULE_NAME="甲骨文云 Root 登录"
MODULE_DESC="启用 Root 登录并设置密码"
MODULE_PORT=""

install() {
    print_step "甲骨文云 - 启用 Root 登录"

    print_info "此脚本将执行以下操作："
    echo "  1. 修改 SSH 配置，允许密码登录"
    echo "  2. 修改 SSH 配置，允许 Root 登录"
    echo "  3. 设置 Root 密码（随机生成或手动输入）"
    echo "  4. 重启 SSH 服务"
    echo ""

    read -p "是否继续？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 0
    fi

    # 1. 备份 SSH 配置文件
    local sshd_config="/etc/ssh/sshd_config"
    local backup_file="/etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)"

    print_info "备份 SSH 配置: $backup_file"
    cp "$sshd_config" "$backup_file"

    # 2. 修改配置
    print_info "修改 SSH 配置..."

    # 启用密码登录
    if grep -q "^PasswordAuthentication" "$sshd_config"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$sshd_config"
    else
        echo "PasswordAuthentication yes" >> "$sshd_config"
    fi

    # 启用 Root 登录
    if grep -q "^PermitRootLogin" "$sshd_config"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$sshd_config"
    else
        echo "PermitRootLogin yes" >> "$sshd_config"
    fi

    # 可选：禁用 ChallengeResponseAuthentication
    if grep -q "^ChallengeResponseAuthentication" "$sshd_config"; then
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$sshd_config"
    fi

    print_success "SSH 配置修改完成"

    # 3. 设置 Root 密码
    echo ""
    print_info "设置 Root 密码"

    echo "请选择密码设置方式："
    echo "  1. 随机生成密码（推荐）"
    echo "  2. 手动输入密码"
    read -p "请选择 (1/2): " pwd_choice

    local root_password=""

    case $pwd_choice in
        1)
            # 随机生成 16 位密码（大小写字母+数字）
            root_password=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
            print_info "随机生成的密码: $root_password"
            echo "$root_password" | passwd --stdin root 2>/dev/null || echo "root:$root_password" | chpasswd
            ;;
        2)
            # 手动输入密码（隐藏输入）
            while true; do
                read -s -p "请输入 Root 密码: " root_password
                echo ""
                read -s -p "再次输入确认: " root_password2
                echo ""
                if [ "$root_password" = "$root_password2" ] && [ -n "$root_password" ]; then
                    break
                else
                    print_error "两次输入不一致或密码为空，请重新输入"
                fi
            done
            echo "root:$root_password" | chpasswd
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac

    print_success "Root 密码设置完成"

    # 4. 重启 SSH 服务
    print_info "重启 SSH 服务..."
    systemctl restart sshd

    if systemctl is-active --quiet sshd; then
        print_success "SSH 服务重启成功"
    else
        print_error "SSH 服务启动失败，正在恢复备份..."
        cp "$backup_file" "$sshd_config"
        systemctl restart sshd
        print_warning "已恢复原配置"
        return 1
    fi

    # 5. 获取服务器 IP
    local server_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "未知")

    # 6. 记录凭证
    record_credential "甲骨文云 Root 登录" "root" "$root_password" \
        "服务器 IP: $server_ip\n  SSH 端口: 22\n  配置备份: $backup_file\n  首次登录建议修改密码"

    # 7. 输出成功信息
    print_success "甲骨文云 Root 登录配置完成！"
    echo ""
    echo "========================================="
    print_info "登录信息："
    echo "  SSH 命令: ssh root@$server_ip"
    echo "  密码: $root_password"
    echo "  SSH 端口: 22"
    echo ""
    print_warning "请保存好密码，建议首次登录后立即修改"
    echo "========================================="
    echo ""
    print_info "验证 SSH 配置："
    echo "  grep -E 'PasswordAuthentication|PermitRootLogin' /etc/ssh/sshd_config"
}

# ============================================
# 卸载/恢复函数
# ============================================
uninstall() {
    print_warning "恢复 SSH 配置到修改前状态"

    local sshd_config="/etc/ssh/sshd_config"
    local backup_file=$(ls -t /etc/ssh/sshd_config.bak.* 2>/dev/null | head -1)

    if [ -z "$backup_file" ]; then
        print_error "未找到备份文件"
        read -p "是否手动禁用 Root 登录？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' "$sshd_config"
            sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$sshd_config"
            systemctl restart sshd
            print_success "已手动禁用 Root 密码登录"
        fi
        return 0
    fi

    print_info "恢复备份: $backup_file"
    cp "$backup_file" "$sshd_config"
    systemctl restart sshd

    print_success "SSH 配置已恢复"
    print_warning "Root 密码登录已被禁用，请使用原账号登录"
}
