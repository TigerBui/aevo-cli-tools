#!/usr/bin/env bash
# TITLE: GitLab EE Install
# DESC: Cài đặt GitLab Enterprise Edition bản Free Tier tự động trên Ubuntu/Debian.
set -euo pipefail

# Tên ứng dụng
APP_NAME="gitlab-ee"

# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Biến cấu hình
GITLAB_EXTERNAL_URL="${GITLAB_EXTERNAL_URL:-http://$(hostname -I | awk '{print $1}')}"
MIN_RAM_GB=4
MIN_DISK_GB=10

# Hàm kiểm tra yêu cầu hệ thống
check_requirements() {
    echo -e "${YELLOW}[1/4] Kiểm tra yêu cầu hệ thống...${NC}"
    
    # Kiểm tra quyền root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ Vui lòng chạy script với quyền sudo hoặc root${NC}"
        exit 1
    fi
    
    # Kiểm tra hệ điều hành (Ubuntu/Debian)
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${RED}✗ Không thể xác định hệ điều hành${NC}"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        echo -e "${RED}✗ Chỉ hỗ trợ Ubuntu và Debian${NC}"
        echo -e "   Hệ điều hành hiện tại: $ID"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Hệ điều hành: $PRETTY_NAME${NC}"
    
    # Kiểm tra RAM (tối thiểu 4GB khuyến nghị)
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    if [[ $total_ram_gb -lt $MIN_RAM_GB ]]; then
        echo -e "${YELLOW}⚠ Cảnh báo: RAM hiện tại ${total_ram_gb}GB < ${MIN_RAM_GB}GB khuyến nghị${NC}"
        echo -e "   GitLab có thể chạy chậm trên hệ thống này"
    else
        echo -e "${GREEN}✓ RAM: ${total_ram_gb}GB${NC}"
    fi
    
    # Kiểm tra dung lượng đĩa
    available_disk_gb=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
    if [[ $available_disk_gb -lt $MIN_DISK_GB ]]; then
        echo -e "${RED}✗ Không đủ dung lượng đĩa${NC}"
        echo -e "   Có sẵn: ${available_disk_gb}GB, Yêu cầu: ${MIN_DISK_GB}GB"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Dung lượng đĩa khả dụng: ${available_disk_gb}GB${NC}"
    
    # Kiểm tra kết nối internet
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "${RED}✗ Không có kết nối internet${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Kết nối internet hoạt động${NC}"
    
    # Kiểm tra GitLab đã được cài đặt chưa (Idempotent check)
    if command -v gitlab-ctl &> /dev/null; then
        echo -e "${YELLOW}⚠ GitLab đã được cài đặt trên hệ thống${NC}"
        gitlab-ctl status | head -5
        
        read -p "Bạn có muốn cấu hình lại GitLab? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✓ Bỏ qua cài đặt, giữ nguyên cấu hình hiện tại${NC}"
            exit 0
        fi
    fi
}

# Hàm cài đặt GitLab EE
install_app() {
    echo -e "${YELLOW}[2/4] Cài đặt GitLab Enterprise Edition...${NC}"
    
    # Thiết lập biến môi trường cho apt (Performance rule)
    export DEBIAN_FRONTEND=noninteractive
    
    # Cài đặt các dependencies cần thiết
    echo -e "${YELLOW}→ Cài đặt dependencies...${NC}"
    apt-get update -qq
    apt-get install -y -qq curl openssh-server ca-certificates tzdata perl
    
    # Cài đặt Postfix cho email (tùy chọn)
    echo -e "${YELLOW}→ Cài đặt Postfix...${NC}"
    apt-get install -y -qq postfix
    
    # Thêm GitLab package repository
    echo -e "${YELLOW}→ Thêm GitLab repository...${NC}"
    
    # Tải script cài đặt repository (với verification)
    curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh -o /tmp/gitlab_repo_script.sh
    
    # Kiểm tra file đã tải về thành công
    if [[ ! -f /tmp/gitlab_repo_script.sh ]]; then
        echo -e "${RED}✗ Không thể tải script repository${NC}"
        exit 1
    fi
    
    # Chạy script thêm repository
    bash /tmp/gitlab_repo_script.sh
    rm -f /tmp/gitlab_repo_script.sh
    
    # Cài đặt GitLab EE package
    echo -e "${YELLOW}→ Cài đặt GitLab EE package (có thể mất vài phút)...${NC}"
    
    # Set external URL trước khi cài đặt
    EXTERNAL_URL="$GITLAB_EXTERNAL_URL" apt-get install -y -qq gitlab-ee
    
    echo -e "${GREEN}✓ GitLab EE đã được cài đặt${NC}"
}

