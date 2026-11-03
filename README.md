# NFC Attendance — Flutter + ASP.NET Core + SQL Server

Admin/Quản lý có thể [xuất Excel bảng lương đã chốt](docs/XUAT_LUONG_EXCEL.md)
ngay trong **Báo cáo & lương** hoặc danh sách **Lương đã chốt**.

Ứng dụng dùng **SQL Server**, quản lý database bằng **SSMS**. Flutter gọi ASP.NET Core
REST API; không kết nối SQL trực tiếp, không cần Firebase hoặc dịch vụ database cloud.
Hai phương thức chấm công là **NFC và khuôn mặt bằng camera**. Vân tay đã được bỏ.

Swagger: **http://localhost:5080/swagger/index.html**. Có đầy đủ endpoint,
request mẫu và Authorize bằng session token. Xem [hướng dẫn test API](docs/SWAGGER.md)
để mở từ điện thoại/máy ảo và test theo từng vai trò.

Nhân viên có thể tạo và theo dõi ticket sửa công từ **Lịch sử chấm công**;
Admin/Quản lý duyệt hoặc từ chối từ biểu tượng ticket trên dashboard.
Xem [hướng dẫn ticket sửa công](docs/TICKET_SUA_CONG.md).

Thiết kế nghiệp vụ đã thống nhất: [Ba giao diện, ticket sửa công và bảng công chung](docs/THIET_KE_NGHIEP_VU.md).

Admin có thể **nhập danh sách Excel `.xls`/`.xlsx` để tạo hàng loạt hồ sơ và tài
khoản nhân viên**, xem trước lỗi/trùng và tải tài khoản sau khi tạo. Xem
[hướng dẫn và file mẫu](docs/NHAP_NHAN_VIEN_EXCEL.md).

Dashboard quản lý hiển thị lượt mới, trạng thái trong ca, từng khoảng vào–ra,
giờ còn thiếu và mốc dự kiến đủ công. Cách tính trừ giờ nghỉ và phạm vi đã triển khai
được ghi tại mục 8 của tài liệu nghiệp vụ. Giờ nghỉ mặc định 12:00–13:00 là giả định
có thể thay đổi trong `AttendancePolicy` của server.

Kiểm tra nghiệp vụ tính công độc lập và API với database thử nghiệm riêng:

```powershell
dotnet build server/Attendance.Tests -o .local-data/attendance-checks -p:UseAppHost=false
dotnet .local-data/attendance-checks/Attendance.Tests.dll
powershell -ExecutionPolicy Bypass -File server/test-api.ps1 -ApiDll "$PWD/.local-data/attendance-checks/Attendance.Api.dll"
flutter analyze
flutter test
```

## Chạy trên máy hiện tại

1. Mở SQL Server/SSMS: server **localhost**, Windows Authentication, database **NfcAttendance**.
2. Terminal thứ nhất, tại thư mục project:

   ```powershell
   dotnet run --project server/Attendance.Api --no-launch-profile --urls http://127.0.0.1:5080
   ```

3. Terminal thứ hai:

   ```powershell
   flutter pub get
   flutter run -d chrome --dart-define-from-file=config.local.json
   ```

`config.local.json` dùng `API_BASE_URL=http://127.0.0.1:5080`. Không cần API key phía app.
Mẫu cấu hình ở `config.example.json`.

## Tài khoản sau khi chuyển database

Thông tin đăng nhập mới nằm trong **`.local-data/account-credentials.json`** trên máy bạn.
Riêng tài khoản tạo bằng nhập Excel: lấy mật khẩu khởi tạo từ file tải về trong
màn hình nhập; các tài khoản này không được ghi vào file credentials cục bộ trên.
Tài khoản bootstrap có mật khẩu ngẫu nhiên riêng; tài khoản nhập Excel mới dùng
`12345678` theo luồng cấp tài khoản. Mật khẩu đăng nhập lưu hash PBKDF2 của ASP.NET Identity.
Không thể chuyển trực tiếp mật khẩu từ hệ xác thực cũ. Admin có thể đổi lại mật khẩu tài khoản
trong **Tài khoản & thiết bị**. Không gửi file mật khẩu lên Git hoặc nộp kèm project.

