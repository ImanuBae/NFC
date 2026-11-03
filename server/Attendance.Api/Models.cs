using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api;

public class TicketEvidence
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid TicketId { get; set; }
    public string FileName { get; set; } = "";
    public string ContentType { get; set; } = "";
    public byte[] Content { get; set; } = [];
    public int SizeBytes { get; set; }
}

public class AttendanceTicket
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid EmployeeId { get; set; }
    public Guid CreatedBy { get; set; }
    public string Kind { get; set; } = "missing_in";
    public Guid? OriginalEventId { get; set; }
    public DateTimeOffset? OriginalOccurredAt { get; set; }
    public string EventType { get; set; } = "check_in";
    public DateTimeOffset ProposedAt { get; set; }
    public string Reason { get; set; } = "";
    public string Status { get; set; } = "pending";
    public string? Response { get; set; }
    public Guid? ReviewedBy { get; set; }
    public Guid? AppliedEventId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? ReviewedAt { get; set; }
}

public class Employee
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Code { get; set; } = "";
    public string FullName { get; set; } = "";
    public string? Email { get; set; }
    public string? Department { get; set; }
    public string? JobTitle { get; set; }
    public string? Phone { get; set; }
    public DateOnly? HireDate { get; set; }
    public bool Active { get; set; } = true;
    public decimal HourlyRate { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
public class Account
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Email { get; set; } = "";
    public string Role { get; set; } = "employee";
    public bool Active { get; set; } = true;
    public Guid? EmployeeId { get; set; }
    public bool MustChangePassword { get; set; }
    [JsonIgnore] public string PasswordHash { get; set; } = "";
}
public class LoginSession
{
    public string TokenHash { get; set; } = "";
    public Guid AccountId { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
}
public class Device
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "";
    public Guid RegisteredBy { get; set; }
    public bool Active { get; set; } = true;
}
public class Card
{
    public string Uid { get; set; } = "";
    public Guid EmployeeId { get; set; }
    public bool Active { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
public class AttendanceEvent
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid EmployeeId { get; set; }
    public Guid? DeviceId { get; set; }
    public Guid? ClientScanId { get; set; }
    public string Type { get; set; } = "check_in";
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset? DeviceTime { get; set; }
    public string Source { get; set; } = "nfc";
    public string? Flag { get; set; }
    public Guid? CreatedBy { get; set; }
    public DateTimeOffset? VoidedAt { get; set; }
    public Guid? VoidedBy { get; set; }
    public string? VoidReason { get; set; }
}
public class FaceCredential
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid EmployeeId { get; set; }
    [JsonIgnore] public string Embedding { get; set; } = "[]";
    public string Model { get; set; } = "sface-2021dec-v1";
    public bool Approved { get; set; }
    public bool Revoked { get; set; }
    public Guid? ApprovedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
public class FaceChallenge
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string Purpose { get; set; } = "enroll";
    public Guid? CredentialId { get; set; }
    public Guid? DeviceId { get; set; }
    public bool TurnFirst { get; set; }
    public bool Consumed { get; set; }
    public DateTimeOffset ExpiresAt { get; set; } = DateTimeOffset.UtcNow.AddMinutes(2);
}
public class PayrollRun
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public string Period { get; set; } = "month";
    public Guid CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
