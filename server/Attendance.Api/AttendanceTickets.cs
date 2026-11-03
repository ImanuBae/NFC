using System.Data;
using Microsoft.EntityFrameworkCore;
using static Attendance.Api.Business;

namespace Attendance.Api;

public record EvidenceUpload(string FileName, string ContentBase64);
public record TicketRequest(string Kind, DateTimeOffset ProposedAt, string Reason, Guid? OriginalEventId, List<EvidenceUpload>? Attachments = null);
public record TicketReview(string Decision, string? Response);

public static class AttendanceTickets
{
    static Account Actor(HttpContext c) => (Account)c.Items["account"]!;
    static void Access(Account a) => Require(a.Role is "employee" or "manager" or "admin");

    public static List<TicketEvidence> ReadEvidence(List<EvidenceUpload>? uploads)
    {
        Require(uploads == null || uploads.Count <= 3, "Tối đa 3 tệp bằng chứng.", 400);
        var files = new List<TicketEvidence>();
        foreach (var file in uploads ?? [])
        {
            Require(file != null && !string.IsNullOrWhiteSpace(file.FileName) && file.FileName.Length <= 200 &&
                !file.FileName.Any(c => char.IsControl(c) || "/\\:".Contains(c)), "Tên tệp bằng chứng không hợp lệ, tối đa 200 ký tự.", 400);
            Require(file!.ContentBase64 != null && file.ContentBase64.Length <= (2 * 1024 * 1024 + 2) / 3 * 4,
                "Mỗi tệp bằng chứng tối đa 2 MB.", 400);
            byte[] bytes;
            try { bytes = Convert.FromBase64String(file.ContentBase64!); }
            catch (FormatException) { throw new ApiError("Nội dung tệp bằng chứng không hợp lệ.", 400); }
            Require(bytes.Length > 0 && bytes.Length <= 2 * 1024 * 1024, "Tệp bằng chứng trống hoặc lớn hơn 2 MB.", 400);
            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            var type = ext switch {
                ".png" when bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(new byte[] {137,80,78,71,13,10,26,10}) => "image/png",
                ".jpg" or ".jpeg" when bytes.Length >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255 => "image/jpeg",
                ".pdf" when bytes.Length >= 5 && bytes.AsSpan(0, 5).SequenceEqual("%PDF-"u8) => "application/pdf",
                _ => null
            };
            Require(type != null, "Bằng chứng chỉ nhận ảnh JPG/PNG hoặc PDF có nội dung đúng định dạng.", 400);
            files.Add(new() { FileName = file.FileName.Trim(), ContentType = type!, Content = bytes, SizeBytes = bytes.Length });
        }
        Require(files.Sum(f => f.SizeBytes) <= 5 * 1024 * 1024, "Tổng dung lượng bằng chứng tối đa 5 MB.", 400);
        return files;
    }

