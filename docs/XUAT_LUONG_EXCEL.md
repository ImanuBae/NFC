# Xuất Excel bảng lương đã chốt

1. Vào **Báo cáo & lương**, chọn đúng kỳ đã kết thúc rồi **Chốt lương**.
2. Khi kỳ đã có bản chốt, màn hình hiện **Đã chốt** và nút **Xuất Excel**.
   Với dữ liệu mẫu, chọn tháng 10/2026 để thấy kỳ đã chốt.
3. Hoặc bấm **Lương đã chốt** trên thanh công cụ → biểu tượng tải ở kỳ cần xuất;
   mở chi tiết kỳ cũng có nút **Xuất Excel**.
4. Chọn nơi lưu tệp `.xlsx` trên điện thoại/máy tính; trình duyệt tải tệp theo cơ
   chế tải xuống của trình duyệt. Hủy hộp thoại lưu sẽ không báo xuất thành công.

File gồm mã/tên nhân viên, phút công, giờ công, đơn giá và lương gộp cùng dòng
tổng cộng, kỳ lương và thời điểm chốt. Các cột số là ô số Excel để tính toán;
tên nhân viên luôn là văn bản, kể cả khi bắt đầu bằng ký tự công thức.

Dữ liệu lấy từ `PayrollRuns` và `PayrollItems`, không tính lại theo hồ sơ/đơn giá
hiện tại. Đổi tên hoặc đơn giá nhân viên sau khi chốt không làm thay đổi file kỳ
cũ. Báo cáo dự kiến trên màn hình vẫn dùng dữ liệu hiện tại; bản xuất đã chốt
được phân biệt bằng tiêu đề và tên tệp.

API: GET `/api/payroll/runs/{id}/export`, chỉ Admin/Quản lý; phản hồi có `file_name`
và `content_base64`. Kỳ không tồn tại trả 404; kỳ không còn chi tiết lương để xuất
trả 409. Chức năng xóa nhân viên của bản demo xóa cả chi tiết lương liên quan,
vì vậy nên xuất file trước khi xóa dữ liệu demo.
