# Test API bằng Swagger

Swagger mô tả toàn bộ endpoint đang đăng ký trong backend, gồm đăng nhập, hồ sơ
nhân viên, nhập Excel, NFC, thiết bị kiosk, khuôn mặt, báo cáo và chốt lương.

Đã đối chiếu mã Flutter, các route backend và tài liệu sinh ra: **41 endpoint**.
Các trường JSON dùng **snake_case** đúng với API thực tế, bao gồm cả schema DTO
và response (`full_name`, `employee_id`, `proposed_at`, `content_base64`...).

| Nhóm chức năng | Số endpoint |
| --- | ---: |
| Health | 1 |
| Đăng nhập, thông tin phiên, đổi mật khẩu, đăng xuất | 4 |
| CRUD nhân viên, gồm xóa và dữ liệu liên quan | 5 |
| Gán/xem/khóa thẻ NFC | 3 |
| Lịch sử công, tổng hợp ngày, thêm/hủy lượt thủ công | 4 |
| Ticket, bằng chứng, hủy và duyệt/từ chối | 5 |
| Thiết bị Kiosk và quét NFC/đồng bộ offline | 2 |
| Danh sách tài khoản và mẫu khuôn mặt | 2 |
| Báo cáo, kỳ lương, chi tiết, chốt và xuất Excel | 5 |
| Nhập Excel, email cấp tài khoản, thử lại và tải tài khoản | 9 |
| Nghiệp vụ tài khoản/khuôn mặt/email theo action | 1 |

`POST /api/business` là một endpoint với **6 giá trị action**, có **9 mẫu request**
do `begin_face_camera` tách riêng enroll, reenroll, check_in và check_out.

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

Chọn đúng Example rồi nhập ID thực tế. `save_account` trả `{ "id": "..." }`;
đọc thông tin tài khoản từ `GET /api/accounts`. Các phản hồi của business và NFC
có mẫu riêng trong Responses; đặc biệt NFC có `ok`, `duplicate`, `ignored` hoặc
`rejected`, không phải mọi HTTP 200 đều là một lượt công mới.

## Ticket sửa công và bằng chứng

- `POST /api/attendance/tickets`: chọn Example `missing_in`, `missing_out` hoặc
  `incorrect_time`. Nhân viên/Quản lý tạo cho hồ sơ của chính mình; Admin xử lý
  yêu cầu thay vì tạo thay nhân viên. Giờ đề nghị phải ở quá khứ, ngoài kỳ đã chốt.
- Khi sửa giờ đã ghi nhận, thay `original_event_id` bằng lượt còn hiệu lực của
  chính mình. Khi bổ sung lượt thiếu thì để null hoặc bỏ qua trường này.
- `attachments` không bắt buộc; tối đa 3 ảnh JPG/PNG hoặc PDF, tối đa 2 MB/tệp,
  tổng 5 MB. Mỗi phần tử có `file_name`, `content_base64` thuần. Example có ảnh
  PNG 1 pixel hợp lệ để thử đường truyền; thay bằng bằng chứng thực khi cần.
- `GET /api/attendance/tickets` trả metadata tệp; lấy `attachments[].id` làm
  `fileId` cho `GET /api/attendance/tickets/{id}/attachments/{fileId}`. Tệp chỉ
  đọc được bởi chủ hồ sơ hoặc Admin/Quản lý, không có URL công khai.
- `POST /api/attendance/tickets/{id}/review`: Example `approve` hoặc `reject`.
  Khi từ chối phải có `response`; không tự duyệt yêu cầu của chính mình.
- `POST /api/attendance/tickets/{id}/cancel` không cần request body. Chỉ người
  tạo, đúng hồ sơ và ticket đang chờ mới hủy được.

## Tải Excel và tệp bằng chứng

Các API sau trả JSON, không trả tệp nhị phân trực tiếp:

- `GET /api/payroll/runs/{id}/export`: lấy ID từ danh sách kỳ lương; xuất số liệu
  đã chốt, không tính lại theo hồ sơ/đơn giá hiện tại. Kỳ không có trả 404; kỳ
  không còn chi tiết để xuất trả 409.
- `GET /api/employees/import/template`: file Excel mẫu nhập nhân viên.
- `GET /api/employees/import/{id}/credentials`: file tài khoản của lần nhập,
  chỉ Admin tạo lần nhập và trong 24 giờ.
- `GET /api/attendance/tickets/{id}/attachments/{fileId}`: tệp bằng chứng đúng quyền.

Giải mã `content_base64` và lưu với tên `file_name`. Tệp bằng chứng còn có
`content_type` và `size_bytes`. Có thể dùng PowerShell sau khi Authorize/đăng nhập
và lấy token để tải bảng lương (thay ID và token trên máy của bạn):

```powershell
$headers = @{ Authorization = 'Bearer TOKEN_CUA_BAN' }
$file = Invoke-RestMethod 'http://localhost:5080/api/payroll/runs/ID_KY_LUONG/export' -Headers $headers
[IO.File]::WriteAllBytes((Join-Path $PWD $file.file_name), [Convert]::FromBase64String($file.content_base64))
```

File upload Excel và bằng chứng gửi JSON base64, không dùng multipart. Vector
SFace mới cần đúng 128 phần tử; mảng bằng chứng có giới hạn riêng 3 tệp.

## Mã phản hồi

Swagger bổ sung mô tả 400/401/403/404/409, 413 khi vượt giới hạn request 8 MB,
và 429 khi vượt giới hạn tần suất. Phản hồi 413/429 có thể không có JSON.
`GET /api/employees/{id}` có thể trả 204 khi không có hồ sơ, đúng hành vi null
của Minimal API hiện tại. Các thao tác thành công hiện dùng HTTP 200.

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
Kiểm tra còn quét toàn bộ file C# đăng ký API và lệnh gọi API trong Flutter,
đối chiếu action nghiệp vụ, cách đặt tên snake_case, mẫu ticket/review, giới hạn
bằng chứng, vector SFace và schema phản hồi tải file. Kết quả lần kiểm tra cập
nhật ngày 03/11/2026: **566 kiểm tra API đạt**.
Swagger được sinh từ endpoint thực tế; nếu thêm route mới, bổ sung mô tả trong
`ApiDocumentation.cs` để giữ tài liệu đầy đủ.
