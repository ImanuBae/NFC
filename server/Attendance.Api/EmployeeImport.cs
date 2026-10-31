using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using static Attendance.Api.Business;

namespace Attendance.Api;

public record ImportedCredential(string Code, string FullName, string Email, string Password);
public record EmployeeImportResult(Guid ImportId, int CreatedCount, int SkippedCount, List<ImportedCredential> Credentials, int CardsAssignedCount = 0, int UpdatedCount = 0);

public static class EmployeeImport
{
    // Blank optional cells preserve existing values. Code/email identify the employee;
    // never change account ownership, password, activity or biometrics from a workbook.
    public static List<string> ProfileChanges(Employee employee, EmployeeImportRow row)
    {
        var fields = new List<string>();
        if (employee.FullName != row.FullName) fields.Add("Họ và tên");
        if (employee.Email != row.Email) fields.Add("Email hồ sơ");
        if (row.Department != null && employee.Department != row.Department) fields.Add("Phòng ban");
        if (row.JobTitle != null && employee.JobTitle != row.JobTitle) fields.Add("Chức vụ");
        if (row.Phone != null && employee.Phone != row.Phone) fields.Add("Số điện thoại");
        if (row.HireDate != null && employee.HireDate != DateOnly.Parse(row.HireDate)) fields.Add("Ngày vào làm");
        if (row.HasHourlyRate && employee.HourlyRate != row.HourlyRate) fields.Add("Đơn giá giờ");
        return fields;
    }

    public static void ApplyProfile(Employee employee, EmployeeImportRow row)
    {
        employee.FullName = row.FullName;
        employee.Email = row.Email;
        if (row.Department != null) employee.Department = row.Department;
        if (row.JobTitle != null) employee.JobTitle = row.JobTitle;
        if (row.Phone != null) employee.Phone = row.Phone;
        if (row.HireDate != null) employee.HireDate = DateOnly.Parse(row.HireDate);
        if (row.HasHourlyRate) employee.HourlyRate = row.HourlyRate;
    }

    static void Admin(HttpContext context)
    {
        Require(((Account)context.Items["account"]!).Role == "admin");
        context.Response.Headers.CacheControl = "no-store";
    }
    public static async Task ValidateExisting(AttendanceDb db, List<EmployeeImportRow> rows)
    {
        var employees = await db.Employees.AsNoTracking().ToListAsync();
        var accounts = await db.Accounts.AsNoTracking().ToListAsync();
        var cards = await db.Cards.AsNoTracking().ToListAsync();
        foreach (var row in rows)
        {
            var employee = employees.FirstOrDefault(e => string.Equals(e.Code, row.Code, StringComparison.OrdinalIgnoreCase));
            var account = accounts.FirstOrDefault(a => string.Equals(a.Email, row.Email, StringComparison.OrdinalIgnoreCase));
            if (employee != null && account?.EmployeeId == employee.Id && account.Role == "employee")
            {
                row.UpdatedFields = ProfileChanges(employee, row);
                row.Status = row.UpdatedFields.Count > 0 ? "update" : "skip";
                if (row.UpdatedFields.Count > 0 && (!employee.Active || !account.Active))
                    row.Errors.Add("Nhân viên hoặc tài khoản đã ngừng hoạt động; không cập nhật qua Excel.");
                row.Warnings.Add(row.UpdatedFields.Count > 0
                    ? "Cập nhật: " + string.Join(", ", row.UpdatedFields) + ". Giữ mật khẩu, mẫu mặt và lịch sử công; không gửi lại email."
                    : "Mã NV và email đã có, thông tin không đổi. Giữ nguyên hồ sơ và mật khẩu hiện tại.");
            }
            else
            {
                if (employee != null) row.Errors.Add("Mã NV đã tồn tại với tài khoản khác hoặc chưa có tài khoản. Kiểm tra hồ sơ hiện tại trước khi nhập.");
                if (account != null) row.Errors.Add("Email đã được dùng bởi tài khoản khác.");
                if (employees.Any(e => e.Id != employee?.Id && string.Equals(e.Email, row.Email, StringComparison.OrdinalIgnoreCase)))
                    row.Errors.Add("Email đã được gán cho hồ sơ nhân viên khác.");
            }
            if (row.UidThe != null)
            {
                var card = cards.FirstOrDefault(c => c.Uid == row.UidThe);
                if (card != null && (employee == null || card.EmployeeId != employee.Id))
                    row.Errors.Add("UID thẻ đã thuộc nhân viên khác; không tự chuyển chủ thẻ.");
                else if (card != null && !card.Active)
                    row.Errors.Add("UID thẻ đã bị khóa/thu hồi; không tự kích hoạt lại qua Excel.");
                else if (row.Status is "skip" or "update" && card == null)
                {
                    if (!employee!.Active || !account!.Active)
                        row.Errors.Add("Tài khoản hoặc nhân viên đã ngừng hoạt động; không thể gán thẻ.");
                    else if (cards.Any(c => c.EmployeeId == employee.Id && c.Active))
                        row.Errors.Add("Nhân viên đã có thẻ đang hoạt động. Dùng luồng thay thẻ, không gán thêm qua Excel.");
                    else
                    {
                        row.NeedsCard = true;
                        if (row.Status == "skip") row.Status = "link_card";
                        row.Warnings.Add("Gán UID đã cấp cho nhân viên này; giữ nguyên mật khẩu, không gửi lại email.");
                    }
                }
            }
            if (row.Status == "create" && row.UidThe != null) row.NeedsCard = true;
            if (row.Errors.Count > 0) row.Status = "error";
        }
    }

