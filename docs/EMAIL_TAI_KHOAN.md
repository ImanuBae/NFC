# Email cấp tài khoản sau khi nhập Excel

Áp dụng cho tài khoản nhân viên **mới tạo từ Excel**:

- Tên đăng nhập: email trong danh sách.
- Mật khẩu ban đầu: `12345678`, lưu hash trong bảng Accounts.
- Tạo một email riêng cho từng nhân viên mới, cùng transaction tạo tài khoản.
- Nội dung có họ tên, email đăng nhập, mật khẩu ban đầu và hướng dẫn đổi mật khẩu,
  tự đăng ký khuôn mặt bằng camera; thành công là dùng chấm công được ngay.
- Chức vụ trong Excel không tự cấp quyền quản trị.

Danh sách nhập lại cùng mã/email giữ nguyên tài khoản, mật khẩu và email đã xếp
hàng; không tạo thêm thư. Những tài khoản được nhập trước khi có chức năng này
không bị đổi mật khẩu hoặc tự gửi lại thông tin đăng nhập.

## Cấu hình gửi thư thật

Backend dùng **Gmail công ty + mật khẩu ứng dụng Google của Gmail công ty** để
gửi thư qua SMTP. Cả thư cấp tài khoản và báo cáo công dùng chung cấu hình này.
Chỉ cần một Gmail gửi và một mật khẩu ứng dụng; nhân viên nhận thư không cần tạo
mật khẩu ứng dụng. Mật khẩu đăng nhập app chấm công khác với mật khẩu Gmail.

