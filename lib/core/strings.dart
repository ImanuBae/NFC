/// UI Strings in Vietnamese (class S)
/// No UI strings should be hardcoded in widgets.
class S {
  S._();

  // App & Common
  static const appTitle = 'NFC Attendance';
  static const configErrorTitle = 'Lỗi cấu hình';
  static const configErrorMsg =
      'Thiếu API_BASE_URL. Vui lòng chạy app với --dart-define-from-file=config.local.json.';
  static const retry = 'Thử lại';
  static const save = 'Lưu';
  static const cancel = 'Hủy';
  static const close = 'Đóng';
  static const confirm = 'Xác nhận';
  static const error = 'Lỗi';
  static const success = 'Thành công';
  static const loading = 'Đang tải...';
  static const unknownError = 'Đã có lỗi không xác định xảy ra';
  static const logout = 'Đăng xuất';
  static const login = 'Đăng nhập';

  // Auth
  static const loginTitle = 'Đăng nhập hệ thống';
  static const email = 'Email';
  static const password = 'Mật khẩu';
  static const emailEmpty = 'Vui lòng nhập email';
  static const passwordEmpty = 'Vui lòng nhập mật khẩu';
  static const loginFailed = 'Email hoặc mật khẩu không chính xác';
  static const noRoleAssigned = 'Tài khoản chưa được phân quyền trong hệ thống';

  // Kiosk Setup & Idle
  static const kioskSetupTitle = 'Thiết lập Kiosk';
  static const deviceName = 'Tên thiết bị';
  static const deviceNameEmpty = 'Vui lòng nhập tên thiết bị kiosk';
  static const registerDevice = 'Kích hoạt thiết bị';
  static const tapCardPrompt = 'Quẹt thẻ để chấm công';
  static const onlineStatus = 'Trực tuyến';
  static const offlineStatus = 'Ngoại tuyến';
  static const pendingScansFormat = 'Đang chờ đồng bộ: %d';
  static const nfcDisabledWarning = 'NFC đang tắt hoặc không được hỗ trợ';
  static const openSettings = 'Cài đặt NFC';
  static const enterPinToExit = 'Nhập mã PIN để thoát';
  static const pin = 'Mã PIN';
  static const wrongPin = 'Mã PIN không đúng';
  static const fakeNfcButton = 'Giả lập quẹt thẻ';
  static const selectSampleUid = 'Chọn UID mẫu:';

  // Kiosk Results
  static const welcomePrefix = 'Xin chào, ';
  static const goodbyePrefix = 'Tạm biệt, ';
  static const invalidCard = 'Thẻ không hợp lệ';
  static const alreadyScanned = 'Bạn vừa quẹt xong rồi';
  static const scanQueuedOffline = 'Đã ghi nhận (offline), sẽ đồng bộ sau';
  static const scanDuplicate = 'Lượt quẹt đã được ghi nhận trước đó';

  // Admin Navigation
  static const navAttendance = 'Bảng công';
  static const navEmployees = 'Nhân viên';
  static const navEvents = 'Sự kiện';

  // Admin Employees
  static const employeesListTitle = 'Danh sách nhân viên';
  static const addEmployee = 'Thêm nhân viên';
  static const editEmployee = 'Sửa nhân viên';
  static const employeeCode = 'Mã nhân viên';
  static const employeeName = 'Họ và tên';
  static const employeeStatus = 'Trạng thái hoạt động';
  static const codeEmpty = 'Vui lòng nhập mã nhân viên';
  static const nameEmpty = 'Vui lòng nhập họ và tên';
  static const employeeDetail = 'Chi tiết nhân viên';
  static const cardsList = 'Danh sách thẻ';
  static const assignCard = 'Gán thẻ';
  static const noCards = 'Chưa có thẻ nào được gán';
  static const cardActive = 'Đang hoạt động';
  static const cardLocked = 'Đang bị khóa';
  static const lockCard = 'Khóa thẻ';
  static const unlockCard = 'Mở khóa thẻ';
  static const active = 'Hoạt động';
  static const inactive = 'Tạm dừng';
  static const searchEmployees = 'Tìm nhân viên theo tên hoặc mã';

  // Admin Assign Card
  static const tapCardToRead = 'Quẹt thẻ để đọc UID';
  static const readingCard = 'Đang chờ đọc thẻ NFC...';
  static const manualUid = 'Nhập UID thủ công';
  static const uidEmpty = 'Vui lòng nhập hoặc quẹt thẻ để lấy UID';
  static const cardAlreadyExists = 'Thẻ này đã tồn tại trong hệ thống';

  // Admin Attendance & Events
  static const selectDate = 'Chọn ngày';
  static const checkIn = 'Giờ vào';
  static const checkOut = 'Giờ ra';
  static const totalHours = 'Tổng giờ';
  static const lateBadge = 'Trễ';
  static const missingCheckoutBadge = 'Thiếu check-out';
  static const noAttendanceData = 'Không có dữ liệu chấm công cho ngày này';
  static const eventsListTitle = 'Lịch sử sự kiện';
  static const sourceNfc = 'NFC';
  static const sourceManual = 'Thủ công';
  static const voidEvent = 'Hủy sự kiện (Void)';
  static const voidReason = 'Lý do hủy';
  static const voidReasonEmpty = 'Vui lòng nhập lý do hủy';
  static const addManualEvent = 'Thêm sự kiện tay';
  static const eventType = 'Loại sự kiện';
  static const eventTime = 'Thời điểm';
  static const voided = 'Đã hủy';
}
