# CÂU HỎI VẤN ĐÁP VÀ TRẢ LỜI PROJECT

## Hệ thống chấm công NFC và khuôn mặt

Ngày biên soạn: 04/11/2026. Nội dung được đối chiếu với mã nguồn hiện tại trong repository; đây là các câu hỏi dự kiến, không phải đề vấn đáp chính thức của giảng viên.

Cách ôn: ưu tiên các câu có ký hiệu ★. Tập trả lời theo ba ý: chức năng làm gì, được xử lý như thế nào, và giới hạn hiện tại. Các đường dẫn mã nguồn giúp tìm phần triển khai khi giảng viên yêu cầu giải thích trực tiếp.

## 1. Tổng quan và kiến trúc

### Câu 1 ★. Em hãy giới thiệu project trong khoảng một phút.

**Trả lời:** Project là hệ thống chấm công bằng thẻ NFC và khuôn mặt, dùng Flutter cho giao diện, ASP.NET Core cho REST API và SQL Server để lưu dữ liệu. Kiosk ghi nhận vào–ra; nhân viên xem công, lương và gửi yêu cầu sửa công; Admin/Quản lý theo dõi, xử lý sai sót và chốt lương. Hai phương thức nhận diện cùng ghi về một bảng sự kiện và dùng chung quy tắc tính công, tránh tính lương riêng cho từng phương thức.

### Câu 2. Project giải quyết vấn đề gì?

**Trả lời:** Hệ thống giảm việc tổng hợp công thủ công, lưu thời điểm vào–ra và giúp đối chiếu khi có sai sót. NFC là phương thức chính, khuôn mặt là phương án bổ sung khi không sử dụng được thẻ. Ticket sửa công tạo quy trình đề nghị và duyệt có lịch sử, thay vì để nhân viên tự sửa giờ làm.

### Câu 3 ★. Kiến trúc tổng thể hoạt động như thế nào?

**Trả lời:** Luồng chính là Flutter → HTTP/JSON → ASP.NET Core API → Entity Framework Core → SQL Server. Flutter hiển thị và gửi thao tác; backend xác thực, phân quyền, kiểm tra nghiệp vụ và ghi dữ liệu. Riêng camera Android có phần Kotlin xử lý hình ảnh và tạo vector khuôn mặt, được Flutter gọi qua MethodChannel.

### Câu 4. Vì sao Flutter không kết nối SQL Server trực tiếp?

**Trả lời:** Kết nối qua backend giúp giữ thông tin truy cập database ở server và tập trung kiểm tra quyền, chấm công, tính lương. Nếu app tự ghi SQL, người dùng có thể bỏ qua kiểm tra trên giao diện. Các client web và Android cũng cần dùng chung một nguồn quy tắc nghiệp vụ.

### Câu 5. Vì sao chọn Flutter và Riverpod?

**Trả lời:** Flutter cho phép dùng chung phần lớn mã giao diện cho Android và web. Riverpod cung cấp repository, API client và các service cho màn hình, đồng thời giúp thay bằng mock trong kiểm thử. Những tính năng phụ thuộc phần cứng vẫn cần xử lý theo nền tảng; không phải mọi chức năng đều chạy được trên web.

### Câu 6. Repository, service và widget khác nhau thế nào?

**Trả lời:** Widget phụ trách hiển thị và tương tác. Repository đóng gói việc gọi API theo nghiệp vụ. Service xử lý tác vụ như đọc NFC, đồng bộ hàng đợi hoặc gọi camera. Ví dụ ScanCoordinator điều phối một lượt đọc thẻ, còn ApiKioskRpcService gửi yêu cầu ghi nhận tới API. Việc tách này giúp kiểm thử xử lý mà không cần thiết bị NFC thật.

**Mã nguồn nên mở:** `lib/core/api_client.dart`, `lib/core/router.dart`, `lib/features/kiosk/scan_coordinator.dart`, `server/Attendance.Api/Program.cs`.

## 2. Vai trò, đăng nhập và bảo mật

### Câu 7 ★. Hệ thống có những vai trò nào?

**Trả lời:** Có admin, manager, employee và kiosk. Admin quản trị nhân viên, tài khoản, thẻ và các chức năng quản lý. Manager theo dõi công, báo cáo và xử lý ticket theo quyền backend, không có quyền quản trị tài khoản/nhân viên như Admin. Employee xem dữ liệu cá nhân, đăng ký khuôn mặt và gửi ticket. Kiosk đại diện cho máy chấm công, không phải một nhân viên.

### Câu 8. Vì sao tài khoản kiosk không gắn EmployeeId?

**Trả lời:** Một kiosk phục vụ nhiều nhân viên nên tài khoản máy không được đại diện cho một người. Khi đọc thẻ, server tìm chủ thẻ; khi quét mặt, server tìm nhân viên khớp mẫu. Database có ràng buộc tài khoản kiosk phải có EmployeeId rỗng để tránh gắn nhầm danh tính máy với danh tính người.

### Câu 9 ★. Đăng nhập có sử dụng JWT không?