Tài khoản Kiosk chỉ đại diện cho máy quét, **không có EmployeeId và không sở hữu mẫu khuôn mặt**.
API từ chối việc gán tài khoản Kiosk vào một hồ sơ nhân viên. Thẻ vẫn thuộc hồ sơ nhân viên;
gỡ liên kết của Kiosk không xóa thẻ và lịch sử của nhân viên.

## Demo bằng Android Studio / máy ảo

Để demo các điện thoại **không cần USB**, xem
[hướng dẫn Visual Studio Persistent Dev Tunnel](docs/DEMO_DEV_TUNNEL.md).
App có mục **Máy chủ** ở màn hình đăng nhập để kiểm tra và lưu URL HTTPS,
không cần build lại khi đổi URL. Địa chỉ đã lưu ưu tiên hơn `API_BASE_URL` lúc build.

Mở máy ảo trong Device Manager, rồi chạy tại thư mục project:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-android-demo.ps1
```

Script kiểm tra backend và SQL Server, tự khởi động backend nếu chưa chạy, rồi chạy
Flutter với `API_BASE_URL=http://10.0.2.2:5080`. Nếu mã máy ảo khác, thêm
`-Device emulator-5556` theo kết quả `flutter devices`. Backend do script khởi động
tiếp tục chạy sau khi thoát Flutter; log nằm trong `.local-data/demo-api.*.log`.

Nếu dùng nút Run/Debug của Android Studio, chọn cấu hình **Android Emulator**
(lưu trong `.run/Android Emulator.run.xml`) và chọn máy ảo. Backend phải đang chạy
theo bước 2 ở trên, hoặc đã được script khởi động. Nếu cấu hình chưa xuất hiện,
mở lại project; có thể thêm vào **Run → Edit Configurations → Additional run args**:

```text
--dart-define-from-file=config.local.json --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

`10.0.2.2` là địa chỉ máy tính chủ trong Android Emulator, không cần `adb reverse`
và không mất chuyển tiếp cổng khi khởi động lại máy ảo. `127.0.0.1` trong máy ảo
là chính máy ảo. Cấu hình này chỉ dùng cho Android Emulator, không dùng cho điện thoại thật.
Sau khi đổi địa chỉ, Stop rồi Run lại hoàn toàn; hot reload không cập nhật dart-define.
Backend và SQL Server vẫn phải hoạt động mỗi lần demo.

## Chạy Android thật qua USB

Với OnePlus đang dùng, mở USB debugging, kết nối USB và chạy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-android-demo.ps1 -Device f0909e72
```

Script tự phân biệt máy ảo/điện thoại thật: máy ảo dùng `10.0.2.2`, điện thoại
dùng `127.0.0.1` qua `adb reverse` được thiết lập tự động trước khi chạy Flutter.
Chạy lại script sau khi rút/cắm USB. Không dùng cấu hình **Android Emulator**
cho OnePlus. Nếu chạy bằng nút Run, chọn **OnePlus USB** và thực hiện chuyển tiếp
cổng bằng lệnh bên dưới trước mỗi lần kết nối USB mới.

API phải chạy ở terminal thứ nhất. Trong terminal có `adb`:

```powershell
adb devices
adb -s f0909e72 reverse tcp:5080 tcp:5080
flutter run -d f0909e72 --dart-define-from-file=config.local.json
```

`adb reverse` cho phép app dùng địa chỉ `127.0.0.1:5080` qua USB.
Chạy lại lệnh này sau khi kết nối lại điện thoại hoặc khởi động lại ADB.
Nếu không có lệnh `adb`, dùng đường dẫn Android SDK `platform-tools/adb.exe`.
Chỉ bản **debug** cho phép HTTP tới localhost/10.0.2.2; triển khai thật cần HTTPS.

Nếu máy ảo báo **Android App Compatibility / 16 KB**, hãy dừng phiên Flutter cũ và
chạy lại đầy đủ để Gradle lấy ONNX Runtime **1.23.2**; hot reload không cập nhật thư viện native.
Bản cũ 1.20.0 có JNI chưa căn chỉnh 16 KB. Có thể kiểm tra bản APK bằng:

```powershell
python scripts/check_android_alignment.py build/app/outputs/flutter-apk/app-debug.apk
```

