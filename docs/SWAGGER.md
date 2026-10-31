# Test API bằng Swagger

Swagger mô tả toàn bộ endpoint đang đăng ký trong backend, gồm đăng nhập, hồ sơ
nhân viên, nhập Excel, NFC, thiết bị kiosk, khuôn mặt, báo cáo và chốt lương.

## Mở giao diện

- Laptop: <http://localhost:5080/swagger/index.html>.
- Điện thoại thật đang cắm USB: <http://127.0.0.1:5080/swagger/index.html> sau khi
  chạy `adb -s f0909e72 reverse tcp:5080 tcp:5080`.
- Máy ảo Android: <http://10.0.2.2:5080/swagger/index.html>.
- Qua tunnel HTTPS: thêm `/swagger/index.html` vào URL gốc của tunnel đang chạy.
  Không dùng URL localhost trên điện thoại khác hoặc khi đã rút USB.

Tài liệu OpenAPI JSON: `/swagger/v1/swagger.json`. Swagger dùng cùng origin đang
mở để gọi API, không cố định host của laptop. Không cần token để mở tài liệu;
API nghiệp vụ vẫn yêu cầu tài khoản và kiểm tra quyền như khi gọi từ app.

## Đăng nhập và test

1. Mở nhóm **Xác thực**, chọn `POST /api/auth/login`, bấm **Try it out**.
2. Thay email/mật khẩu ví dụ bằng tài khoản của bạn, bấm **Execute**.
3. Sao chép trường `token` trong response.
4. Bấm **Authorize**, chỉ dán token; không thêm chữ `Bearer`. Đây là session
   token của ứng dụng, không phải JWT.
5. Chọn endpoint muốn test. Thay UUID giả bằng ID lấy từ danh sách thực tế.
6. Để test phân quyền, đăng nhập tài khoản có vai trò khác rồi thay token trong
   Authorize. Đăng xuất làm token hiện tại mất hiệu lực.

Nhóm **Nghiệp vụ** (`POST /api/business`) có danh sách **Examples** cho tạo/sửa
tài khoản, kích hoạt/thu hồi mẫu mặt, bắt đầu đăng ký/đăng ký lại/chấm công bằng
camera, hoàn tất camera và gửi báo cáo email. Mỗi mẫu có mô tả quyền và dữ liệu
cần thay. Khi cập nhật tài khoản, thêm `id`; khi tạo tài khoản phải cung cấp mật
khẩu tối thiểu 12 ký tự. Tài khoản employee cần `employee_id`; kiosk không được
liên kết nhân viên.

`finish_face_camera` cần hai vector 128 phần tử từ model SFace trên Android.
Ví dụ để mảng rỗng nhằm chỉ rõ vị trí cần dữ liệu; phải thay bằng dữ liệu camera
hợp lệ. Swagger không chụp camera, không thực hiện chớp mắt/quay đầu thay app.

Nhập Excel gửi JSON với `file_name` và `content_base64`, không dùng multipart.
Lấy file mẫu từ `/api/employees/import/template`, giải mã base64, điền dữ liệu,
rồi gửi file đã mã hóa base64 vào preview trước khi commit. Commit cần UUID
`import_id` mới cho một lần nhập và giữ nguyên UUID khi thử lại cùng file.

Ngày báo cáo tính từ `start` đến trước `end`. Các thao tác ghi công, thu hồi mẫu,
chốt lương và gửi email tác động thật tới database/dịch vụ đang kết nối. Sử dụng
database thử nghiệm nếu cần tạo, sửa, hủy dữ liệu để kiểm tra.

## Chạy kiểm tra tự động

```powershell
dotnet build server/Attendance.Tests -o .local-data/swagger-checks -p:UseAppHost=false
powershell -ExecutionPolicy Bypass -File server/test-api.ps1 -ApiDll "$PWD/.local-data/swagger-checks/Attendance.Api.dll"
```

Script dùng database SQL Server riêng và kiểm tra mỗi route có trong tài liệu,
schema request, mẫu business action, Bearer security và các nghiệp vụ hiện có.
Swagger được sinh từ endpoint thực tế; nếu thêm route mới, bổ sung mô tả trong
`ApiDocumentation.cs` để giữ tài liệu đầy đủ.
