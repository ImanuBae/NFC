using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api;

public record ReportRow(Guid EmployeeId, string Code, string FullName, string? Email, decimal HourlyRate,
    decimal WorkedMinutes, int DaysWorked, int MissingCheckout, int LateDays, int EarlyDays, decimal GrossPay);
public record WorkSession(Guid EmployeeId, DateTimeOffset Start, DateTimeOffset? End);
public sealed class ApiError(string message, int status = 400) : Exception(message) { public int Status => status; }
public static class Business
{
    public static readonly TimeSpan Zone = TimeSpan.FromHours(7);
    public static DateTimeOffset Bound(DateOnly date) => new(date.ToDateTime(TimeOnly.MinValue), Zone);
    public static DateOnly Today => DateOnly.FromDateTime(DateTimeOffset.UtcNow.ToOffset(Zone).DateTime);
    public static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    public static bool Staff(Account a) => a.Role is "admin" or "manager";
    public static void Require(bool test, string message = "Không có quyền truy cập.", int status = 403) { if (!test) throw new ApiError(message, status); }
    public static void Range(DateOnly start, DateOnly end) => Require(end > start && end.DayNumber - start.DayNumber <= 366, "Kỳ báo cáo không hợp lệ.", 400);
    public static List<WorkSession> Sessions(IEnumerable<AttendanceEvent> events)
    {
        var result = new List<WorkSession>();
        foreach (var group in events.Where(e => e.VoidedAt == null).GroupBy(e => e.EmployeeId))
        {
            AttendanceEvent? open = null;
            foreach (var e in group.OrderBy(e => e.OccurredAt).ThenBy(e => e.Id))
            {
                if (e.Type == "check_in") { if (open != null) result.Add(new(group.Key, open.OccurredAt, null)); open = e; }
                else if (e.Type == "check_out" && open != null) { if (e.OccurredAt > open.OccurredAt && e.OccurredAt - open.OccurredAt <= TimeSpan.FromHours(16)) result.Add(new(group.Key, open.OccurredAt, e.OccurredAt)); else result.Add(new(group.Key, open.OccurredAt, null)); open = null; }
            }
            if (open != null) result.Add(new(group.Key, open.OccurredAt, null));
        }
        return result;
    }
    public static async Task<List<ReportRow>> Report(AttendanceDb db, DateOnly start, DateOnly end, AttendancePolicy policy)
    {
        Range(start, end);
        var a = Bound(start); var b = Bound(end);
        var events = await db.Events.AsNoTracking().ToListAsync();
        var sessions = Sessions(events);
        var employees = await db.Employees.AsNoTracking().OrderBy(e => e.Code).ToListAsync();
        var rows = new List<ReportRow>();
        foreach (var e in employees)
        {
            var selected = sessions.Where(s => s.EmployeeId == e.Id && s.Start < b && (s.End > a || (s.End == null && s.Start >= a))).ToList();
            if (!e.Active && selected.Count == 0) continue;
            var minutes = selected.Where(s => s.End != null).Sum(s => (decimal)policy.Minutes(s.Start > a ? s.Start : a, s.End!.Value < b ? s.End.Value : b));
            var days = selected.GroupBy(s => DateOnly.FromDateTime(s.Start.ToOffset(Zone).DateTime)).ToList();
            var late = days.Count(g => g.Key >= start && g.Key < end && g.Min(s => s.Start).ToOffset(Zone).TimeOfDay > TimeSpan.FromMinutes(policy.StartMinute));
            var early = days.Count(g => g.Key >= start && g.Key < end && g.All(s => s.End != null) && g.Max(s => s.End) < Bound(g.Key).AddMinutes(policy.EndMinute));
            var orphanOuts = events.Count(v => v.EmployeeId == e.Id && v.VoidedAt == null && v.Type == "check_out"
                && v.OccurredAt >= a && v.OccurredAt < b && !sessions.Any(s => s.EmployeeId == e.Id && s.End == v.OccurredAt));
            rows.Add(new(e.Id, e.Code, e.FullName, e.Email, e.HourlyRate, minutes, days.Count, selected.Count(s => s.End == null) + orphanOuts, late, early, Math.Round(minutes / 60 * e.HourlyRate, 0, MidpointRounding.AwayFromZero)));
        }
        return rows;
    }
    public static async Task ProtectPayroll(AttendanceDb db, DateTimeOffset at)
    {
        var date = DateOnly.FromDateTime(at.ToOffset(Zone).DateTime);
        Require(!await db.PayrollRuns.AnyAsync(r => r.StartDate <= date && r.EndDate > date), "Kỳ lương đã chốt, không thể sửa công.", 409);
    }
    public static async Task<object> Record(AttendanceDb db, Account actor, Employee employee, string type, DateTimeOffset at,
        string source, Guid? device = null, Guid? scan = null, DateTimeOffset? deviceTime = null)
    {
        Require(employee.Active, "Nhân viên đã ngừng hoạt động.", 400);
        Require(type is "check_in" or "check_out", "Loại lượt không hợp lệ.", 400);
        await ProtectPayroll(db, at);
        var last = await db.Events.Where(e => e.EmployeeId == employee.Id && e.VoidedAt == null && e.OccurredAt <= at).OrderByDescending(e => e.OccurredAt).FirstOrDefaultAsync();
        if (last != null && at - last.OccurredAt < TimeSpan.FromSeconds(60))
        {
            Require(source != "face_camera", "Vui lòng chờ ít nhất 60 giây giữa hai lượt chấm công.", 409);
            return new { status = "ignored", employee_name = employee.FullName };
        }
        if (type == "check_out") Require(last?.Type == "check_in" && at - last.OccurredAt <= TimeSpan.FromHours(16), "Không có lượt vào hợp lệ. Liên hệ quản lý.", 400);
        if (type == "check_in") Require(last?.Type != "check_in" || at - last.OccurredAt > TimeSpan.FromHours(16), "Đã ghi nhận vào ca.", 409);
        var entry = new AttendanceEvent { EmployeeId = employee.Id, Type = type, OccurredAt = at, Source = source, DeviceId = device, ClientScanId = scan, DeviceTime = deviceTime, CreatedBy = actor.Id };
        db.Events.Add(entry); await db.SaveChangesAsync();
        return new { status = "ok", event_id = entry.Id, type, employee_name = employee.FullName, employee_code = employee.Code, occurred_at = at };
    }
    public static double Cosine(double[] a, double[] b)
    {
        Require(a.Length == 128 && b.Length == 128 && a.Concat(b).All(x => double.IsFinite(x) && Math.Abs(x) <= 1), "Mẫu khuôn mặt không hợp lệ.", 400);
        var na = a.Sum(x => x * x); var nb = b.Sum(x => x * x);
        Require(na is >= .5 and <= 1.5 && nb is >= .5 and <= 1.5, "Mẫu khuôn mặt không hợp lệ.", 400);
        return a.Zip(b, (x, y) => x * y).Sum() / Math.Sqrt(na * nb);
    }
    static IQueryable<FaceCredential> EligibleFaces(AttendanceDb db) =>
        from f in db.Faces
        join a in db.Accounts on f.UserId equals a.Id
        join e in db.Employees on f.EmployeeId equals e.Id
        where f.Approved && !f.Revoked && f.Model == "sface-2021dec-v1" && a.Active && e.Active
            && a.EmployeeId == e.Id && (a.Role == "employee" || a.Role == "manager")
        select f;

