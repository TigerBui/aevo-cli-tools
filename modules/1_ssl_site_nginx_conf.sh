#!/usr/bin/env bash
# TITLE: Nginx Site SSL Configurer
# DESC: Tạo nhanh cấu hình vhost Nginx hỗ trợ SSL và tự động chuyển hướng HTTP sang HTTPS.
set -euo pipefail

# =========================================================
# Script: SSL + Nginx site config checker & fixer
# Usage:
#   sudo ./ssl_site_nginx_conf.sh <domain> [email]
# Example:
#   sudo ./ssl_site_nginx_conf.sh hobinh.io.vn admin@hobinh.io.vn
# =========================================================

DOMAIN="${1:?Domain không được để trống}"
EMAIL="${2:-admin@${DOMAIN}}"

SITE_CONF="/etc/nginx/sites-available/${DOMAIN}.conf"
NGINX_USER="$(ps -o user= -C nginx 2>/dev/null | grep -v root | head -n1 || echo www-data)"
GROUP_NAME="letsencrypt-access"

# ================== HELPERS ==================
info() { echo -e "[INFO] $*"; }
ok()   { echo -e "[OK]   $*"; }
warn() { echo -e "[WARN] $*"; }
err()  { echo -e "[ERROR] $*"; }

# ================== FIX SSL PERMISSIONS ==================
fix_ssl_permissions() {
    info "Fix permissions thư mục Let's Encrypt"
    # Tạo group nếu chưa có
    getent group "$GROUP_NAME" >/dev/null || groupadd "$GROUP_NAME"
    # Thêm nginx user vào group
    id -nG "$NGINX_USER" | grep -qw "$GROUP_NAME" || usermod -aG "$GROUP_NAME" "$NGINX_USER"

    # Fix /etc/letsencrypt
    chown root:root /etc/letsencrypt
    chmod 755 /etc/letsencrypt

    for dir in "/etc/letsencrypt/live" "/etc/letsencrypt/archive"; do
        [[ ! -d "$dir" ]] && continue
        chown -R root:"$GROUP_NAME" "$dir"
        find "$dir" -type d -exec chmod 750 {} \;
        find "$dir" -type d -exec chmod g+s {} \;
        find "$dir" -type f -name "*.pem" -exec chmod 640 {} \;
    done

    ok "Đã fix permissions SSL"
}

# ================== CREATE NGINX SITE ==================
config_nginx_site() {
    info "Tạo cấu hình Nginx cho $DOMAIN"

    [[ ! -d /var/www/$DOMAIN/html ]] && mkdir -p /var/www/$DOMAIN/html
    chown -R $NGINX_USER:$NGINX_USER /var/www/$DOMAIN/html
    chmod 755 /var/www/$DOMAIN

    if [[ -f "$SITE_CONF" ]]; then
        warn "$SITE_CONF đã tồn tại, backup"
        cp "$SITE_CONF" "${SITE_CONF}.bak.$(date +%s)"
    fi

    cat <<EOF | tee "$SITE_CONF" >/dev/null
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/$DOMAIN/html;
    index index.html index.htm;

    location / {
        return 301 https://\$host\$request_uri;
    }

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/$DOMAIN/html;
    index index.html index.htm;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;

    location / {
        try_files \$uri \$uri/ =404;
    }

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;
}
EOF

    ln -sf "$SITE_CONF" "/etc/nginx/sites-enabled/$DOMAIN.conf"
    ok "Kích hoạt site Nginx cho $DOMAIN"

    # Test config & reload
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx
        ok "Reload Nginx thành công"
    else
        err "nginx -t thất bại. Kiểm tra config thủ công"
    fi
}

# ================== MAIN ==================
echo "=== Bắt đầu debug & fix SSL + Nginx cho $DOMAIN ==="
fix_ssl_permissions
config_nginx_site
echo "=== Hoàn tất cho $DOMAIN ==="
