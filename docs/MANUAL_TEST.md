# Hướng Dẫn & Nhật Ký Kiểm Thử Thủ Công (Manual Test Log)

Tài liệu ghi lại quy trình và kết quả kiểm thử thủ công các kịch bản thực tế trên thiết bị Kiosk và trang quản trị Admin.

---

## 1. Kịch bản MT1: 4 nhân viên quẹt vào / ra trong ngày

- **Mục tiêu:** Kiểm tra luồng check-in / check-out thông thường của 4 nhân viên trong một ngày làm việc.
- **Các bước thực hiện:**
  1. Thêm 4 nhân viên: NV01, NV02, NV03, NV04 tại trang Admin.
  2. Gán 4 thẻ NFC tương ứng cho 4 nhân viên.
  3. Lần lượt quẹt 4 thẻ tại Kiosk vào buổi sáng.
     - **Kết quả kỳ vọng:** Kiosk hiển thị màn hình xanh lá "Xin chào, {Tên}", phản hồi tức thì < 2 giây. Server ghi nhận 4 event `check_in`.
  4. Sau ca làm việc (sau >= 60 giây), lần lượt quẹt lại 4 thẻ.
     - **Kết quả kỳ vọng:** Kiosk hiển thị màn hình xanh dương "Tạm biệt, {Tên}", server ghi nhận 4 event `check_out`.
  5. Admin mở Bảng công ngày (`/admin/days`):
     - **Kết quả kỳ vọng:** Hiển thị đủ 4 nhân viên với giờ vào, giờ ra, tổng thời gian làm việc được tính chính xác.

---

## 2. Kịch bản MT2: Mất mạng giữa chừng (Offline Queue & Sync)

- **Mục tiêu:** Kiểm tra hàng đợi offline và cơ chế tự động đồng bộ khi mất kết nối mạng.
- **Các bước thực hiện:**
  1. Tắt kết nối Wifi / 4G trên máy Kiosk.
  2. Chấm trạng thái trên màn hình Kiosk chuyển sang màu vàng: `Ngoại tuyến (0 chờ đồng bộ)`.
  3. Quẹt 3 thẻ khác nhau tại Kiosk khi đang mất mạng.
     - **Kết quả kỳ vọng:** Kiosk hiển thị màn hình vàng "Đã ghi nhận (offline), sẽ đồng bộ sau".
     - Chấm trạng thái cập nhật: `Ngoại tuyến (3 chờ đồng bộ)`.
  4. Bật lại kết nối Wifi / 4G.
     - **Kết quả kỳ vọng:** Trong vòng <= 30 giây, `SyncService` tự động phát hiện mạng và gửi toàn bộ 3 lượt quẹt lên server với `p_is_replay: true`.
     - Số chờ đồng bộ giảm dần về 0.
     - Chấm trạng thái chuyển sang xanh lá `Trực tuyến`.
     - Dữ liệu `attendance_events` trên Supabase có đủ 3 event với `occurred_at` = `device_time`.

---

## 3. Kịch bản MT3: Quẹt thẻ chưa đăng ký (Thẻ lạ)

- **Mục tiêu:** Kiểm tra từ chối thẻ không hợp lệ.
- **Các bước thực hiện:**
  1. Quẹt một thẻ NFC bất kỳ chưa được gán cho nhân viên nào.
  2. **Kết quả kỳ vọng:** Kiosk hiển thị màn hình đỏ "Thẻ không hợp lệ". Bảng `scan_rejections` trên Supabase có một dòng ghi lại UID, thời gian và lý do `unknown_or_inactive_card`.

---

## 4. Kịch bản MT4: Quẹt liên tục hai lần (Debounce chống quẹt đúp)

- **Mục tiêu:** Kiểm tra chống quẹt đúp vô tình.
- **Các bước thực hiện:**
  1. Quẹt thẻ nhân viên NV01 lần 1 -> Màn hình xanh "Xin chào, Nguyen Van A".
  2. Quẹt lại ngay lập tức thẻ NV01 trong vòng < 3 giây:
     - **Kết quả kỳ vọng:** Kiosk bỏ qua cục bộ, không nháy màn hình.
  3. Quẹt lại thẻ NV01 trong khoảng 3 giây đến 60 giây:
     - **Kết quả kỳ vọng:** Kiosk hiển thị màn hình xám "Bạn vừa quẹt xong rồi". Không phát sinh event mới trong DB.

---

## 5. Kịch bản MT5: Khóa thẻ nhân viên

- **Mục tiêu:** Kiểm tra vô hiệu hóa thẻ bị mất hoặc tạm dừng.
- **Các bước thực hiện:**
  1. Admin mở chi tiết nhân viên NV01, bấm nút "Khóa thẻ".
  2. Đưa thẻ vừa bị khóa quẹt tại Kiosk.
  3. **Kết quả kỳ vọng:** Kiosk hiển thị màn hình đỏ "Thẻ không hợp lệ".
  4. Admin bấm "Mở khóa thẻ", quẹt lại -> Kiosk nhận bình thường.

---

## 6. Kịch bản MT6: Quên check-out

- **Mục tiêu:** Xử lý nhân viên quên quẹt ra trước khi về.
- **Các bước thực hiện:**
  1. Nhân viên chỉ quẹt check-in buổi sáng hôm trước.
  2. Đến sáng hôm sau (> 16 tiếng), nhân viên quẹt thẻ lần tiếp theo.
  3. **Kết quả kỳ vọng:** Lần quẹt mới được tính là `check_in` mới. Event check-in cũ của ngày hôm trước được đánh dấu cờ `missing_checkout`.
  4. Trên Bảng công ngày của Admin, dòng công của ngày hôm trước hiển thị badge đỏ "Thiếu check-out".

---

## 7. Kịch bản MT7: Khởi động lại máy Kiosk

- **Mục tiêu:** Kiểm tra tính bền vững của phiên đăng nhập và hàng đợi sau khi khởi động lại máy.
- **Các bước thực hiện:**
  1. Tắt mạng, quẹt 2 thẻ để có 2 item trong hàng đợi offline.
  2. Tắt nguồn và bật lại máy Android Kiosk.
  3. Mở ứng dụng NFC Attendance:
     - **Kết quả kỳ vọng:** Ứng dụng tự động khôi phục cấu hình từ `SharedPreferences`, vào thẳng màn hình `/kiosk` (không bị đẩy về `/login` hoặc `/kiosk/setup`).
     - Hàng đợi offline trong SQLite vẫn nguyên vẹn (2 item chờ đồng bộ).
  4. Bật mạng -> Tự động đồng bộ đủ 2 item lên server.
