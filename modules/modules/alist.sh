#!/bin/bash
# Alist 模块

install() {
    print_info "安装 Alist (原生一键脚本)"
    curl -fsSL "https://alist.nn.ci/v3.sh" | bash -s install
    sleep 2
    ALIST_PWD=$(alist admin random 2>&1 | grep -oP '密码：\K.*' || echo "请运行 'alist admin random' 获取密码")
    print_success "Alist 安装完成，端口 5244"
    record_credential "Alist" "admin" "$ALIST_PWD" "访问端口5244，使用 'alist admin random' 可重置密码"
}
