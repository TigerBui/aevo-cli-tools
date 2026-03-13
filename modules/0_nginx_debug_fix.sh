#!/usr/bin/env bash
# TITLE: Nginx Debug Fix (Basic)
# DESC: Kiểm tra và sửa các lỗi cơ bản của Nginx (quyền hạn, config syntax, service status).
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

# Hàm kiểm tra yêu cầu hệ thống
check_requirements() {
    echo -e "${YELLOW}[1/4] Kiểm tra yêu cầu hệ thống...${NC}"
    
    # Kiểm tra quyền root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ Vui lòng chạy script với quyền sudo hoặc root${NC}"
        exit 1
    fi
    
    # Kiểm tra Nginx đã được cài đặt
    if ! command -v nginx &> /dev/null; then
        echo -e "${RED}✗ Nginx chưa được cài đặt trên hệ thống${NC}"
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
    fi
    
    echo -e "${GREEN}✓ Nginx đã được cài đặt${NC}"
    nginx -v 2>&1 | head -1
}

# Hàm kiểm tra và sửa lỗi cấu hình
install_app() {
    echo -e "${YELLOW}[2/4] Kiểm tra và phát hiện lỗi Nginx...${NC}\n"
    
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
    echo -e "\n${BLUE}→ Kiểm tra xung đột port...${NC}"
    if netstat -tulpn 2>/dev/null | grep -q ":80.*nginx" || ss -tulpn 2>/dev/null | grep -q ":80.*nginx"; then
        echo -e "${GREEN}✓ Port 80 đang được Nginx sử dụng${NC}"
    else
        if netstat -tulpn 2>/dev/null | grep -q ":80" || ss -tulpn 2>/dev/null | grep -q ":80"; then
            echo -e "${RED}✗ Port 80 bị chiếm bởi process khác${NC}"
            netstat -tulpn 2>/dev/null | grep ":80" || ss -tulpn 2>/dev/null | grep ":80"
            ((ISSUES_FOUND++))
        else
            echo -e "${YELLOW}⚠ Port 80 không được sử dụng (Nginx có thể chưa start)${NC}"
        fi
    fi
    
    # 4. Kiểm tra quyền truy cập file
    echo -e "\n${BLUE}→ Kiểm tra quyền truy cập thư mục web...${NC}"
    if [[ -d /var/www/html ]]; then
        local perms=$(stat -c %a /var/www/html)
        if [[ "$perms" == "755" || "$perms" == "775" ]]; then
            echo -e "${GREEN}✓ Quyền thư mục /var/www/html: $perms${NC}"
        else
            echo -e "${YELLOW}⚠ Quyền thư mục /var/www/html: $perms (khuyến nghị 755)${NC}"
            ((ISSUES_FOUND++))
        fi
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
    
    echo -e "\n${YELLOW}Tổng số vấn đề phát hiện: $ISSUES_FOUND${NC}\n"
}

# Hàm tự động sửa lỗi
post_install() {
    echo -e "${YELLOW}[3/4] Tự động sửa các lỗi phát hiện...${NC}\n"
    
    if [[ $ISSUES_FOUND -eq 0 ]]; then
        echo -e "${GREEN}✓ Không có lỗi cần sửa${NC}"
        return
    fi
    
    # 1. Fix quyền thư mục web
    echo -e "${BLUE}→ Sửa quyền thư mục web...${NC}"
    if [[ -d /var/www/html ]]; then
        chmod 755 /var/www/html
        chown -R www-data:www-data /var/www/html
        echo -e "${GREEN}✓ Đã sửa quyền /var/www/html${NC}"
        ((ISSUES_FIXED++))
    fi
    
    # 2. Fix log files permissions
    echo -e "\n${BLUE}→ Sửa quyền log files...${NC}"
    for log in /var/log/nginx/error.log /var/log/nginx/access.log; do
        touch "$log" 2>/dev/null || true
        chmod 640 "$log"
        chown www-data:adm "$log"
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
    
    # 4. Tạo backup và test config
    echo -e "\n${BLUE}→ Backup và test cấu hình...${NC}"
    if [[ -f /etc/nginx/nginx.conf ]]; then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
        echo -e "${GREEN}✓ Đã tạo backup cấu hình${NC}"
    fi
    
    # 5. Restart Nginx nếu cần
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
    echo -e "${YELLOW}[4/4] Xác thực kết quả...${NC}\n"
    
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
    
    # Hiển thị thông tin
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  Kết quả kiểm tra Nginx${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Vấn đề phát hiện: ${YELLOW}$ISSUES_FOUND${NC}"
    echo -e "Vấn đề đã sửa: ${GREEN}$ISSUES_FIXED${NC}"
    
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
    
    check_requirements
    install_app
    post_install
    verify_install
    
    echo -e "${GREEN}✅ Hoàn tất kiểm tra và sửa lỗi Nginx!${NC}"
}
