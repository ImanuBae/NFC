using System.Data;
using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using static Attendance.Api.Business;

namespace Attendance.Api;

public static class EmployeeDeletion
{
    public static async Task Delete(Guid id, Guid actorId, AttendanceDb db, IDataProtectionProvider protection)
    {
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var employee = await db.Employees.SingleOrDefaultAsync(e => e.Id == id);
        Require(employee != null, "Không tìm thấy nhân viên.", 404);
        var accounts = await db.Accounts.Where(a => a.EmployeeId == id && (a.Role == "employee" || a.Role == "manager"))
            .Select(a => a.Id).ToListAsync();
        Require(!accounts.Contains(actorId), "Không thể xóa tài khoản đang đăng nhập.", 409);
        Require(!await db.OnboardingEmails.AnyAsync(j => j.EmployeeId == id && j.Status == "sending"),
            "Email cấp tài khoản đang được gửi. Vui lòng thử xóa lại sau.", 409);

        // Remove credentials from shared import receipts, retaining the batch identity for safe retries.
        var batches = await db.OnboardingEmails.Where(j => j.EmployeeId == id).Select(j => j.ImportId).Distinct().ToListAsync();
        var protector = protection.CreateProtector("Attendance.EmployeeImport.Credentials.v1");
        foreach (var batch in await db.EmployeeImports.Where(b => batches.Contains(b.Id) && b.ProtectedResult != "").ToListAsync())
        {
            var result = JsonSerializer.Deserialize<EmployeeImportResult>(protector.Unprotect(batch.ProtectedResult))!;
            batch.ProtectedResult = protector.Protect(JsonSerializer.Serialize(result with
            {
                Credentials = result.Credentials.Where(c => !string.Equals(c.Code, employee!.Code, StringComparison.OrdinalIgnoreCase)).ToList()
            }));
        }
        await db.OnboardingEmails.Where(j => j.EmployeeId == id || accounts.Contains(j.AccountId)).ExecuteDeleteAsync();
        await db.Sessions.Where(s => accounts.Contains(s.AccountId)).ExecuteDeleteAsync();
        await db.Challenges.Where(c => accounts.Contains(c.UserId) || db.Faces.Any(f => f.Id == c.CredentialId && f.EmployeeId == id)).ExecuteDeleteAsync();
        await db.Faces.Where(f => f.EmployeeId == id || accounts.Contains(f.UserId)).ExecuteDeleteAsync();
        await db.Cards.Where(c => c.EmployeeId == id).ExecuteDeleteAsync();
        await db.Events.Where(e => e.EmployeeId == id).ExecuteDeleteAsync();
        await db.AttendanceTickets.Where(t => t.EmployeeId == id).ExecuteDeleteAsync();
        await db.EmailJobs.Where(j => j.EmployeeId == id).ExecuteDeleteAsync();
        await db.PayrollItems.Where(i => i.EmployeeId == id).ExecuteDeleteAsync();
        // Keep devices and privileged accounts usable after removing their employee association.
        await db.Devices.Where(d => accounts.Contains(d.RegisteredBy)).ExecuteUpdateAsync(s => s.SetProperty(d => d.RegisteredBy, actorId));
        await db.Accounts.Where(a => a.EmployeeId == id && !accounts.Contains(a.Id)).ExecuteUpdateAsync(s => s.SetProperty(a => a.EmployeeId, (Guid?)null));
        await db.Accounts.Where(a => accounts.Contains(a.Id)).ExecuteDeleteAsync();
        db.Employees.Remove(employee!);
        db.Audits.Add(new() { Actor = actorId, Action = "delete_employee", Detail = $"{id}; code={employee!.Code}; removed employee and associated accounts, cards, faces, attendance and payroll items" });
        await db.SaveChangesAsync();
        await tx.CommitAsync();
    }
}
