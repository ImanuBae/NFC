# Nhập nhân viên và tài khoản bằng Excel

Admin có thể tải danh sách của một phòng ban hoặc cả công ty để tạo hồ sơ và tài
khoản cùng lúc. Nhân viên đăng nhập bằng email trong danh sách và tự đăng ký mẫu
khuôn mặt; mẫu tự kích hoạt sau khi đăng ký thành công, không cần Admin duyệt.

## Cách dùng

1. Đăng nhập Admin, bấm **Nhập Excel** (hoặc biểu tượng tải file trên màn hình nhỏ) trên thanh công cụ
   dashboard, hoặc mở **Nhân viên → Nhập nhân viên từ Excel**.
2. Bấm **Tải file mẫu** hoặc dùng danh sách đang có. Có thể dùng
   [file mẫu trống](templates/nhan_vien_mau.xlsx) và
   [file ví dụ 4 nhân viên](templates/nhan_vien_vi_du.xlsx).
   File ví dụ chỉ chứa dữ liệu minh họa, không tự được đưa vào database.
3. Nếu nhập cho một phòng ban, có thể nhập **Phòng ban chung**. Giá trị này chỉ
   điền vào các dòng chưa có phòng ban trong Excel.
4. Chọn file `.xls` hoặc `.xlsx`, xem bảng kiểm tra. Mỗi dòng hiển thị sheet/dòng
   gốc, thông tin nhân viên, trạng thái và lỗi/cảnh báo. Có thể rê chuột hoặc giữ
   vào phần kiểm tra để đọc thông báo dài. Sửa lỗi trong Excel rồi chọn lại file.
5. Bấm nút tạo nhân viên/gán thẻ theo số lượng đã xem trước. Chọn file và xem trước chưa ghi dữ liệu.
6. Sau khi thành công, hệ thống xếp hàng gửi email riêng cho từng nhân viên mới:
   tên đăng nhập là email, mật khẩu ban đầu là `12345678`, kèm hướng dẫn đổi mật
   khẩu và đăng ký khuôn mặt. Xem trạng thái từng thư ngay trên màn hình nhập.
   Có thể bấm **Tải tài khoản nhân viên (.xlsx)** để lấy bản hỗ trợ bàn giao.
   Nếu rời trang hoặc mất phản hồi, có thể tải lại trong **Các lần nhập của tôi
   trong 24 giờ** bằng đúng tài khoản Admin đã nhập.

## Các cột

| Cột | Bắt buộc | Quy tắc |
| --- | --- | --- |
| Mã NV | Có | Tối đa 50 ký tự; bỏ khoảng trắng đầu/cuối và chuyển thành chữ hoa |
| Họ và tên | Có | Tối đa 200 ký tự; giữ tiếng Việt |
| Email | Có | Email hợp lệ, dùng để đăng nhập; chuyển chữ thường |
| Phòng ban | Không | Tối đa 200 ký tự; có thể dùng phòng ban chung khi tải file |
| Chức vụ | Không | Tối đa 200 ký tự; lưu mô tả công việc, tài khoản nhập luôn có quyền nhân viên |
| Số điện thoại | Không | Nên dùng ô Text để giữ số 0 đầu; hỗ trợ ô số định dạng `0000000000` |
| Ngày vào làm | Không | Ô ngày Excel, `dd/MM/yyyy`, `d/M/yyyy` hoặc `yyyy-MM-dd` |
| Đơn giá giờ | Không | Ô số không âm; để trống là 0, chưa có lương giờ. Nếu dùng ô chữ thì chỉ nhập chữ số, ví dụ `60000` |
| uid_the | Không | UID NFC dạng **Text**, hexadecimal đầy đủ. Ví dụ `0400AA01`; để trống thì không gán thẻ |
| STT | Không | Không lưu; không ảnh hưởng mã nhân viên |

Nhận diện cả tiêu đề tiếng Việt có dấu/không dấu và các tên tương ứng như
`Employee Code`, `Full Name`, `Email`, `Department`, `Job Title`, `Phone`,
`Hire Date`, `Hourly Rate`. Tiêu đề có thể xuống dòng như hình minh họa.
Hàng tiêu đề cần nằm trong 30 dòng đầu mỗi sheet. File có nhiều sheet được đọc
chung; sheet không có đủ tiêu đề bắt buộc không được nhập.

Mỗi lần tối đa **5 MB, 1.000 nhân viên**. Không đọc file đặt mật khẩu. Cần tách
danh sách lớn hơn thành nhiều file.

## Xử lý dữ liệu đã có và lỗi

- Trùng mã NV hoặc email giữa các dòng trong file: báo lỗi ở các dòng bị trùng.
- Mã NV và email đã liên kết cùng một tài khoản nhân viên: dùng cặp
  mã/email để đối chiếu đúng người. Các ô có dữ liệu sẽ cập nhật họ tên, phòng ban,
  chức vụ, điện thoại, ngày vào làm, đơn giá giờ và email hồ sơ. Ô tùy chọn trống
  hoặc cột không có giữ nguyên dữ liệu cũ; ô đơn giá `0` là cập nhật về 0.
  Nếu có `uid_the` mới và chưa có thẻ hoạt động, gán thẻ trong cùng lần nhập.
  Giữ mật khẩu, trạng thái tài khoản, mẫu mặt và lịch sử công; không gửi lại email.