    const string NoApprovedFace = "Chưa có mẫu khuôn mặt để chấm công. Nhân viên đăng nhập tài khoản của mình và đăng ký khuôn mặt trước.";

    public static async Task<object> FaceBegin(AttendanceDb db, Account actor, JsonElement body)
    {
        var purpose = body.GetProperty("purpose").GetString();
        Guid? deviceId = null;
        if (actor.Role == "kiosk")
        {
            Require(purpose is "check_in" or "check_out", "Kiosk chỉ dùng nhận diện để chấm công.", 400);
            deviceId = body.GetProperty("device_id").GetGuid();
            Require(await db.Devices.AnyAsync(d => d.Id == deviceId && d.Active && d.RegisteredBy == actor.Id), "Máy kiosk chưa đăng ký hoặc đã bị khóa.", 403);
            Require(await EligibleFaces(db).AnyAsync(), NoApprovedFace, 400);
        }
        else
        {
            Require(purpose is "enroll" or "reenroll", "Nhân viên chấm công tại kiosk của công ty.", 403);
            Require(actor.EmployeeId != null && actor.Role is "employee" or "manager", "Tài khoản không liên kết nhân viên.", 400);
            Require(await db.Employees.AnyAsync(e => e.Id == actor.EmployeeId && e.Active), "Nhân viên đã ngừng hoạt động.", 400);
            var hasFace = await db.Faces.AnyAsync(f => f.UserId == actor.Id && f.EmployeeId == actor.EmployeeId && !f.Revoked);
            Require(purpose == "reenroll" ? hasFace : !hasFace,
                purpose == "reenroll" ? "Chưa có mẫu khuôn mặt. Hãy đăng ký mẫu mới." : "Đã có mẫu khuôn mặt. Hãy chọn Đăng ký lại khuôn mặt để thay mẫu.", 409);
        }
        Require(await db.Challenges.CountAsync(c => c.UserId == actor.Id && !c.Consumed && c.ExpiresAt > DateTimeOffset.UtcNow) < 5, "Quá nhiều phiên camera, chờ hai phút.", 429);
        var challenge = new FaceChallenge { UserId = actor.Id, Purpose = purpose!, DeviceId = deviceId, TurnFirst = RandomNumberGenerator.GetInt32(2) == 0 };
        db.Challenges.Add(challenge); await db.SaveChangesAsync();
        return new { challenge.Id, challenge.TurnFirst };
    }
    public static async Task<object> FaceFinish(AttendanceDb db, Account actor, JsonElement body)
    {
        var id = body.GetProperty("challenge_id").GetGuid();
        // Claim is committed before validation; failed/mismatched attempts cannot reuse a challenge.
        var claimed = await db.Challenges.Where(c => c.Id == id && c.UserId == actor.Id && !c.Consumed && c.ExpiresAt > DateTimeOffset.UtcNow)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.Consumed, true));
        Require(claimed == 1, "Phiên camera đã hết hạn hoặc được sử dụng.", 400);
        var c = await db.Challenges.SingleAsync(c => c.Id == id);
        Require(body.GetProperty("model").GetString() == "sface-2021dec-v1", "Model không hợp lệ.", 400);
        var first = body.GetProperty("first").Deserialize<double[]>() ?? []; var last = body.GetProperty("last").Deserialize<double[]>() ?? [];
        Require(Cosine(first, last) >= .45, "Các mẫu khuôn mặt không nhất quán.", 400);
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var account = await db.Accounts.SingleAsync(a => a.Id == actor.Id);
        if (c.DeviceId != null)
        {
            Require(account.Active && account.Role == "kiosk" && c.Purpose is "check_in" or "check_out", "Không có quyền chấm công kiosk.", 403);
            Require(await db.Devices.AnyAsync(d => d.Id == c.DeviceId && d.Active && d.RegisteredBy == actor.Id), "Máy kiosk chưa đăng ký hoặc đã bị khóa.", 403);
            // Only compare active, approved employee templates. Never return vectors to the kiosk.
            var faces = await EligibleFaces(db).ToListAsync();
            Require(faces.Count > 0, NoApprovedFace, 400);
            var matches = faces.Select(f => {
                var template = JsonSerializer.Deserialize<double[]>(f.Embedding)!;
                return new { f.EmployeeId, Score = Math.Min(Cosine(template, first), Cosine(template, last)) };
            }).GroupBy(x => x.EmployeeId).Select(g => g.MaxBy(x => x.Score)!).OrderByDescending(x => x.Score).ToList();
            Require(matches.Count > 0 && matches[0].Score >= .45, "Khuôn mặt chưa khớp với mẫu đã đăng ký. Nhìn thẳng, giữ yên và đủ sáng; nếu vẫn không khớp, dùng NFC và nhờ Admin kiểm tra mẫu đăng ký.", 400);
            Require(matches.Count == 1 || matches[0].Score - matches[1].Score >= .05, "Khuôn mặt chưa phân biệt rõ với nhân viên khác. Vui lòng dùng thẻ NFC.", 400);
            var matched = await db.Employees.SingleAsync(e => e.Id == matches[0].EmployeeId);
            var recorded = await Record(db, actor, matched, c.Purpose, DateTimeOffset.UtcNow, "face_camera", c.DeviceId);
            await tx.CommitAsync(); return recorded;
        }
        Require(c.Purpose is "enroll" or "reenroll", "Nhân viên chấm công tại kiosk của công ty.", 403);
        Require(account.Active && account.EmployeeId != null && account.Role is "employee" or "manager", "Tài khoản chưa liên kết nhân viên.", 400);
        var employee = await db.Employees.SingleAsync(e => e.Id == account.EmployeeId);
        Require(employee.Active, "Nhân viên đã ngừng hoạt động.", 400);
        var previous = await db.Faces.SingleOrDefaultAsync(f => f.UserId == actor.Id && !f.Revoked);
        Require(c.Purpose == "reenroll" ? previous != null && previous.EmployeeId == employee.Id : previous == null,
            c.Purpose == "reenroll" ? "Mẫu cũ đã thay đổi hoặc bị thu hồi. Hãy tải lại trạng thái khuôn mặt." : "Đã có mẫu khuôn mặt. Hãy chọn Đăng ký lại khuôn mặt để thay mẫu.", 409);
        // Validation is complete. Revoke and replace in the same transaction so
        // cancellation or any failed save leaves the previous template intact.
        if (previous != null)
            await db.Faces.Where(f => f.Id == previous.Id).ExecuteUpdateAsync(s => s.SetProperty(f => f.Revoked, true));
        var face = new FaceCredential { Approved = true, UserId = actor.Id, EmployeeId = employee.Id, Embedding = JsonSerializer.Serialize(first.Zip(last, (x, y) => (x + y) / 2).ToArray()) };
        db.Faces.Add(face);
        if (previous != null)
            db.Audits.Add(new() { Actor = actor.Id, Action = "reenroll_face", Detail = $"{previous.Id} -> {face.Id}" });
        await db.SaveChangesAsync();
        await tx.CommitAsync(); return new { status = "enrolled", credential_id = face.Id };
    }
}
