#!/bin/bash
# ============================================
# 甲骨文云 - 启用 Root 登录脚本
# 适用于: Ubuntu 系统（正确处理 Include 配置）
# 版本: v3.0 (最终版)
# ============================================

MODULE_NAME="甲骨文云 Root 登录"
MODULE_DESC="启用 Root 登录并设置密码"

install() {
    print_step "甲骨文云 - 启用 Root 登录"

    echo ""
    echo "此脚本适用于 Ubuntu 系统，将执行以下操作："
    echo "  1. 切换为 root 用户"
    echo "  2. 设置 root 密码"
    echo "  3. 修改 /etc/ssh/sshd_config（注释 Include 行）"
    echo "  4. 修改 /etc/ssh/sshd_config.d/*.conf 文件"
    echo "  5. 添加 PermitRootLogin yes 和 PasswordAuthentication yes"
    echo "  6. 重启 SSH 服务"
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

    # 1. 确保是 root
    if [ "$EUID" -ne 0 ]; then
        print_info "切换到 root 用户..."
        exec sudo bash "$0"
        exit
    fi

    # 2. 设置 root 密码
    echo ""
    print_info "设置 root 密码（输入时不会显示）"
    passwd root
    if [ $? -ne 0 ]; then
        print_error "密码设置失败"
        return 1
    fi
    print_success "Root 密码设置成功"

    # 3. 备份原配置
    local sshd_config="/etc/ssh/sshd_config"
    local backup_file="/etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)"
    print_info "备份配置: $backup_file"
    cp "$sshd_config" "$backup_file"

    # 4. 注释掉 Include 行（Ubuntu 特有）
    print_info "处理 Include 配置..."
    sed -i 's/^Include \/etc\/ssh\/sshd_config.d\/\*.conf/#&/' "$sshd_config"

    # 5. 修改主配置文件
    print_info "修改 SSH 配置..."
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$sshd_config"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$sshd_config"

    # 6. 处理 sshd_config.d 目录下的配置文件
    print_info "处理 /etc/ssh/sshd_config.d/ 目录..."
    if [ -d "/etc/ssh/sshd_config.d" ]; then
        for conf in /etc/ssh/sshd_config.d/*.conf; do
            if [ -f "$conf" ]; then
                print_info "修改: $conf"
                sed -i 's/^PasswordAuthentication no/#PasswordAuthentication no/' "$conf"
                # 确保文件中有允许的配置
                if ! grep -q "^PermitRootLogin" "$conf"; then
                    echo "PermitRootLogin yes" >> "$conf"
                fi
                if ! grep -q "^PasswordAuthentication yes" "$conf"; then
                    echo "PasswordAuthentication yes" >> "$conf"
                fi
            fi
        done
    fi

    # 7. 验证配置
    echo ""
    print_info "当前 SSH 配置验证："
    echo "  --- 主配置文件 ---"
    grep -E "^PermitRootLogin|^PasswordAuthentication" "$sshd_config" | while read line; do
        echo "    $line"
    done
    echo "  --- sshd_config.d 目录 ---"
    grep -r -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config.d/ 2>/dev/null | while read line; do
        echo "    $line"
    done

    # 8. 重启 SSH 服务
    print_info "重启 SSH 服务..."
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null

    if [ $? -eq 0 ]; then
        print_success "SSH 服务重启成功"
    else
        print_warning "SSH 服务重启可能失败，请手动检查"
    fi

    # 9. 获取 IP
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "请手动获取")

    # 10. 显示结果
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
    echo "  密码: 刚才设置的密码"
    echo ""
    echo "========================================="

    record_credential "甲骨文云 Root 登录" "root" "【用户自设密码】" "服务器 IP: $server_ip"
}

# 卸载：恢复配置
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
