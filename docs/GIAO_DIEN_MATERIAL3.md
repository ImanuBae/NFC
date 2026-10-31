# Giao diện Material 3 — Lavender

App dùng Material 3 của Flutter, với màu lavender và hình dáng mềm mại lấy cảm hứng từ ảnh tham khảo M3 Expressive. Giao diện sáng được cố định bằng `ThemeMode.light` trên web, điện thoại và máy ảo, kể cả khi hệ điều hành bật chế độ tối. Đây là cách áp dụng bằng các component Flutter hiện có; không phải mọi component mới trên trang M3 Expressive đều đã được tái hiện.

## Bảng màu

| Vai trò | Theme sáng | Sử dụng |
| --- | --- | --- |
| Primary | `#675091` | Thao tác chính, số liệu nổi bật, tiến độ |
| Primary container | `#D8C7FF` | Tiêu đề trang, đồng hồ kiosk, vùng đang chọn |
| Nền | `#E6E1F5` | Nền lavender sáng tổng thể |
| Surface | `#FCF8FF` | Thẻ nội dung, form |
| Secondary container | `#CEB9FF` | Thao tác phụ dạng tonal |
| Tertiary | `#824780` | Điểm nhấn hồng tím |

Theme tối còn được giữ trong mã để tham khảo nhưng app không tự kích hoạt. Màu chữ trên container dùng đúng vai trò `onPrimaryContainer`, `onSurface`… để giữ độ tương phản. Không ép toàn bộ trạng thái thành màu tím: thành công, lỗi và cảnh báo vẫn cần phân biệt bằng màu, biểu tượng và nội dung.

## Quy tắc sử dụng

- Nút chính và phụ bo dạng viên thuốc, vùng chạm tối thiểu 48 dp.
- Thẻ nội dung bo 24 dp; phần giới thiệu và dialog bo 28 dp; ô nhập liệu bo 16 dp.
- Dùng `PageHeader` cho tiêu đề nổi bật có mô tả và thao tác tùy chọn. Nội dung và thao tác tự xuống dòng khi hẹp.
- Điện thoại dùng thanh điều hướng dưới: admin có 5 mục, manager có 3 mục. Từ 900 dp chuyển sang navigation rail; từ 1200 dp hiển thị nhãn mở rộng.
- Bảng dữ liệu ưu tiên khả năng đọc và so sánh; dùng chip cho bộ lọc và trạng thái. Tránh thêm chuyển động vào số giờ hoặc dữ liệu tự làm mới.
- Màu và hình dáng dùng chung đặt trong `lib/core/theme.dart`; tránh thêm màu nền cố định vào từng màn hình.

## Phạm vi đã áp dụng

Theme chung cập nhật button, card, input, chip, navigation, dialog, bottom sheet, snackbar và progress indicator. Đăng nhập có thẻ form và biểu tượng NFC; dashboard và màn hình nhân viên có tiêu đề tonal; các thẻ thống kê có nền và vùng biểu tượng theo màu; kiosk có đồng hồ và vùng quét màu lavender.

Các màn hình cũ còn một số màu trạng thái riêng, đặc biệt kết quả quét toàn màn hình. Chúng vẫn giữ cách phân biệt trạng thái hiện có và chưa được chuẩn hóa hết theo token.

## Đề xuất cho các bước tiếp theo

1. **Giữ Material 3:** phù hợp với Flutter và app Android có kiosk, form và quản lý dữ liệu. Hiện chưa có lý do để chuyển sang một hệ thống khác. Dùng nét Expressive rõ hơn ở đăng nhập và kiosk; giữ trang báo cáo gọn.
2. **Tách trải nghiệm theo vai trò:** nhân viên ưu tiên công hôm nay và lịch sử; quản lý ưu tiên trường hợp cần xử lý; kiosk ưu tiên đồng hồ, vùng quét và phản hồi lớn.
3. **Bổ sung semantic color token:** gom các màu thành công/cảnh báo/trung tính còn rải rác vào một theme extension trước khi mở rộng thêm trạng thái. Kiểm tra tương phản và theme tối trên từng màn hình dữ liệu.
4. **Tăng tính rõ ràng khi thao tác dữ liệu:** hiển thị trạng thái tải, rỗng và lỗi với nút thử lại nhất quán; các thao tác hủy lượt quét hoặc chốt lương cần nội dung xác nhận rõ hậu quả.
5. **Kiểm tra thiết bị thật:** thử ngoài sáng tại kiosk, bàn phím mở trên điện thoại nhỏ, font hệ thống lớn và phản hồi sau quét NFC/khuôn mặt. Widget test không xác nhận được camera và NFC thực tế.

Tài liệu tham khảo: [Material 3](https://m3.material.io/), [Material Design trong Flutter](https://docs.flutter.dev/ui/design/material).