**Trả lời:** Không. Backend sinh token ngẫu nhiên từ 32 byte và trả cho app. App gửi token bằng header Authorization: Bearer. Server lưu SHA-256 của token trong bảng Sessions, tra phiên còn hạn và tài khoản còn hoạt động ở các yêu cầu được bảo vệ. Phiên được tạo với hạn bảy ngày. Đây là token phiên lưu phía server, không phải JWT chứa các claim tự xác minh.

### Câu 10. Mật khẩu và token được lưu thế nào?

**Trả lời:** Mật khẩu dùng PasswordHasher của ASP.NET Identity, không lưu mật khẩu gốc trong bảng Accounts. Server lưu hash token, nhưng app cần giữ token gốc để gửi API; hiện token được lưu bằng SharedPreferences theo URL máy chủ. SharedPreferences không phải kho bí mật chuyên dụng. Khi nâng cấp bảo mật có thể dùng kho an toàn của hệ điều hành và rà soát cách lưu token trên web.

### Câu 11 ★. Ẩn nút trên giao diện đã đủ phân quyền chưa?

**Trả lời:** Chưa. GoRouter kiểm soát điều hướng và giao diện giúp người dùng thấy đúng chức năng, nhưng backend vẫn phải kiểm tra tài khoản, vai trò và phạm vi dữ liệu. Ví dụ truy vấn dữ liệu cá nhân phải lấy hoặc lọc EmployeeId theo tài khoản đăng nhập; không thể tin một EmployeeId bất kỳ do client gửi lên.

### Câu 12. Hệ thống xử lý đăng xuất và đổi mật khẩu ra sao?

**Trả lời:** Đăng xuất gọi API xóa phiên hiện tại và xóa token cục bộ. Đổi mật khẩu yêu cầu kiểm tra mật khẩu hiện tại, hash mật khẩu mới, bỏ cờ yêu cầu đổi mật khẩu và xóa các phiên khác của tài khoản. Nếu mất mạng khi đăng xuất, app vẫn xóa phiên cục bộ trong khối finally; không nên khẳng định server luôn đã thu hồi phiên khi yêu cầu chưa tới được server.

### Câu 13. Có chống thử mật khẩu liên tục không?

**Trả lời:** Endpoint đăng nhập có rate limit theo IP: tối đa 12 yêu cầu trong một phút, vượt giới hạn trả HTTP 429. Đây là một lớp hạn chế; chưa nên khẳng định hệ thống đã có đầy đủ khóa tài khoản, MFA hoặc phát hiện tấn công. Khi triển khai qua proxy cần xem lại cách xác định IP người dùng.

**Mã nguồn nên mở:** `server/Attendance.Api/Endpoints.cs` phần auth, `server/Attendance.Api/Program.cs`, `server/Attendance.Api/Models.cs`, `lib/core/api_client.dart`.

## 3. NFC và luồng ghi nhận chấm công

### Câu 14 ★. Trình bày luồng từ lúc chạm thẻ đến lúc lưu chấm công.

**Trả lời:** NfcService đọc UID, đổi các byte thành chuỗi hexadecimal và chuẩn hóa. ScanCoordinator chống đọc lặp nhanh, tạo client_scan_id, lấy thiết bị đã đăng ký rồi gửi POST /api/scans. Server kiểm tra quyền và thiết bị, tìm thẻ/nhân viên hoạt động, xác định vào hay ra, kiểm tra nghiệp vụ rồi ghi Events. App hiển thị thành công, bỏ qua, từ chối hoặc trạng thái chờ đồng bộ theo kết quả.

### Câu 15. UID là gì? Thẻ có lưu email, mật khẩu không?

**Trả lời:** UID là mã định danh được đọc từ thẻ trong luồng của project. Hệ thống dùng UID để tra bảng Cards và lấy EmployeeId; không ghi email hay mật khẩu lên thẻ. Mã nhân viên là định danh nghiệp vụ khác với UID nên không thể tự lấy mã nhân viên thay cho UID thực tế của thẻ.

### Câu 16. Vì sao phải chuẩn hóa UID?

**Trả lời:** Cùng một dãy byte cần có cách biểu diễn thống nhất để tra cứu. Project đổi byte sang hexadecimal, giữ biểu diễn byte đầy đủ và chuẩn hóa qua hàm dùng chung. Khi nhập Excel, UID cần đặt dạng Text để không mất số 0 đầu hoặc bị Excel đổi định dạng. Việc chuẩn hóa phải nhất quán giữa đọc thẻ, gán thẻ và gửi API.

### Câu 17 ★. NFC xác định vào ca hay ra ca như thế nào?

**Trả lời:** Theo mã hiện tại, NFC tự suy ra từ lượt hợp lệ gần nhất tại thời điểm ghi nhận. Nếu lượt trước là check_in và cách không quá 16 giờ thì lượt mới là check_out; trường hợp còn lại là check_in. Camera có mục đích check_in/check_out rõ ràng. Cần trình bày đúng khác biệt này: thiết kế mong muốn vào–ra tường minh không có nghĩa NFC hiện tại đã triển khai chọn chế độ như camera.

