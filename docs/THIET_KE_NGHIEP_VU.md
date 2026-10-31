# Thiết kế nghiệp vụ hệ thống chấm công

Tài liệu ghi lại thiết kế đã thống nhất. Đây là yêu cầu đích của hệ thống,
không phải xác nhận tất cả chức năng bên dưới đã được triển khai.
Xem phạm vi hiện tại và cách chạy trong [README](../README.md).

## 1. Ba giao diện

| Giao diện | Chức năng chính |
| --- | --- |
| **Admin/Quản lý** | Quản lý nhân viên, nhập Excel, đăng ký thẻ/khuôn mặt, quản lý ca, duyệt yêu cầu sửa công, tính và chốt lương |
| **Máy chấm công Kiosk** | Đặt tại công ty, nhân viên xác thực để ghi nhận vào/ra, không cần đăng nhập cá nhân |
| **App nhân viên** | Xem công, lịch làm, phiếu lương và tạo ticket yêu cầu sửa công |

**App nhân viên không có chức năng chấm công.** Nhân viên đăng nhập tài khoản
do công ty cấp hoặc qua lời mời kích hoạt và chỉ xem dữ liệu của mình.
Đăng ký mẫu khuôn mặt là bước thiết lập danh tính có quản trị viên xác minh,
không phải một lượt chấm công.

## 2. App nhân viên

App có bốn mục:

- **Tổng quan:** ca hôm nay, giờ vào/ra đã ghi nhận, cảnh báo thiếu công.
- **Lịch sử chấm công:** xem theo ngày/tháng; phân biệt lượt quét gốc và công đã được điều chỉnh.
- **Lương của tôi:** xem phiếu lương đã được công ty chốt và phát hành. Nếu hiển thị lương tạm tính phải ghi rõ.
- **Yêu cầu của tôi:** tạo và theo dõi ticket sửa công.

Nhân viên không được xem công/lương của người khác hoặc tự sửa dữ liệu chấm công.

## 3. Ticket sửa công

1. Nhân viên chọn ngày/ca bị sai và loại vấn đề: thiếu giờ vào, thiếu giờ ra hoặc giờ ghi nhận không đúng.
2. Nhập giờ đề nghị, lý do và đính kèm minh chứng nếu có.
3. Quản lý xem dữ liệu gốc cùng nội dung đề nghị rồi duyệt hoặc từ chối, kèm phản hồi.
4. Khi được duyệt, hệ thống cập nhật bảng công, giữ lịch sử thay đổi và thông báo cho nhân viên.

Trạng thái gồm **Chờ xử lý**, **Cần bổ sung**, **Đã duyệt**, **Từ chối**, **Đã hủy**.
Từ Chờ xử lý, quản lý có thể yêu cầu bổ sung, duyệt hoặc từ chối;
nhân viên có thể hủy yêu cầu đang chờ. Yêu cầu cần bổ sung được gửi lại để tiếp tục xét duyệt.
Nhân viên không tự sửa công trực tiếp.

Nếu kỳ lương đã chốt, yêu cầu phải qua quy trình điều chỉnh sau chốt;
không âm thầm sửa phiếu lương đã phát hành.

## 4. Phương thức chấm công

- **NFC là phương thức chính:** nhanh, phù hợp khi nhiều người đến cùng lúc.
- **Khuôn mặt là phương thức thay thế:** dùng khi quên thẻ; nhân viên tự đăng ký mẫu, thành công là dùng được ngay.
  Khi đăng ký mẫu trong app nhân viên, thực hiện chớp mắt/quay đầu một lần cho
  phiên đăng ký. Khi chấm công tại kiosk, chỉ cần nhìn thẳng và giữ yên để máy
  tự lấy mẫu đối chiếu, không lặp lại cử chỉ. Luồng này chưa bảo đảm chống chấm
  hộ bằng ảnh/video.
- **Bỏ vân tay khỏi phạm vi triển khai:** chỉ cân nhắc bổ sung khi có đầu đọc chuyên dụng phù hợp nhận diện nhiều nhân viên.

Các phương thức thay thế nhau. Nhân viên không phải thực hiện cả NFC và khuôn mặt
cho một lượt vào hoặc ra.

Trong kịch bản demo:

