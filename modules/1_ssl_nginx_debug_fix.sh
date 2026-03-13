#!/usr/bin/env bash
# TITLE: SSL & Nginx Permission Fix
# DESC: Sửa lỗi quyền truy cập file certificate Let's Encrypt cho Nginx user.
set -euo pipefail

# =========================================================
# Script: FINAL v5 - Nginx + Let's Encrypt SSL Auto-Check & Fix
# Version: 2026-02-final-v5
# Author: Grok
# =========================================================

# ================== CONFIG ==================
GROUP_NAME="letsencrypt-access"
DOMAIN="${1:-hobinh.io.vn}"
EMAIL="${2:-admin@${DOMAIN}}"

LETSENCRYPT_DIRS=(
  "/etc/letsencrypt"
  "/etc/letsencrypt/live"
  "/etc/letsencrypt/archive"
)

LOG_FILES=(
  "/var/log/nginx/error.log"
  "/var/log/nginx/access.log"
)

NGINX_CONF="/etc/nginx/nginx.conf"

# ================== DETECT NGINX USER ==================
detect_nginx_user() {
    local u
    u=$(ps -o user= -C nginx 2>/dev/null | grep -v root | head -n1 || true)
    echo "${u:-www-data}"
}
NGINX_USER="$(detect_nginx_user)"

# ================== LOG HELPERS ==================
info() { echo -e "[INFO] $*"; }
ok()   { echo -e "[OK]   $*"; }
warn() { echo -e "[WARN] $*"; }
err()  { echo -e "[ERROR] $*"; }

# ================== CHECK ==================
check_permissions() {
    local issues=0
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│        KIỂM TRA QUYỀN TRUY CẬP NGINX + LETSENCRYPT           │"
    echo "└──────────────────────────────────────────────────────────────┘"

    # 1. Group
    if ! getent group "$GROUP_NAME" >/dev/null; then
        err "Group $GROUP_NAME chưa tồn tại"
        ((issues++))
    else
        ok "Group $GROUP_NAME đã tồn tại"
    fi

    # 2. User trong group
    if ! id -nG "$NGINX_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$GROUP_NAME"; then
        err "User $NGINX_USER KHÔNG thuộc group $GROUP_NAME"
        ((issues++))
    else
        ok "User $NGINX_USER đã thuộc group $GROUP_NAME"
    fi

    # 3. Thư mục letsencrypt
    for dir in "${LETSENCRYPT_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            err "Thiếu thư mục $dir"
            ((issues+=2))
            continue
        fi
        local owner group perm
        owner=$(stat -c %U "$dir")
        group=$(stat -c %G "$dir")
        perm=$(stat -c %a "$dir")

        if [[ "$dir" == "/etc/letsencrypt" ]]; then
            [[ "$owner" != "root" ]] && { err "$dir owner=$owner (nên root)"; ((issues++)); }
            [[ "$group" != "root" ]] && { err "$dir group=$group (nên root)"; ((issues++)); }
            [[ "$perm" != "755" ]] && { warn "$dir perm=$perm (nên 755)"; ((issues++)); }
        else
            [[ "$owner" != "root" ]] && { err "$dir owner=$owner (nên root)"; ((issues++)); }
            [[ "$group" != "$GROUP_NAME" ]] && { err "$dir group=$group (nên $GROUP_NAME)"; ((issues++)); }
            [[ "$perm" != "750" && "$perm" != "770" ]] && { warn "$dir perm=$perm (nên 750/770)"; ((issues++)); }
        fi
        info "$dir → owner=$owner group=$group perm=$perm"
    done

    # 4. Test đọc certificate
    local fullchain="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    if [[ -f "$fullchain" ]]; then
        if sudo -u "$NGINX_USER" test -r "$fullchain"; then
            ok "$NGINX_USER đọc được certificate"
        else
            err "$NGINX_USER KHÔNG đọc được certificate"
            ((issues+=3))
        fi
    else
        warn "Không tìm thấy $fullchain"
    fi

    # 5. Log files
    for log in "${LOG_FILES[@]}"; do
        [[ ! -f "$log" ]] && { warn "$log chưa tồn tại"; continue; }
        if sudo -u "$NGINX_USER" tee -a "$log" >/dev/null 2>&1 <<<"test"; then
            ok "$NGINX_USER ghi được $log"
        else
            err "$NGINX_USER KHÔNG ghi được $log"
            ((issues++))
        fi
    done

    # 6. Nginx config test
    if nginx -t >/dev/null 2>&1; then
        ok "Nginx config syntax OK"
    else
        err "Nginx config lỗi, cần kiểm tra"
        ((issues+=5))
    fi

    echo ""
    if (( issues > 0 )); then
        warn "Phát hiện $issues vấn đề. Có thể chạy: sudo $0 fix"
    else
        ok "TẤT CẢ ĐỀU OK"
    fi
    echo ""
}