### Câu 18 ★. Quẹt thẻ liên tục có tạo nhiều lượt không?

**Trả lời:** Client có cooldown ba giây cho cùng UID. Backend còn kiểm tra khoảng cách với lượt trước của nhân viên: dưới 60 giây, NFC trả ignored và camera báo lỗi yêu cầu chờ. Hai lớp giải quyết việc đọc lặp ở thiết bị và ghi lặp giữa các nguồn. Tuy nhiên sau khoảng chặn, NFC vẫn có thể đổi từ vào thành ra theo cơ chế hiện tại.

### Câu 19. Quẹt NFC rồi quét mặt thì có hai bảng công không?

**Trả lời:** Không. Cả hai phương thức ghi chung Events và gọi logic Record ở server; trường Source phân biệt nfc và face_camera. Kiểm tra khoảng cách lượt và trạng thái vào–ra áp dụng theo nhân viên. Nhờ vậy vào bằng NFC và ra bằng camera vẫn có thể tạo một cặp tính công chung, nếu lượt ra hợp lệ.

### Câu 20. Thẻ lạ, thẻ khóa hoặc nhân viên nghỉ việc được xử lý thế nào?

**Trả lời:** API chỉ tra thẻ đang hoạt động và nhân viên đang hoạt động. Nếu không tìm được đối tượng hợp lệ, trả rejected với lý do unknown_or_inactive_card, không tạo sự kiện chấm công. Thiết bị cũng phải đăng ký, còn hoạt động và thuộc tài khoản được phép; chỉ biết UID không đủ để gọi API ghi công tùy ý.

### Câu 21. Dùng UID có ngăn được chấm công hộ không?

**Trả lời:** Chưa. Người giữ thẻ có thể chạm thay chủ thẻ; UID cũng không phải bằng chứng mật mã bảo đảm thẻ không bị sao chép. Khuôn mặt trong project là phương thức bổ sung, không phải bước bắt buộc sau mỗi lần NFC. Nếu cần chống chấm công hộ mạnh hơn, phải thiết kế kết hợp xác minh và đánh giá phần cứng/thẻ phù hợp.

**Mã nguồn nên mở:** `lib/features/kiosk/nfc_service.dart`, `lib/core/uid.dart`, `lib/features/kiosk/scan_coordinator.dart`, `server/Attendance.Api/Endpoints.cs` hàm Scan, `server/Attendance.Api/Business.cs` hàm Record.

## 4. Offline, đồng bộ và tính nhất quán

### Câu 22 ★. Project có chấm công khi mất mạng không?

**Trả lời:** Có cơ chế hàng đợi NFC: một số lỗi hoặc timeout được ScanCoordinator đưa vào pending_scans để gửi lại. Trên Android hàng đợi dùng SQLite; web dùng bộ nhớ và không bền qua tải lại trang. Tuy nhiên hiện ScanCoordinator trả lỗi ngay với ApiException, trong khi ApiClient chuyển lỗi kết nối thành ApiException. Vì vậy không được khẳng định mọi lần mất mạng đều được xếp hàng; nhánh xử lý lỗi này còn cần hoàn thiện.

### Câu 23. Khi nào hàng đợi được đồng bộ?

**Trả lời:** SyncService thử gửi khi khởi động, khi có thay đổi kết nối cho thấy có mạng và theo chu kỳ 30 giây. Các mục được đọc theo device_time tăng dần, gửi với is_replay=true. Cờ isFlushing ngăn hai đợt flush chạy chồng trong cùng service. Có kết nối Wi-Fi không đồng nghĩa API truy cập được nên kết quả gọi API mới quyết định xử lý tiếp.

### Câu 24 ★. Nếu server đã lưu nhưng app chưa nhận phản hồi thì gửi lại có bị trùng?

**Trả lời:** Mỗi lượt có UUID client_scan_id. Khi gửi lại phải giữ nguyên ID đó. Server kiểm tra ID đã tồn tại và database có unique index cho ClientScanId khác null, giúp không tạo hai Events cùng ID. Đây là tính idempotent cho việc ghi sự kiện đã thành công; nó khác với cooldown chống nhiều lần quẹt có ID mới.

### Câu 25. Khi nào một mục được xóa khỏi hàng đợi?

**Trả lời:** Khi server trả một trạng thái được chấp nhận trong giao thức: ok, duplicate, ignored hoặc rejected. Xóa khỏi hàng đợi không đồng nghĩa tất cả đều đã ghi công thành công. Nếu lỗi gọi API hoặc phản hồi không hợp lệ, service ghi số lần thử/lỗi rồi dừng vòng hiện tại. Một mục lỗi kéo dài có thể chặn các mục sau; cần bổ sung cơ chế đối soát hoặc tách lỗi vĩnh viễn khi mở rộng.

### Câu 26. Server lấy giờ thiết bị hay giờ server?

**Trả lời:** Với NFC online, thời điểm ghi nhận dùng giờ server. Khi replay, API kiểm tra device_time không cũ quá bảy ngày và không vượt quá giờ server năm phút; thời gian hợp lệ trong quá khứ có thể được dùng làm thời điểm sự kiện. Đây chỉ là giới hạn kiểm tra, chưa chứng minh đồng hồ thiết bị không bị sửa. Camera ghi nhận bằng giờ server và không dùng hàng đợi NFC.