- **OnePlus:** kiosk quẹt thẻ NFC thật tại công ty.
- **Máy ảo Android Studio:** kiosk sử dụng camera để thử quét mặt.
- **Web:** Admin/Quản lý.

Tài khoản Kiosk đại diện cho máy quét, không liên kết với một hồ sơ nhân viên
và không sở hữu mẫu khuôn mặt. Nhân viên không đăng nhập tài khoản cá nhân tại kiosk
để thực hiện chấm công.

## 5. Một bảng công chung

Mỗi lần xác thực thành công tạo cùng một loại dữ liệu chấm công:

| Nhân viên | Thời gian | Loại lượt | Phương thức |
| --- | --- | --- | --- |
| NV01 | 08:00 | Vào | NFC |
| NV01 | 17:00 | Ra | Khuôn mặt |

**Báo cáo công và lương không tách theo phương thức.** Hệ thống ghép giờ vào/ra
theo nhân viên và ca làm để tính công. Ví dụ trên vẫn là một ca của NV01;
vào bằng thẻ và ra bằng khuôn mặt không thay đổi cách tính.

Phương thức xuất hiện trong chi tiết lượt chấm công để quản lý tra soát.
Báo cáo tổng hợp gồm ngày công, giờ làm, đi muộn, về sớm, thiếu lượt
và các điều chỉnh đã được duyệt.

Lượt chấm công cần giữ nhân viên, thời gian, loại lượt, phương thức và máy ghi nhận.
Điều chỉnh phải giữ dữ liệu gốc, người duyệt, thời điểm và lý do thay đổi.

## 6. Chống ghi nhận trùng giữa các phương thức

Hệ thống kiểm tra theo **nhân viên + ca + loại lượt**, không chỉ theo thẻ.

- Nếu đã ghi nhận vào ca, báo “Bạn đã vào ca lúc 08:00”; không tạo thêm lượt hoặc tự chuyển thành ra.
- Ghi nhận ra ca phải theo chế độ **Ra ca** rõ ràng.
- NV01 vừa quẹt thẻ rồi quét mặt để vào cùng một ca chỉ có một lượt vào hợp lệ.
- Kiểm tra trùng phải thực hiện tại server cho cả NFC và khuôn mặt, kể cả hai máy gửi đồng thời.
- Chống quét liên tiếp trong một khoảng ngắn là biện pháp bổ sung, không thay thế kiểm tra theo ca và loại lượt.

## 7. Tổ chức triển khai

Có thể giữ chung một project Flutter nhưng build hai bản Android: **Kiosk** và
**Nhân viên**, còn Admin chạy web. Các giao diện dùng chung backend và database;
server kiểm tra quyền theo tài khoản, không chỉ ẩn nút trên giao diện.

Phạm vi nghiệp vụ thống nhất: **một luồng chấm công chung, NFC chính và khuôn mặt
dự phòng; một bảng công, một cách tính lương**. Không tạo ba bộ chức năng
hay các loại báo cáo riêng theo phương thức xác thực.

## 8. Dashboard và tổng hợp công đã triển khai (30/10/2026)

- Bảng công quản lý tải lại khoảng 2 giây sau khi yêu cầu trước hoàn tất.
  Khi có lượt mới sau lần tải đầu, hiện thông báo ngay trên bảng với nhân viên,
  giờ, vào/ra và phương thức. Không cần mở chi tiết nhân viên. Đây là thông báo
  trong màn hình đang mở, chưa phải thông báo đẩy khi đóng app.
- Mỗi nhân viên có trạng thái đang trong ca, đã ra ca, chưa vào ca hoặc cần kiểm tra;
  hiển thị từng khoảng vào–ra, giờ đã làm, thời gian còn thiếu và mốc dự kiến đủ công.
  Người chưa có lượt cũng xuất hiện nếu hồ sơ còn hoạt động. Chưa có lịch phân ca
  để phân biệt ngày nghỉ, nghỉ phép và vắng mặt.
- Cấu hình `AttendancePolicy` trong `server/Attendance.Api/appsettings.json` dùng
  phút tính từ 00:00: bắt đầu 540 (09:00), kết thúc 1080 (18:00), nghỉ 720–780
  (12:00–13:00), yêu cầu 480 phút/ngày. **Giờ nghỉ này đang là giả định triển khai**,
  cần đổi cấu hình nếu công ty dùng giờ nghỉ khác. Ngày công dùng múi giờ UTC+7.
