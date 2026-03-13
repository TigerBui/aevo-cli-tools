#!/usr/bin/env bash
# TITLE: Nginx Debug Fix (Advanced)
# DESC: Công cụ debug và tự động sửa lỗi Nginx nâng cao với phân tích log và fix lỗi 4xx/5xx.
set -euo pipefail

# Tên ứng dụng
APP_NAME="nginx-debug-fix"

# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Biến đếm lỗi
ISSUES_FOUND=0
ISSUES_FIXED=0

# Biến cấu hình mặc định
NGINX_CONF="${NGINX_CONF:-/etc/nginx/nginx.conf}"
NGINX_PORT="${NGINX_PORT:-80}"
NGINX_DOMAIN="${NGINX_DOMAIN:-localhost}"
NGINX_ROOT="${NGINX_ROOT:-/var/www/html}"
INTERACTIVE_MODE="${INTERACTIVE_MODE:-true}"

# Hàm hiển thị usage
show_usage() {
    cat << EOF
${GREEN}=== Nginx Debug & Auto-Fix Tool ===${NC}

Usage: $0 [OPTIONS]

Options:
  -c, --config PATH       Đường dẫn file nginx.conf (mặc định: /etc/nginx/nginx.conf)
  -p, --port PORT         Port nginx (mặc định: 80)
  -d, --domain DOMAIN     Domain/Server name (mặc định: localhost)
  -r, --root PATH         Root directory (mặc định: /var/www/html)
  -y, --yes              Chạy tự động không cần xác nhận
  -h, --help             Hiển thị hướng dẫn này

Ví dụ:
  $0 -c /etc/nginx/sites-available/mysite.conf -p 8080 -d example.com
  $0 --domain myapp.local --root /var/www/myapp -y

Biến môi trường:
  NGINX_CONF              Đường dẫn file nginx.conf
  NGINX_PORT              Port nginx
  NGINX_DOMAIN            Domain/Server name
  NGINX_ROOT              Root directory
  INTERACTIVE_MODE        true/false (mặc định: true)

EOF
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                NGINX_CONF="$2"
                shift 2
                ;;
            -p|--port)
                NGINX_PORT="$2"
                shift 2
                ;;
            -d|--domain)
                NGINX_DOMAIN="$2"
                shift 2
                ;;
            -r|--root)
                NGINX_ROOT="$2"
                shift 2
                ;;
            -y|--yes)
                INTERACTIVE_MODE=false
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Hàm kiểm tra yêu cầu hệ thống
check_requirements() {
    echo -e "${YELLOW}[1/6] Kiểm tra yêu cầu hệ thống...${NC}"
    
    # Kiểm tra quyền root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ Vui lòng chạy script với quyền sudo hoặc root${NC}"
        exit 1
    fi
    
    # Kiểm tra Nginx đã được cài đặt
    if ! command -v nginx &> /dev/null; then
        echo -e "${RED}✗ Nginx chưa được cài đặt trên hệ thống${NC}"
        if [[ "$INTERACTIVE_MODE" == "true" ]]; then
            echo -e "${YELLOW}Bạn có muốn cài đặt Nginx không? (y/N): ${NC}"
            read -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                apt-get update -qq
                apt-get install -y nginx
                echo -e "${GREEN}✓ Đã cài đặt Nginx${NC}"
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Nginx đã được cài đặt${NC}"
    nginx -v 2>&1 | head -1
    
    # Hiển thị cấu hình hiện tại
    echo -e "\n${BLUE}Cấu hình hiện tại:${NC}"
    echo -e "  Config file: ${GREEN}$NGINX_CONF${NC}"
    echo -e "  Port: ${GREEN}$NGINX_PORT${NC}"
    echo -e "  Domain: ${GREEN}$NGINX_DOMAIN${NC}"
    echo -e "  Root: ${GREEN}$NGINX_ROOT${NC}"
}