### Câu 27. Nếu hai kiosk gửi đồng thời thì sao?

**Trả lời:** Các luồng ghi quan trọng dùng transaction Serializable, kết hợp kiểm tra sự kiện gần nhất và các ràng buộc database. Unique index chống hai Events có cùng client_scan_id. Với hai ID khác nhau, logic trạng thái/khoảng cách thời gian vẫn cần kiểm tra. Serializable có thể phát sinh deadlock hoặc lỗi cạnh tranh; không nên khẳng định mọi request đồng thời đều thành công nếu chưa có đo tải và cơ chế retry phù hợp.

**Mã nguồn nên mở:** `lib/features/kiosk/pending_scan_store.dart`, `lib/features/kiosk/sync_service.dart`, `lib/features/kiosk/scan_coordinator.dart`, `lib/core/api_client.dart`, `server/Attendance.Api/Models.cs`.

## 5. Camera và nhận diện khuôn mặt

### Câu 28 ★. ML Kit có nhận diện danh tính nhân viên không?

**Trả lời:** Trong project, ML Kit phát hiện khuôn mặt, các điểm mốc và thông tin phục vụ kiểm tra chuyển động. Model SFace chạy bằng ONNX Runtime tạo vector đặc trưng 128 chiều. Backend so vector đó với mẫu đã đăng ký để xác định nhân viên. Vì vậy cần phân biệt phát hiện có khuôn mặt với nhận diện người đó là ai.

### Câu 29. Vì sao phải dùng Kotlin và MethodChannel?

**Trả lời:** Luồng camera sử dụng API và thư viện Android để lấy khung hình, phát hiện mặt và chạy model. Flutter gọi channel attendance/face_camera để mở luồng native và nhận kết quả vector. FaceCameraService kiểm tra nền tảng, hiện chỉ cho chạy camera này trên Android; không có cơ sở nói chức năng đã hỗ trợ web hoặc iOS.

### Câu 30. Ảnh khuôn mặt được xử lý thế nào trước khi tạo vector?

**Trả lời:** FaceEmbedding lấy năm điểm mốc gồm hai mắt, mũi và hai điểm miệng để căn chỉnh mặt. Ảnh được đưa về 112 × 112, tách kênh RGB thành tensor NCHW kích thước [1, 3, 112, 112] với giá trị 0–255. Model trả vector 128 chiều rồi chuẩn hóa L2. Căn chỉnh giúp giảm khác biệt do vị trí, tỉ lệ và góc nghiêng trong ảnh.

### Câu 31 ★. Server quyết định khớp mặt theo tiêu chí nào?

**Trả lời:** Server dùng cosine similarity: tích vô hướng chia tích độ dài hai vector. Hai mẫu đầu/cuối phải có độ tương đồng ít nhất 0,45. Khi tìm nhân viên, điểm của một mẫu đăng ký là giá trị nhỏ hơn giữa hai lần so với vector đầu và cuối; điểm tốt nhất phải đạt 0,45 và hơn ứng viên thứ hai ít nhất 0,05. Đây là ngưỡng của triển khai hiện tại, không phải khẳng định độ chính xác 100%.

### Câu 32. Vì sao cần hai vector và challenge dùng một lần?

**Trả lời:** Hai vector giúp kiểm tra tính nhất quán giữa đầu và cuối quá trình chụp. Challenge gắn với tài khoản, mục đích và thiết bị nếu là kiosk, có thời hạn và chỉ được dùng một lần. Backend đánh dấu đã dùng trước khi xử lý tiếp để không tái sử dụng cả khi gửi mẫu sai. Hai cơ chế này bổ sung cho nhau nhưng không thay thế hệ thống xác thực thiết bị và chống giả mạo chuyên dụng.

### Câu 33 ★. Chớp mắt và quay đầu đã chống ảnh/video giả hoàn toàn chưa?

**Trả lời:** Chưa. Đây là kiểm tra chuyển động cơ bản ở client. Server nhận vector, không trực tiếp xem video để kiểm chứng hành động. App bị sửa hoặc video phát lại vẫn là vấn đề cần đánh giá. Khi trình bày chỉ nên nói hệ thống có lớp kiểm tra cơ bản; hướng cải tiến là liveness chuyên dụng, kiểm tra độ tin cậy thiết bị và thử nghiệm chống giả mạo.

### Câu 34. Đăng ký lại khuôn mặt có làm mất mẫu cũ khi thất bại không?

**Trả lời:** Server kiểm tra mẫu mới trước, sau đó thu hồi mẫu cũ và tạo mẫu mới trong cùng transaction. Nếu hủy camera hoặc mẫu mới không hợp lệ, mẫu cũ được giữ lại. Đăng ký thành công thì mẫu mới tự kích hoạt, không có bước Admin duyệt; Admin vẫn có khả năng thu hồi mẫu theo chức năng quản lý.

