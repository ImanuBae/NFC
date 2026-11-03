# Ticket sửa công

Nhân viên mở **Lịch sử → Tạo ticket sửa công** để đề nghị bổ sung giờ vào/ra,
kể cả khi chưa có lượt chấm công. Chọn ngày giờ đề nghị và nhập lý do.
Để sửa giờ đã ghi nhận, bấm **Yêu cầu sửa giờ** ngay dưới lượt đó.

Trong biểu mẫu, bấm **Đính kèm bằng chứng** để chọn ảnh JPG/PNG hoặc PDF từ
điện thoại/máy tính. Cho phép tối đa 3 tệp, mỗi tệp tối đa 2 MB, tổng tối đa
5 MB; có thể bỏ tệp đã chọn trước khi gửi. Đính kèm không bắt buộc.
Bằng chứng được lưu cùng ticket trong SQL Server, không có đường dẫn công khai.
Chủ ticket và Admin/Quản lý có thể xem trước ảnh hoặc tải tệp; PDF tải về để mở.
Admin xem được bằng chứng cả ở danh sách lẫn hộp thoại xử lý ticket.

**Ticket của tôi** hiển thị trạng thái và phản hồi của quản lý. Nhân viên có thể
hủy yêu cầu đang chờ. Nếu bị từ chối, xem phản hồi và gửi ticket mới khi cần.
Gửi ticket chưa thay đổi bảng công.

Admin/Quản lý bấm biểu tượng ticket trên thanh công cụ dashboard để mở
**Duyệt ticket sửa công**, xem giờ gốc, giờ đề nghị và lý do, rồi duyệt hoặc
từ chối. Khi từ chối phải nhập phản hồi. Không tự duyệt ticket của mình.
Khi duyệt, server bổ sung lượt thiếu hoặc đánh dấu hủy lượt sai và tạo lượt thay thế;
giữ lượt gốc và audit, không duyệt lặp hoặc sửa kỳ lương đã chốt. Nhân viên xem
kết quả ở Ticket của tôi (bấm Tải lại hoặc kéo xuống để làm mới).

Khởi động lại backend để tự thêm bảng `AttendanceTickets` và `TicketEvidence`, sau đó chạy lại/cài
APK mới. API gồm GET/POST `/api/attendance/tickets` và POST
`/api/attendance/tickets/{id}/cancel`, `/api/attendance/tickets/{id}/review`.
GET `/api/attendance/tickets/{id}/attachments/{fileId}` trả tệp sau khi kiểm tra
quyền. Xóa nhân viên sẽ xóa ticket và toàn bộ bằng chứng liên quan; hủy ticket
giữ bằng chứng để đối chiếu lịch sử.

Phạm vi hiện tại gồm Chờ xử lý, Đã duyệt, Từ chối, Đã hủy. Các bước Cần bổ sung,
gửi lại cùng ticket và quy trình điều chỉnh sau chốt trong thiết kế
đích chưa được triển khai.
