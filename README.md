# Hệ thống Điểm danh NFC (NFC Attendance System)

Hệ thống chấm công bằng thẻ NFC trên thiết bị Android Kiosk kết hợp bảng điều khiển Quản trị viên (Admin) thời gian thực trên nền tảng Supabase và Flutter.

---

## 1. Thiết lập Backend (Supabase)

1. Tạo một dự án mới trên [Supabase](https://supabase.com).
2. Mở **SQL Editor** trên Supabase Dashboard và thực thi toàn bộ script trong file:
   ```
   supabase/migrations/0001_init.sql
   ```
3. Tạo 2 tài khoản người dùng trong mục **Authentication -> Users**:
   - `admin@attendance.local` (Tài khoản quản trị viên)
   - `kiosk@attendance.local` (Tài khoản máy kiosk)
4. Lấy UUID của 2 user vừa tạo và gắn quyền tương ứng vào bảng `profiles` bằng câu lệnh SQL:
   ```sql
   insert into profiles (id, role) values
     ('<uuid-cua-admin>', 'admin'),
     ('<uuid-cua-kiosk>', 'kiosk');
   ```
5. (Tùy chọn) Chạy bộ kiểm thử SQL `supabase/tests.sql` trong SQL Editor để xác nhận tất cả logic `record_scan` đã pass 100%.

---

## 2. Cấu hình biến môi trường (`--dart-define`)

Hệ thống bảo mật tuyệt đối không commit thông tin bí mật. Mọi thông tin kết nối được truyền qua cờ `--dart-define`:

| Tham số | Bắt buộc | Mặc định | Mô tả |
|---|---|---|---|
| `SUPABASE_URL` | Có | *(Trống)* | URL dự án Supabase (`https://xxxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | Có | *(Trống)* | Anon/Public API Key của Supabase |
| `KIOSK_PIN` | Không | `1234` | Mã PIN mở menu quản trị/thoát trên Kiosk |
| `FAKE_NFC` | Không | `false` | Bật chế độ giả lập quẹt thẻ khi chạy emulator |

---

## 3. Hướng dẫn chạy ứng dụng (Development)

### Chạy với NFC thật trên thiết bị Android vật lý:
```bash
flutter run -d <device-id> \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Chạy giả lập trên Emulator / Web / Desktop (không có phần cứng NFC):
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=FAKE_NFC=true
```
*Khi bật `FAKE_NFC=true`, máy kiosk sẽ hiển thị nút "Giả lập quẹt thẻ" để bạn chọn UID mẫu hoặc nhập UID tùy ý.*

---

## 4. Hướng dẫn Build APK Release

Để build bản phát hành (Release APK) cài đặt lên máy Kiosk hoặc thiết bị Admin:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=KIOSK_PIN=1234
```

File APK đầu ra sẽ nằm tại:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 5. Checklist triển khai thiết bị Kiosk Android thực tế

Để đảm bảo Kiosk hoạt động liên tục 24/7 ổn định:

1. **NFC:** Bật tính năng NFC trong mục *Cài đặt (Settings) -> Kết nối (Connected devices/NFC)*.
2. **Không tắt màn hình:**
   - Ứng dụng đã tự động kích hoạt `wakelock_plus` để giữ sáng màn hình.
   - Trong *Cài đặt nhà phát triển (Developer Options)* trên Android, bật thêm tùy chọn **"Luôn sáng khi sạc" (Stay awake while charging)**.
3. **Ghim màn hình (App Pinning / Screen Pinning):**
   - Vào *Cài đặt -> Bảo mật -> Ghim ứng dụng (App Pinning)* và bật tính năng này.
   - Ghim ứng dụng NFC Attendance để nhân viên không thể thoát ra màn hình chính của Android.
4. **Nguồn điện:** Cắm sạc liên tục bằng củ sạc và dây cáp chính hãng.
5. **Cố định:** Đặt máy kiosk tại giá đỡ cố định ở cửa ra vào, độ cao thuận tiện (khoảng 1.2m - 1.4m so với mặt sàn).
6. **Thoát Kiosk:** Nhấn giữ biểu tượng logo NFC trên màn hình chính trong 3 giây và nhập mã PIN (`1234`) để xóa cấu hình hoặc đăng xuất.

---

## 6. Chạy Kiểm thử Tự động (Tests)

```bash
# Phân tích mã nguồn (yêu cầu 0 issue)
flutter analyze

# Chạy toàn bộ test suites (Core, Auth, Kiosk, Offline Queue, Admin)
flutter test
```