Script kiểm tra ELF của các ABI 64-bit; kiểm tra đóng gói APK bằng công cụ Android SDK:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\build-tools\36.0.0\zipalign.exe" -c -P 16 -v 4 build/app/outputs/flutter-apk/app-debug.apk
```

## SSMS và dữ liệu

- Database: `NfcAttendance`. Bảng: `Employees`, `Accounts`, `Cards`, `Devices`, `Events`,
  `Faces`, `Challenges`, `PayrollRuns`, `PayrollItems`, `EmailJobs`, `Sessions`, `Audits`.
- Script tạo bảng được sinh tại `server/sql/001_schema.sql` khi API khởi động.
- Khởi tạo database trống: API tự tạo schema và tài khoản Admin/Kiosk khi chạy lần đầu.
- Dữ liệu cũ đã được sao lưu cục bộ và nhập một lần, giữ ID và lịch sử công. Import không
  chạy lại khi database đã có tài khoản. Không dùng thao tác reset/drop trên database thật.
- Mẫu khuôn mặt không được trả về API cho nhân viên hoặc màn hình Admin; chỉ trả trạng thái.
- Thời gian công lưu dạng `datetimeoffset`, tổng hợp theo giờ Việt Nam (UTC+7).

## Cập nhật dữ liệu chấm công

Màn hình Admin **Bảng công ngày** và **Lịch sử lượt quét** tự tải lại dữ liệu sau
mỗi 2 giây kể từ khi yêu cầu trước hoàn tất, giữ nguyên bộ lọc và dừng khi rời trang.
Lượt NFC/khuôn mặt mới không cần reload thủ công; thời gian hiển thị còn phụ thuộc
tốc độ mạng. Khi cập nhật mã Flutter web đang chạy, hot restart một lần để nạp bản mới.

Khi đang mở **Tổng quan chấm công**, lượt mới xuất hiện sau lần tải đầu sẽ hiện
thẻ thông báo nhỏ ở **góc trên bên phải**, gồm mã/tên nhân viên, phương thức
NFC/khuôn mặt, giờ và loại lượt vào/ra. Hiển thị tối đa 3 thông báo cùng lúc;
mỗi thông báo tự đóng sau 8 giây hoặc có thể đóng bằng nút ×. Dữ liệu cũ ở lần
mở trang đầu tiên và khi đổi ngày không được thông báo lại. Thông báo theo ngày
đang chọn; khi demo cần chọn hôm nay và để trang tải xong trước khi quét.
Đây là cơ chế tải định kỳ, không phải kết nối đẩy tức thời; các thao tác chỉ xem
lịch sử hoặc bảng lương trên điện thoại không tạo thông báo chấm công.

## Camera

Kiosk có hai mục **Thẻ NFC** và **Khuôn mặt**. Máy Android không có NFC (như máy ảo)
tự mở mục Khuôn mặt. Đăng nhập `kiosk@attendance.local`, kích hoạt thiết bị nếu chưa
có, rồi chọn **Vào làm bằng khuôn mặt** hoặc **Ra về bằng khuôn mặt**.
Kiosk so khớp với các mẫu nhân viên hoạt động đã đăng ký thành công, không cần
đăng nhập cá nhân và không lưu mẫu khuôn mặt cho chính tài khoản Kiosk.

Để có mẫu thử: nhân viên đăng nhập trên Android, vào **Đăng ký khuôn mặt**, đồng ý
và làm theo camera; mẫu tự kích hoạt ngay, không cần Admin duyệt.
Sau đó đăng nhập lại tài khoản Kiosk để chấm công. App nhân viên không có nút vào/ra;
đăng ký mẫu chỉ là thiết lập danh tính. Có thể dùng mẫu đã đăng ký từ trước nếu chưa bị thu hồi.
Máy ảo dùng ảnh camera mô phỏng không thay thế việc kiểm tra nhận diện với người thật.

Lượt NFC và khuôn mặt cùng lưu trong `Events`, cùng được tính công/lương;
lượt khuôn mặt tại kiosk ghi kèm `DeviceId`. Không tách báo cáo theo phương thức.
Khuôn mặt chưa rõ hoặc gần giống nhiều nhân viên sẽ bị từ chối, đề nghị dùng NFC.

Đăng ký mẫu trong app nhân viên yêu cầu chớp mắt/quay đầu, mẫu tự kích hoạt khi đăng ký thành công. Chấm công tại kiosk chỉ cần nhìn thẳng và giữ yên, không yêu cầu cử chỉ;
app tự lấy hai mẫu liên tiếp, kiểm tra nhất quán rồi gửi đối chiếu.
CameraX + ML Kit phát hiện khuôn mặt; model SFace tạo vector trên Android.
API đối chiếu vector với mẫu đã đăng ký thành công, ngưỡng cosine 0.45 cho cả hai mẫu.
Không tải ảnh/video lên server. Vector vẫn là dữ liệu sinh trắc học cần bảo vệ.
Giấy phép model nằm trong `android/app/src/main/assets/SFACE_LICENSE.txt`.

Kiểm tra chuyển động khi đăng ký chỉ ở mức cơ bản, chưa là PAD được chứng nhận.
Kiosk không kiểm tra cử chỉ khi chấm công nên chưa bảo đảm chống dùng ảnh/video
để chấm hộ; cũng chưa chống ứng dụng bị sửa/giả mạo vector.

## Email

Nhập Excel tự tạo tài khoản với email đăng nhập và mật khẩu ban đầu `12345678`,
xếp hàng gửi email cho từng người cùng hướng dẫn đổi mật khẩu và đăng ký khuôn
mặt. App nhân viên đã có **Đổi mật khẩu**. Xem
[cấu hình email và trạng thái gửi](docs/EMAIL_TAI_KHOAN.md).

Điền Gmail công ty và mật khẩu ứng dụng Google trong `.local-data/email-settings.json`; file này
không đưa lên Git. Khi chưa cấu hình, thư cấp tài khoản sẽ chờ, không báo đã gửi.

Email là dịch vụ riêng, không phụ thuộc nền tảng database cũ. Cấu hình trên API bằng
environment variables hoặc file cục bộ nói trên, không đưa khóa vào Flutter:

```powershell
$env:Email__Provider = 'Gmail'
$env:Email__From = 'Cham cong <company@gmail.com>'
$env:Email__Smtp__Username = 'company@gmail.com'
$env:Email__Smtp__AppPassword = 'GOOGLE_APP_PASSWORD'
```

Khởi động lại API sau khi đổi cấu hình. Thiếu cấu hình sẽ báo rõ chưa có dịch vụ email;
không giả lập thành công. Ngoài thư cấp tài khoản, email báo cáo công/lương vẫn
là số liệu dự kiến, không phải phiếu lương đã phát hành.

## Kiểm tra

```powershell
flutter analyze
flutter test
dotnet build server/Attendance.Api
./server/test-api.ps1
```

Script API tạo database kiểm thử riêng có tên ngẫu nhiên, tự xóa khi xong; không dùng database thật.

## Phạm vi hiện tại

Backend dùng SQL Server; Kiosk không liên kết một nhân viên. Camera kiosk nhận diện
nhiều nhân viên từ các mẫu đã đăng ký; nhân viên chỉ đăng ký mẫu và xem công/lương,
không chấm công cá nhân. API chặn cả yêu cầu chấm công từ app nhân viên cũ.
Schema hiện hữu tự bổ sung cột `Challenges.DeviceId` khi khởi động, không xóa dữ liệu.
Các mục đã thống nhất nhưng **chưa triển khai**: tổng quan/lịch ca, ticket sửa công,
nhập Excel, phát hành phiếu lương riêng và build hai bản Android theo vai trò.
NFC hiện vẫn tự xác định vào/ra theo lượt trước; chế độ vào/ra rõ ràng cho NFC và
chống trùng theo ca còn cần triển khai. Hiện có chống quét liên tiếp theo nhân viên
trong 60 giây và kiểm tra trạng thái vào/ra chung cho NFC/khuôn mặt.

`.migration-backup/` chứa mã backend cũ chỉ để khôi phục/tham khảo. `.local-data/` chứa
backup dữ liệu, mật khẩu và log. Hai thư mục bị loại khỏi Git và **không nộp kèm project**.

Tài liệu nền tảng:
- https://learn.microsoft.com/ef/core/providers/sql-server/
- https://learn.microsoft.com/ef/core/miscellaneous/connection-strings
- https://developer.android.com/develop/ui/views/layout/webapps/access-local-server