# Hàm cấu hình sau cài đặt
post_install() {
    echo -e "${YELLOW}[3/4] Cấu hình GitLab...${NC}"
    
    # Tạo backup của file cấu hình
    if [[ -f /etc/gitlab/gitlab.rb ]]; then
        cp /etc/gitlab/gitlab.rb /etc/gitlab/gitlab.rb.backup.$(date +%Y%m%d_%H%M%S)
        echo -e "${GREEN}✓ Đã tạo backup cấu hình${NC}"
    fi
    
    # Cấu hình External URL nếu chưa được set
    if ! grep -q "^external_url" /etc/gitlab/gitlab.rb; then
        echo "external_url '$GITLAB_EXTERNAL_URL'" >> /etc/gitlab/gitlab.rb
        echo -e "${GREEN}✓ Đã cấu hình external_url${NC}"
    fi
    
    # Chạy reconfigure để áp dụng cấu hình
    echo -e "${YELLOW}→ Đang cấu hình GitLab (có thể mất vài phút)...${NC}"
    gitlab-ctl reconfigure
    
    echo -e "${GREEN}✓ Hoàn tất cấu hình${NC}"
}

# Hàm xác thực cài đặt
verify_install() {
    echo -e "${YELLOW}[4/4] Xác thực cài đặt...${NC}"
    
    # Kiểm tra GitLab service status
    if ! gitlab-ctl status &> /dev/null; then
        echo -e "${RED}✗ GitLab services không chạy${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ GitLab services đang chạy${NC}"
    
    # Hiển thị trạng thái các services
    gitlab-ctl status
    
    # Kiểm tra port 80 hoặc 443 đang listen
    if netstat -tulpn 2>/dev/null | grep -q ':80\|:443'; then
        echo -e "${GREEN}✓ Web server đang listen trên port 80/443${NC}"
    else
        echo -e "${YELLOW}⚠ Cảnh báo: Không tìm thấy web server listening${NC}"
    fi
    
    # Lấy initial root password
    if [[ -f /etc/gitlab/initial_root_password ]]; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}  GitLab đã được cài đặt thành công!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "\n${YELLOW}Thông tin đăng nhập:${NC}"
        echo -e "URL: ${GITLAB_EXTERNAL_URL}"
        echo -e "Username: ${GREEN}root${NC}"
        echo -e "Password: ${GREEN}$(cat /etc/gitlab/initial_root_password | grep Password: | awk '{print $2}')${NC}"
        echo -e "\n${YELLOW}⚠ Mật khẩu root ban đầu sẽ bị xóa sau 24 giờ.${NC}"
        echo -e "${YELLOW}   Vui lòng đăng nhập và đổi mật khẩu ngay!${NC}"
        echo -e "\n${YELLOW}Các bước tiếp theo:${NC}"
        echo -e "1. Truy cập ${GITLAB_EXTERNAL_URL} trên trình duyệt"
        echo -e "2. Đăng nhập với username 'root' và password ở trên"
        echo -e "3. Đổi mật khẩu root ngay lập tức"
        echo -e "4. Tạo user và project đầu tiên"
        echo -e "\n${YELLOW}Quản lý GitLab:${NC}"
        echo -e "- Kiểm tra status: ${GREEN}sudo gitlab-ctl status${NC}"
        echo -e "- Dừng services: ${GREEN}sudo gitlab-ctl stop${NC}"
        echo -e "- Khởi động lại: ${GREEN}sudo gitlab-ctl restart${NC}"
        echo -e "- Xem logs: ${GREEN}sudo gitlab-ctl tail${NC}"
        echo -e "\n${GREEN}========================================${NC}\n"
    else
        echo -e "${YELLOW}⚠ Không tìm thấy file initial_root_password${NC}"
        echo -e "   GitLab đã được cài đặt nhưng bạn cần reset password root"
    fi
}

# Hàm chính - được gọi từ entry point
run() {
    echo -e "${GREEN}=== Cài đặt GitLab Enterprise Edition (Free Tier) ===${NC}\n"
    
    check_requirements
    install_app
    post_install
    verify_install
    
    echo -e "${GREEN}✅ Hoàn tất cài đặt GitLab EE!${NC}"
}