- Mã NV/email đã thuộc hồ sơ hoặc tài khoản khác: báo lỗi để Admin đối chiếu;
  không tự gộp người hoặc đổi quyền. Hồ sơ tạo thủ công chưa có tài khoản cần
  được kiểm tra và gán tài khoản qua **Tài khoản & thiết bị**.
- Có bất kỳ dòng lỗi nào: chưa nhập toàn bộ danh sách. Server kiểm tra lại trong
  transaction khi xác nhận, gồm cả trường hợp dữ liệu thay đổi sau bước xem trước.
- Mất kết nối khi xác nhận: bấm lại nút tạo để thử lại cùng lần nhập. Hệ thống giữ
  kết quả để không tạo trùng và không sinh mật khẩu khác cho các tài khoản đã tạo.
- Mật khẩu đăng nhập lưu dưới dạng hash. Bản kết quả phục vụ tải lại được mã hóa,
  chỉ Admin tạo lần nhập được tải trong 24 giờ. Sau đó có thể đặt lại mật khẩu
  bằng công cụ tài khoản hiện có. Email cấp tài khoản cần cấu hình Gmail công ty
  và mật khẩu ứng dụng Google trên backend;
  nếu thiếu cấu hình thì thư chờ trong hàng đợi, chưa được gửi.

Xem [cấu hình email cấp tài khoản và đổi mật khẩu](EMAIL_TAI_KHOAN.md).

## Khởi chạy và kiểm tra

Khởi động lại backend để áp dụng các cột hồ sơ mới và bảng kết quả nhập. Nâng cấp
schema chỉ thêm cột/bảng, giữ dữ liệu hiện có. Hot restart Flutter sau khi thêm
plugin chọn file.

Chạy kiểm tra nghiệp vụ và API theo README. Fixture thực `.xls` và `.xlsx` nằm
trong `server/Attendance.Tests/Fixtures`; kiểm tra API dùng database thử riêng,
không tự nhập file mẫu vào database đang dùng.

## Gán thẻ NFC hàng loạt qua Excel

Đặt cột `uid_the` thành **Text trước khi đọc/nhập UID**. UID được chuyển chữ hoa,
bỏ khoảng trắng, dấu `:` và `-`, giữ số 0 đầu. Chỉ nhận hexadecimal đủ byte
(số ký tự chẵn, 2–64 ký tự). Ô số bị từ chối vì Excel có thể làm mất số 0 hoặc
làm tròn; đổi định dạng sau khi đã mất dữ liệu không khôi phục được UID.

Có thể lấy UID từ danh sách nhà cung cấp hoặc máy đọc hỗ trợ NFC tương thích thẻ.
Nếu máy đọc giả lập bàn phím, cấu hình để xuất **UID hexadecimal theo đúng thứ tự
byte mà app Android đọc**. Không dùng nguyên chuỗi mã thập phân hoặc UID đảo byte;
đối chiếu một thẻ trên app trước khi nhập cả danh sách. Không phải mọi đầu đọc USB
đều hỗ trợ đúng loại thẻ hoặc cùng cách biểu diễn UID.

Mỗi dòng phải khớp đúng thẻ được phát cho nhân viên. Không ghi mật khẩu/email lên
thẻ. File mẫu trống tải từ app có cột mới; file cũ thiếu cột này vẫn dùng được.

- Trùng UID trong cùng file (kể cả khác cách viết): báo lỗi tất cả dòng trùng.
- UID đã thuộc người khác hoặc đã khóa/thu hồi: từ chối, không chuyển chủ/mở khóa.
- Nhân viên cũ đã có thẻ hoạt động: không gán thêm thẻ khác qua Excel; dùng luồng thay thẻ.
- Nhân viên cũ chưa có thẻ: chỉ gán thẻ khi mã NV và email khớp, tài khoản còn hoạt động.
- Tạo nhân viên, tài khoản, thẻ, hàng đợi email và kết quả nhập trong cùng transaction.
  Có lỗi thì không ghi một phần; thử lại cùng lần nhập không tạo thẻ/tài khoản trùng.
- Nhập file/gán thẻ không tạo lượt chấm công. Chạm thẻ tại kiosk sau khi gán mới chấm công.

## Mẫu nhanvien.xlsx và cập nhật hồ sơ đã nhập

Mẫu chuẩn theo file người dùng cung cấp: tên sheet có thể là **Kinh doanh**,
tiêu đề ở dòng 3, thứ tự STT, Mã NV, Họ và tên, Chức vụ, Số điện thoại, Email,
Ngày vào làm, Phòng ban, Đơn giá giờ; thêm cột `uid_the` cuối cùng khi có UID.
Tên sheet chỉ xác định vị trí dữ liệu, không ghi đè cột Phòng ban. Ví dụ ô Phòng
ban là IT thì hồ sơ là IT dù tên sheet là Kinh doanh hay đã nhập phòng ban chung.

Bảng xem trước hiển thị số hồ sơ cập nhật và tên các trường thay đổi. Nhập lại
cùng file đã đồng bộ sẽ bỏ qua, không tạo tài khoản/thẻ trùng. Thay dữ liệu trong
file phải dùng lần nhập mới; thử lại cùng mã lần nhập chỉ trả kết quả cũ.

Màn hình chính của nhân viên hiển thị dữ liệu hồ sơ và UID thẻ lấy từ backend.
Bấm **Tải lại hồ sơ** sau khi Admin cập nhật để xem dữ liệu mới. Đây là hồ sơ
chỉ đọc; nhân viên không tự sửa phòng ban hoặc UID của mình.