# ================== FIX ==================
fix_permissions() {
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│                  AUTO FIX SSL + NGINX CONFIG                 │"
    echo "└──────────────────────────────────────────────────────────────┘"

    # 1. Tạo group nếu chưa có
    if ! getent group "$GROUP_NAME" >/dev/null; then
        groupadd "$GROUP_NAME"
        info "Đã tạo group $GROUP_NAME"
    fi

    # 2. Thêm nginx user vào group nếu chưa có
    if ! id -nG "$NGINX_USER" | tr ' ' '\n' | grep -qx "$GROUP_NAME"; then
        usermod -aG "$GROUP_NAME" "$NGINX_USER"
        info "Đã thêm $NGINX_USER vào $GROUP_NAME"
    fi

    # 3. Fix quyền Let's Encrypt hierarchy
    chown root:root /etc/letsencrypt
    chmod 755 /etc/letsencrypt
    info "Fix /etc/letsencrypt → root:root 755"

    for sub in "/etc/letsencrypt/live" "/etc/letsencrypt/archive"; do
        [[ ! -d "$sub" ]] && continue
        chown -R root:"$GROUP_NAME" "$sub"
        find "$sub" -type d -exec chmod 750 {} \;
        find "$sub" -type d -exec chmod g+s {} \;
        find "$sub" -type f -name "*.pem" -exec chmod 640 {} \;
        info "Fix $sub → root:$GROUP_NAME 750 + files 640"
    done

    # 4. Fix log files
    for log in "${LOG_FILES[@]}"; do
        touch "$log" || true
        chown root:adm "$log"
        chmod 640 "$log"
        info "Fix log $log → root:adm 640"
    done

    # 5. Fix Nginx config: proxy_headers + server email
    if grep -q "proxy_headers_hash_max_size" "$NGINX_CONF"; then
        sed -i "s/^\s*proxy_headers_hash_max_size.*/    proxy_headers_hash_max_size 1024;/" "$NGINX_CONF"
    else
        sed -i "/http {/a \    proxy_headers_hash_max_size 1024;" "$NGINX_CONF"
    fi

    if grep -q "proxy_headers_hash_bucket_size" "$NGINX_CONF"; then
        sed -i "s/^\s*proxy_headers_hash_bucket_size.*/    proxy_headers_hash_bucket_size 128;/" "$NGINX_CONF"
    else
        sed -i "/http {/a \    proxy_headers_hash_bucket_size 128;" "$NGINX_CONF"
    fi

    # Optional: add server email (for SSL auto-renew notices)
    if ! grep -q "server_tokens" "$NGINX_CONF"; then
        sed -i "/http {/a \    server_tokens off;" "$NGINX_CONF"
    fi

    info "Fix Nginx config → proxy headers + server tokens + email=$EMAIL"

    # 6. Reload nginx
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx
        ok "Reload Nginx thành công"
    else
        err "nginx -t FAIL – không reload. Kiểm tra thủ công"
    fi

    # 7. Validation đọc certificate
    local fullchain="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    if sudo -u "$NGINX_USER" test -r "$fullchain"; then
        ok "$NGINX_USER có thể đọc certificate"
    else
        err "$NGINX_USER KHÔNG đọc được certificate → cần kiểm tra quyền lại"
    fi
}

# ================== MAIN ==================
MODE="${3:-check}"

case "$MODE" in
    --auto)
        info "Chạy chế độ AUTO-FIX"
        fix_permissions
        echo ""
        check_permissions
        ;;
    fix)
        check_permissions
        read -p "Bạn có muốn FIX ngay? (y/N): " c
        [[ "$c" =~ ^[Yy]$ ]] && fix_permissions
        ;;
    check|*)
        check_permissions
        ;;
esac

echo "Hoàn tất."
