#!/bin/bash
# 甲骨文云 - 启用 Root 登录（简单可靠版）

install() {
    print_step "甲骨文云 - 启用 Root 登录"

    echo ""
    echo "此脚本将："
    echo "  1. 修改 SSH 配置允许 Root 登录"
    echo "  2. 设置 Root 密码"
    echo ""

    read -p "确认继续？(y/n): " yn
    if [[ ! "$yn" =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 0
    fi

    # 备份
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)

    # 修改配置（直接追加，避免 sed 问题）
    echo "" >> /etc/ssh/sshd_config
    echo "# Added by theboxes" >> /etc/ssh/sshd_config
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

    # 生成随机密码
    ROOT_PASS=$(tr -dc 'A-Za-z0-9!@#' < /dev/urandom 2>/dev/null | head -c 16)
    echo "root:$ROOT_PASS" | chpasswd

    # 重启 SSH
    systemctl restart sshd

    # 显示信息
    IP=$(curl -s ifconfig.me)
    echo ""
    echo "========================================="
    echo "✅ Root 登录已启用"
    echo "========================================="
    echo "登录命令: ssh root@$IP"
    echo "密码: $ROOT_PASS"
    echo "========================================="
    echo ""
    echo "⚠️ 首次登录后请立即修改密码: passwd"

    # 记录凭证
    record_credential "甲骨文云 Root" "root" "$ROOT_PASS" "服务器 IP: $IP"
}
