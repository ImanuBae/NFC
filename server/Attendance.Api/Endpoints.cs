using System.Data;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using static Attendance.Api.Business;

namespace Attendance.Api;

public static class Endpoints
{
    static Account Actor(HttpContext c) => (Account)c.Items["account"]!;
    static string Text(JsonElement b, string key, int max = 200) { var v = b.GetProperty(key).GetString()?.Trim(); Require(!string.IsNullOrEmpty(v) && v.Length <= max, $"Thiếu hoặc sai trường {key}.", 400); return v!; }
    static Guid? Id(JsonElement b, string key) => b.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String && Guid.TryParse(v.GetString(), out var id) ? id : null;
    static void StaffOnly(HttpContext c) => Require(Staff(Actor(c)));
    static void Admin(HttpContext c) => Require(Actor(c).Role == "admin");
    static void Own(HttpContext c, Guid id) => Require(Staff(Actor(c)) || Actor(c).EmployeeId == id);
    public static void Register(WebApplication app)
    {
        app.MapGet("/health", async (AttendanceDb db) => new { status = "ok", database = await db.Database.CanConnectAsync() ? "SQL Server" : "unavailable" });
        app.MapPost("/api/auth/login", async (JsonElement b, AttendanceDb db) =>
        {
            var email = Text(b, "email", 254).ToLowerInvariant(); var password = b.GetProperty("password").GetString() ?? "";
            var a = await db.Accounts.SingleOrDefaultAsync(a => a.Email == email && a.Active);
            Require(a != null && new PasswordHasher<Account>().VerifyHashedPassword(a, a.PasswordHash, password) != PasswordVerificationResult.Failed, "Invalid login credentials", 401);
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)); db.Sessions.Add(new() { AccountId = a!.Id, TokenHash = Hash(token), ExpiresAt = DateTimeOffset.UtcNow.AddDays(7) }); await db.SaveChangesAsync(); return new { token, user = a };
        }).RequireRateLimiting("login");
        app.MapGet("/api/auth/me", (HttpContext c) => Actor(c));
        app.MapPost("/api/auth/change-password", async (JsonElement b, HttpContext c, AttendanceDb db) =>
        {
            Require(Actor(c).Role is "employee" or "manager" or "admin");
            var current = b.GetProperty("current_password").GetString() ?? "";
            var replacement = b.GetProperty("new_password").GetString() ?? "";
            Require(replacement.Length is >= 8 and <= 128 && !string.IsNullOrWhiteSpace(replacement), "Mật khẩu mới cần từ 8 đến 128 ký tự.", 400);
            Require(replacement != OnboardingMessage.InitialPassword && replacement != current, "Chọn mật khẩu mới khác mật khẩu hiện tại và mật khẩu mặc định.", 400);
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var account = await db.Accounts.SingleAsync(a => a.Id == Actor(c).Id && a.Active);
            var hasher = new PasswordHasher<Account>();
            Require(hasher.VerifyHashedPassword(account, account.PasswordHash, current) != PasswordVerificationResult.Failed, "Mật khẩu hiện tại không đúng.", 400);
            account.PasswordHash = hasher.HashPassword(account, replacement); account.MustChangePassword = false;
            var currentSession = (string)c.Items["token_hash"]!;
            await db.Sessions.Where(s => s.AccountId == account.Id && s.TokenHash != currentSession).ExecuteDeleteAsync();
            await db.OnboardingEmails.Where(j => j.AccountId == account.Id && (j.Status == "pending" || j.Status == "failed"))
                .ExecuteUpdateAsync(s => s.SetProperty(j => j.Status, "cancelled")
                    .SetProperty(j => j.LastError, "Nhân viên đã đổi mật khẩu; không gửi thông tin đăng nhập cũ."));
            db.Audits.Add(new() { Actor = account.Id, Action = "change_own_password", Detail = "Password changed; other sessions revoked." });
            await db.SaveChangesAsync(); await tx.CommitAsync(); return new { status = "ok" };
        });
        app.MapPost("/api/auth/logout", async (HttpContext c, AttendanceDb db) => { await db.Sessions.Where(s => s.TokenHash == (string)c.Items["token_hash"]!).ExecuteDeleteAsync(); return new { status = "ok" }; });
        app.MapGet("/api/employees", async (HttpContext c, AttendanceDb db, string? query, bool? active) =>
        {
            var a = Actor(c); var q = db.Employees.AsNoTracking().AsQueryable(); if (!Staff(a)) q = q.Where(e => e.Id == a.EmployeeId); if (active != null) q = q.Where(e => e.Active == active);
            if (!string.IsNullOrWhiteSpace(query)) q = q.Where(e => e.Code.Contains(query) || e.FullName.Contains(query) || (e.Department != null && e.Department.Contains(query)) || (e.Email != null && e.Email.Contains(query))); return await q.OrderBy(e => e.Code).ToListAsync();
        });
        app.MapGet("/api/employees/{id:guid}", async (Guid id, HttpContext c, AttendanceDb db) => { Own(c, id); return await db.Employees.AsNoTracking().SingleOrDefaultAsync(e => e.Id == id); });
        app.MapPost("/api/employees", (JsonElement b, HttpContext c, AttendanceDb db) => SaveEmployee(null, b, c, db));
        app.MapPut("/api/employees/{id:guid}", (Guid id, JsonElement b, HttpContext c, AttendanceDb db) => SaveEmployee(id, b, c, db));
        app.MapGet("/api/cards", async (HttpContext c, AttendanceDb db, Guid? employeeId, string? uid) =>
        {
            var a = Actor(c); var q = db.Cards.AsNoTracking().AsQueryable(); if (!Staff(a)) q = q.Where(x => x.EmployeeId == a.EmployeeId); if (employeeId != null) q = q.Where(x => x.EmployeeId == employeeId); if (uid != null) q = q.Where(x => x.Uid == uid.ToUpper()); return await q.OrderByDescending(x => x.CreatedAt).ToListAsync();
        });
        app.MapPost("/api/cards", async (JsonElement b, HttpContext c, AttendanceDb db) =>
        {
            Admin(c); var uid = Text(b, "uid", 64).ToUpperInvariant(); Require(uid.All(Uri.IsHexDigit), "UID không hợp lệ.", 400); var employee = b.GetProperty("employee_id").GetGuid(); Require(await db.Employees.AnyAsync(e => e.Id == employee && e.Active), "Nhân viên không hợp lệ.", 400);
            var card = new Card { Uid = uid, EmployeeId = employee }; db.Cards.Add(card); await db.SaveChangesAsync(); return card;
        });
        app.MapPut("/api/cards/{uid}", async (string uid, JsonElement b, HttpContext c, AttendanceDb db) => { Admin(c); var card = await db.Cards.SingleAsync(x => x.Uid == uid); card.Active = b.GetProperty("active").GetBoolean(); await db.SaveChangesAsync(); return card; });
        app.MapGet("/api/attendance/events", async (HttpContext c, AttendanceDb db, Guid? employeeId, DateOnly? date) =>
        {
            var a = Actor(c); var q = db.Events.AsNoTracking().AsQueryable(); if (!Staff(a)) { Require(employeeId == null || employeeId == a.EmployeeId); q = q.Where(e => e.EmployeeId == a.EmployeeId); }
            if (employeeId != null) q = q.Where(e => e.EmployeeId == employeeId);
            if (date != null) { var start = Bound(date.Value); var end = start.AddDays(1); q = q.Where(e => e.OccurredAt >= start && e.OccurredAt < end); }
            var rows = await q.OrderByDescending(e => e.OccurredAt).ToListAsync(); var employees = await db.Employees.AsNoTracking().ToDictionaryAsync(e => e.Id);
            return rows.Select(e => new { e.Id, e.EmployeeId, e.DeviceId, e.Type, e.OccurredAt, e.Source, e.Flag, e.VoidedAt, e.VoidReason, employees = new { code = employees[e.EmployeeId].Code, full_name = employees[e.EmployeeId].FullName } });
        });
        app.MapGet("/api/attendance/days", async (DateOnly date, HttpContext c, AttendanceDb db, AttendancePolicy policy) =>
        {
            var actor = Actor(c); Require(Staff(actor) || actor.Role == "employee");
            var start = Bound(date).AddHours(-16); var end = Bound(date).AddDays(1).AddHours(16);
            var query = db.Events.AsNoTracking().Where(e => e.OccurredAt >= start && e.OccurredAt < end);
            if (!Staff(actor)) query = query.Where(e => e.EmployeeId == actor.EmployeeId);
            var events = await query.ToListAsync();
            var employees = await db.Employees.AsNoTracking().Where(e => Staff(actor) || e.Id == actor.EmployeeId).OrderBy(e => e.Code).ToListAsync();
            var now = DateTimeOffset.UtcNow;
            return employees.Where(e => e.Active || events.Any(v => v.EmployeeId == e.Id))
                .Select(e => AttendanceSummary.Day(e.Id, date, events, e, policy, now)).ToList();
        });
        app.MapPost("/api/attendance/manual", async (JsonElement b, HttpContext c, AttendanceDb db) =>
        {
            StaffOnly(c); var at = b.GetProperty("occurred_at").GetDateTimeOffset(); Require(at <= DateTimeOffset.UtcNow, "Không ghi công tương lai.", 400); var employee = b.GetProperty("employee_id").GetGuid(); Require(await db.Employees.AnyAsync(e => e.Id == employee && e.Active), "Nhân viên không hoạt động.", 400);
            var type = Text(b, "type"); Require(type is "check_in" or "check_out", "Loại lượt không hợp lệ.", 400); var reason = Text(b, "reason", 1000);
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable); await ProtectPayroll(db, at); var e = new AttendanceEvent { EmployeeId = employee, Type = type, OccurredAt = at, Source = "manual", Flag = reason, CreatedBy = Actor(c).Id }; db.Events.Add(e); db.Audits.Add(new() { Actor = Actor(c).Id, Action = "manual_attendance", Detail = $"{e.Id}: {reason}" }); await db.SaveChangesAsync(); await tx.CommitAsync(); return new { e.Id };
        });
        app.MapPost("/api/attendance/{id:guid}/void", async (Guid id, JsonElement b, HttpContext c, AttendanceDb db) =>
        {
            StaffOnly(c); await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable); var e = await db.Events.SingleAsync(e => e.Id == id); await ProtectPayroll(db, e.OccurredAt); Require(e.VoidedAt == null, "Lượt đã hủy.", 409); e.VoidReason = Text(b, "reason", 1000); e.VoidedAt = DateTimeOffset.UtcNow; e.VoidedBy = Actor(c).Id; db.Audits.Add(new() { Actor = Actor(c).Id, Action = "void_attendance", Detail = $"{e.Id}: {e.VoidReason}" }); await db.SaveChangesAsync(); await tx.CommitAsync(); return new { status = "ok" };
        });
        app.MapPost("/api/devices", async (JsonElement b, HttpContext c, AttendanceDb db) => { Require(Actor(c).Role is "kiosk" or "admin"); var d = new Device { Name = Text(b, "name"), RegisteredBy = Actor(c).Id }; db.Devices.Add(d); await db.SaveChangesAsync(); return new { d.Id }; });
        app.MapPost("/api/scans", Scan);
        app.MapGet("/api/accounts", async (HttpContext c, AttendanceDb db) => { Admin(c); return await db.Accounts.AsNoTracking().OrderBy(a => a.Email).ToListAsync(); });
        app.MapGet("/api/faces", async (HttpContext c, AttendanceDb db) => { var a = Actor(c); return await db.Faces.AsNoTracking().Where(f => a.Role == "admin" || f.UserId == a.Id).OrderByDescending(f => f.CreatedAt).Select(f => new { f.Id, f.UserId, f.EmployeeId, f.Approved, f.Revoked, f.CreatedAt }).ToListAsync(); });
        app.MapGet("/api/reports", async (DateOnly start, DateOnly end, HttpContext c, AttendanceDb db) => { StaffOnly(c); return await Report(db, start, end, c.RequestServices.GetRequiredService<AttendancePolicy>()); });
        app.MapGet("/api/payroll/runs", async (HttpContext c, AttendanceDb db) => { var a = Actor(c); var staff = Staff(a); return await db.PayrollRuns.AsNoTracking().Where(r => staff || db.PayrollItems.Any(i => i.RunId == r.Id && i.EmployeeId == a.EmployeeId)).OrderByDescending(r => r.StartDate).ToListAsync(); });
        app.MapGet("/api/payroll/items", async (HttpContext c, AttendanceDb db, Guid? runId, Guid? employeeId) =>
        {
            var a = Actor(c); var q = db.PayrollItems.AsNoTracking().AsQueryable(); if (!Staff(a)) q = q.Where(i => i.EmployeeId == a.EmployeeId); if (runId != null) q = q.Where(i => i.RunId == runId); if (employeeId != null) q = q.Where(i => i.EmployeeId == employeeId);
            return await q.OrderBy(i => i.EmployeeCode).Join(db.PayrollRuns, i => i.RunId, r => r.Id, (i, r) => new { i.RunId, i.EmployeeId, i.EmployeeCode, i.EmployeeName, i.WorkedMinutes, i.HourlyRate, i.GrossPay, payroll_runs = new { r.StartDate, r.EndDate } }).ToListAsync();
        });
        app.MapPost("/api/payroll/close", ClosePayroll);
        app.MapPost("/api/business", (JsonElement b, HttpContext c, AttendanceDb db, IHttpClientFactory clients) => Action(b, c, db, clients, app.Configuration));
    }
    static async Task<Employee> SaveEmployee(Guid? id, JsonElement b, HttpContext c, AttendanceDb db)
    {
        Admin(c); await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable); var e = id == null ? new Employee() : await db.Employees.SingleAsync(e => e.Id == id); e.Code = Text(b, "code", 50); e.FullName = Text(b, "full_name"); e.Active = b.GetProperty("active").GetBoolean(); if (b.TryGetProperty("hourly_rate", out var rate)) e.HourlyRate = rate.GetDecimal(); Require(e.HourlyRate >= 0, "Đơn giá không hợp lệ.", 400); if (id == null) db.Employees.Add(e);
        if (!e.Active) { foreach (var card in await db.Cards.Where(x => x.EmployeeId == e.Id).ToListAsync()) card.Active = false; foreach (var f in await db.Faces.Where(x => x.EmployeeId == e.Id && !x.Revoked).ToListAsync()) f.Revoked = true; }
        db.Audits.Add(new() { Actor = Actor(c).Id, Action = "save_employee", Detail = e.Id.ToString() }); await db.SaveChangesAsync(); await tx.CommitAsync(); return e;
    }
    static async Task<IResult> Scan(JsonElement b, HttpContext c, AttendanceDb db)
    {
        var a = Actor(c); Require(a.Role is "kiosk" or "admin"); var device = b.GetProperty("device_id").GetGuid(); Require(await db.Devices.AnyAsync(d => d.Id == device && d.Active && (d.RegisteredBy == a.Id || a.Role == "admin")), "Unregistered or inactive device", 403);
        var scan = b.GetProperty("client_scan_id").GetGuid(); var uid = Text(b, "uid", 64).ToUpperInvariant(); var time = b.GetProperty("device_time").GetDateTimeOffset(); var replay = b.GetProperty("is_replay").GetBoolean(); var now = DateTimeOffset.UtcNow; Require(!replay || (time >= now.AddDays(-7) && time <= now.AddMinutes(5)), "Lượt offline ngoài giới hạn 7 ngày.", 400);
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable); if (await db.Events.AnyAsync(e => e.ClientScanId == scan)) return Results.Ok(new { status = "duplicate" });
        var card = await db.Cards.SingleOrDefaultAsync(x => x.Uid == uid && x.Active); var emp = card == null ? null : await db.Employees.SingleOrDefaultAsync(e => e.Id == card.EmployeeId && e.Active); if (emp == null) return Results.Ok(new { status = "rejected", reason = "unknown_or_inactive_card" });
        var at = replay && time < now ? time : now; var last = await db.Events.Where(e => e.EmployeeId == emp.Id && e.VoidedAt == null && e.OccurredAt <= at).OrderByDescending(e => e.OccurredAt).FirstOrDefaultAsync(); var type = last?.Type == "check_in" && at - last.OccurredAt <= TimeSpan.FromHours(16) ? "check_out" : "check_in";
        var result = await Record(db, a, emp, type, at, "nfc", device, scan, time); await tx.CommitAsync(); return Results.Ok(result);
    }
    static async Task<object> ClosePayroll(JsonElement b, HttpContext c, AttendanceDb db)
    {
        StaffOnly(c); var start = b.GetProperty("start").Deserialize<DateOnly>(); var period = Text(b, "period"); Require(period == "week" && start.DayOfWeek == DayOfWeek.Monday || period == "month" && start.Day == 1, "Kỳ lương phải bắt đầu thứ Hai hoặc đầu tháng.", 400); var end = period == "week" ? start.AddDays(7) : start.AddMonths(1); Require(end <= Today, "Kỳ lương chưa kết thúc.", 400);
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable); Require(!await db.PayrollRuns.AnyAsync(r => r.StartDate < end && r.EndDate > start), "Kỳ lương chồng với kỳ đã chốt.", 409); var rows = await Report(db, start, end, c.RequestServices.GetRequiredService<AttendancePolicy>()); Require(rows.All(r => r.MissingCheckout == 0), "Cần xử lý lượt thiếu giờ ra trước khi chốt.", 409);
        var run = new PayrollRun { StartDate = start, EndDate = end, Period = period, CreatedBy = Actor(c).Id }; db.PayrollRuns.Add(run); db.PayrollItems.AddRange(rows.Select(r => new PayrollItem { RunId = run.Id, EmployeeId = r.EmployeeId, EmployeeCode = r.Code, EmployeeName = r.FullName, WorkedMinutes = r.WorkedMinutes, HourlyRate = r.HourlyRate, GrossPay = r.GrossPay })); await db.SaveChangesAsync(); await tx.CommitAsync(); return new { run.Id };
    }
    static async Task<IResult> Action(JsonElement b, HttpContext c, AttendanceDb db, IHttpClientFactory clients, IConfiguration config)
    {
        var actor = Actor(c); var action = Text(b, "action");
        if (action == "save_account")
        {
            Admin(c); await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable); var id = Id(b, "id"); var a = id == null ? new Account() : await db.Accounts.SingleAsync(a => a.Id == id); var role = Text(b, "role"); Require(new[] { "admin", "manager", "employee", "kiosk" }.Contains(role), "Vai trò không hợp lệ.", 400); var employee = Id(b, "employee_id"); Require(role != "kiosk" || employee == null, "Tài khoản Kiosk không liên kết nhân viên.", 400); Require(role != "employee" || employee != null, "Chọn nhân viên.", 400); if (employee != null) Require(await db.Employees.AnyAsync(e => e.Id == employee), "Nhân viên không tồn tại.", 400);
            var active = b.GetProperty("active").GetBoolean(); Require(a.Id != actor.Id || (role == "admin" && active), "Không thể tự khóa/hạ quyền.", 400); var email = Text(b, "email", 254).ToLowerInvariant(); Require(System.Net.Mail.MailAddress.TryCreate(email, out _), "Email không hợp lệ.", 400); var password = b.TryGetProperty("password", out var pass) ? pass.GetString() : null;
            if (id == null || !string.IsNullOrEmpty(password)) { Require(password?.Length >= 12, "Mật khẩu tối thiểu 12 ký tự.", 400); a.PasswordHash = new PasswordHasher<Account>().HashPassword(a, password!); }
            if (a.Role != role || a.EmployeeId != employee || !active) foreach (var f in await db.Faces.Where(f => f.UserId == a.Id && !f.Revoked).ToListAsync()) f.Revoked = true;
            a.Email = email; a.Role = role; a.EmployeeId = employee; a.Active = active; if (id == null) db.Accounts.Add(a); if (employee != null) (await db.Employees.SingleAsync(e => e.Id == employee)).Email = email; if (!active || !string.IsNullOrEmpty(password)) await db.Sessions.Where(s => s.AccountId == a.Id).ExecuteDeleteAsync(); db.Audits.Add(new() { Actor = actor.Id, Action = "save_account", Detail = a.Id.ToString() }); await db.SaveChangesAsync(); await tx.CommitAsync(); return Results.Ok(new { a.Id });
        }
        if (action is "approve_face" or "revoke_face")
        {
            Admin(c); var id = b.GetProperty("id").GetGuid(); var f = await db.Faces.SingleAsync(f => f.Id == id && !f.Revoked); if (action == "approve_face") { f.Approved = true; f.ApprovedBy = actor.Id; } else f.Revoked = true; db.Audits.Add(new() { Actor = actor.Id, Action = action, Detail = id.ToString() }); await db.SaveChangesAsync(); return Results.Ok(new { status = "ok" });
        }
        if (action == "begin_face_camera") return Results.Ok(await FaceBegin(db, actor, b));
        if (action == "finish_face_camera") return Results.Ok(await FaceFinish(db, actor, b));
        if (action == "email_report") return await SendEmail(b, c, db, clients, config);
        throw new ApiError("Chức năng không được hỗ trợ.");
    }
    static async Task<IResult> SendEmail(JsonElement b, HttpContext c, AttendanceDb db, IHttpClientFactory clients, IConfiguration config)
    {
        StaffOnly(c); var delivery = c.RequestServices.GetRequiredService<EmailDeliveryService>(); var from = EmailDeliveryService.Sender(config); Require(EmailDeliveryService.Configured(config), "Chưa cấu hình dịch vụ gửi email trên máy chủ.", 400); var start = b.GetProperty("start").Deserialize<DateOnly>(); var end = b.GetProperty("end").Deserialize<DateOnly>(); var emp = b.GetProperty("employee_id").GetGuid(); var row = (await Report(db, start, end, c.RequestServices.GetRequiredService<AttendancePolicy>())).Single(r => r.EmployeeId == emp); var recipient = await db.Accounts.SingleOrDefaultAsync(a => a.EmployeeId == emp && a.Role != "kiosk" && a.Active); Require(recipient != null, "Nhân viên chưa có tài khoản email hoạt động.", 400); var job = await db.EmailJobs.SingleOrDefaultAsync(j => j.EmployeeId == emp && j.StartDate == start && j.EndDate == end);
        if (job?.Status == "sent") return Results.Ok(new { status = "already_sent" });
        if (job == null) { job = new() { EmployeeId = emp, StartDate = start, EndDate = end, Recipient = recipient!.Email, Subject = $"Báo cáo công {start} - {end.AddDays(-1)}", Body = $"Xin chào {row.FullName},\nTổng giờ: {row.WorkedMinutes / 60:0.00}\nĐi trễ: {row.LateDays}\nVề sớm: {row.EarlyDays}\nThiếu ra: {row.MissingCheckout}\nLương gộp dự kiến: {row.GrossPay:0} VND (chưa phải phiếu lương đã chốt)." }; db.EmailJobs.Add(job); await db.SaveChangesAsync(); }
        Require(job.Status is not ("sending" or "needs_review"), "Phiên gửi trước cần đối soát. Kiểm tra thư mục Đã gửi trước khi gửi lại báo cáo.", 409);
        Require(DateTimeOffset.UtcNow - job.CreatedAt < TimeSpan.FromHours(23), "Email chờ quá lâu, cần đối soát.", 409);
        var claimed = await db.EmailJobs.Where(j => j.Id == job.Id && (j.Status == "pending" || j.Status == "failed"))
            .ExecuteUpdateAsync(s => s.SetProperty(j => j.Status, "sending"));
        Require(claimed == 1, "Báo cáo đang được gửi hoặc đã được xử lý bởi yêu cầu khác.", 409);
        job.Status = "sending";
        try
        {
            job.ProviderId = await delivery.Send(from, job.Recipient, job.Subject, job.Body, $"attendance-{job.Id}");
            job.Status = "sent"; await db.SaveChangesAsync(); return Results.Ok(new { status = "sent" });
        }
        catch (Exception e)
        {
            job.Status = e is EmailDeliveryUncertain ? "needs_review" : "failed";
            await db.SaveChangesAsync();
            throw new ApiError(e is EmailDeliveryFailure or EmailDeliveryUncertain ? e.Message : "Không gửi được email. Kiểm tra cấu hình email trên máy chủ.", 400);
        }
    }
}