1. Dùng Gmail công ty đã tạo [mật khẩu ứng dụng Google](https://support.google.com/accounts/answer/185833?hl=vi).
   Không cần Resend API key hoặc domain riêng cho luồng Gmail SMTP.
2. Mở file `.local-data/email-settings.json` và điền:

   ```json
   {
     "Email": {
       "Provider": "Gmail",
       "From": "Cham cong <company@gmail.com>",
       "Smtp": {
         "Host": "smtp.gmail.com",
         "Port": 587,
         "Username": "company@gmail.com",
         "AppPassword": "MAT_KHAU_UNG_DUNG_GOOGLE"
       }
     }
   }
   ```

   File mẫu cấu trúc là `email-settings.example.json`. `.local-data` được bỏ qua
   khi commit Git. Thay Gmail mẫu bằng đúng Gmail đã tạo mật khẩu ứng dụng; địa
   chỉ trong From phải khớp Username. Backend tự bỏ khoảng trắng trình bày trong
   mật khẩu ứng dụng. Không đưa mật khẩu ứng dụng vào Flutter, Excel hoặc Git.
   Kết nối Gmail dùng STARTTLS trên cổng 587 (hoặc TLS trực tiếp nếu dùng cổng 465).
3. Khởi chạy bản backend mới:

   ```powershell
   dotnet run --project server/Attendance.Api --no-launch-profile --urls http://localhost:5080
   ```

   Backend đọc file cấu hình email cục bộ và theo dõi thay đổi của file. Biến môi
   trường `Email__Provider`, `Email__From`, `Email__Smtp__Username`,
   `Email__Smtp__AppPassword` có ưu tiên cao hơn file nếu đã đặt.
4. Trang **Nhập Excel** báo có/chưa có cấu hình gửi thư. Trạng thái này kiểm tra
   thông tin cấu hình. Bấm **Kiểm tra kết nối Gmail** để kiểm tra kết nối TLS và
   đăng nhập SMTP; thao tác này không gửi thư thử. Sai Gmail hoặc mật khẩu ứng
   dụng sẽ được báo rõ, không hiển thị giá trị mật khẩu.
5. Sau khi nhập, xem **Email cấp tài khoản → Chi tiết từng email**. Với lần nhập
   cũ, bấm biểu tượng email trong **Các lần nhập của tôi trong 24 giờ**.

Nếu chưa cấu hình, tài khoản vẫn được tạo và thư ở hàng đợi; không báo gửi thành
công giả. Khi cấu hình hợp lệ, backend tự xử lý thư đang chờ, kể cả sau khi khởi
động lại. Hàng đợi không phụ thuộc việc Admin còn mở trang nhập hay không.

## Trạng thái và thử lại

| Trạng thái | Ý nghĩa |
| --- | --- |
| Đang chờ gửi / Chờ cấu hình email | Đã xếp hàng trong SQL Server |
| Đang gửi | Worker đã nhận xử lý thư |
| Dịch vụ đã nhận thư | SMTP đã chấp nhận thư; chưa xác nhận thư đã vào Inbox |
| Gửi lỗi | Dịch vụ từ chối hoặc lỗi kết nối; xem nguyên nhân trên dashboard |
| Đã ngừng gửi | Tài khoản bị khóa, thay đổi, xóa hoặc nhân viên đã đổi mật khẩu |
| Cần Admin xử lý | Quá thời hạn thử gửi; cần đối soát hoặc đặt lại mật khẩu |
| Cần kiểm tra thư mục Đã gửi | Mất kết nối khi gửi hoặc phiên gửi SMTP bị gián đoạn; chưa xác định thư đã được nhận hay chưa |

Worker tự thử tối đa 5 lần với thời gian chờ tăng dần; Admin có thể bấm **Thử gửi
lại email lỗi** khi đã sửa cấu hình. Chỉ thử lại tự động khi biết kết nối/xác thực
chưa thành công hoặc SMTP trả lời từ chối thư. Thư có Message-Id ổn định để hỗ trợ
đối soát, nhưng SMTP không có bảo đảm idempotency như HTTP API.

Nếu mất kết nối trong lúc gửi hoặc backend dừng khi chưa kịp lưu kết quả, thư
chuyển sang trạng thái cần kiểm tra, **không tự gửi lại**. Admin kiểm tra thư mục
**Đã gửi** của Gmail công ty trước khi xử lý tiếp. Không thử lại thư đã được tiếp
nhận. Lỗi gửi thư không hoàn tác tài khoản đã tạo.

Email có thể vào Spam. Hệ thống hiện chưa nhận webhook để xác nhận thư được giao,
bị trả lại hoặc được mở. Cần kiểm tra Gmail gửi nếu trạng thái tiếp nhận thành công
nhưng nhân viên chưa thấy thư.

## Nhân viên đổi mật khẩu và đăng ký khuôn mặt

Sau khi đăng nhập, nhân viên thấy lời nhắc đổi mật khẩu. Bấm **Đổi mật khẩu** trên
thanh công cụ hoặc trong lời nhắc, nhập mật khẩu hiện tại, mật khẩu mới và xác nhận.
Mật khẩu mới dài 8–128 ký tự, khác mật khẩu hiện tại và `12345678`.

Đổi mật khẩu giữ phiên hiện tại, đăng xuất các phiên khác và ngừng thư chờ chứa
mật khẩu ban đầu. Tiếp theo dùng **Đăng ký khuôn mặt** trong app nhân viên; mẫu
tự kích hoạt sau khi đăng ký thành công, không cần Admin duyệt. Không tự tạo mẫu mặt từ dữ liệu Excel.

## Kiểm thử không gửi mail thật

```powershell
dotnet build server/Attendance.Tests -o .local-data/attendance-checks -p:UseAppHost=false
powershell -ExecutionPolicy Bypass -File server/test-api.ps1 -ApiDll "$PWD/.local-data/attendance-checks/Attendance.Api.dll"
powershell -ExecutionPolicy Bypass -File server/test-api.ps1 -ApiDll "$PWD/.local-data/attendance-checks/Attendance.Api.dll" -WithEmail
powershell -ExecutionPolicy Bypass -File server/test-api.ps1 -ApiDll "$PWD/.local-data/attendance-checks/Attendance.Api.dll" -WithSmtp
```

Lượt đầu kiểm tra trạng thái thiếu cấu hình. `-WithEmail` khởi chạy máy chủ email
HTTP giả lập ở localhost để kiểm tra tùy chọn Resend cũ. `-WithSmtp` khởi chạy
SMTP giả lập để kiểm tra xác thực, thư cấp tài khoản, gửi báo cáo, thử lại lỗi và
xử lý mất kết nối sau khi SMTP nhận thư. Các lượt đều dùng database riêng và
thông tin đăng nhập giả, không gửi đến email thật.

## Tùy chọn Resend cũ

Code vẫn hỗ trợ cấu hình `Email:Provider=Resend` cùng `ResendApiKey` và `From`
cho cài đặt đã dùng Resend. Gmail SMTP là luồng mặc định của project hiện tại.
Không đổi phương thức gửi cho một thư đang xử lý mà chưa kiểm tra kết quả cũ;
hệ thống sẽ yêu cầu đối soát thay vì tự chuyển và có thể gửi trùng.