### Câu 35. Có gửi ảnh/video lên server không? Mẫu mặt có được bảo vệ tuyệt đối không?

**Trả lời:** Luồng hiện tại gửi vector thay vì ảnh/video; mẫu vector được lưu trong Faces và không trả vector mẫu cho kiosk. Điều này giảm dữ liệu hình ảnh truyền đi, nhưng vector vẫn là dữ liệu sinh trắc học nhạy cảm. Không nên nói vector là dữ liệu vô hại hay đã được mã hóa ở mức ứng dụng nếu mã nguồn không thực hiện điều đó. Triển khai thực tế cần kiểm soát truy cập, bảo vệ lưu trữ và quy trình thu hồi/xóa phù hợp.

**Mã nguồn nên mở:** `lib/features/business/face_camera_service.dart`, `android/app/src/main/kotlin/com/example/demo_nfc/FaceEmbedding.kt`, `FaceCameraActivity.kt`, `FaceCaptureFlow.kt`, `server/Attendance.Api/Business.cs` phần FaceBegin/FaceFinish/Cosine.

## 6. Tính công, báo cáo và chốt lương

### Câu 36 ★. Hệ thống tính giờ làm như thế nào?

**Trả lời:** Server bỏ các lượt đã hủy, sắp xếp sự kiện theo nhân viên và ghép check_in với check_out hợp lệ. Tổng phút công là tổng thời gian của từng cặp, trừ phần giao với giờ nghỉ 12:00–13:00. Không cộng khoảng nhân viên đã ra ngoài. Cấu hình mặc định làm 09:00–18:00, trừ một giờ nghỉ còn 480 phút; có thể đổi AttendancePolicy trên server.

### Câu 37 ★. Cho ví dụ cụ thể để chứng minh cách trừ giờ nghỉ.

**Trả lời:** Vào 09:00, ra 18:00 là chín giờ hiện diện, trừ nghỉ trưa còn tám giờ công. Nếu vào 09:30, làm liên tục ngoài giờ nghỉ thì đủ tám giờ lúc 18:30. Nếu ra ngoài thêm 11:00–11:30 thì cần tới 19:00. Ra ngoài trong giờ nghỉ không bị trừ hai lần, vì mỗi khoảng làm chỉ trừ phần giao thực tế với giờ nghỉ.

### Câu 38. Quên chấm ra hoặc có lượt ra không có lượt vào thì sao?

**Trả lời:** Hệ thống đánh dấu thiếu hoặc bất thường, không tự đoán giờ để tính lương. Báo cáo chỉ cộng cặp đã hoàn tất và chặn chốt khi còn lỗi thiếu lượt. Nhân viên có thể gửi ticket, quản lý xác minh rồi bổ sung hoặc thay thế lượt sai. Cặp cách nhau quá 16 giờ không được coi là một ca hợp lệ trong cách ghép hiện tại.

### Câu 39. Có hỗ trợ ca qua đêm và ca làm linh hoạt không?

**Trả lời:** Bộ ghép cặp hỗ trợ cặp qua nửa đêm trong giới hạn 16 giờ; báo cáo kỳ cắt thời gian theo biên kỳ. Tuy nhiên đó chưa phải hệ thống phân ca linh hoạt đầy đủ. Quy tắc trễ/sớm và giờ nghỉ vẫn dựa trên AttendancePolicy chung; dashboard ngày có cách quy thuộc ca riêng. Cần bổ sung lịch phân ca và kiểm thử biên ngày trước khi khẳng định hỗ trợ mọi ca đêm.

### Câu 40. Dashboard đang làm khác báo cáo lương như thế nào?

**Trả lời:** Dashboard có thể cộng tạm thời từ lượt vào còn mở tới thời điểm hiện tại để hiển thị đã làm, còn thiếu và giờ dự kiến đủ công. Báo cáo kỳ/chốt lương chỉ cộng cặp đã có giờ ra. Giờ dự kiến đủ công chỉ là ước tính nếu tiếp tục làm, không tự tạo sự kiện ra ca và không tự chuyển thành lương đã chốt.

### Câu 41 ★. Công thức lương là gì? Có tính thuế và bảo hiểm không?

**Trả lời:** Lương gộp hiện tại bằng tổng phút công hợp lệ chia 60, nhân đơn giá theo giờ của nhân viên. Server dùng decimal và làm tròn về đơn vị đồng bằng MidpointRounding.AwayFromZero. Ví dụ 480 phút, đơn giá 30.000 đồng/giờ thì lương gộp là 240.000 đồng. Project chưa phải bảng lương đầy đủ gồm thuế, bảo hiểm, phụ cấp và quy tắc tăng ca.

### Câu 42 ★. Chốt lương khác xem báo cáo ở điểm nào?

**Trả lời:** Báo cáo tính từ dữ liệu hiện tại. Chốt lương tạo PayrollRun và các PayrollItems lưu ảnh chụp dữ liệu gồm phút công, đơn giá và lương gộp. Server chặn kỳ chồng lấn và lỗi thiếu lượt; các thao tác sửa công phải kiểm tra kỳ đã chốt. Xuất Excel từ kỳ đã chốt dùng dữ liệu đã lưu để kết quả ổn định.