# Hàm phân tích lỗi HTTP từ access log
analyze_http_errors() {
    echo -e "\n${BLUE}→ Phân tích lỗi HTTP từ access log...${NC}"
    
    local access_log="/var/log/nginx/access.log"
    if [[ ! -f "$access_log" ]]; then
        echo -e "${YELLOW}⚠ Access log không tồn tại${NC}"
        return
    fi
    
    # Đếm lỗi 4xx
    local errors_4xx=$(grep -E '" [4][0-9]{2} ' "$access_log" 2>/dev/null | wc -l)
    if [[ $errors_4xx -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Tìm thấy $errors_4xx lỗi 4xx${NC}"
        echo -e "${BLUE}  Chi tiết lỗi 4xx:${NC}"
        grep -E '" [4][0-9]{2} ' "$access_log" 2>/dev/null | awk '{print $9}' | sort | uniq -c | sort -rn | head -5 | while read count code; do
            echo -e "    ${YELLOW}$code${NC}: $count lần"
        done
        ((ISSUES_FOUND++))
    fi
    
    # Đếm lỗi 5xx
    local errors_5xx=$(grep -E '" [5][0-9]{2} ' "$access_log" 2>/dev/null | wc -l)
    if [[ $errors_5xx -gt 0 ]]; then
        echo -e "${RED}✗ Tìm thấy $errors_5xx lỗi 5xx${NC}"
        echo -e "${BLUE}  Chi tiết lỗi 5xx:${NC}"
        grep -E '" [5][0-9]{2} ' "$access_log" 2>/dev/null | awk '{print $9}' | sort | uniq -c | sort -rn | head -5 | while read count code; do
            echo -e "    ${RED}$code${NC}: $count lần"
        done
        ((ISSUES_FOUND++))
    fi
    
    # Top URLs gây lỗi
    local error_urls=$(grep -E '" [45][0-9]{2} ' "$access_log" 2>/dev/null | awk '{print $7}' | sort | uniq -c | sort -rn | head -3)
    if [[ -n "$error_urls" ]]; then
        echo -e "\n${BLUE}  Top URLs gây lỗi:${NC}"
        echo "$error_urls" | while read count url; do
            echo -e "    ${YELLOW}$url${NC}: $count lần"
        done
    fi
    
    if [[ $errors_4xx -eq 0 && $errors_5xx -eq 0 ]]; then
        echo -e "${GREEN}✓ Không có lỗi HTTP trong access log${NC}"
    fi
}

# Hàm kiểm tra và sửa lỗi cấu hình
install_app() {
    echo -e "${YELLOW}[2/6] Kiểm tra và phát hiện lỗi Nginx...${NC}\n"
    
    # 1. Kiểm tra syntax config
    echo -e "${BLUE}→ Kiểm tra syntax cấu hình Nginx...${NC}"
    if nginx -t 2>&1 | grep -q "syntax is ok"; then
        echo -e "${GREEN}✓ Syntax cấu hình Nginx hợp lệ${NC}"
    else
        echo -e "${RED}✗ Lỗi syntax trong cấu hình Nginx${NC}"
        nginx -t 2>&1 | grep -v "syntax is ok"
        ((ISSUES_FOUND++))
    fi
    
    # 2. Kiểm tra service status
    echo -e "\n${BLUE}→ Kiểm tra trạng thái Nginx service...${NC}"
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx service đang chạy${NC}"
    else
        echo -e "${RED}✗ Nginx service không chạy${NC}"
        ((ISSUES_FOUND++))
    fi
    
    # 3. Kiểm tra port conflicts
    echo -e "\n${BLUE}→ Kiểm tra xung đột port $NGINX_PORT...${NC}"
    if netstat -tulpn 2>/dev/null | grep -q ":$NGINX_PORT.*nginx" || ss -tulpn 2>/dev/null | grep -q ":$NGINX_PORT.*nginx"; then
        echo -e "${GREEN}✓ Port $NGINX_PORT đang được Nginx sử dụng${NC}"
    else
        if netstat -tulpn 2>/dev/null | grep -q ":$NGINX_PORT" || ss -tulpn 2>/dev/null | grep -q ":$NGINX_PORT"; then
            echo -e "${RED}✗ Port $NGINX_PORT bị chiếm bởi process khác${NC}"
            netstat -tulpn 2>/dev/null | grep ":$NGINX_PORT" || ss -tulpn 2>/dev/null | grep ":$NGINX_PORT"
            ((ISSUES_FOUND++))
        else
            echo -e "${YELLOW}⚠ Port $NGINX_PORT không được sử dụng (Nginx có thể chưa start)${NC}"
        fi
    fi
    
    # 4. Kiểm tra quyền truy cập file
    echo -e "\n${BLUE}→ Kiểm tra quyền truy cập thư mục web...${NC}"
    if [[ -d "$NGINX_ROOT" ]]; then
        local perms=$(stat -c %a "$NGINX_ROOT" 2>/dev/null || stat -f %A "$NGINX_ROOT" 2>/dev/null)
        if [[ "$perms" == "755" || "$perms" == "775" ]]; then
            echo -e "${GREEN}✓ Quyền thư mục $NGINX_ROOT: $perms${NC}"
        else
            echo -e "${YELLOW}⚠ Quyền thư mục $NGINX_ROOT: $perms (khuyến nghị 755)${NC}"
            ((ISSUES_FOUND++))
        fi
    else
        echo -e "${RED}✗ Thư mục $NGINX_ROOT không tồn tại${NC}"
        ((ISSUES_FOUND++))
    fi
    
    # 5. Kiểm tra log files
    echo -e "\n${BLUE}→ Kiểm tra log files...${NC}"
    for log in /var/log/nginx/error.log /var/log/nginx/access.log; do
        if [[ -f "$log" ]]; then
            if [[ -w "$log" ]]; then
                echo -e "${GREEN}✓ $log có thể ghi${NC}"
            else
                echo -e "${RED}✗ $log không có quyền ghi${NC}"
                ((ISSUES_FOUND++))
            fi
        else
            echo -e "${YELLOW}⚠ $log chưa tồn tại${NC}"
        fi
    done
    
    # 6. Kiểm tra lỗi trong error log
    echo -e "\n${BLUE}→ Kiểm tra lỗi gần đây trong error.log...${NC}"
    if [[ -f /var/log/nginx/error.log ]]; then
        local recent_errors=$(tail -50 /var/log/nginx/error.log | grep -i "error\|crit\|alert\|emerg" | wc -l)
        if [[ $recent_errors -gt 0 ]]; then
            echo -e "${YELLOW}⚠ Tìm thấy $recent_errors lỗi gần đây${NC}"
            echo -e "${YELLOW}5 lỗi mới nhất:${NC}"
            tail -50 /var/log/nginx/error.log | grep -i "error\|crit\|alert\|emerg" | tail -5
            ((ISSUES_FOUND++))
        else
            echo -e "${GREEN}✓ Không có lỗi nghiêm trọng trong log${NC}"
        fi
    fi
    
    # 7. Kiểm tra worker_connections
    echo -e "\n${BLUE}→ Kiểm tra cấu hình worker_connections...${NC}"
    local worker_conn=$(grep -r "worker_connections" /etc/nginx/ 2>/dev/null | grep -v "#" | head -1 | awk '{print $2}' | tr -d ';')
    if [[ -n "$worker_conn" ]]; then
        if [[ $worker_conn -ge 1024 ]]; then
            echo -e "${GREEN}✓ worker_connections: $worker_conn${NC}"
        else
            echo -e "${YELLOW}⚠ worker_connections: $worker_conn (khuyến nghị >= 1024)${NC}"
            ((ISSUES_FOUND++))
        fi
    fi
    
    # 8. Kiểm tra sites-enabled symlinks
    echo -e "\n${BLUE}→ Kiểm tra symlinks trong sites-enabled...${NC}"
    if [[ -d /etc/nginx/sites-enabled ]]; then
        local broken_links=$(find /etc/nginx/sites-enabled -type l ! -exec test -e {} \; -print | wc -l)
        if [[ $broken_links -gt 0 ]]; then
            echo -e "${RED}✗ Tìm thấy $broken_links symlink bị hỏng${NC}"
            find /etc/nginx/sites-enabled -type l ! -exec test -e {} \; -print
            ((ISSUES_FOUND++))
        else
            echo -e "${GREEN}✓ Tất cả symlinks hợp lệ${NC}"
        fi
    fi
    
    # 9. Phân tích lỗi HTTP
    analyze_http_errors
    
    echo -e "\n${YELLOW}Tổng số vấn đề phát hiện: $ISSUES_FOUND${NC}\n"
}

# Hàm debug và fix lỗi 4xx
fix_4xx_errors() {
    echo -e "${BLUE}→ Debug và fix lỗi 4xx...${NC}"
    
    local access_log="/var/log/nginx/access.log"
    if [[ ! -f "$access_log" ]]; then
        return
    fi
    
    # Fix 403 Forbidden
    if grep -q '" 403 ' "$access_log" 2>/dev/null; then
        echo -e "${YELLOW}  Phát hiện lỗi 403 Forbidden${NC}"
        
        # Kiểm tra quyền thư mục
        if [[ -d "$NGINX_ROOT" ]]; then
            chmod 755 "$NGINX_ROOT"
            find "$NGINX_ROOT" -type d -exec chmod 755 {} \;
            find "$NGINX_ROOT" -type f -exec chmod 644 {} \;
            echo -e "${GREEN}  ✓ Đã sửa quyền truy cập thư mục${NC}"
            ((ISSUES_FIXED++))
        fi
        
        # Kiểm tra index file
        if [[ ! -f "$NGINX_ROOT/index.html" && ! -f "$NGINX_ROOT/index.php" ]]; then
            echo "<html><body><h1>Welcome to Nginx</h1></body></html>" > "$NGINX_ROOT/index.html"
            echo -e "${GREEN}  ✓ Đã tạo index.html mặc định${NC}"
            ((ISSUES_FIXED++))
        fi
    fi
    
    # Fix 404 Not Found
    if grep -q '" 404 ' "$access_log" 2>/dev/null; then
        echo -e "${YELLOW}  Phát hiện lỗi 404 Not Found${NC}"
        
        # Kiểm tra root directory
        if [[ ! -d "$NGINX_ROOT" ]]; then
            mkdir -p "$NGINX_ROOT"
            echo -e "${GREEN}  ✓ Đã tạo thư mục root: $NGINX_ROOT${NC}"
            ((ISSUES_FIXED++))
        fi
    fi
    
    # Fix 413 Request Entity Too Large
    if grep -q '" 413 ' "$access_log" 2>/dev/null; then
        echo -e "${YELLOW}  Phát hiện lỗi 413 Request Entity Too Large${NC}"
        
        # Tăng client_max_body_size
        if ! grep -q "client_max_body_size" "$NGINX_CONF" 2>/dev/null; then
            sed -i '/http {/a \    client_max_body_size 100M;' "$NGINX_CONF"
            echo -e "${GREEN}  ✓ Đã thêm client_max_body_size 100M${NC}"
            ((ISSUES_FIXED++))
        fi
    fi
}

# Hàm debug và fix lỗi 5xx
fix_5xx_errors() {
    echo -e "${BLUE}→ Debug và fix lỗi 5xx...${NC}"
    
    local access_log="/var/log/nginx/access.log"
    if [[ ! -f "$access_log" ]]; then
        return
    fi
    
    # Fix 502 Bad Gateway
    if grep -q '" 502 ' "$access_log" 2>/dev/null; then
        echo -e "${YELLOW}  Phát hiện lỗi 502 Bad Gateway${NC}"
        
        # Kiểm tra upstream/backend services
        if systemctl list-units --type=service | grep -q "php.*fpm"; then
            local php_service=$(systemctl list-units --type=service | grep "php.*fpm" | awk '{print $1}' | head -1)
            if ! systemctl is-active --quiet "$php_service"; then
                systemctl start "$php_service"
                echo -e "${GREEN}  ✓ Đã khởi động $php_service${NC}"
                ((ISSUES_FIXED++))
            fi
        fi
    fi
    
    # Fix 503 Service Unavailable
    if grep -q '" 503 ' "$access_log" 2>/dev/null; then
        echo -e "${YELLOW}  Phát hiện lỗi 503 Service Unavailable${NC}"
        
        # Tăng worker_connections nếu cần
        local worker_conn=$(grep -r "worker_connections" /etc/nginx/ 2>/dev/null | grep -v "#" | head -1 | awk '{print $2}' | tr -d ';')
        if [[ -n "$worker_conn" && $worker_conn -lt 2048 ]]; then
            sed -i "s/worker_connections $worker_conn;/worker_connections 2048;/" "$NGINX_CONF"
            echo -e "${GREEN}  ✓ Đã tăng worker_connections lên 2048${NC}"
            ((ISSUES_FIXED++))
        fi
    fi
    
    # Fix 504 Gateway Timeout
    if grep -q '" 504 ' "$access_log" 2>/dev/null; then
        echo -e "${YELLOW}  Phát hiện lỗi 504 Gateway Timeout${NC}"
        
        # Tăng timeout settings
        if ! grep -q "proxy_read_timeout" "$NGINX_CONF" 2>/dev/null; then
            sed -i '/http {/a \    proxy_read_timeout 300s;\n    proxy_connect_timeout 300s;\n    proxy_send_timeout 300s;' "$NGINX_CONF"
            echo -e "${GREEN}  ✓ Đã thêm timeout settings${NC}"
            ((ISSUES_FIXED++))
        fi
    fi
}

# Hàm tự động sửa lỗi
post_install() {
    echo -e "${YELLOW}[3/6] Tự động sửa các lỗi phát hiện...${NC}\n"
    
    if [[ $ISSUES_FOUND -eq 0 ]]; then
        echo -e "${GREEN}✓ Không có lỗi cần sửa${NC}"
        return
    fi
    
    # 1. Fix quyền thư mục web
    echo -e "${BLUE}→ Sửa quyền thư mục web...${NC}"
    if [[ -d "$NGINX_ROOT" ]]; then
        chmod 755 "$NGINX_ROOT"
        chown -R www-data:www-data "$NGINX_ROOT" 2>/dev/null || chown -R nginx:nginx "$NGINX_ROOT" 2>/dev/null || true
        echo -e "${GREEN}✓ Đã sửa quyền $NGINX_ROOT${NC}"
        ((ISSUES_FIXED++))
    else
        mkdir -p "$NGINX_ROOT"
        chmod 755 "$NGINX_ROOT"
        echo -e "${GREEN}✓ Đã tạo và cấu hình $NGINX_ROOT${NC}"
        ((ISSUES_FIXED++))
    fi
    
    # 2. Fix log files permissions
    echo -e "\n${BLUE}→ Sửa quyền log files...${NC}"
    for log in /var/log/nginx/error.log /var/log/nginx/access.log; do
        touch "$log" 2>/dev/null || true
        chmod 640 "$log"
        chown www-data:adm "$log" 2>/dev/null || chown nginx:nginx "$log" 2>/dev/null || true
    done
    echo -e "${GREEN}✓ Đã sửa quyền log files${NC}"
    ((ISSUES_FIXED++))
    
    # 3. Xóa broken symlinks
    echo -e "\n${BLUE}→ Xóa symlinks bị hỏng...${NC}"
    if [[ -d /etc/nginx/sites-enabled ]]; then
        local removed=0
        while IFS= read -r link; do
            rm -f "$link"
            ((removed++))
        done < <(find /etc/nginx/sites-enabled -type l ! -exec test -e {} \; -print)
        
        if [[ $removed -gt 0 ]]; then
            echo -e "${GREEN}✓ Đã xóa $removed symlink bị hỏng${NC}"
            ((ISSUES_FIXED++))
        fi
    fi
    
    # 4. Fix lỗi 4xx
    fix_4xx_errors
    
    # 5. Fix lỗi 5xx
    fix_5xx_errors
    
    # 6. Tạo backup và test config
    echo -e "\n${BLUE}→ Backup và test cấu hình...${NC}"
    if [[ -f "$NGINX_CONF" ]]; then
        cp "$NGINX_CONF" "$NGINX_CONF.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Đã tạo backup cấu hình${NC}"
    fi
    
    # 7. Restart Nginx nếu cần
    echo -e "\n${BLUE}→ Khởi động lại Nginx...${NC}"
    if nginx -t &>/dev/null; then
        systemctl restart nginx
        echo -e "${GREEN}✓ Đã khởi động lại Nginx thành công${NC}"
        ((ISSUES_FIXED++))
    else
        echo -e "${RED}✗ Không thể khởi động lại do lỗi cấu hình${NC}"
        nginx -t
    fi
    
    echo -e "\n${GREEN}Đã sửa $ISSUES_FIXED vấn đề${NC}\n"
}

# Hàm xác thực sau khi sửa
verify_install() {
    echo -e "${YELLOW}[4/6] Xác thực kết quả...${NC}\n"
    
    # Kiểm tra service
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx service đang chạy${NC}"
    else
        echo -e "${RED}✗ Nginx service vẫn chưa chạy${NC}"
    fi
    
    # Kiểm tra config
    if nginx -t &>/dev/null; then
        echo -e "${GREEN}✓ Cấu hình Nginx hợp lệ${NC}"
    else
        echo -e "${RED}✗ Vẫn còn lỗi trong cấu hình${NC}"
    fi
    
    # Kiểm tra port
    if netstat -tulpn 2>/dev/null | grep -q ":$NGINX_PORT.*nginx" || ss -tulpn 2>/dev/null | grep -q ":$NGINX_PORT.*nginx"; then
        echo -e "${GREEN}✓ Nginx đang lắng nghe trên port $NGINX_PORT${NC}"
    else
        echo -e "${RED}✗ Nginx không lắng nghe trên port $NGINX_PORT${NC}"
    fi
    
    # Hiển thị thông tin
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  Kết quả kiểm tra Nginx${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Vấn đề phát hiện: ${YELLOW}$ISSUES_FOUND${NC}"
    echo -e "Vấn đề đã sửa: ${GREEN}$ISSUES_FIXED${NC}"
    echo -e "Domain: ${GREEN}$NGINX_DOMAIN${NC}"
    echo -e "Port: ${GREEN}$NGINX_PORT${NC}"
    echo -e "Root: ${GREEN}$NGINX_ROOT${NC}"
    
    echo -e "\n${YELLOW}Các lệnh hữu ích:${NC}"
    echo -e "- Kiểm tra config: ${GREEN}nginx -t${NC}"
    echo -e "- Reload config: ${GREEN}systemctl reload nginx${NC}"
    echo -e "- Xem error log: ${GREEN}tail -f /var/log/nginx/error.log${NC}"
    echo -e "- Xem access log: ${GREEN}tail -f /var/log/nginx/access.log${NC}"
    echo -e "- Kiểm tra status: ${GREEN}systemctl status nginx${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

# Hàm chính
run() {
    echo -e "${GREEN}=== Nginx Debug & Auto-Fix Tool ===${NC}\n"
    
    parse_arguments "$@"
    check_requirements
    install_app
    post_install
    verify_install
    
    echo -e "${GREEN}✅ Hoàn tất kiểm tra và sửa lỗi Nginx!${NC}"
}

# Chạy script
run "$@"