- Chỉ cộng thời gian có mặt trong các khoảng vào–ra hợp lệ, trừ phần giao với giờ
  nghỉ; không cộng các khoảng gián đoạn. Thời gian có mặt trước 09:00 và sau 18:00
  vẫn được cộng theo cách ghi nhận hiện tại; chưa có bước duyệt tăng ca riêng.
  Không tự sinh lượt để làm bù và không sửa lượt quét gốc.
- Ví dụ: vào 09:30, nghỉ 12:00–13:00, làm liên tục các khoảng còn lại thì đủ 8 giờ
  lúc 18:30. Nếu ra ngoài 11:00–11:30, mốc dự kiến thành 19:00. Nếu ra ngoài trong
  giờ nghỉ, không trừ hai lần. Mốc dự kiến chỉ hiện khi đang trong ca và dữ liệu
  không có dấu hiệu thiếu/sai lượt; giả định tiếp tục làm việc đến đủ công.
- Thời gian đang trong ca là tạm tính. Báo cáo kỳ và chốt lương chỉ cộng các cặp
  đã hoàn tất, dùng chung quy tắc trừ giờ nghỉ. Phiếu lương đã chốt được giữ nguyên.
  Lượt vào cũ chưa có giờ ra không tự cộng đến ngày hôm sau; cặp dài hơn 16 giờ
  được đánh dấu thiếu lượt để kiểm tra. Cặp qua nửa đêm trong giới hạn 16 giờ vẫn
  được hỗ trợ; báo cáo kỳ chia thời gian tại ranh giới kỳ như trước.
- Lượt vào liên tiếp hoặc ra không có vào được cảnh báo để kiểm tra; không tự
  đoán giờ thiếu. Báo cáo kỳ tính các lượt ra không ghép được vào nhóm lỗi thiếu
  lượt và chặn chốt lương đến khi được xử lý.

Dashboard nhân viên đủ bốn mục và quy trình ticket tại mục 2–3 vẫn là yêu cầu đích,
chưa hoàn thiện trong đợt sửa dashboard quản lý này.

## 9. Nhập danh sách nhân viên đã triển khai (30/10/2026)

Admin có chức năng nhập `.xls`/`.xlsx` ngay từ thanh công cụ dashboard và trang
Nhân viên. Hệ thống xem trước dữ liệu, báo lỗi theo dòng, nhận phòng ban chung
hoặc phòng ban theo từng dòng, rồi tạo đồng thời hồ sơ và tài khoản email cho
nhân viên mới. Lưu thêm chức vụ, số điện thoại và ngày vào làm.

Nhập lại người đã có cùng mã và email sẽ cập nhật các ô hồ sơ có dữ liệu, giữ mật khẩu và lịch sử công. Nếu thông tin không đổi thì bỏ qua. Mọi lỗi
mã/email xung đột phải được xử lý trước khi nhập; không ghi một phần danh sách.
Admin tải bảng tài khoản và mật khẩu khởi tạo để bàn giao. Nhân viên vẫn tự đăng
ký khuôn mặt trong app; việc nhập danh sách không tạo mẫu mặt.

Chi tiết định dạng, giới hạn và file mẫu tại
[Nhập nhân viên bằng Excel](NHAP_NHAN_VIEN_EXCEL.md).

## 10. Email cấp tài khoản và đổi mật khẩu (31/10/2026)

Tài khoản nhân viên mới nhập Excel dùng email trong file để đăng nhập, mật khẩu
ban đầu `12345678`. Hệ thống lưu hàng đợi email trong SQL Server và tự gửi riêng
cho từng nhân viên thông tin đăng nhập, hướng dẫn đổi mật khẩu và đăng ký khuôn
mặt. Gửi qua Gmail SMTP bằng Gmail công ty và mật khẩu ứng dụng của tài khoản
gửi. Nhân viên nhận thư không cần mật khẩu ứng dụng. Khi thiếu cấu hình, tài khoản vẫn tạo thành công, thư chờ gửi và Admin
thấy trạng thái đúng trên dashboard; không báo giả đã gửi.

Nhân viên có chức năng đổi mật khẩu của chính mình trong app. Đăng ký khuôn mặt
do nhân viên tự thực hiện, mẫu tự kích hoạt khi đăng ký thành công. Tài khoản cũ không bị tự
đổi mật khẩu hay gửi thêm thư khi triển khai tính năng này.

