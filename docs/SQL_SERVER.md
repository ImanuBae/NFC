# Sử dụng SSMS

SSMS là công cụ quản trị; hệ quản trị dữ liệu của project là Microsoft SQL Server.
Chọn Database Engine → Server name `localhost` → Windows Authentication → Connect.
Refresh **Databases**, mở **NfcAttendance**.

Xem dữ liệu bằng New Query:

```sql
USE NfcAttendance;
SELECT Id, Code, FullName, Active, HourlyRate FROM Employees;
SELECT Id, Email, Role, Active, EmployeeId FROM Accounts;
SELECT Uid, EmployeeId, Active FROM Cards;
SELECT TOP (100) Id, EmployeeId, Type, OccurredAt, Source, VoidedAt
FROM Events ORDER BY OccurredAt DESC;
SELECT Id, UserId, EmployeeId, Approved, Revoked FROM Faces;
SELECT Id, StartDate, EndDate, Period FROM PayrollRuns;
```

Không xuất `PasswordHash`, `Embedding` hoặc session token cho bài thuyết trình.
Tài khoản Kiosk phải có `EmployeeId = NULL`, được ràng buộc bằng check constraint.

API lấy kết nối từ `ConnectionStrings:Attendance` trong `server/Attendance.Api/appsettings.json`.
Nếu máy khác dùng instance `SQLEXPRESS`, thay bằng `Server=localhost\\SQLEXPRESS` trong JSON.
Không đổi mật khẩu/quyền SQL trên các database khác của máy để chạy project.

Database trống được tạo bằng EF Core `EnsureCreated` khi API chạy lần đầu. Script schema
trong `server/sql/001_schema.sql` là bản tương ứng để kiểm tra bằng SSMS. Không chạy lại
script tạo bảng trên database đang có dữ liệu. Các thay đổi schema sau này cần migration riêng.

Số liệu đã nhập từ hệ cũ tại thời điểm chuyển: 3 nhân viên, 3 thẻ, 11 lượt công,
1 mẫu khuôn mặt và 6 tài khoản. Không chuyển phiên đăng nhập và khóa vân tay đã bỏ.
Tài khoản Kiosk đã tách khỏi hồ sơ nhân viên; lịch sử gốc giữ nguyên.