    public static void Register(WebApplication app)
    {
        app.MapGet("/api/employees/import/recent", async (HttpContext context, AttendanceDb db, IDataProtectionProvider protection) =>
        {
            Admin(context);
            var actor = (Account)context.Items["account"]!;
            var since = DateTimeOffset.UtcNow.AddHours(-24);
            var batches = await db.EmployeeImports.AsNoTracking().Where(b => b.CreatedBy == actor.Id && b.CreatedAt > since)
                .OrderByDescending(b => b.CreatedAt).Take(10).ToListAsync();
            var protector = protection.CreateProtector("Attendance.EmployeeImport.Credentials.v1");
            return batches.Select(b => {
                var result = JsonSerializer.Deserialize<EmployeeImportResult>(protector.Unprotect(b.ProtectedResult))!;
                return new { b.Id, b.CreatedAt, created_count = result.CreatedCount, cards_assigned_count = result.CardsAssignedCount, updated_count = result.UpdatedCount };
            });
        });
        app.MapGet("/api/employees/import/template", (HttpContext context) =>
        {
            Admin(context);
            return new { file_name = "mau_danh_sach_nhan_vien.xlsx", content_base64 = Convert.ToBase64String(EmployeeSpreadsheet.Write([["DANH SÁCH NHÂN VIÊN"], [], EmployeeSpreadsheet.Headers], "Kinh doanh")) };
        });
        app.MapPost("/api/employees/import/preview", async (EmployeeUpload upload, HttpContext context, AttendanceDb db) =>
        {
            Admin(context);
            var ignoredSheets = new List<string>();
            var rows = EmployeeSpreadsheet.Read(EmployeeSpreadsheet.Decode(upload), upload.Department, ignoredSheets);
            await ValidateExisting(db, rows);
            return new
            {
                rows, ignored_sheets = ignoredSheets, create_count = rows.Count(r => r.Status == "create"), skip_count = rows.Count(r => r.Status == "skip"),
                error_count = rows.Count(r => r.Status == "error"),
                update_count = rows.Count(r => r.Status == "update"),
                card_count = rows.Count(r => r.NeedsCard && r.Status != "error"),
                can_import = rows.Any(r => r.Status is "create" or "link_card" or "update") && rows.All(r => r.Status != "error")
            };
        });
        app.MapPost("/api/employees/import/commit", async (EmployeeUpload upload, HttpContext context, AttendanceDb db, IDataProtectionProvider protection) =>
        {
            Admin(context);
            var actor = (Account)context.Items["account"]!;
            Require(upload.ImportId.HasValue && upload.ImportId.Value != Guid.Empty, "Thiếu mã lần nhập.", 400);
            var bytes = EmployeeSpreadsheet.Decode(upload);
            var payloadHash = Convert.ToHexString(SHA256.HashData(bytes.Concat(Encoding.UTF8.GetBytes("\n" + upload.Department?.Trim())).ToArray()));
            var protector = protection.CreateProtector("Attendance.EmployeeImport.Credentials.v1");
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var prior = await db.EmployeeImports.SingleOrDefaultAsync(b => b.Id == upload.ImportId);
            if (prior != null)
            {
                Require(prior.CreatedBy == actor.Id, "Lần nhập này thuộc quản trị viên khác.", 403);
                Require(prior.PayloadHash == payloadHash, "Mã lần nhập đã được dùng cho file khác.", 409);
                Require(prior.CreatedAt > DateTimeOffset.UtcNow.AddHours(-24), "Lần nhập đã hoàn tất hơn 24 giờ trước. Không tạo lại tài khoản; xem danh sách nhân viên hoặc đặt lại mật khẩu nếu cần.", 409);
                return JsonSerializer.Deserialize<EmployeeImportResult>(protector.Unprotect(prior.ProtectedResult))!;
            }
            var rows = EmployeeSpreadsheet.Read(bytes, upload.Department);
            await ValidateExisting(db, rows);
            Require(rows.All(r => r.Status != "error"), "Danh sách có lỗi hoặc dữ liệu đã thay đổi. Xem trước lại và sửa các dòng lỗi; chưa nhập nhân viên nào.", 409);
            var credentials = new List<ImportedCredential>();
            var cardsAssigned = 0;
            foreach (var row in rows.Where(r => r.Status == "create"))
            {
                var employee = new Employee
                {
                    Code = row.Code, FullName = row.FullName, Email = row.Email, Department = row.Department,
                    JobTitle = row.JobTitle, Phone = row.Phone, HireDate = row.HireDate == null ? null : DateOnly.Parse(row.HireDate),
                    HourlyRate = row.HourlyRate
                };
                var account = new Account { Email = row.Email, Role = "employee", EmployeeId = employee.Id, MustChangePassword = true };
                var password = OnboardingMessage.InitialPassword;
                account.PasswordHash = new PasswordHasher<Account>().HashPassword(account, password);
                db.Employees.Add(employee); db.Accounts.Add(account);
                if (row.UidThe != null)
                {
                    db.Cards.Add(new() { Uid = row.UidThe, EmployeeId = employee.Id });
                    cardsAssigned++;
                }
                db.OnboardingEmails.Add(new() { ImportId = upload.ImportId!.Value, AccountId = account.Id,
                    EmployeeId = employee.Id, FullName = row.FullName, Recipient = row.Email });
                credentials.Add(new(row.Code, row.FullName, row.Email, password));
            }
            foreach (var row in rows.Where(r => r.Status is "link_card" or "update"))
            {
                var employee = await db.Employees.SingleAsync(e => e.Code == row.Code);
                if (row.Status == "update") ApplyProfile(employee, row);
                if (row.NeedsCard)
                {
                    db.Cards.Add(new() { Uid = row.UidThe!, EmployeeId = employee.Id });
                    cardsAssigned++;
                }
            }
            var result = new EmployeeImportResult(upload.ImportId!.Value, credentials.Count, rows.Count(r => r.Status == "skip"), credentials, cardsAssigned, rows.Count(r => r.Status == "update"));
            // Encrypted receipt permits safe retries after a lost response without duplicating accounts or resetting passwords.
            db.EmployeeImports.Add(new() { Id = result.ImportId, CreatedBy = actor.Id, PayloadHash = payloadHash, ProtectedResult = protector.Protect(JsonSerializer.Serialize(result)) });
            db.Audits.Add(new() { Actor = actor.Id, Action = "import_employees", Detail = $"{result.ImportId}: created={result.CreatedCount}; updated={result.UpdatedCount}; skipped={result.SkippedCount}; cards={cardsAssigned}" });
            await db.SaveChangesAsync(); await tx.CommitAsync();
            return result;
        });
        app.MapGet("/api/employees/import/email-settings", (HttpContext context, IConfiguration config) =>
        {
            Admin(context);
            return new { configured = OnboardingEmailService.Configured(config),
                provider = EmailDeliveryService.Provider(config),
                message = OnboardingEmailService.Configured(config) ? "Đã có cấu hình dịch vụ gửi email." : "Chưa cấu hình đầy đủ Gmail gửi và mật khẩu ứng dụng. Tài khoản vẫn được tạo; email chờ cấu hình trên máy chủ." };
        });
        app.MapPost("/api/employees/import/email-test", async (HttpContext context, EmailDeliveryService delivery) =>
        {
            Admin(context);
            try { await delivery.VerifySmtp(context.RequestAborted); }
            catch (EmailDeliveryFailure e) { throw new ApiError(e.Message, 400); }
            return new { status = "connected", message = "Đã đăng nhập Gmail SMTP thành công. Chưa gửi thư thử." };
        });
        app.MapGet("/api/employees/import/{id:guid}/emails", async (Guid id, HttpContext context, AttendanceDb db, IConfiguration config) =>
        {
            Admin(context);
            var actor = (Account)context.Items["account"]!;
            Require(await db.EmployeeImports.AnyAsync(b => b.Id == id && b.CreatedBy == actor.Id), "Không tìm thấy lần nhập của bạn.", 404);
            var rows = await db.OnboardingEmails.AsNoTracking().Where(j => j.ImportId == id).OrderBy(j => j.Recipient)
                .Select(j => new { j.Id, j.Recipient, j.Status, j.Attempts, j.LastError, j.SentAt }).ToListAsync();
            return new { configured = OnboardingEmailService.Configured(config), provider = EmailDeliveryService.Provider(config), rows };
        });
        app.MapPost("/api/employees/import/{id:guid}/emails/retry", async (Guid id, HttpContext context, AttendanceDb db, IConfiguration config) =>
        {
            Admin(context);
            var actor = (Account)context.Items["account"]!;
            Require(await db.EmployeeImports.AnyAsync(b => b.Id == id && b.CreatedBy == actor.Id), "Không tìm thấy lần nhập của bạn.", 404);
            Require(OnboardingEmailService.Configured(config), "Cần cấu hình dịch vụ gửi email trên máy chủ trước khi thử lại.", 400);
            var now = DateTimeOffset.UtcNow;
            var queued = await db.OnboardingEmails.Where(j => j.ImportId == id && (j.Status == "failed" || j.Status == "pending")
                && (j.FirstAttemptAt == null || j.FirstAttemptAt > now.AddHours(-23)))
                .ExecuteUpdateAsync(s => s.SetProperty(j => j.Status, "pending").SetProperty(j => j.Attempts, 0)
                    .SetProperty(j => j.NextAttemptAt, now).SetProperty(j => j.LeaseUntil, (DateTimeOffset?)null).SetProperty(j => j.LastError, (string?)null));
            return new { queued };
        });
        app.MapGet("/api/employees/import/{id:guid}/credentials", async (Guid id, HttpContext context, AttendanceDb db, IDataProtectionProvider protection) =>
        {
            Admin(context);
            var actor = (Account)context.Items["account"]!;
            var batch = await db.EmployeeImports.AsNoTracking().SingleOrDefaultAsync(b => b.Id == id && b.CreatedBy == actor.Id);
            Require(batch != null, "Không tìm thấy lần nhập của bạn.", 404);
            Require(batch!.CreatedAt > DateTimeOffset.UtcNow.AddHours(-24), "Đã hết hạn tải mật khẩu khởi tạo (24 giờ). Admin có thể đặt lại mật khẩu trong Tài khoản & thiết bị.", 409);
            var result = JsonSerializer.Deserialize<EmployeeImportResult>(protection.CreateProtector("Attendance.EmployeeImport.Credentials.v1").Unprotect(batch.ProtectedResult))!;
            // Values stay text cells even if names begin with '=' or '+'. No formulas in downloads.
            var rows = new List<IReadOnlyList<string>> { new[] { "Mã NV", "Họ và tên", "Email đăng nhập", "Mật khẩu khởi tạo" } };
            rows.AddRange(result.Credentials.Select(c => (IReadOnlyList<string>)new[] { c.Code, c.FullName, c.Email, c.Password }));
            return new { file_name = "tai_khoan_nhan_vien.xlsx", content_base64 = Convert.ToBase64String(EmployeeSpreadsheet.Write(rows, "Tai khoan")) };
        });
    }
}
