#!/usr/bin/env bash
# TITLE: Cloudflare Tunnel Install
# DESC: Cài đặt và cấu hình cloudflared để thiết lập Cloudflare Tunnel bảo mật.
set -euo pipefail

# Tên ứng dụng
APP_NAME="cloudflare-tunnel"

# Màu sắc cho thông báo
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Biến cấu hình
TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
TUNNEL_NAME="${CLOUDFLARE_TUNNEL_NAME:-my-tunnel}"

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
    
    # Kiểm tra kết nối internet
    if ! ping -c 1 1.1.1.1 &> /dev/null; then
        echo -e "${RED}✗ Không có kết nối internet${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Kết nối internet hoạt động${NC}"
    
    # Kiểm tra cloudflared đã được cài đặt chưa (Idempotent check)
    if command -v cloudflared &> /dev/null; then
        echo -e "${YELLOW}⚠ Cloudflared đã được cài đặt trên hệ thống${NC}"
        cloudflared --version
        
        read -p "Bạn có muốn cấu hình lại tunnel? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✓ Bỏ qua cài đặt, giữ nguyên cấu hình hiện tại${NC}"
            exit 0
        fi
    fi
    
    # Kiểm tra tunnel token nếu cần thiết
    if [[ -z "$TUNNEL_TOKEN" ]]; then
        echo -e "${YELLOW}⚠ Chưa có CLOUDFLARE_TUNNEL_TOKEN${NC}"
        echo -e "${YELLOW}Bạn có thể:${NC}"
        echo -e "1. Tạo tunnel mới và lấy token từ Cloudflare Dashboard"
        echo -e "2. Set biến môi trường: export CLOUDFLARE_TUNNEL_TOKEN='your-token'"
        echo -e "3. Chạy lại script này"
        echo -e "\n${YELLOW}Hoặc tiếp tục để cài đặt cloudflared và tạo tunnel thủ công sau${NC}"
        
        read -p "Tiếp tục cài đặt không có token? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Hủy cài đặt. Vui lòng chuẩn bị tunnel token và chạy lại.${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}✓ Tunnel token đã được cung cấp${NC}"
    fi
}

# Hàm cài đặt Cloudflared
install_app() {
    echo -e "${YELLOW}[2/4] Cài đặt Cloudflare Tunnel (cloudflared)...${NC}"
    
    # Thiết lập biến môi trường cho apt (Performance rule)
    export DEBIAN_FRONTEND=noninteractive
    
    # Cài đặt các dependencies cần thiết
    echo -e "${YELLOW}→ Cài đặt dependencies...${NC}"
    apt-get update -qq
    apt-get install -y -qq curl gnupg lsb-release
    
    # Thêm Cloudflare GPG key
    echo -e "${YELLOW}→ Thêm Cloudflare GPG key...${NC}"
    mkdir -p /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
    
    # Kiểm tra GPG key đã tải về thành công
    if [[ ! -f /usr/share/keyrings/cloudflare-main.gpg ]]; then
        echo -e "${RED}✗ Không thể tải Cloudflare GPG key${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Đã thêm Cloudflare GPG key${NC}"
    
    # Thêm Cloudflare repository
    echo -e "${YELLOW}→ Thêm Cloudflare repository...${NC}"
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/cloudflared.list
    
    # Cập nhật package list và cài đặt cloudflared
    echo -e "${YELLOW}→ Cài đặt cloudflared...${NC}"
    apt-get update -qq
    apt-get install -y -qq cloudflared
    
    echo -e "${GREEN}✓ Cloudflared đã được cài đặt${NC}"
    cloudflared --version
}

# Hàm cấu hình sau cài đặt
post_install() {
    echo -e "${YELLOW}[3/4] Cấu hình Cloudflare Tunnel...${NC}"
    
    # Tạo thư mục cấu hình nếu chưa tồn tại
    mkdir -p /etc/cloudflared
    chmod 700 /etc/cloudflared
    
    # Nếu có tunnel token, cấu hình tunnel
    if [[ -n "$TUNNEL_TOKEN" ]]; then
        echo -e "${YELLOW}→ Cấu hình tunnel với token...${NC}"
        
        # Tạo file credentials
        cat > /etc/cloudflared/config.yml <<EOF
tunnel: $TUNNEL_TOKEN
credentials-file: /etc/cloudflared/credentials.json
EOF
        
        chmod 600 /etc/cloudflared/config.yml
        
        # Cài đặt cloudflared như một service
        echo -e "${YELLOW}→ Cài đặt cloudflared service...${NC}"
        cloudflared service install $TUNNEL_TOKEN
        
        # Khởi động service
        systemctl enable cloudflared
        systemctl start cloudflared
        
        echo -e "${GREEN}✓ Tunnel đã được cấu hình và khởi động${NC}"
    else
        echo -e "${YELLOW}⚠ Bỏ qua cấu hình tunnel (không có token)${NC}"
        echo -e "${YELLOW}Để cấu hình tunnel sau, sử dụng:${NC}"
        echo -e "  ${GREEN}cloudflared tunnel login${NC}"
        echo -e "  ${GREEN}cloudflared tunnel create $TUNNEL_NAME${NC}"
        echo -e "  ${GREEN}cloudflared tunnel route dns $TUNNEL_NAME yourdomain.com${NC}"
        echo -e "  ${GREEN}cloudflared service install${NC}"
    fi
}

