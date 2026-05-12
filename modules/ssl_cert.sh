#!/bin/bash
# ============================================
# SSL 证书申请模块
# 支持方式:
#   1. DNS API (Cloudflare) - 支持泛域名
#   2. HTTP 验证 (复用 Nginx Proxy Manager 容器)
# 版本: v1.1
# ============================================

MODULE_NAME="SSL证书申请"
MODULE_DESC="申请 Let's Encrypt 免费 SSL 证书"

install() {
    print_step "SSL 证书申请向导"

    # 检查 acme.sh 是否已安装
    if [ ! -f "/root/.acme.sh/acme.sh" ]; then
        print_error "acme.sh 未安装，请先运行主脚本安装基础环境"
        return 1
    fi

    echo ""
    echo "请选择验证方式："
    echo "  1. DNS API 验证 (Cloudflare) - 支持泛域名证书，推荐"
    echo "  2. HTTP 验证 (复用 Nginx Proxy Manager) - 需要 NPM 容器运行"
    echo ""
    read -p "请选择 (1/2): " verify_method

    case $verify_method in
        1)
            dns_api_apply
            ;;
        2)
            http_verify_with_npm
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
}

# ============================================
# 方式一：DNS API 验证（Cloudflare）
# ============================================
dns_api_apply() {
    print_step "DNS API 验证 (Cloudflare)"

    # 输入域名
    echo ""
    read -p "请输入域名（支持泛域名如 *.example.com 或直接 example.com）: " domain_input
    domain_input=$(echo "$domain_input" | tr -d ' ')

    if [ -z "$domain_input" ]; then
        print_error "域名不能为空"
        return 1
    fi

    # 处理泛域名
    if [[ "$domain_input" == *"*"* ]]; then
        main_domain=$(echo "$domain_input" | sed 's/\*\.//')
        is_wildcard=true
    else
        main_domain="$domain_input"
        is_wildcard=false
        domain_input="$main_domain"
    fi

    print_info "主域名: $main_domain"
    [ "$is_wildcard" = true ] && print_info "将申请泛域名证书: *.$main_domain"

    # ========== 输入 API 密钥（隐藏输入）==========
    echo ""
    print_info "请输入 Cloudflare API 密钥（输入时不会显示）"

    read -s -p "CF_Token: " cf_token
    echo ""
    read -s -p "再次输入确认: " cf_token2
    echo ""

    if [ "$cf_token" != "$cf_token2" ]; then
        print_error "两次输入的 Token 不一致"
        return 1
    fi

    if [ -z "$cf_token" ]; then
        print_error "Token 不能为空"
        return 1
    fi

    echo ""
    read -p "CF_Account_ID（可选，按回车跳过）: " cf_account_id
    read -p "CF_Zone_ID（可选，按回车跳过）: " cf_zone_id

    # 设置 API 密钥（临时环境变量）
    export CF_Token="$cf_token"
    [ -n "$cf_account_id" ] && export CF_Account_ID="$cf_account_id"
    [ -n "$cf_zone_id" ] && export CF_Zone_ID="$cf_zone_id"

    # 申请证书
    print_info "正在申请证书..."
    local start_time=$(date +%s)

    if [ "$is_wildcard" = true ]; then
        /root/.acme.sh/acme.sh --issue -d "$main_domain" -d "*.$main_domain" --dns dns_cf -k ec-256
    else
        /root/.acme.sh/acme.sh --issue -d "$domain_input" --dns dns_cf -k ec-256
    fi

    if [ $? -ne 0 ]; then
        print_error "证书申请失败"
        unset CF_Token CF_Account_ID CF_Zone_ID
        return 1
    fi

    # 安装证书
    local cert_dir="/etc/ssl/$main_domain"
    mkdir -p "$cert_dir"

    if [ "$is_wildcard" = true ]; then
        /root/.acme.sh/acme.sh --installcert -d "$main_domain" -d "*.$main_domain" \
            --fullchain-file "$cert_dir/fullchain.crt" \
            --key-file "$cert_dir/private.key" --ecc
    else
        /root/.acme.sh/acme.sh --installcert -d "$domain_input" \
            --fullchain-file "$cert_dir/fullchain.crt" \
            --key-file "$cert_dir/private.key" --ecc
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # 记录凭证
    local server_ip=$(get_server_ip)
    record_credential "SSL 证书 ($main_domain)" "" "" \
        "证书路径: $cert_dir\n  证书文件: fullchain.crt\n  私钥文件: private.key\n  申请耗时: ${duration}秒"

    # 清理 API 密钥
    unset CF_Token CF_Account_ID CF_Zone_ID

    print_success "证书申请完成！"
    echo ""
    print_info "证书位置: $cert_dir"
    echo "  公钥: $cert_dir/fullchain.crt"
    echo "  私钥: $cert_dir/private.key"
    echo ""
    print_warning "API 密钥已从当前会话中清除"
}

