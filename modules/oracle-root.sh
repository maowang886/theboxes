#!/bin/bash
# ============================================
# 甲骨文云 - 启用 Root 登录脚本
# 版本: v2.0 (修复版)
# ============================================

MODULE_NAME="甲骨文云 Root 登录"
MODULE_DESC="启用 Root 登录并设置密码"

install() {
    print_step "甲骨文云 - 启用 Root 登录"

    echo ""
    echo "此脚本将："
    echo "  1. 备份当前 SSH 配置"
    echo "  2. 修改 SSH 配置允许 Root 登录"
    echo "  3. 设置 Root 密码（交互式输入）"
    echo "  4. 重启 SSH 服务"
    echo ""

    read -p "确认继续？(y/n/1): " yn
    case "$yn" in
        y|Y|1|yes|YES|Yes)
            print_info "开始配置..."
            ;;
        *)
            print_info "已取消"
            return 0
            ;;
    esac

    local sshd_config="/etc/ssh/sshd_config"
    local backup_file="/etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)"

    # 1. 备份
    print_info "备份配置: $backup_file"
    cp "$sshd_config" "$backup_file"

    # 2. 修改配置（使用 sed 替换或追加）
    print_info "修改 SSH 配置..."
    
    # 处理 PasswordAuthentication
    if grep -q "^PasswordAuthentication" "$sshd_config"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$sshd_config"
    else
        echo "PasswordAuthentication yes" >> "$sshd_config"
    fi
    
    # 处理 PermitRootLogin
    if grep -q "^PermitRootLogin" "$sshd_config"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$sshd_config"
    else
        echo "PermitRootLogin yes" >> "$sshd_config"
    fi

    # 3. 设置密码（交互式，用户自己输入）
    echo ""
    print_info "请输入 root 密码（输入时不会显示）"
    passwd root

    if [ $? -eq 0 ]; then
        print_success "Root 密码设置成功"
    else
        print_error "密码设置失败"
        return 1
    fi

    # 4. 重启 SSH
    print_info "重启 SSH 服务..."
    systemctl restart sshd

    # 5. 获取 IP
    local server_ip=$(curl -s ifconfig.me)

    # 6. 显示结果
    echo ""
    print_success "配置完成！"
    echo ""
    echo "========================================="
    print_info "登录信息："
    echo "  ssh root@$server_ip"
    echo "  密码: 刚才输入的密码"
    echo "========================================="

    # 记录凭证（密码不保存，因为是用户自己输入的）
    record_credential "甲骨文云 Root 登录" "root" "【用户自设密码】" "服务器 IP: $server_ip"
}

# 卸载：恢复备份
uninstall() {
    print_step "恢复 SSH 配置"

    local bak=$(ls -t /etc/ssh/sshd_config.bak.* 2>/dev/null | head -1)
    
    if [ -n "$bak" ]; then
        print_info "恢复备份: $bak"
        cp "$bak" /etc/ssh/sshd_config
        systemctl restart sshd
        print_success "SSH 配置已恢复"
        print_warning "Root 密码登录已禁用"
    else
        print_warning "未找到备份文件"
    fi
}
