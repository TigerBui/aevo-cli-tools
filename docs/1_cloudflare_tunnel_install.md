# Hướng dẫn sử dụng Cloudflare Tunnel (cloudflared)

Module này giúp bạn cài đặt và cấu hình Cloudflare Tunnel (trước đây là Argo Tunnel) trên hệ điều hành Ubuntu/Debian một cách tự động và an toàn.

## 1. Yêu cầu hệ thống

- **Hệ điều hành**: Ubuntu hoặc Debian (bất kỳ phiên bản nào được hỗ trợ).
- **Quyền hạn**: Quyền `sudo` hoặc `root`.
- **Kết nối**: Phải có kết nối internet để tải package từ Cloudflare.

## 2. Các tính năng chính

- ✅ Tự động thêm repo chính thức của Cloudflare.
- ✅ Cài đặt package `cloudflared` phiên bản mới nhất.
- ✅ Hỗ trợ cấu hình tunnel thông qua Token (tạo từ Dashboard).
- ✅ Cài đặt như một system service để tự động khởi động cùng hệ thống.
- ✅ Kiểm tra tính lặp lại (Idempotent) – chạy nhiều lần không gây lỗi.

## 3. Cách sử dụng

### Cách A: Chạy kèm Token (Khuyên dùng)

Nếu bạn đã tạo Tunnel trên [Cloudflare Dashboard](https://one.dash.cloudflare.com/), hãy lấy **Tunnel Token** và chạy lệnh sau:

```bash
export CLOUDFLARE_TUNNEL_TOKEN="your_token_here"
sudo bash -c 'source modules/1_cloudflare_tunnel_install.sh && run'
```

### Cách B: Chỉ cài đặt (Cấu hình sau)

Nếu bạn chưa có Token và muốn cài đặt trước:

```bash
sudo bash -c 'source modules/1_cloudflare_tunnel_install.sh && run'
```

_Script sẽ hỏi bạn có muốn tiếp tục mà không cần token hay không._

## 4. Sau khi cài đặt

### Nếu đã cấu hình Token:

Tunnel sẽ tự động kết nối. Bạn có thể kiểm tra trạng thái trên Cloudflare Dashboard hoặc dùng lệnh:

```bash
sudo systemctl status cloudflared
```

### Nếu chưa cấu hình Token:

Bạn cần thực hiện các bước sau để kết nối:

1. **Đăng nhập**:
   ```bash
   cloudflared tunnel login
   ```
2. **Tạo Tunnel**:
   ```bash
   cloudflared tunnel create <tên_tunnel>
   ```
3. **Cấu hình DNS**:
   ```bash
   cloudflared tunnel route dns <tên_tunnel> yourdomain.com
   ```
4. **Cài đặt service**:
   ```bash
   sudo cloudflared service install
   sudo systemctl start cloudflared
   ```

## 5. Các lệnh quản lý

- **Kiểm tra trạng thái**: `systemctl status cloudflared`
- **Xem logs**: `journalctl -u cloudflared -f`
- **Khởi động lại**: `sudo systemctl restart cloudflared`
- **Dừng service**: `sudo systemctl stop cloudflared`
- **Danh sách tunnel**: `cloudflared tunnel list`

---

_Lưu ý: Mọi cấu hình tunnel thủ công sẽ được lưu tại `/etc/cloudflared/config.yml`._