### Câu 43. Vì sao dùng UTC+7 và khoảng thời gian dạng [start, end)?

**Trả lời:** Ngày công phải theo ngày Việt Nam, không phụ thuộc múi giờ máy chủ. Business.Zone đặt UTC+7 và Bound tạo mốc đầu ngày theo múi giờ này. Khoảng đầu đóng, cuối mở giúp hai kỳ liền nhau không cùng tính một thời điểm ở ranh giới. Ví dụ báo cáo hết tháng 10 dùng mốc cuối loại trừ là 01/11, thay vì phải chọn 23:59:59 của 31/10.

**Mã nguồn nên mở:** `server/Attendance.Api/AttendanceSummary.cs`, `server/Attendance.Api/Business.cs` phần Sessions/Report/ProtectPayroll, `server/Attendance.Api/Endpoints.cs` phần ClosePayroll, `server/Attendance.Api/PayrollSpreadsheet.cs`.

## 7. Ticket sửa công, Excel và email

### Câu 44 ★. Nhân viên sửa giờ bằng ticket như thế nào?

**Trả lời:** Nhân viên đề nghị bổ sung lượt hoặc sửa giờ một lượt đã có, nhập lý do và có thể đính kèm bằng chứng. Gửi yêu cầu chưa làm thay đổi bảng công. Admin/Quản lý duyệt hoặc từ chối và không được tự duyệt ticket của mình. Khi duyệt sửa lượt, server hủy hiệu lực lượt sai rồi tạo lượt thay thế, giữ lịch sử và audit; kỳ đã chốt không được sửa theo luồng này.

### Câu 45. Vì sao không cập nhật đè giờ gốc? Ticket có những trạng thái nào?

**Trả lời:** Giữ lượt gốc giúp giải thích ai đề nghị, ai duyệt và thay đổi từ giờ nào sang giờ nào. Các trạng thái hiện tại là Chờ xử lý, Đã duyệt, Từ chối và Đã hủy. Nhân viên được hủy yêu cầu đang chờ; từ chối cần phản hồi. Quy trình yêu cầu bổ sung rồi gửi lại cùng ticket và điều chỉnh sau chốt chưa được triển khai đầy đủ.

### Câu 46. Bằng chứng ticket được lưu và kiểm soát ra sao?

**Trả lời:** Cho phép JPG/PNG hoặc PDF, tối đa ba tệp, mỗi tệp tối đa 2 MB và tổng tối đa 5 MB. Nội dung lưu trong SQL Server ở TicketEvidence. API tải tệp kiểm tra quyền của chủ ticket hoặc Admin/Quản lý; không dùng đường dẫn công khai. Đính kèm là tùy chọn, không thay thế việc người duyệt xác minh yêu cầu.

### Câu 47 ★. Nhập nhân viên Excel có ghi dữ liệu ngay lúc chọn file không?

**Trả lời:** Không. Luồng gồm chọn file, xem trước/kiểm tra rồi xác nhận nhập. Server kiểm tra mã, email, dữ liệu hồ sơ và UID nếu có. Các xung đột phải được xử lý trước; khi xác nhận dùng giao dịch để tránh ghi một phần danh sách. Preview hỗ trợ người dùng nhưng server vẫn cần kiểm tra lại khi commit vì dữ liệu có thể đã thay đổi.

### Câu 48. Nhập lại nhân viên đã tồn tại có tạo tài khoản mới không?

**Trả lời:** Khi mã và email khớp tài khoản hiện tại, luồng cập nhật các trường hồ sơ có dữ liệu, giữ mật khẩu, mẫu mặt, trạng thái và lịch sử công. Ô tùy chọn trống không tự xóa dữ liệu cũ. Nếu thông tin không thay đổi thì bỏ qua; nếu mã/email xung đột thì báo lỗi, không tự ghép hai người khác nhau thành một.

### Câu 49. Có gán NFC qua Excel và nhân viên tự liên kết thẻ không?

**Trả lời:** Đã có cột uid_the tùy chọn để gán thẻ thực tế khi nhập Excel, với kiểm tra trùng trong file và database. Không tự chuyển chủ, mở khóa hoặc thay thẻ đang dùng. Nhân viên tự chạm thẻ để liên kết tài khoản mới chỉ là đề xuất trong tài liệu thiết kế; không nên trình bày như chức năng đã hoàn thành. Có email/mã nhân viên thôi thì không tự suy ra UID thẻ.

### Câu 50. Nếu gửi email cấp tài khoản thất bại thì việc tạo tài khoản có bị hủy không?

**Trả lời:** Không. Hệ thống lưu công việc gửi thư trong database và tiến trình nền xử lý việc gửi. Nếu thiếu cấu hình hoặc gửi lỗi thì trạng thái phải thể hiện chờ/lỗi, không báo giả đã gửi. Tài khoản mới nhập Excel hiện dùng mật khẩu khởi tạo chung theo luồng demo và có hướng dẫn đổi mật khẩu. Trước khi dùng thực tế nên thay bằng cơ chế kích hoạt hoặc mật khẩu riêng dùng một lần.