Xem [cấu hình và kiểm thử email](EMAIL_TAI_KHOAN.md).

## 11. Đề xuất nhân viên tự liên kết NFC (chưa triển khai)

Admin phát thẻ trống cho nhân viên. Nhân viên đăng nhập tài khoản của mình trên
điện thoại có NFC, chọn **Liên kết thẻ NFC**, chạm thẻ và xác nhận. App đọc UID;
backend lấy EmployeeId từ phiên đăng nhập và tạo liên kết. Không cần biết trước
UID, không chọn nhân viên khác và không ghi email/mật khẩu lên thẻ. Chế độ liên
kết không tạo lượt chấm công. Khi đã có thẻ, app hiển thị thẻ hiện tại; thẻ của
người khác hoặc đã bị thu hồi không được tự nhận. Đổi/mất thẻ cần luồng thu hồi
và cấp lại, lưu lịch sử. Backend kiểm tra đồng thời bằng ràng buộc UID duy nhất.

Nếu nhân viên không có điện thoại NFC, có thể bổ sung chế độ liên kết riêng tại
kiosk: nhân viên đăng nhập hoặc dùng mã liên kết một lần từ app, sau đó chạm thẻ.
Mã có hạn ngắn, chỉ dùng một lần, gắn đúng tài khoản; không dùng email nhập tay
để xác định chủ thẻ. Đây là phương án bổ sung, chưa triển khai.

Muốn nhập Excel và gán ngay mà không ai cần chạm thẻ khi đăng ký thì phải có cột
UID NFC thực tế cho từng nhân viên từ nhà cung cấp hoặc danh sách đã đọc trước.
Chỉ có ba thẻ vật lý và danh sách email thì hệ thống không tự biết ai giữ thẻ nào.
Mã nhân viên không thay thế UID. Mỗi người nên dùng một thẻ riêng.

## 12. Khuôn mặt tự kích hoạt (31/10/2026)

Nhân viên đăng nhập và đồng ý đăng ký mẫu của mình; camera vẫn yêu cầu chớp mắt/
quay đầu. Khi kiểm tra mẫu thành công, backend lưu và kích hoạt ngay. Không có
bước Admin duyệt. Khi khởi động, backend kích hoạt mẫu cũ đang chờ của tài khoản
và nhân viên còn hoạt động, đúng liên kết, đúng model; không mở lại mẫu đã thu
hồi. Admin vẫn có thể thu hồi mẫu. Nhân viên có thể chọn **Đăng ký lại khuôn mặt**,
đồng ý thay mẫu và thực hiện lại hướng dẫn camera. Backend giữ nguyên mẫu cũ khi
hủy hoặc khi mẫu mới không hợp lệ; chỉ thu hồi mẫu cũ và kích hoạt mẫu mới trong
cùng một giao dịch sau khi kiểm tra thành công. Lịch sử thay mẫu được ghi audit.
Nút **Tải lại trạng thái khuôn mặt** chỉ đọc lại trạng thái, có phản hồi đang tải,
thành công và lỗi; không mở camera hoặc thay mẫu.
Chấm công kiosk giữ kiểm tra so khớp, độ phân biệt và trạng thái hoạt động.

Luồng camera hiển thị tiến trình từng bước. Đăng ký/đăng ký lại vẫn yêu cầu chớp
mắt và quay đầu theo thứ tự challenge, rồi lấy mẫu thứ hai khi nhìn thẳng. Mất
dấu ngắn dưới 1,2 giây giữ bước đang làm; mất dấu lâu hoặc xuất hiện nhiều người
sẽ bắt đầu lại. Tracking ID thay đổi ở cùng vị trí không tự coi là đổi người;
hai vector đầu/cuối vẫn phải đạt ngưỡng nhất quán 0,45 như backend. Đây là kiểm
tra chuyển động cơ bản, không phải giải pháp chống giả mạo chuyên dụng.

Camera phân tích ưu tiên 640×480 (chọn độ phân giải gần nhất nếu thiết bị không
hỗ trợ), ML Kit FAST với landmarks và phân loại mắt. Khoảng lấy mẫu tối thiểu
80 ms, xử lý từng frame và bỏ backlog; tốc độ thực tế còn tùy webcam/CPU máy ảo.
Không tải ảnh/video lên máy chủ. Các quyết định tiến trình có unit test Android
trong `FaceCaptureFlowTest`.

