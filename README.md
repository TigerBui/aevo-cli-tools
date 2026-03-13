# Aevo CLI 🚀

Aevo là một công cụ dòng lệnh (CLI) mạnh mẽ dùng để quản lý và cấu hình nhanh các Cloud Server/VPS (Nginx, SSL, GitLab, NodeJS, v.v.) thông qua hệ thống module linh hoạt.

## ✨ Tính năng nổi bật
- **Giao diện Menu Tương tác**: Dễ dàng chọn module cần chạy trên môi trường headless.
- **Tự động nhận diện Module**: Tự động quét và liệt kê các script mới trong thư mục `modules/`.
- **Cài đặt Toàn cục**: Sử dụng lệnh `aevo` ở bất kỳ đâu trên hệ thống.
- **Hỗ trợ Đối số**: Chạy trực tiếp module cụ thể mà không cần menu (phù hợp cho automation).

## 🛠 Cài đặt Toàn cục

Cho server hiện tại, hãy chạy script cài đặt:
```bash
sudo ./install.sh
```
Sau đó, bạn chỉ cần gõ:
```bash
sudo aevo
```

## ⚡ Cài đặt "1-Click" từ Web (Cloud Installer)
Nếu bạn vừa tạo một VPS mới và muốn cài nhanh toàn bộ công cụ này CHỈ VỚI 1 LỆNH duy nhất, hãy chạy:

```bash
curl -sL https://url-den-file-cua-ban/1click_install_web.sh | sudo bash
```

**Cách thiết lập mô hình 1-Click của riêng bạn:**
1. Trên máy tính cá nhân/server nội bộ, chạy lệnh `./build.sh`. Script sẽ tự động đóng gói dự án thành một file nén nhỏ gọn tên là `aevo-cli.tar.gz`.
2. Upload file `aevo-cli.tar.gz` này lên trình lưu trữ web hoặc tính năng Releases của GitHub.
3. Mở file `1click_install_web.sh`, thay đổi đường dẫn ở dòng `TARBALL_URL="..."` thành URL tải file nén trực tiếp vừa upload.
4. Cung cấp (host) file `1click_install_web.sh` đó công khai, dùng địa chỉ công khai đó để điền vào câu lệnh `curl` ở đầu bài.

Ngay sau khi lệnh cài đặt chạy xong, bạn có thể sử dụng ngay lập tức:
```bash
sudo aevo
```

## 🚀 Tính năng Tự động Triển khai (Deploy)
Bạn có thể dễ dàng đẩy (deploy) mã nguồn của CLI này lên VPS từ xa trực tiếp từ máy của bạn.

### Từ Windows PowerShell:
```powershell
# Cơ bản
.\deploy.ps1 -Target root@202.10.1.10

# Nâng cao (có SSH Key và Port đặc biệt)
.\deploy.ps1 -Target ubuntu@myserver.com -Port 2200 -IdentityFile "C:\Path\To\private_key.pem"
```

### Từ Linux / MacOS / Git Bash:
```bash
# Cơ bản
./deploy.sh root@202.10.1.10

# Nâng cao (có SSH Key và Port đặc biệt)
./deploy.sh ubuntu@myserver.com -p 2200 -i ~/.ssh/id_rsa
```

## 📂 Cấu trúc dự án
- `antigravity.sh`: CLI Core điều phối mọi hoạt động.
- `install.sh`: Script cài đặt lệnh `aevo` vào hệ thống.
- `modules/`: Chứa các script quản lý server riêng lẻ.
- `1_click_install.sh`: Legacy entry point (tương thích ngược).

## 🚀 Thêm Module mới
1. Tạo script `.sh` trong `modules/`.
2. Thêm header metadata để CLI hiển thị đẹp hơn:
   ```bash
   #!/usr/bin/env bash
   # TITLE: Tên Module Của Bạn
   # DESC: Mô tả ngắn gọn chức năng của module.
   ```
3. Định nghĩa hàm `run()` thực thi chính (khuyến nghị). CLI sẽ tự động nhận diện module mới trong lần chạy tiếp theo.

---
*Phát triển bởi đội ngũ Aevo.*