**Mã nguồn nên mở:** `server/Attendance.Api/AttendanceTickets.cs`, `server/Attendance.Api/EmployeeImport.cs`, `server/Attendance.Api/EmployeeSpreadsheet.cs`, `server/Attendance.Api/OnboardingEmailService.cs`. Đọc thêm `docs/TICKET_SUA_CONG.md`, `docs/NHAP_NHAN_VIEN_EXCEL.md`, `docs/EMAIL_TAI_KHOAN.md`.

## 8. Database, kiểm thử và phản biện

### Câu 51 ★. Những bảng dữ liệu quan trọng liên hệ như thế nào?

**Trả lời:** Employees lưu hồ sơ; Accounts lưu thông tin đăng nhập và vai trò; Cards ánh xạ UID sang nhân viên; Devices thuộc tài khoản đăng ký máy; Events lưu các lượt của nhân viên. Faces lưu mẫu sinh trắc, Challenges lưu phiên camera, Sessions lưu phiên đăng nhập. PayrollRuns chứa kỳ chốt và PayrollItems chứa kết quả từng người. AttendanceTickets, TicketEvidence và Audits phục vụ xử lý và đối chiếu sửa công.

### Câu 52. Database có những ràng buộc nào đáng chú ý?

**Trả lời:** Mã nhân viên và email tài khoản có unique index; UID là khóa của Cards; ClientScanId khác null là duy nhất. Một tài khoản chỉ có một mẫu mặt chưa thu hồi nhờ filtered unique index. PayrollItems dùng khóa ghép RunId và EmployeeId. Khóa ngoại giữ liên kết và nhiều quan hệ dùng Restrict. Tuy nhiên ràng buộc khóa/unique không thay thế kiểm tra nghiệp vụ như hai kỳ lương chồng lấn.

### Câu 53 ★. Project đã có những loại kiểm thử gì? Chứng minh bằng đâu?

**Trả lời:** Repository có Flutter unit/widget test cho API client, điều hướng, coordinator, hàng đợi, đồng bộ và nhiều màn hình. Backend có chương trình kiểm tra tính công, Excel, email và bằng chứng ticket; script test-api.ps1 kiểm tra luồng API với database thử nghiệm riêng. Android có FaceCaptureFlowTest cho tiến trình camera. Đây là phạm vi kiểm thử nhìn thấy trong mã nguồn; kết quả pass và số lượng phải lấy từ lần chạy thực tế, không suy ra chỉ vì có file test.

### Câu 54. Nếu giảng viên yêu cầu thử lỗi ngay tại chỗ, em chọn gì?

**Trả lời:** Em thử thẻ chưa gán, quẹt cùng thẻ hai lần nhanh, tài khoản nhân viên gọi chức năng quản trị, ticket sửa công vào kỳ đã chốt và Excel có UID trùng. Kỳ vọng là API từ chối hoặc bỏ qua đúng lý do và dữ liệu không bị ghi sai. Với thử mất mạng, em quan sát cả thông báo lẫn số mục pending vì hiện vẫn có giới hạn ở nhánh ApiException; không cam kết trước rằng mọi lỗi đều được lưu hàng đợi.

### Câu 55. Dashboard cập nhật có dùng WebSocket hay push notification không?

**Trả lời:** Hiện dùng polling: màn hình quản lý tải lại sau khoảng hai giây kể từ khi yêu cầu trước hoàn tất. Dữ liệu lượt mới được so sánh để thông báo trong màn hình đang mở. Đây chưa phải WebSocket và chưa phải thông báo đẩy khi đóng app. Khi số người xem tăng, có thể đánh giá SignalR hoặc cơ chế giảm tần suất tải.

### Câu 56. Vì sao Android Emulator dùng 10.0.2.2 thay vì localhost?

**Trả lời:** Trong emulator, localhost trỏ về chính máy ảo; 10.0.2.2 dùng để truy cập máy host. Điện thoại thật cần đường kết nối thích hợp như mạng nội bộ, HTTPS tunnel hoặc adb reverse khi cắm USB. Backend và SQL Server vẫn phải chạy. Luồng HTTP nội bộ được cho phép ở bản debug theo cấu hình project; triển khai thực tế cần cấu hình HTTPS thích hợp.

### Câu 57 ★. Điểm hạn chế lớn nhất hiện tại là gì?

**Trả lời:** Em chia thành nghiệp vụ và kỹ thuật. Nghiệp vụ chưa có lịch phân ca/thuế/bảo hiểm và điều chỉnh lương sau chốt đầy đủ. Kỹ thuật còn giới hạn xử lý offline ở nhánh lỗi, NFC đang tự luân phiên vào–ra và liveness mới là kiểm tra cơ bản. Mẫu mặt/phiên đăng nhập cần được bảo vệ thêm khi triển khai thực tế. Em trình bày rõ phạm vi này thay vì khẳng định hệ thống đã sẵn sàng cho mọi doanh nghiệp.

### Câu 58. Khi dữ liệu tăng lên hàng triệu lượt thì phần nào cần cải tiến?