# ============================================
# 方式二：HTTP 验证（使用 Nginx Proxy Manager 容器）
# ============================================
http_verify_with_npm() {
    print_step "HTTP 验证 (使用 Nginx Proxy Manager)"

    # 检查 Docker 和 NPM 容器
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装"
        return 1
    fi

    if ! docker ps --format 'table' 2>/dev/null | grep -q "nginx-proxy-manager"; then
        print_error "Nginx Proxy Manager 容器未运行"
        echo "请先通过百宝箱安装 npm 模块"
        return 1
    fi

    # 获取 NPM 容器的 webroot 路径
    NPM_DATA_DIR="/opt/nginx-proxy-manager/data"
    if [ ! -d "$NPM_DATA_DIR" ]; then
        print_error "找不到 NPM 数据目录: $NPM_DATA_DIR"
        return 1
    fi

    # 创建临时验证目录（acme.sh 需要 .well-known 可写）
    VERIFY_DIR="$NPM_DATA_DIR/letsencrypt"
    mkdir -p "$VERIFY_DIR"
    
    # 确保目录权限正确
    chmod 755 "$VERIFY_DIR"

    echo ""
    read -p "请输入要申请证书的域名: " domain
    domain=$(echo "$domain" | tr -d ' ')

    if [ -z "$domain" ]; then
        print_error "域名不能为空"
        return 1
    fi

    # 检查域名是否解析到本服务器
    print_info "检查域名解析..."
    local domain_ip=$(dig +short "$domain" @8.8.8.8 2>/dev/null | head -1)
    local server_ip=$(curl -s ifconfig.me)

    if [ -n "$domain_ip" ] && [ "$domain_ip" != "$server_ip" ]; then
        print_warning "域名解析 IP ($domain_ip) 与服务器 IP ($server_ip) 不一致"
        read -p "是否继续？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    # 测试 80 端口是否可访问
    print_info "测试 80 端口连通性..."
    if ! curl -s -o /dev/null --max-time 5 "http://$domain/.well-known/acme-challenge/test"; then
        print_warning "无法访问 http://$domain/.well-known/"
        print_info "请确保域名已解析到本服务器，且 NPM 容器正在监听 80 端口"
        read -p "是否继续？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    # ========== 申请证书 ==========
    print_info "正在通过 HTTP 验证申请证书..."
    print_info "验证目录: $VERIFY_DIR"
    
    local start_time=$(date +%s)

    /root/.acme.sh/acme.sh --issue -d "$domain" --webroot "$VERIFY_DIR" -k ec-256

    if [ $? -ne 0 ]; then
        print_error "证书申请失败"
        print_info "请检查:"
        echo "  1. 域名是否正确解析到本服务器 IP"
        echo "  2. NPM 容器是否正常运行"
        echo "  3. 80 端口是否可以从外网访问"
        return 1
    fi

    # ========== 安装证书 ==========
    local cert_dir="/etc/ssl/$domain"
    mkdir -p "$cert_dir"

    /root/.acme.sh/acme.sh --installcert -d "$domain" \
        --fullchain-file "$cert_dir/fullchain.crt" \
        --key-file "$cert_dir/private.key" --ecc

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # ========== 提示导入到 NPM ==========
    record_credential "SSL 证书 ($domain)" "" "" \
        "证书路径: $cert_dir\n  证书文件: fullchain.crt\n  私钥文件: private.key\n  申请耗时: ${duration}秒"

    print_success "证书申请完成！"
    echo ""
    print_info "证书位置: $cert_dir"
    echo "  公钥: $cert_dir/fullchain.crt"
    echo "  私钥: $cert_dir/private.key"
    echo ""
    print_info "下一步：将证书导入 Nginx Proxy Manager"
    echo "  1. 登录 NPM WebUI (http://$(get_server_ip):81)"
    echo "  2. 进入 SSL Certificates → Add SSL Certificate"
    echo "  3. 选择 Custom，上传上面的证书文件"
}

# ============================================
# 查看已安装的证书
# ============================================
list_certificates() {
    print_step "已安装的 SSL 证书"

    local certs_found=false

    for cert_dir in /etc/ssl/*/; do
        if [ -f "$cert_dir/fullchain.crt" ] && [ -f "$cert_dir/private.key" ]; then
            certs_found=true
            local domain=$(basename "$cert_dir")
            local expiry_date=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.crt" 2>/dev/null | cut -d= -f2)
            echo "  域名: $domain"
            echo "    路径: $cert_dir"
            echo "    有效期至: $expiry_date"
            echo ""
        fi
    done

    if [ "$certs_found" = false ]; then
        print_warning "未找到任何证书"
    fi
}

# ============================================
# 卸载函数
# ============================================
uninstall() {
    print_warning "卸载 SSL 证书将删除所有证书文件"
    read -p "确认删除所有证书？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf /etc/ssl/*/
        print_success "所有证书已删除"
        
        /root/.acme.sh/acme.sh --list 2>/dev/null | tail -n +2 | awk '{print $1}' | while read domain; do
            /root/.acme.sh/acme.sh --remove -d "$domain" 2>/dev/null
        done
        
        print_success "acme.sh 中的证书记录已清理"
    fi
}
