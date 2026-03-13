#!/usr/bin/env bash
# Aevo CLI - 1-Click Web Installer
# Designed to be executed via curl:
# curl -sL https://your-domain.com/1click_install_web.sh | sudo bash

set -euo pipefail

# --- Configuration ---
# UPDATE THIS URL to point to the raw location of the aevo-cli.tar.gz file you host.
TARBALL_URL="https://github.com/TigerBui/aevo-cli-tools/releases/download/aevo-cli/aevo-cli.tar.gz"
INSTALL_DIR="/opt/aevo"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}🚀 Bắt đầu quá trình cấu hình Aevo 1-Click...${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗ Lỗi: Vui lòng chạy lệnh này với quyền root (thêm 'sudo' trước bash).${NC}"
   exit 1
fi

# 1. Download
echo -e "${YELLOW}→ Đang tải hệ thống Aevo CLI...${NC}"
mkdir -p "$INSTALL_DIR"
cd /tmp
if ! curl -sL "$TARBALL_URL" -o aevo-cli.tar.gz; then
    echo -e "${RED}✗ Lỗi tải file. Vui lòng kiểm tra lại URL TARBALL_URL trong script này.${NC}"
    exit 1
fi

# 2. Extract
echo -e "${YELLOW}→ Đang giải nén...${NC}"
tar -xzf aevo-cli.tar.gz -C "$INSTALL_DIR"
rm aevo-cli.tar.gz

# 3. Permissions & Install
echo -e "${YELLOW}→ Cài đặt Aevo CLI toàn cục...${NC}"
cd "$INSTALL_DIR"
chmod +x install.sh antigravity.sh modules/*.sh
./install.sh

echo ""
echo -e "${GREEN}✅ Hoàn tất cấu hình 1-Click!${NC}"
echo -e "Bạn đã có thể gọi lệnh này lập tức: ${CYAN}sudo aevo${NC}"