public class PayrollItem
{
    public Guid RunId { get; set; }
    public Guid EmployeeId { get; set; }
    public string EmployeeCode { get; set; } = "";
    public string EmployeeName { get; set; } = "";
    public decimal WorkedMinutes { get; set; }
    public decimal HourlyRate { get; set; }
    public decimal GrossPay { get; set; }
}
public class EmailJob
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid EmployeeId { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public string Recipient { get; set; } = "";
    public string Subject { get; set; } = "";
    public string Body { get; set; } = "";
    public string Status { get; set; } = "pending";
    public string? ProviderId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
public class Audit
{
    public long Id { get; set; }
    public Guid Actor { get; set; }
    public string Action { get; set; } = "";
    public string Detail { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
public class EmployeeImportBatch
{
    public Guid Id { get; set; }
    public Guid CreatedBy { get; set; }
    public string PayloadHash { get; set; } = "";
    public string ProtectedResult { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
public class OnboardingEmail
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ImportId { get; set; }
    public Guid AccountId { get; set; }
    public Guid EmployeeId { get; set; }
    public string FullName { get; set; } = "";
    public string Recipient { get; set; } = "";
    public string? Sender { get; set; }
    public string? Transport { get; set; }
    public string Status { get; set; } = "pending";
    public int Attempts { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset NextAttemptAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? FirstAttemptAt { get; set; }
    public DateTimeOffset? LeaseUntil { get; set; }
    public DateTimeOffset? SentAt { get; set; }
    public string? ProviderId { get; set; }
    public string? LastError { get; set; }
}

public class AttendanceDb(DbContextOptions<AttendanceDb> options) : DbContext(options)
{
    public DbSet<Employee> Employees => Set<Employee>();
    public DbSet<AttendanceTicket> AttendanceTickets => Set<AttendanceTicket>();
    public DbSet<TicketEvidence> TicketEvidence => Set<TicketEvidence>();
    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<LoginSession> Sessions => Set<LoginSession>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<Card> Cards => Set<Card>();
    public DbSet<AttendanceEvent> Events => Set<AttendanceEvent>();
    public DbSet<FaceCredential> Faces => Set<FaceCredential>();
    public DbSet<FaceChallenge> Challenges => Set<FaceChallenge>();
    public DbSet<PayrollRun> PayrollRuns => Set<PayrollRun>();
    public DbSet<PayrollItem> PayrollItems => Set<PayrollItem>();
    public DbSet<EmailJob> EmailJobs => Set<EmailJob>();
    public DbSet<Audit> Audits => Set<Audit>();
    public DbSet<EmployeeImportBatch> EmployeeImports => Set<EmployeeImportBatch>();
    public DbSet<OnboardingEmail> OnboardingEmails => Set<OnboardingEmail>();
    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<LoginSession>().HasKey(x => x.TokenHash);
        b.Entity<AttendanceTicket>().HasIndex(x => new { x.EmployeeId, x.CreatedAt });
        b.Entity<TicketEvidence>().Property(x => x.FileName).HasMaxLength(200);
        b.Entity<TicketEvidence>().Property(x => x.ContentType).HasMaxLength(50);
        b.Entity<TicketEvidence>().HasOne<AttendanceTicket>().WithMany().HasForeignKey(x => x.TicketId).OnDelete(DeleteBehavior.Cascade);
        b.Entity<AttendanceTicket>().Property(x => x.Kind).HasMaxLength(30);
        b.Entity<AttendanceTicket>().Property(x => x.EventType).HasMaxLength(20);
        b.Entity<AttendanceTicket>().Property(x => x.Status).HasMaxLength(20);
        b.Entity<AttendanceTicket>().Property(x => x.Reason).HasMaxLength(1000);
        b.Entity<AttendanceTicket>().Property(x => x.Response).HasMaxLength(1000);
        b.Entity<Card>().HasKey(x => x.Uid);
        b.Entity<PayrollItem>().HasKey(x => new { x.RunId, x.EmployeeId });
        b.Entity<Employee>().HasIndex(x => x.Code).IsUnique();
        b.Entity<Employee>().Property(x => x.Code).HasMaxLength(50);
        b.Entity<Employee>().Property(x => x.FullName).HasMaxLength(200);
        b.Entity<Employee>().Property(x => x.Department).HasMaxLength(200);
        b.Entity<Employee>().Property(x => x.JobTitle).HasMaxLength(200);
        b.Entity<Employee>().Property(x => x.Phone).HasMaxLength(30);
        b.Entity<EmployeeImportBatch>().Property(x => x.PayloadHash).HasMaxLength(64);
        b.Entity<OnboardingEmail>().HasIndex(x => x.AccountId).IsUnique();
        b.Entity<OnboardingEmail>().HasIndex(x => x.ImportId);
        b.Entity<OnboardingEmail>().Property(x => x.FullName).HasMaxLength(200);
        b.Entity<OnboardingEmail>().Property(x => x.Recipient).HasMaxLength(254);
        b.Entity<OnboardingEmail>().Property(x => x.Sender).HasMaxLength(500);
        b.Entity<OnboardingEmail>().Property(x => x.Transport).HasMaxLength(20);
        b.Entity<OnboardingEmail>().Property(x => x.Status).HasMaxLength(20);
        b.Entity<OnboardingEmail>().Property(x => x.ProviderId).HasMaxLength(200);
        b.Entity<OnboardingEmail>().Property(x => x.LastError).HasMaxLength(500);
        b.Entity<Account>().Property(x => x.Email).HasMaxLength(254);
        b.Entity<Account>().Property(x => x.Role).HasMaxLength(20);
        b.Entity<Account>().HasIndex(x => x.Email).IsUnique();
        b.Entity<Account>().HasIndex(x => x.EmployeeId).IsUnique().HasFilter("[EmployeeId] IS NOT NULL AND [Role] <> 'kiosk'");
        b.Entity<Account>().ToTable(t => t.HasCheckConstraint("CK_Account_Kiosk", "[Role] <> 'kiosk' OR [EmployeeId] IS NULL"));
        b.Entity<Card>().Property(x => x.Uid).HasMaxLength(64);
        b.Entity<LoginSession>().Property(x => x.TokenHash).HasMaxLength(64);
        b.Entity<AttendanceEvent>().HasIndex(x => x.ClientScanId).IsUnique().HasFilter("[ClientScanId] IS NOT NULL");
        b.Entity<AttendanceEvent>().HasIndex(x => new { x.EmployeeId, x.OccurredAt });
        b.Entity<FaceCredential>().HasIndex(x => x.UserId).IsUnique().HasFilter("[Revoked] = 0");
        b.Entity<PayrollRun>().HasIndex(x => new { x.StartDate, x.EndDate }).IsUnique();
        b.Entity<EmailJob>().HasIndex(x => new { x.EmployeeId, x.StartDate, x.EndDate }).IsUnique();
        b.Entity<Account>().HasOne<Employee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Card>().HasOne<Employee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<AttendanceEvent>().HasOne<Employee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Device>().HasOne<Account>().WithMany().HasForeignKey(x => x.RegisteredBy).OnDelete(DeleteBehavior.Restrict);
        b.Entity<FaceCredential>().HasOne<Account>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<FaceCredential>().HasOne<Employee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<PayrollItem>().HasOne<PayrollRun>().WithMany().HasForeignKey(x => x.RunId).OnDelete(DeleteBehavior.Restrict);
        foreach (var entity in b.Model.GetEntityTypes()) foreach (var property in entity.GetProperties())
        {
            if (property.ClrType == typeof(decimal)) { property.SetPrecision(18); property.SetScale(property.Name == "WorkedMinutes" ? 6 : 2); }
        }
    }
}