**Trả lời:** Report hiện đọc toàn bộ Events rồi ghép và lọc trong bộ nhớ, nên cần tối ưu truy vấn theo khoảng thời gian có xét cặp giao biên, index và chiến lược tổng hợp. So khớp mặt hiện duyệt các mẫu đủ điều kiện trên server, cần đo hiệu năng và đánh giá phương án tìm kiếm khi số lượng lớn. Cũng cần phân trang, đo tải polling, giám sát lỗi và xử lý cạnh tranh. Đây là hướng cải tiến, chưa phải chức năng đã có.

### Câu 59. Em có tự huấn luyện model và tự làm toàn bộ thư viện không?

**Trả lời:** Không nên nhận phần việc của thư viện là của mình. Project sử dụng Flutter, nfc_manager, ML Kit, ONNX Runtime và model SFace có sẵn. Phần triển khai trong project là tích hợp thiết bị, xử lý luồng camera, gọi model, thiết kế API/database, phân quyền và nghiệp vụ công/lương/ticket. Khi nói về đóng góp cá nhân, cần chỉ đúng file hoặc chức năng mình thực sự thực hiện; không tự nhận số liệu độ chính xác khi chưa đo.

### Câu 60 ★. Nếu được phát triển tiếp, em ưu tiên gì?

**Trả lời:** Trước hết em hoàn thiện cách phân loại lỗi để hàng đợi offline hoạt động nhất quán, có đối soát lượt bị từ chối và xử lý mục lỗi không chặn cả hàng. Tiếp theo em làm rõ chế độ vào–ra NFC, tăng bảo vệ token và sinh trắc, đánh giá liveness. Sau đó bổ sung phân ca, tối ưu báo cáo và kiểm thử tải. Thứ tự ưu tiên dựa trên tính đúng của dữ liệu trước khi mở rộng nghiệp vụ.

**Mã nguồn nên mở:** `server/Attendance.Api/Models.cs`, `server/Attendance.Api/Business.cs`, `server/Attendance.Tests/Program.cs`, `server/test-api.ps1`, `test/`, `android/app/src/test/kotlin/com/example/demo_nfc/FaceCaptureFlowTest.kt`.

## 9. Kịch bản ôn và demo ngắn

1. Giới thiệu mục tiêu và sơ đồ Flutter → API → SQL Server trong một phút.
2. Đăng nhập đúng vai trò, chỉ ra quyền khác nhau giữa Admin, nhân viên và kiosk.
3. Dùng thẻ đã gán để ghi nhận; chạm lại ngay để minh họa chống đọc lặp. Muốn demo lượt tiếp theo phải lưu ý ngưỡng 60 giây ở server.
4. Mở dashboard hoặc lịch sử, đối chiếu nhân viên, thời điểm và nguồn sự kiện với dữ liệu server.
5. Trên Android đã chuẩn bị quyền camera và mẫu mặt, minh họa nhận diện; nếu điều kiện camera không tốt thì giải thích giới hạn và dùng NFC theo phương án dự phòng.
6. Cho xem ticket trước và sau duyệt: gửi chưa đổi công, duyệt mới áp dụng thay đổi và giữ lịch sử.
7. Dùng dữ liệu thử nghiệm có cặp vào–ra đầy đủ để giải thích phút công, lương gộp và xuất Excel. Chốt lương làm khóa các thay đổi công trong kỳ, nên dùng kỳ demo riêng.
8. Kết thúc bằng hai hạn chế cụ thể và hướng phát triển, không tự đưa số liệu độ chính xác hoặc hiệu năng chưa đo.

## 10. Các điểm cần nhớ để tránh trả lời sai

- Token phiên hiện tại không phải JWT; dùng Bearer không có nghĩa là dùng JWT.
- ML Kit phát hiện mặt; SFace tạo đặc trưng; backend quyết định nhân viên khớp.
- NFC hiện tự suy ra vào–ra; camera có mục đích vào/ra cụ thể.
- Có hàng đợi offline nhưng chưa bảo đảm mọi lỗi kết nối đi vào hàng đợi; web chỉ lưu bộ nhớ.
- Mục được đồng bộ khỏi hàng đợi có thể là rejected hoặc ignored, không nhất thiết là đã được tính công.
- Đăng ký mặt tự kích hoạt sau kiểm tra; không có bước Admin duyệt mẫu trong luồng hiện tại.
- Chớp mắt/quay đầu chưa phải chống giả mạo chuyên dụng; vector cũng cần bảo vệ.
- Dashboard đang làm là tạm tính; lương kỳ chỉ cộng cặp hoàn tất và dùng snapshot khi chốt.
- Đi trễ/về sớm là chỉ số; không tự suy diễn thành công thức phạt nếu mã nguồn chưa có.
- Nhân viên tự liên kết NFC là đề xuất; gán UID qua Admin/Excel đã có.
- Polling khoảng hai giây không phải WebSocket hay push notification.
- Có file kiểm thử không đồng nghĩa lần chạy hiện tại đã pass; trình bày bằng kết quả chạy thật.
