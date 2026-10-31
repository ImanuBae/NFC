# Demo điện thoại không cần USB bằng Visual Studio Dev Tunnel

Laptop chạy Admin trên Chrome, backend ASP.NET Core và SQL Server. Điện thoại
chạy kiosk NFC/khuôn mặt hoặc tài khoản nhân viên, gọi cùng backend qua Internet.
USB chỉ dùng để cài app; sau đó các điện thoại có thể dùng Wi-Fi hoặc 4G.

## 1. Chạy API trong Visual Studio

1. Dùng Visual Studio hỗ trợ .NET 10, cài workload ASP.NET/web và .NET 10 SDK.
2. Mở `server/Attendance.Api/Attendance.Api.csproj` bằng Visual Studio, không phải
   Android Studio. Chọn profile **Demo Tunnel**.
3. Nếu API đã chạy ở cổng 5080 trong terminal/script, dừng đúng tiến trình API đó
   trước khi chạy profile để tránh lỗi trùng cổng. Không cần dừng SQL Server.
4. Chạy API, kiểm tra `http://localhost:5080/health` có
   `{"status":"ok","database":"SQL Server"}`. Swagger ở
   `http://localhost:5080/swagger/index.html`; qua tunnel dùng
   `<URL>/swagger/index.html`. Xem [hướng dẫn test API](SWAGGER.md).

## 2. Tạo Persistent Dev Tunnel

1. Đăng nhập tài khoản Microsoft/GitHub trong Visual Studio.
2. Mở menu cạnh nút Run, chọn **Dev Tunnels → Create a Tunnel**.
   Có thể mở **View → Other Windows → Dev Tunnels** để quản lý.
3. Đặt tên dễ nhớ, chọn **Persistent** và quyền **Public**, rồi tạo tunnel.
4. Chọn tunnel làm active và chạy lại profile **Demo Tunnel** nếu cần.
5. Sao chép URL HTTPS trỏ tới cổng API (không lấy URL inspect, không thêm `/api`).
   Tên miền thường có dạng `https://<id>-5080.<region>.devtunnels.ms`;
   luôn dùng URL thực tế Visual Studio cung cấp.
6. Trên điện thoại dùng 4G, mở `<URL>/health`. Nếu trình duyệt hiện trang xác nhận
   của Dev Tunnels, chọn tiếp tục. Kết quả phải là JSON nêu trên, không phải
   trang đăng nhập Microsoft. Nếu bị yêu cầu đăng nhập, kiểm tra quyền Public.

Persistent giữ URL qua các lần mở Visual Studio; API và tunnel vẫn phải chạy
thì điện thoại mới kết nối được. Quyền Public của tunnel không thay thế đăng nhập
trong app. Không chia sẻ mật khẩu hoặc session token.

## 3. Cài app một lần và nhập URL trên từng điện thoại

Build APK từ thư mục project:

```powershell
flutter build apk --release --dart-define-from-file=config.local.json
```

APK ở `build/app/outputs/flutter-apk/app-release.apk`. Cài qua USB bằng ADB
hoặc chuyển APK tới từng điện thoại để cài thủ công:

```powershell
& "$env:LOCALAPPDATA/Android/sdk/platform-tools/adb.exe" devices
& "$env:LOCALAPPDATA/Android/sdk/platform-tools/adb.exe" -s f0909e72 install -r build/app/outputs/flutter-apk/app-release.apk
```

1. Mở app → màn hình đăng nhập → **Máy chủ**.
2. Nhập URL HTTPS gốc của API → **Kiểm tra và sử dụng**.
3. App kiểm tra `/health` và SQL Server trước khi dùng URL, lưu địa chỉ trên
   điện thoại để giữ qua lần mở sau. URL đã lưu được ưu tiên hơn dart-define.
4. Đăng nhập lại. Kiosk đăng nhập tài khoản kiosk; dashboard dùng tài khoản
   nhân viên. Khi đổi từ URL USB sang URL tunnel, kiosk có thể cần kích hoạt
   thiết bị lại vì đăng ký/session được phân theo địa chỉ máy chủ.
5. Rút USB, tắt Wi-Fi trên điện thoại và dùng 4G để thử đăng nhập, tải lịch sử,
   quẹt NFC hoặc quét mặt. NFC cần điện thoại có NFC và thẻ đã được gán;
   khuôn mặt cần mẫu nhân viên đã đăng ký thành công.
6. Mở lại app để xác nhận địa chỉ vẫn được lưu.

Nếu URL thay đổi, nhập lại ở **Máy chủ**, không cần build/cài lại APK. Muốn đổi
máy chủ khi đã đăng nhập, đăng xuất trước; kiosk yêu cầu PIN để thoát.
HTTP từ xa bị từ chối; không cần mở quyền cleartext cho domain tunnel vì dùng HTTPS.

## 4. Màn hình Admin và kịch bản kiểm tra

Admin trên chính laptop có thể tiếp tục gọi API qua localhost:

```powershell
flutter run -d chrome --dart-define-from-file=config.local.json
```

Nếu trước đó đã lưu URL khác trong app web, chọn **Máy chủ** ở màn hình đăng nhập
và nhập `http://127.0.0.1:5080`. App web và điện thoại vẫn dùng chung SQL Server.
Không cần công khai trang Admin qua tunnel để trình chiếu.

Trình tự kiểm tra: Admin xem nhân viên/thẻ/mẫu đã đăng ký → kiosk NFC ghi nhận
→ kiosk khuôn mặt ghi nhận → nhân viên tải lại lịch sử → Admin đối chiếu kết quả.
Không chấm cùng nhân viên liên tiếp trong 60 giây vì có chống quét liên tiếp.
Kiểm tra các chức năng thực tế trong README trước khi đưa vào kịch bản báo cáo;
tunnel không bổ sung ticket sửa công hay các mục dashboard chưa triển khai.

Trong buổi demo: cắm sạc laptop, tắt sleep, giữ Internet, SQL Server, API và tunnel
hoạt động. Đặt mạng nội bộ/USB làm phương án dự phòng nếu Internet trục trặc.
Các thiết bị khác chỉ cần Internet và URL API, không cần cài Visual Studio.

## Xử lý lỗi

| Hiện tượng | Kiểm tra |
| --- | --- |
| Visual Studio báo address already in use | API khác đang giữ cổng 5080; dừng đúng phiên cũ |
| `/health` yêu cầu Microsoft login | Tunnel chưa Public hoặc đang dùng nhầm URL |
| `/health` báo database unavailable | SQL Server trên laptop chưa sẵn sàng |
| App báo JSON không hợp lệ | Nhập URL API gốc, không dùng URL inspect/trang web |
| Rút USB thì lỗi kết nối | App còn dùng localhost; vào Máy chủ nhập URL tunnel |
| Mất kết nối khi khóa laptop | Kiểm tra sleep, Internet và phiên backend/tunnel |

Hướng dẫn Microsoft:
https://learn.microsoft.com/aspnet/core/test/dev-tunnels?view=aspnetcore-10.0

Lưu ý kiểm chứng: phần app/profile được chuẩn bị trong mã nguồn. Chỉ có thể xác
nhận demo không dây sau khi tạo tunnel bằng tài khoản của bạn và thử trên điện
thoại qua 4G; kiểm thử cục bộ không chứng minh được đường truyền tunnel thực tế.
