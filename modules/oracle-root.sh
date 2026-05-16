#!/bin/bash
# ============================================
# 甲骨文云 - 启用 Root 登录脚本
# 根据正确的手动步骤编写
# 版本: v3.0
# ============================================

MODULE_NAME="甲骨文云 Root 登录"
MODULE_DESC="启用 Root 登录并设置密码"

install() {
    print_step "甲骨文云 - 启用 Root 登录"

    echo ""
    echo "此脚本将执行以下操作："
    echo "  1. 修改 SSH 配置 (PermitRootLogin yes, PasswordAuthentication yes)"
    echo "  2. 重启 SSH 服务"
    echo "  3. 设置 root 密码"
    echo ""
    echo "⚠️ 注意：脚本执行后请保持当前 SSH 连接，新开窗口测试 root 登录"
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

    # 2. 修改配置（去掉注释并设置为 yes）
    print_info "修改 SSH 配置..."
    
    # 去掉 PermitRootLogin 前面的 #，并设置为 yes
    sed -i 's/^#\s*PermitRootLogin.*/PermitRootLogin yes/' "$sshd_config"
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$sshd_config"
    
    # 去掉 PasswordAuthentication 前面的 #，并设置为 yes
    sed -i 's/^#\s*PasswordAuthentication.*/PasswordAuthentication yes/' "$sshd_config"
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$sshd_config"

    # 3. 验证修改
    print_info "当前 SSH 配置："
    grep -E "^PermitRootLogin|^PasswordAuthentication" "$sshd_config" | while read line; do
        echo "    $line"
    done

    # 4. 重启 SSH 服务（Ubuntu 是 ssh，不是 sshd）
    print_info "重启 SSH 服务..."
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "SSH 服务重启成功"
    else
        print_warning "SSH 服务重启可能失败，请手动检查"
    fi

    # 5. 设置 root 密码
    echo ""
    print_info "请输入 root 密码（输入时不会显示）"
    passwd root

    if [ $? -eq 0 ]; then
        print_success "Root 密码设置成功"
    else
        print_error "Root 密码设置失败"
        return 1
    fi

    # 6. 获取 IP
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "请手动获取")

    # 7. 显示结果
    echo ""
    print_success "配置完成！"
    echo ""
    echo "========================================="
    echo "✅ 配置已生效"
    echo "========================================="
    echo ""
    echo "📌 重要提示："
    echo "  1. 请保持当前 SSH 连接不要关闭"
    echo "  2. 新开一个终端窗口测试 root 登录"
    echo ""
    print_info "登录信息："
    echo "  ssh root@$server_ip"
    echo "  密码: 刚才输入的密码"
    echo ""
    echo "========================================="

    record_credential "甲骨文云 Root 登录" "root" "【用户自设密码】" "服务器 IP: $server_ip"
}

# 卸载函数
uninstall() {
    print_step "恢复 SSH 配置"

    local bak=$(ls -t /etc/ssh/sshd_config.bak.* 2>/dev/null | head -1)
    
    if [ -n "$bak" ]; then
        print_info "恢复备份: $bak"
        cp "$bak" /etc/ssh/sshd_config
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
        print_success "SSH 配置已恢复"
        print_warning "Root 密码登录已被禁用"
    else
        print_warning "未找到备份文件"
    fi
}
