#!/bin/bash
# EasyImage 图床模块

install() {
    print_info "安装 EasyImage 图床 (原生 PHP+Nginx)"
    apt update
    apt install -y nginx php php-fpm php-gd php-json php-mbstring php-zip unzip wget
    cd /var/www
    wget https://github.com/icret/EasyImages2.0/archive/refs/heads/master.zip
    unzip -o master.zip
    mv EasyImages2.0-master easyimage
    chown -R www-data:www-data easyimage
    cat > /etc/nginx/sites-available/easyimage << EOF
server {
    listen 8082;
    root /var/www/easyimage;
    index index.php;
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/easyimage /etc/nginx/sites-enabled/
    systemctl restart nginx php$(php -r 'echo PHP_VERSION;' | cut -d. -f1-2)-fpm 2>/dev/null || systemctl restart php-fpm
    print_success "EasyImage 已安装，访问端口 8082"
    record_credential "EasyImage 图床" "" "" "访问地址: http://$(curl -s ifconfig.me):8082 (无默认密码，初次访问需设置)"
}
