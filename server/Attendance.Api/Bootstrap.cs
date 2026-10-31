using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api;

public static class Bootstrap
{
    static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower, NumberHandling = JsonNumberHandling.AllowReadingFromString };
    public record Credential(string Email, string Role, string Password);
    public static async Task Initialize(AttendanceDb db, IConfiguration config, string root)
    {
        if (await db.Accounts.AnyAsync()) return;
        var importPath = Path.GetFullPath(config["Bootstrap:ImportFile"] ?? Path.Combine(root, "..", "..", ".local-data", "legacy-export.json"));
        var credentialPath = Path.GetFullPath(config["Bootstrap:CredentialsFile"] ?? Path.Combine(root, "..", "..", ".local-data", "account-credentials.json"));
        var credentials = File.Exists(credentialPath) ? JsonSerializer.Deserialize<List<Credential>>(await File.ReadAllTextAsync(credentialPath)) ?? [] : [];
        var accounts = new List<Account>();
        await using var tx = await db.Database.BeginTransactionAsync();
        if (File.Exists(importPath))
        {
            using var document = JsonDocument.Parse(await File.ReadAllTextAsync(importPath)); var data = document.RootElement;
            List<T> Read<T>(string name) => data.TryGetProperty(name, out var value) ? value.Deserialize<List<T>>(Json) ?? [] : [];
            db.Employees.AddRange(Read<Employee>("employees")); await db.SaveChangesAsync();
            accounts = Read<Account>("profiles");
            foreach (var a in accounts) { a.Email = a.Email.ToLowerInvariant(); if (a.Role == "kiosk") a.EmployeeId = null; SetPassword(a, credentials); }
            db.Accounts.AddRange(accounts); await db.SaveChangesAsync();
            var devices = new List<Device>();
            if (data.TryGetProperty("devices", out var deviceRows)) foreach (var r in deviceRows.EnumerateArray()) devices.Add(new() { Id = r.GetProperty("id").GetGuid(), Name = r.GetProperty("name").GetString()!, Active = r.GetProperty("active").GetBoolean(), RegisteredBy = r.TryGetProperty("registered_by", out var owner) && owner.ValueKind == JsonValueKind.String ? owner.GetGuid() : accounts.First(a => a.Role == "kiosk").Id });
            db.Devices.AddRange(devices); db.Cards.AddRange(Read<Card>("cards")); db.Events.AddRange(Read<AttendanceEvent>("attendance_events"));
            db.PayrollRuns.AddRange(Read<PayrollRun>("payroll_runs")); await db.SaveChangesAsync(); db.PayrollItems.AddRange(Read<PayrollItem>("payroll_items"));
            if (data.TryGetProperty("face_credentials", out var faces)) foreach (var r in faces.EnumerateArray())
            {
                var f = new FaceCredential { Id = r.GetProperty("id").GetGuid(), UserId = r.GetProperty("user_id").GetGuid(), EmployeeId = r.GetProperty("employee_id").GetGuid(), Embedding = r.GetProperty("embedding").GetRawText(), Approved = r.GetProperty("approved").GetBoolean(), Revoked = r.GetProperty("revoked").GetBoolean(), CreatedAt = r.GetProperty("created_at").GetDateTimeOffset() };
                if (accounts.Single(a => a.Id == f.UserId).Role == "kiosk") f.Revoked = true;
                db.Faces.Add(f);
            }
            db.EmailJobs.AddRange(Read<EmailJob>("report_emails"));
        }
        else
        {
            accounts = [new() { Email = "admin@attendance.local", Role = "admin" }, new() { Email = "kiosk@attendance.local", Role = "kiosk" }];
            foreach (var a in accounts) SetPassword(a, credentials); db.Accounts.AddRange(accounts);
        }
        await db.SaveChangesAsync();
        Directory.CreateDirectory(Path.GetDirectoryName(credentialPath)!);
        await File.WriteAllTextAsync(credentialPath, JsonSerializer.Serialize(credentials, new JsonSerializerOptions { WriteIndented = true }));
        await tx.CommitAsync();
    }
    static void SetPassword(Account account, List<Credential> credentials)
    {
        var existing = credentials.SingleOrDefault(c => c.Email == account.Email);
        if (existing == null) { existing = new(account.Email, account.Role, "Nfc!" + Convert.ToHexString(RandomNumberGenerator.GetBytes(12))); credentials.Add(existing); }
        account.PasswordHash = new PasswordHasher<Account>().HashPassword(account, existing.Password);
    }
}