    public static void Register(WebApplication app)
    {
        app.MapGet("/api/attendance/tickets", async (HttpContext c, AttendanceDb db) =>
        {
            var actor = Actor(c); Access(actor);
            return await db.AttendanceTickets.AsNoTracking()
                .Where(t => Staff(actor) || t.EmployeeId == actor.EmployeeId)
                .Join(db.Employees, t => t.EmployeeId, e => e.Id, (t, e) => new {
                    t.Id, t.EmployeeId, employee_code = e.Code, employee_name = e.FullName,
                    t.Kind, t.EventType, t.ProposedAt, t.Reason, t.Status, t.Response,
                    t.OriginalEventId, t.OriginalOccurredAt, t.AppliedEventId, t.CreatedAt, t.ReviewedAt,
                    attachments = db.TicketEvidence.Where(f => f.TicketId == t.Id).OrderBy(f => f.FileName)
                        .Select(f => new { f.Id, f.FileName, f.ContentType, f.SizeBytes }).ToList()
                }).OrderByDescending(t => t.CreatedAt).ToListAsync();
        });
        app.MapGet("/api/attendance/tickets/{id:guid}/attachments/{fileId:guid}", async (Guid id, Guid fileId, HttpContext c, AttendanceDb db) =>
        {
            var actor = Actor(c); Access(actor);
            c.Response.Headers.CacheControl = "no-store";
            Require(await db.AttendanceTickets.AnyAsync(t => t.Id == id && (Staff(actor) || t.EmployeeId == actor.EmployeeId)), "Không tìm thấy bằng chứng của ticket.", 404);
            var file = await db.TicketEvidence.AsNoTracking().SingleOrDefaultAsync(f => f.Id == fileId && f.TicketId == id);
            Require(file != null, "Không tìm thấy tệp bằng chứng.", 404);
            return new { file!.FileName, file.ContentType, file.SizeBytes, content_base64 = Convert.ToBase64String(file.Content) };
        });
        app.MapPost("/api/attendance/tickets", async (TicketRequest body, HttpContext c, AttendanceDb db) =>
        {
            var actor = Actor(c);
            Require(actor.Role is "employee" or "manager");
            Require(actor.EmployeeId != null && await db.Employees.AnyAsync(e => e.Id == actor.EmployeeId && e.Active), "Tài khoản chưa liên kết nhân viên đang hoạt động.", 400);
            Require(body.Kind is "missing_in" or "missing_out" or "incorrect_time", "Loại yêu cầu không hợp lệ.", 400);
            Require(!string.IsNullOrWhiteSpace(body.Reason) && body.Reason.Trim().Length <= 1000, "Nhập lý do, tối đa 1000 ký tự.", 400);
            Require(body.ProposedAt <= DateTimeOffset.UtcNow, "Không đề nghị công trong tương lai.", 400);
            var attachments = ReadEvidence(body.Attachments);
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            await ProtectPayroll(db, body.ProposedAt);
            AttendanceEvent? original = null;
            if (body.Kind == "incorrect_time")
            {
                original = await db.Events.SingleOrDefaultAsync(e => e.Id == body.OriginalEventId && e.EmployeeId == actor.EmployeeId);
                Require(original != null && original.VoidedAt == null, "Lượt chấm công cần sửa không hợp lệ hoặc đã hủy.", 400);
                await ProtectPayroll(db, original!.OccurredAt);
            }
            else Require(body.OriginalEventId == null, "Yêu cầu bổ sung lượt thiếu không gắn lượt cũ.", 400);
            Require(!await db.AttendanceTickets.AnyAsync(t => t.EmployeeId == actor.EmployeeId && t.Status == "pending" &&
                t.Kind == body.Kind && t.OriginalEventId == body.OriginalEventId && t.ProposedAt == body.ProposedAt), "Đã có ticket đang chờ cho yêu cầu này.", 409);
            var ticket = new AttendanceTicket {
                EmployeeId = actor.EmployeeId!.Value, CreatedBy = actor.Id, Kind = body.Kind,
                EventType = original?.Type ?? (body.Kind == "missing_out" ? "check_out" : "check_in"),
                OriginalEventId = original?.Id, OriginalOccurredAt = original?.OccurredAt,
                ProposedAt = body.ProposedAt, Reason = body.Reason.Trim()
            };
            db.AttendanceTickets.Add(ticket);
            foreach (var file in attachments) { file.TicketId = ticket.Id; db.TicketEvidence.Add(file); }
            db.Audits.Add(new() { Actor = actor.Id, Action = "create_attendance_ticket", Detail = ticket.Id.ToString() });
            await db.SaveChangesAsync(); await tx.CommitAsync();
            return ticket;
        });
        app.MapPost("/api/attendance/tickets/{id:guid}/cancel", async (Guid id, HttpContext c, AttendanceDb db) =>
        {
            var actor = Actor(c); Access(actor);
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var ticket = await db.AttendanceTickets.SingleOrDefaultAsync(t => t.Id == id && t.EmployeeId == actor.EmployeeId && t.CreatedBy == actor.Id);
            Require(ticket != null, "Không tìm thấy ticket của bạn.", 404);
            Require(ticket!.Status == "pending", "Chỉ hủy được ticket đang chờ xử lý.", 409);
            ticket.Status = "cancelled";
            db.Audits.Add(new() { Actor = actor.Id, Action = "cancel_attendance_ticket", Detail = ticket.Id.ToString() });
            await db.SaveChangesAsync(); await tx.CommitAsync();
            return new { status = ticket.Status };
        });
        app.MapPost("/api/attendance/tickets/{id:guid}/review", async (Guid id, TicketReview body, HttpContext c, AttendanceDb db) =>
        {
            var actor = Actor(c); Require(Staff(actor));
            Require(body.Decision is "approved" or "rejected", "Chọn duyệt hoặc từ chối.", 400);
            Require(body.Response?.Length is null or <= 1000, "Phản hồi tối đa 1000 ký tự.", 400);
            Require(body.Decision != "rejected" || !string.IsNullOrWhiteSpace(body.Response), "Nhập lý do từ chối.", 400);
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var ticket = await db.AttendanceTickets.SingleOrDefaultAsync(t => t.Id == id);
            Require(ticket != null, "Không tìm thấy ticket.", 404);
            Require(ticket!.CreatedBy != actor.Id && ticket.EmployeeId != actor.EmployeeId, "Không tự duyệt yêu cầu của mình.", 403);
            Require(ticket.Status == "pending", "Ticket đã được xử lý.", 409);
            if (body.Decision == "approved")
            {
                Require(await db.Employees.AnyAsync(e => e.Id == ticket.EmployeeId && e.Active), "Nhân viên đã ngừng hoạt động.", 409);
                await ProtectPayroll(db, ticket.ProposedAt);
                if (ticket.OriginalEventId != null)
                {
                    var original = await db.Events.SingleOrDefaultAsync(e => e.Id == ticket.OriginalEventId && e.EmployeeId == ticket.EmployeeId);
                    Require(original != null && original.VoidedAt == null && original.OccurredAt == ticket.OriginalOccurredAt, "Lượt gốc đã thay đổi. Từ chối ticket và yêu cầu nhân viên gửi lại.", 409);
                    await ProtectPayroll(db, original!.OccurredAt);
                    original.VoidedAt = DateTimeOffset.UtcNow; original.VoidedBy = actor.Id;
                    original.VoidReason = $"Ticket {ticket.Id}: {ticket.Reason}";
                }
                Require(!await db.Events.AnyAsync(e => e.EmployeeId == ticket.EmployeeId && e.Type == ticket.EventType && e.OccurredAt == ticket.ProposedAt && e.VoidedAt == null), "Đã có lượt chấm công trùng giờ đề nghị.", 409);
                var corrected = new AttendanceEvent { EmployeeId = ticket.EmployeeId, Type = ticket.EventType,
                    OccurredAt = ticket.ProposedAt, Source = "manual", CreatedBy = actor.Id, Flag = $"Ticket {ticket.Id}: {ticket.Reason}" };
                db.Events.Add(corrected); ticket.AppliedEventId = corrected.Id;
            }
            ticket.Status = body.Decision; ticket.Response = body.Response?.Trim();
            ticket.ReviewedBy = actor.Id; ticket.ReviewedAt = DateTimeOffset.UtcNow;
            db.Audits.Add(new() { Actor = actor.Id, Action = "review_attendance_ticket", Detail = $"{ticket.Id}: {ticket.Status}" });
            await db.SaveChangesAsync(); await tx.CommitAsync();
            return new { status = ticket.Status };
        });
    }
}
