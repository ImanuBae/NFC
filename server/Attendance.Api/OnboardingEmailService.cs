using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api;

public static class OnboardingMessage
{
    public const string InitialPassword = "12345678";
    public const string Subject = "Thông tin tài khoản chấm công của bạn";
    public static string Body(string name, string email) => $"""
        Xin chào {name},

        Công ty đã tạo tài khoản chấm công cho bạn.
        Tên đăng nhập (email): {email}
        Mật khẩu ban đầu: {InitialPassword}

        Sau khi đăng nhập app nhân viên, vui lòng:
        1. Chọn Đổi mật khẩu để thay mật khẩu ban đầu bằng mật khẩu riêng của bạn.
        2. Mở Đăng ký khuôn mặt, thực hiện hướng dẫn chớp mắt/quay đầu để đăng ký mẫu khuôn mặt của chính bạn.
        3. Đăng ký khuôn mặt thành công là có thể chấm công tại kiosk ngay, không cần chờ Admin duyệt.

        Vui lòng không chia sẻ tài khoản với người khác. Liên hệ Admin nếu cần địa chỉ máy chủ hoặc hỗ trợ đăng nhập.
        """;
}

public sealed class OnboardingEmailService(IServiceScopeFactory scopes, EmailDeliveryService delivery,
    IConfiguration configuration, ILogger<OnboardingEmailService> logger) : BackgroundService
{
    public static bool Configured(IConfiguration config) => EmailDeliveryService.Configured(config);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try { await ProcessDue(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception e) { logger.LogWarning("Onboarding email worker will retry after {ErrorType}", e.GetType().Name); }
            try { await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken); }
            catch (OperationCanceledException) { break; }
        }
    }

    public async Task ProcessDue(CancellationToken cancellationToken)
    {
        if (!Configured(configuration)) return; // Keep the durable queue until real sender settings exist.
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AttendanceDb>();
        var now = DateTimeOffset.UtcNow;
        await db.OnboardingEmails.Where(j => j.Status == "sending" && j.Transport != "Resend" && j.LeaseUntil < now)
            .ExecuteUpdateAsync(s => s.SetProperty(j => j.Status, "needs_review")
                .SetProperty(j => j.LeaseUntil, (DateTimeOffset?)null)
                .SetProperty(j => j.LastError, "Phiên gửi SMTP trước bị gián đoạn. Admin kiểm tra thư mục Đã gửi của Gmail; hệ thống không tự gửi lại để tránh thư trùng."), cancellationToken);
        await db.OnboardingEmails.Where(j => j.FirstAttemptAt < now.AddHours(-23) &&
            (j.Status == "pending" || j.Status == "failed" || (j.Status == "sending" && j.LeaseUntil < now)))
            .ExecuteUpdateAsync(s => s.SetProperty(j => j.Status, "expired")
                .SetProperty(j => j.LeaseUntil, (DateTimeOffset?)null)
                .SetProperty(j => j.LastError, "Đã quá thời hạn thử gửi an toàn. Admin cần liên hệ nhân viên hoặc đặt lại mật khẩu."), cancellationToken);
        await db.OnboardingEmails.Where(j => j.Status == "sending" && j.Attempts >= 5 && j.LeaseUntil < now)
            .ExecuteUpdateAsync(s => s.SetProperty(j => j.Status, "failed")
                .SetProperty(j => j.LeaseUntil, (DateTimeOffset?)null)
                .SetProperty(j => j.LastError, "Phiên gửi trước bị gián đoạn. Admin có thể thử lại trong thời hạn gửi an toàn."), cancellationToken);
        var ids = await db.OnboardingEmails.AsNoTracking().Where(j =>
            (j.Status == "pending" || j.Status == "failed" || j.Status == "sending") &&
            j.Attempts < 5 && j.NextAttemptAt <= now && (j.LeaseUntil == null || j.LeaseUntil < now))
            .OrderBy(j => j.CreatedAt).Select(j => j.Id).Take(20).ToListAsync(cancellationToken);
        foreach (var id in ids)
        {
            cancellationToken.ThrowIfCancellationRequested();
            now = DateTimeOffset.UtcNow;
            var sender = EmailDeliveryService.Sender(configuration);
            var transport = EmailDeliveryService.Provider(configuration);
            var claimed = await db.OnboardingEmails.Where(j => j.Id == id &&
                (j.Status == "pending" || j.Status == "failed" || j.Status == "sending") &&
                j.Attempts < 5 && (j.LeaseUntil == null || j.LeaseUntil < now))
                .ExecuteUpdateAsync(s => s.SetProperty(j => j.Status, "sending")
                    .SetProperty(j => j.Attempts, j => j.Attempts + 1)
                    .SetProperty(j => j.LeaseUntil, now.AddMinutes(2))
                    .SetProperty(j => j.FirstAttemptAt, j => j.FirstAttemptAt ?? now)
                    .SetProperty(j => j.Sender, j => j.Sender ?? sender)
                    .SetProperty(j => j.Transport, j => j.Transport ?? transport), cancellationToken);
            if (claimed == 0) continue;
            var job = await db.OnboardingEmails.SingleAsync(j => j.Id == id, cancellationToken);
            var account = await db.Accounts.AsNoTracking().SingleOrDefaultAsync(a => a.Id == job.AccountId, cancellationToken);
            if (account == null || !account.Active || account.EmployeeId != job.EmployeeId || account.Email != job.Recipient ||
                !account.MustChangePassword || new PasswordHasher<Account>().VerifyHashedPassword(account, account.PasswordHash,
                    OnboardingMessage.InitialPassword) == PasswordVerificationResult.Failed)
            {
                job.Status = "cancelled"; job.LastError = "Tài khoản đã thay đổi hoặc đã đổi mật khẩu; không gửi thông tin cũ.";
            }
            else if (job.FirstAttemptAt < now.AddHours(-23))
            {
                job.Status = "expired"; job.LastError = "Đã quá thời hạn thử gửi an toàn. Admin cần liên hệ nhân viên hoặc đặt lại mật khẩu.";
            }
            else
            {
                try
                {
                    if (job.Transport != transport)
                        throw new EmailDeliveryUncertain("Phương thức gửi đã thay đổi. Admin cần kiểm tra kết quả gửi trước khi dùng phương thức khác.");
                    job.ProviderId = await delivery.Send(job.Sender!, job.Recipient, OnboardingMessage.Subject,
                        OnboardingMessage.Body(job.FullName, job.Recipient), $"welcome-employee/{job.Id}", cancellationToken);
                    job.SentAt = DateTimeOffset.UtcNow;
                    job.Status = "sent"; job.LastError = null;
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
                catch (Exception e)
                {
                    job.Status = e is EmailDeliveryUncertain ? "needs_review" : "failed";
                    job.LastError = e is EmailDeliveryFailure or EmailDeliveryUncertain ? e.Message : "Không kết nối được dịch vụ gửi email hoặc phản hồi không hợp lệ. Hệ thống sẽ thử lại.";
                    job.NextAttemptAt = DateTimeOffset.UtcNow.AddSeconds(Math.Min(900, 30 * Math.Pow(2, job.Attempts - 1)));
                }
            }
            job.LeaseUntil = null;
            await db.SaveChangesAsync(cancellationToken);
            db.ChangeTracker.Clear();
            await Task.Delay(TimeSpan.FromMilliseconds(750), cancellationToken);
        }
    }
}