## 13. Gán NFC bằng Excel (đã triển khai)

Cột tùy chọn `uid_the` cho phép tạo tài khoản và gán thẻ đồng thời. Nhân viên cũ
đúng mã/email chưa có thẻ có thể được gán mà không đổi mật khẩu hoặc gửi lại thư.
UID phải là ô Text, hexadecimal đầy đủ; kiểm tra trùng trong file và database,
không tự chuyển chủ, mở khóa hoặc thay thẻ đang dùng. Bảng xem trước hiển thị UID,
số thẻ sẽ gán và lỗi; xác nhận nhập ghi nguyên tử, hỗ trợ thử lại an toàn.
Xem [quy tắc và chuẩn bị UID](NHAP_NHAN_VIEN_EXCEL.md#gán-thẻ-nfc-hàng-loạt-qua-excel).
Luồng nhân viên tự liên kết ở mục 11 vẫn chỉ là đề xuất.

## 14. Đồng bộ hồ sơ theo mẫu nhanvien.xlsx

Dùng cột Phòng ban của từng nhân viên, không lấy tên sheet làm phòng ban. Khi mã
NV và email khớp tài khoản hiện tại, xem trước các trường thay đổi rồi cập nhật
hồ sơ và gán UID mới (nếu chưa có thẻ), giữ mật khẩu, mẫu mặt, trạng thái và lịch
sử công. Ô tùy chọn trống không xóa dữ liệu cũ. UID xung đột chặn cả giao dịch.
Nhân viên xem hồ sơ đầy đủ và UID đang hoạt động trên màn hình chính, có nút tải
lại để nhận dữ liệu mới sau khi Admin đồng bộ.

## 15. Giao diện quản lý và nhân viên (31/10/2026)

Giao diện Material 3 dùng nền xám nhẹ, thẻ nội dung, màu xanh dương và hỗ trợ
sáng/tối. Dashboard Admin có menu bên trái trên màn hình rộng, điều hướng dưới
trên điện thoại; giữ phân quyền Admin/Quản lý. Bốn chỉ số gồm đang trong ca,
đi trễ, chưa vào ca và cần kiểm tra được tính theo ngày đang chọn, không giả lập.
Có tìm mã/tên, lọc trạng thái, bảng công trên desktop và thẻ chi tiết trên mobile.
Hoạt động gần nhất hiển thị lượt gần nhất của mỗi người; thông báo lượt mới và
cơ chế tự tải lại sau khoảng 2 giây vẫn hoạt động. Các khoảng vào–ra được xem
trong chi tiết, giờ đang làm là tạm tính và không đổi quy tắc chốt lương.

Cổng nhân viên có bốn mục Hôm nay, Lịch sử, Lương của tôi, Cá nhân. Hôm nay lấy
bảng công của chính nhân viên cho ngày Việt Nam, tự cập nhật sau mỗi lần tải;
hiển thị giờ đã làm, còn thiếu, trạng thái, giờ vào/ra và dự kiến đủ công nếu có.
Khi mất mạng không hiển thị số giờ giả; giữ dữ liệu cũ kèm cảnh báo hoặc cho thử
lại nếu chưa có dữ liệu. Hồ sơ, thẻ NFC và đăng ký mặt nằm trong mục Cá nhân.
Không thêm thao tác chấm công cá nhân ngoài kiosk.

Nhập Excel được phân thành Chọn file → Kiểm tra → Kết quả; chọn file/xem trước
không ghi dữ liệu. Kiosk giữ cơ chế quét hiện tại, tăng kích thước nút vào/ra bằng
mặt và khoảng cách để dễ thao tác. Không thay đổi logic NFC, model mặt hoặc DB.

Bổ sung bản 1.0.1: màn hình Điểm chấm công (kiosk) có thẻ thời gian, trạng thái
mạng/hàng đợi riêng, khu vực Chạm thẻ NFC với trạng thái sẵn sàng đọc, và nút vào/
ra lớn khi chọn khuôn mặt. Bố cục có cuộn cho màn hình nhỏ; giữ cơ chế quét,
đăng xuất có xác nhận và cấu hình kiosk đang lưu trên máy.
