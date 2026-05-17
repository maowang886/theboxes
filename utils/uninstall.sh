#!/bin/bash
# ============================================
# 百宝箱统一卸载工具
# 使用方法: sudo bash utils/uninstall.sh
# ============================================

# 获取脚本所在目录的上级目录（theboxes根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 加载公共函数库（修复：添加 source）
source "$SCRIPT_DIR/lib/common.sh"

# 检查 root 权限（现在 check_root 函数已可用）
check_root

print_step "百宝箱卸载工具"

# 检测已安装的模块
declare -A INSTALLED_MODULES
INSTALLED_LIST=()

# 检测 Komari (Docker)
if docker ps --format 'table' 2>/dev/null | grep -q "komari"; then
    INSTALLED_MODULES["komari"]="Komari 探针"
    INSTALLED_LIST+=("komari")
fi

# 检测 Nginx Proxy Manager
if docker ps --format 'table' 2>/dev/null | grep -q "nginx-proxy-manager"; then
    INSTALLED_MODULES["npm"]="Nginx Proxy Manager"
    INSTALLED_LIST+=("npm")
fi

# 检测 EasyImg
if docker ps --format 'table' 2>/dev/null | grep -q "easyimg"; then
    INSTALLED_MODULES["easyimg"]="EasyImg 图床"
    INSTALLED_LIST+=("easyimg")
fi

# 检测 qBittorrent
if docker ps --format 'table' 2>/dev/null | grep -q "qbittorrent"; then
    INSTALLED_MODULES["qbittorrent"]="qBittorrent"
    INSTALLED_LIST+=("qbittorrent")
fi

# 检测 Alist (Docker)
if docker ps --format 'table' 2>/dev/null | grep -q "alist"; then
    INSTALLED_MODULES["alist"]="Alist"
    INSTALLED_LIST+=("alist")
fi

# 检测 Alist (原生，兼容旧版)
if [ -f /opt/alist/alist ] && ! docker ps | grep -q alist; then
    INSTALLED_MODULES["alist"]="Alist (原生)"
    INSTALLED_LIST+=("alist")
fi

# 检测 SSL 证书（检查是否有证书文件）
if ls /etc/ssl/*/fullchain.crt 2>/dev/null | head -1 | grep -q .; then
    INSTALLED_MODULES["ssl_cert"]="SSL 证书"
    INSTALLED_LIST+=("ssl_cert")
fi

# 检测 BBR
if lsmod | grep -q bbr; then
    INSTALLED_MODULES["bbr"]="BBR 加速"
    INSTALLED_LIST+=("bbr")
fi

# 检测 WARP (WireGuard 或 warp-go)
if [ -f /etc/wireguard/wgcf.conf ] || systemctl is-active --quiet warp-go 2>/dev/null; then
    INSTALLED_MODULES["warp"]="WARP"
    INSTALLED_LIST+=("warp")
fi

# 检测 Swap 文件
if swapon --show 2>/dev/null | grep -q "/swapfile"; then
    INSTALLED_MODULES["swap"]="Swap 虚拟内存"
    INSTALLED_LIST+=("swap")
fi

if [ ${#INSTALLED_LIST[@]} -eq 0 ]; then
    print_warning "没有检测到任何已安装的服务"
    exit 0
fi

echo ""
print_info "检测到以下已安装的服务："
for i in "${!INSTALLED_LIST[@]}"; do
    idx=$((i+1))
    echo "  $idx. ${INSTALLED_MODULES[${INSTALLED_LIST[$i]}]}"
done
echo "  a. 全部卸载"
echo "  0. 退出"
echo ""

read -p "请选择要卸载的服务编号: " choice

if [ "$choice" = "0" ]; then
    print_info "退出"
    exit 0
fi

if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
    print_warning "即将卸载所有服务"
    read -p "确认全部卸载？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for module in "${INSTALLED_LIST[@]}"; do
            module_file="$SCRIPT_DIR/modules/${module}.sh"
            if [ -f "$module_file" ]; then
                source "$module_file"
                if declare -f uninstall > /dev/null; then
                    uninstall
                else
                    print_warning "模块 $module 没有卸载函数，跳过"
                fi
            else
                print_warning "模块文件不存在: $module_file"
            fi
        done
        print_success "所有服务已卸载"
    fi
    exit 0
fi

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#INSTALLED_LIST[@]} ]; then
    idx=$((choice-1))
    module_name="${INSTALLED_LIST[$idx]}"
    module_file="$SCRIPT_DIR/modules/${module_name}.sh"
    
    if [ -f "$module_file" ]; then
        source "$module_file"
        if declare -f uninstall > /dev/null; then
            uninstall
            # 从凭证文件中移除相关记录
            service_name="${INSTALLED_MODULES[$module_name]}"
            sed -i "/【${service_name}】/,/^$/d" "$CREDENTIALS_FILE" 2>/dev/null
            print_success "已从凭证文件中移除 $service_name 的记录"
        else
            print_error "模块 $module_name 没有卸载函数"
        fi
    else
        print_error "模块文件不存在: $module_file"
    fi
else
    print_error "无效选择"
fi

print_success "卸载操作完成"