# Hàm xác thực cài đặt
verify_install() {
    echo -e "${YELLOW}[4/4] Xác thực cài đặt...${NC}"
    
    # Kiểm tra cloudflared đã được cài đặt
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}✗ Cloudflared không được cài đặt đúng cách${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Cloudflared đã được cài đặt${NC}"
    
    # Kiểm tra service status nếu đã cấu hình
    if systemctl is-enabled cloudflared &> /dev/null; then
        echo -e "${GREEN}✓ Cloudflared service đã được kích hoạt${NC}"
        
        if systemctl is-active cloudflared &> /dev/null; then
            echo -e "${GREEN}✓ Cloudflared service đang chạy${NC}"
            systemctl status cloudflared --no-pager | head -10
        else
            echo -e "${YELLOW}⚠ Cloudflared service chưa chạy${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Cloudflared service chưa được cấu hình${NC}"
    fi
    
    # Hiển thị thông tin hướng dẫn
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  Cloudflared đã được cài đặt!${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    if [[ -n "$TUNNEL_TOKEN" ]]; then
        echo -e "\n${YELLOW}Tunnel đã được cấu hình và đang chạy${NC}"
        echo -e "Kiểm tra trạng thái tunnel tại Cloudflare Dashboard"
    else
        echo -e "\n${YELLOW}Các bước tiếp theo để tạo tunnel:${NC}"
        echo -e "1. Đăng nhập Cloudflare:"
        echo -e "   ${GREEN}cloudflared tunnel login${NC}"
        echo -e "\n2. Tạo tunnel mới:"
        echo -e "   ${GREEN}cloudflared tunnel create $TUNNEL_NAME${NC}"
        echo -e "\n3. Cấu hình DNS routing:"
        echo -e "   ${GREEN}cloudflared tunnel route dns $TUNNEL_NAME yourdomain.com${NC}"
        echo -e "\n4. Tạo file cấu hình /etc/cloudflared/config.yml:"
        echo -e "   ${GREEN}cat > /etc/cloudflared/config.yml <<EOF"
        echo -e "tunnel: <tunnel-id>"
        echo -e "credentials-file: /root/.cloudflared/<tunnel-id>.json"
        echo -e ""
        echo -e "ingress:"
        echo -e "  - hostname: yourdomain.com"
        echo -e "    service: http://localhost:80"
        echo -e "  - service: http_status:404"
        echo -e "EOF${NC}"
        echo -e "\n5. Cài đặt service:"
        echo -e "   ${GREEN}cloudflared service install${NC}"
        echo -e "   ${GREEN}systemctl start cloudflared${NC}"
    fi
    
    echo -e "\n${YELLOW}Quản lý Cloudflared:${NC}"
    echo -e "- Kiểm tra status: ${GREEN}systemctl status cloudflared${NC}"
    echo -e "- Xem logs: ${GREEN}journalctl -u cloudflared -f${NC}"
    echo -e "- Dừng service: ${GREEN}systemctl stop cloudflared${NC}"
    echo -e "- Khởi động lại: ${GREEN}systemctl restart cloudflared${NC}"
    echo -e "- List tunnels: ${GREEN}cloudflared tunnel list${NC}"
    echo -e "- Tunnel info: ${GREEN}cloudflared tunnel info <tunnel-name>${NC}"
    echo -e "\n${GREEN}========================================${NC}\n"
}

# Hàm chính - được gọi từ entry point
run() {
    echo -e "${GREEN}=== Cài đặt Cloudflare Tunnel (cloudflared) ===${NC}\n"
    
    check_requirements
    install_app
    post_install
    verify_install
    
    echo -e "${GREEN}✅ Hoàn tất cài đặt Cloudflare Tunnel!${NC}"
}
