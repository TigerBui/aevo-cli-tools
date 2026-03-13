#!/bin/bash
# TITLE: Certbot SSL Debug & Renew
# DESC: Tự động kiểm tra và sửa lỗi gia hạn SSL Certbot (mismatch symlinks, archive consistency).
# ==========================================================
# Auto Debug & Fix Certbot Renewal Issues
# File: auto-debug-renew-certbot.sh
# Author: Sir-X 😎
# ==========================================================

set -euo pipefail

DOMAIN="$1"
LE_BASE="/etc/letsencrypt"
ARCHIVE="$LE_BASE/archive/$DOMAIN"
LIVE="$LE_BASE/live/$DOMAIN"
RENEWAL_CONF="$LE_BASE/renewal/$DOMAIN.conf"
BACKUP_DIR="/root/letsencrypt-backup-$(date +%F-%H%M%S)"
LOG="/var/log/auto-debug-certbot.log"

exec > >(tee -a "$LOG") 2>&1

echo "=== 🚑 Auto Debug Certbot for domain: $DOMAIN ==="

if [[ $EUID -ne 0 ]]; then
  echo "❌ Must run as root"
  exit 1
fi

# 1️⃣ Pre-check
echo "🔍 Checking certbot..."
command -v certbot >/dev/null || {
  echo "❌ certbot not found"
  exit 1
}

[[ -d "$ARCHIVE" && -d "$LIVE" ]] || {
  echo "❌ Domain does not exist in letsencrypt"
  exit 1
}

# 2️⃣ Backup
echo "📦 Backup letsencrypt to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$LE_BASE" "$BACKUP_DIR/"

# 3️⃣ Detect file collision
echo "🔎 Checking archive consistency..."
cd "$ARCHIVE"

LATEST_KEY=$(ls privkey*.pem 2>/dev/null | sed 's/[^0-9]//g' | sort -n | tail -1)
LATEST_CERT=$(ls cert*.pem 2>/dev/null | sed 's/[^0-9]//g' | sort -n | tail -1)

if [[ -z "$LATEST_KEY" || -z "$LATEST_CERT" ]]; then
  echo "❌ Archive broken"
  exit 1
fi

echo "✔ Latest key version: $LATEST_KEY"
echo "✔ Latest cert version: $LATEST_CERT"

# 4️⃣ Fix symlink if mismatch
echo "🔧 Fixing live symlinks..."
ln -sf "$ARCHIVE/privkey${LATEST_KEY}.pem" "$LIVE/privkey.pem"
ln -sf "$ARCHIVE/cert${LATEST_CERT}.pem" "$LIVE/cert.pem"
ln -sf "$ARCHIVE/chain${LATEST_CERT}.pem" "$LIVE/chain.pem"
ln -sf "$ARCHIVE/fullchain${LATEST_CERT}.pem" "$LIVE/fullchain.pem"

# 5️⃣ Dry-run first
echo "🧪 Certbot dry-run..."
if ! certbot renew --cert-name "$DOMAIN" --dry-run; then
  echo "⚠ Dry-run failed, attempting forced renew..."
fi

# 6️⃣ Force renew
echo "🔁 Renewing certificate..."
certbot renew --cert-name "$DOMAIN" --force-renewal

# 7️⃣ Reload web server
if systemctl is-active --quiet nginx; then
  echo "🔄 Reload nginx"
  systemctl reload nginx
elif systemctl is-active --quiet apache2; then
  echo "🔄 Reload apache"
  systemctl reload apache2
else
  echo "ℹ No web server detected"
fi

echo "✅ Certbot auto-debug completed successfully"
