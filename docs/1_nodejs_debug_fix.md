Hoàn toàn được! Chúng ta có thể cập nhật script để **biến `PROJECT_DIR` được nhập từ tham số dòng lệnh** khi chạy script, thay vì hardcode sẵn trong file.

Dưới đây là phiên bản nâng cao đã chỉnh sửa:

```bash
#!/bin/bash

# nodejs_debug_fix.sh - Phiên bản nâng cao
# Tự động check/fix lỗi 403 Next.js + đọc log Nginx
# PROJECT_DIR được truyền từ bên ngoài khi chạy script

# 1️⃣ Kiểm tra tham số đầu vào
if [ -z "$1" ]; then
    echo "Usage: sudo ./nodejs_debug_fix.sh /path/to/your/project"
    exit 1
fi

PROJECT_DIR="$1"
NEXT_PORT=3000

echo "===== NODEJS DEBUG & FIX SCRIPT (ADVANCED) ====="
echo "[INFO] Project directory: $PROJECT_DIR"

# 2️⃣ Tự động phát hiện file Nginx config theo server_name
read -p "Nhập domain bạn muốn kiểm tra (ví dụ example.com): " DOMAIN

NGINX_CONF=$(grep -rl "server_name $DOMAIN" /etc/nginx/sites-available/)
if [ -z "$NGINX_CONF" ]; then
    echo "[WARNING] Không tìm thấy config cho $DOMAIN. Sử dụng default."
    NGINX_CONF="/etc/nginx/sites-available/default"
else
    echo "[OK] Config Nginx cho $DOMAIN: $NGINX_CONF"
fi

# 3️⃣ Kiểm tra nếu đã build chưa
if [ ! -d "$PROJECT_DIR/.next" ]; then
    echo "[INFO] Chưa build dự án. Tiến hành build..."
    cd $PROJECT_DIR || { echo "[ERROR] Không tìm thấy thư mục dự án."; exit 1; }
    npm install
    npm run build || { echo "[ERROR] Build thất bại."; exit 1; }
else
    echo "[OK] Dự án đã được build."
fi

# 4️⃣ Kiểm tra quyền thư mục
echo "[INFO] Kiểm tra quyền thư mục dự án..."
sudo chown -R www-data:www-data $PROJECT_DIR
sudo chmod -R 755 $PROJECT_DIR
echo "[OK] Quyền thư mục đã được set."

# 5️⃣ Kiểm tra cấu hình Nginx proxy
echo "[INFO] Kiểm tra cấu hình Nginx..."
if ! grep -q "proxy_pass http://localhost:$NEXT_PORT;" $NGINX_CONF; then
    echo "[WARNING] Nginx có thể chưa proxy đúng. Backup và update..."
    sudo cp $NGINX_CONF ${NGINX_CONF}.bak
    sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$NEXT_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL
    sudo nginx -t && sudo systemctl reload nginx
    echo "[OK] Nginx proxy đã được cập nhật."
else
    echo "[OK] Nginx đã được proxy đúng."
fi

# 6️⃣ Kiểm tra cổng Next.js
if lsof -i:$NEXT_PORT | grep LISTEN > /dev/null; then
    echo "[OK] Next.js đang chạy trên cổng $NEXT_PORT."
else
    echo "[INFO] Next.js chưa chạy. Tiến hành start..."
    cd $PROJECT_DIR
    nohup npm run start > nextjs_prod.log 2>&1 &
    echo "[OK] Next.js đã start."
fi

# 7️⃣ Đọc log Nginx trong 1 phút gần nhất và gợi ý fix lỗi 403
echo "[INFO] Kiểm tra log Nginx trong 1 phút gần nhất..."
ERROR_LOG="/var/log/nginx/error.log"
if [ -f "$ERROR_LOG" ]; then
    tail -n 50 $ERROR_LOG | grep "$(date '+%d/%b/%Y:%H:%M')" | while read line; do
        if echo $line | grep -q "permission denied"; then
            echo "[LOG WARNING] Lỗi permission: hãy kiểm tra quyền thư mục của Next.js và Nginx user (www-data)."
        elif echo $line | grep -q "directory index of"; then
            echo "[LOG WARNING] Directory index forbidden: hãy chắc chắn Nginx proxy tới Next.js, không serve static folder trực tiếp."
        elif echo $line | grep -q "client denied by server configuration"; then
            echo "[LOG WARNING] Client bị từ chối: hãy kiểm tra block trong Nginx config hoặc file .htaccess nếu có."
        fi
    done
else
    echo "[INFO] Không tìm thấy error.log Nginx tại $ERROR_LOG"
fi

echo "===== KIỂM TRA HOÀN THÀNH ====="
echo "Truy cập lại website $DOMAIN để kiểm tra lỗi 403."
```

---

### ✅ Cách chạy script

```bash
sudo ./nodejs_debug_fix.sh /path/to/your/nextjs/project
```

- `/path/to/your/nextjs/project` → đường dẫn tới thư mục Next.js của bạn.
- Script sẽ hỏi **domain** để tự động tìm file Nginx config.

---

Nếu muốn, tôi có thể nâng cấp thêm để **nếu không nhập domain, script tự lấy domain từ server_name trong config** mà không cần hỏi, để chạy hoàn toàn tự động.

Bạn có muốn tôi làm luôn không?
