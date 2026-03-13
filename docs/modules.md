# Danh sách Module Cài đặt (Aevo CLI)

Thư mục `modules/` chứa các script độc lập (thường được gọi là Module). Mỗi script đảm nhận một tác vụ cài đặt, cấu hình hoặc gỡ lỗi cụ thể trên server.

Các Module được tự động nhận dạng và hiển thị trên menu của Aevo CLI dựa trên chuẩn siêu dữ liệu (Metadata) nằm ở đầu mỗi file script:
```bash
# TITLE: Tên Module
# DESC: Mô tả ngắn gọn chức năng của Module
```

Dưới đây là danh sách phân loại tổng hợp chức năng của các Module hiện có:

## 🌐 Mảng Nginx & HTTP Server

| Tên File | Tiêu đề (TITLE) | Chức năng (DESC) |
| :--- | :--- | :--- |
| `0_nginx_debug_fix.sh` | **Nginx Debug Fix (Basic)** | Kiểm tra và sửa các lỗi cơ bản của Nginx (quyền hạn, config syntax, service status). |
| `1_nginx_debug_fix_install.sh` | **Nginx Debug Fix (Advanced)** | Công cụ debug và tự động sửa lỗi Nginx nâng cao với phân tích log và fix lỗi 4xx/5xx. |
| `1_ssl_site_nginx_conf.sh` | **Nginx Site SSL Configurer** | Tạo nhanh cấu hình vhost Nginx hỗ trợ SSL và tự động chuyển hướng HTTP sang HTTPS. |

## 🔒 Kiểm tra & Khắc phục lỗi SSL

| Tên File | Tiêu đề (TITLE) | Chức năng (DESC) |
| :--- | :--- | :--- |
| `1_ssl_nginx_debug_fix.sh` | **SSL & Nginx Permission Fix** | Sửa lỗi quyền truy cập file certificate Let's Encrypt cho Nginx user. |
| `1_ssl_debug_renew_certbot.sh` | **Certbot SSL Debug & Renew** | Tự động kiểm tra và sửa lỗi gia hạn SSL Certbot (mismatch symlinks, archive consistency). |

## 🚀 Mảng Web App (Node.js & Next.js)

| Tên File | Tiêu đề (TITLE) | Chức năng (DESC) |
| :--- | :--- | :--- |
| `1_nodejs_debug_fix.sh` | **NodeJS/Next.js Debug Fix** | Sửa lỗi permission 403 cho project Next.js và tự động cấu hình Nginx proxy. |

## ☁️ Network & DevOps (Cloudflare, GitLab)

| Tên File | Tiêu đề (TITLE) | Chức năng (DESC) |
| :--- | :--- | :--- |
| `1_cloudflare_tunnel_install.sh` | **Cloudflare Tunnel Install** | Cài đặt và cấu hình cloudflared để thiết lập Cloudflare Tunnel bảo mật. |
| `1_gitlab_ee_install.sh` | **GitLab EE Install** | Cài đặt GitLab Enterprise Edition bản Free Tier tự động trên Ubuntu/Debian. |

---

> **Gợi ý dành cho Nhà phát triển:**
> Nếu bạn muốn bổ sung thêm module mới, chỉ cần tạo trực tiếp file Bash (`*.sh`) vào thư mục `modules/` và đừng quên gắn tag `# TITLE:` cùng `# DESC:` ở ngay dòng 2, dòng 3 để hệ CLI nhận diện tự động nhé!
