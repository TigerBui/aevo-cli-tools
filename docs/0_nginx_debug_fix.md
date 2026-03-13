# Hướng dẫn sử dụng Nginx Debug & Fix Module

Module này tự động kiểm tra và sửa các lỗi phổ biến liên quan đến Nginx trên Linux.

## 1. Tính năng chính

Module thực hiện **8 kiểm tra tự động**:

1. ✅ **Syntax cấu hình** - Kiểm tra lỗi cú pháp trong file config
2. ✅ **Service status** - Kiểm tra Nginx có đang chạy không
3. ✅ **Port conflicts** - Phát hiện xung đột port 80/443
4. ✅ **Quyền truy cập** - Kiểm tra permissions của thư mục web
5. ✅ **Log files** - Kiểm tra quyền ghi log
6. ✅ **Error analysis** - Phân tích lỗi gần đây trong error.log
7. ✅ **Worker connections** - Kiểm tra cấu hình hiệu suất
8. ✅ **Broken symlinks** - Tìm và xóa symlink bị hỏng

## 2. Auto-Fix tự động

Module có khả năng **tự động sửa** các lỗi sau:

- 🔧 Sửa quyền thư mục `/var/www/html` (755)
- 🔧 Sửa quyền log files (640)
- 🔧 Xóa symlinks bị hỏng trong `sites-enabled`
- 🔧 Tạo backup cấu hình trước khi sửa
- 🔧 Restart Nginx service nếu cần

## 3. Cách sử dụng

### Chạy module độc lập:
```bash
sudo bash -c 'source modules/0_nginx_debug_fix.sh && run'
```

### Hoặc tích hợp vào 1_click_install.sh:
Thêm dòng sau vào file chính:
```bash
run_module "modules/0_nginx_debug_fix.sh"
```

## 4. Kết quả mẫu

```
=== Nginx Debug & Auto-Fix Tool ===

[1/4] Kiểm tra yêu cầu hệ thống...
✓ Nginx đã được cài đặt

[2/4] Kiểm tra và phát hiện lỗi Nginx...
→ Kiểm tra syntax cấu hình Nginx...
✓ Syntax cấu hình Nginx hợp lệ
→ Kiểm tra trạng thái Nginx service...
✓ Nginx service đang chạy
...
Tổng số vấn đề phát hiện: 3

[3/4] Tự động sửa các lỗi phát hiện...
→ Sửa quyền thư mục web...
✓ Đã sửa quyền /var/www/html
...
Đã sửa 3 vấn đề

[4/4] Xác thực kết quả...
✓ Nginx service đang chạy
✓ Cấu hình Nginx hợp lệ
```

## 5. Các lệnh hữu ích

Sau khi chạy module, bạn có thể sử dụng:

- **Kiểm tra config**: `nginx -t`
- **Reload config**: `systemctl reload nginx`
- **Xem error log**: `tail -f /var/log/nginx/error.log`
- **Xem access log**: `tail -f /var/log/nginx/access.log`
- **Kiểm tra status**: `systemctl status nginx`

## 6. Lưu ý quan trọng

- ⚠️ Module cần quyền **root/sudo** để chạy
- ⚠️ Tự động tạo **backup** trước khi sửa cấu hình
- ⚠️ **Idempotent** - An toàn khi chạy nhiều lần
- ⚠️ Không xóa dữ liệu người dùng

## 7. Khi nào nên sử dụng?

- 🔍 Nginx không khởi động được
- 🔍 Lỗi 403 Forbidden không rõ nguyên nhân
- 🔍 Lỗi 502 Bad Gateway
- 🔍 Sau khi cập nhật cấu hình
- 🔍 Kiểm tra định kỳ hệ thống
- 🔍 Trước khi deploy production

---

*Module này tuân thủ đầy đủ Antigravity standards: Security, Idempotency, Performance, và Quality.*
