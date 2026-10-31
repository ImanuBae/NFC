using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace Attendance.Api;

public sealed class EmailDeliveryFailure(string message) : Exception(message);
public sealed class EmailDeliveryUncertain(string message) : Exception(message);

public sealed class EmailDeliveryService(IConfiguration config, IHttpClientFactory clients)
{
    public static string Provider(IConfiguration config) =>
        string.Equals(config["Email:Provider"], "Resend", StringComparison.OrdinalIgnoreCase) ? "Resend" : "Smtp";
    public static string Sender(IConfiguration config) =>
        string.IsNullOrWhiteSpace(config["Email:From"]) ? config["Email:Smtp:Username"]?.Trim() ?? "" : config["Email:From"]!.Trim();
    public static string AppPassword(IConfiguration config) =>
        new((config["Email:Smtp:AppPassword"] ?? "").Where(c => !char.IsWhiteSpace(c)).ToArray());
    public static bool Configured(IConfiguration config)
    {
        if (!config.GetValue("Email:Enabled", true) || !MailboxAddress.TryParse(Sender(config), out var from)) return false;
        if (Provider(config) == "Resend") return !string.IsNullOrWhiteSpace(config["Email:ResendApiKey"]);
        var username = config["Email:Smtp:Username"]?.Trim();
        return !string.IsNullOrEmpty(AppPassword(config)) && !string.IsNullOrWhiteSpace(username)
            && string.Equals(from.Address, username, StringComparison.OrdinalIgnoreCase);
    }

    public async Task VerifySmtp(CancellationToken cancellationToken = default)
    {
        if (Provider(config) != "Smtp" || !Configured(config))
            throw new EmailDeliveryFailure("Cần cấu hình Gmail gửi và mật khẩu ứng dụng trước khi kiểm tra SMTP.");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(30));
        using var smtp = new SmtpClient();
        await ConnectSmtp(smtp, timeout.Token, cancellationToken);
        try { await smtp.DisconnectAsync(true, timeout.Token); } catch { }
    }

    async Task ConnectSmtp(SmtpClient smtp, CancellationToken timeout, CancellationToken stopping)
    {
        var host = config["Email:Smtp:Host"] ?? "smtp.gmail.com";
        var port = config.GetValue("Email:Smtp:Port", 587);
        var security = port == 465 ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTls;
        if (config.GetValue("Email:Smtp:AllowLocalPlaintext", false))
        {
            if (!(host == "localhost" || (IPAddress.TryParse(host, out var ip) && IPAddress.IsLoopback(ip))))
                throw new EmailDeliveryFailure("Chế độ SMTP không TLS chỉ dành cho máy chủ kiểm thử localhost.");
            security = SecureSocketOptions.None;
        }
        try
        {
            await smtp.ConnectAsync(host, port, security, timeout);
            smtp.AuthenticationMechanisms.Remove("XOAUTH2");
            smtp.AuthenticationMechanisms.Remove("OAUTHBEARER");
            await smtp.AuthenticateAsync(config["Email:Smtp:Username"]!.Trim(), AppPassword(config), timeout);
        }
        catch (OperationCanceledException) when (stopping.IsCancellationRequested) { throw; }
        catch (MailKit.Security.AuthenticationException)
        { throw new EmailDeliveryFailure("Gmail từ chối đăng nhập. Kiểm tra đúng Gmail gửi và mật khẩu ứng dụng Google."); }
        catch (Exception)
        { throw new EmailDeliveryFailure("Không kết nối hoặc xác thực được SMTP. Kiểm tra mạng, cấu hình Gmail và TLS."); }
    }

    public async Task<string> Send(string sender, string recipient, string subject, string body, string operationId,
        CancellationToken cancellationToken = default)
    {
        if (!Configured(config)) throw new EmailDeliveryFailure("Chưa cấu hình email gửi: cần Gmail công ty và mật khẩu ứng dụng trên backend.");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(30));
        if (Provider(config) == "Resend")
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, config["Email:ResendEndpoint"] ?? "https://api.resend.com/emails");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", config["Email:ResendApiKey"]);
            request.Headers.Add("Idempotency-Key", operationId);
            request.Content = JsonContent.Create(new { from = sender, to = new[] { recipient }, subject, text = body });
            using var response = await clients.CreateClient().SendAsync(request, timeout.Token);
            if (!response.IsSuccessStatusCode) throw new EmailDeliveryFailure($"Dịch vụ gửi thư trả HTTP {(int)response.StatusCode}. Kiểm tra cấu hình và hạn mức gửi.");
            var data = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: timeout.Token);
            if (!data.TryGetProperty("id", out var id) || string.IsNullOrEmpty(id.GetString()))
                throw new EmailDeliveryFailure("Dịch vụ gửi thư không trả mã thư hợp lệ.");
            return id.GetString()!;
        }

        var from = MailboxAddress.Parse(sender);
        if (!string.Equals(from.Address, config["Email:Smtp:Username"]?.Trim(), StringComparison.OrdinalIgnoreCase))
            throw new EmailDeliveryFailure("Địa chỉ gửi phải khớp Gmail đã tạo mật khẩu ứng dụng. Kiểm tra lại cấu hình người gửi.");
        var message = new MimeMessage();
        message.From.Add(from); message.To.Add(MailboxAddress.Parse(recipient));
        message.Subject = subject; message.Body = new TextPart("plain") { Text = body };
        // Stable Message-Id assists manual reconciliation; SMTP does not provide idempotency guarantees.
        var messageKey = Business.Hash(operationId).ToLowerInvariant();
        message.MessageId = $"{messageKey}@{from.Address.Split('@').Last()}";
        using var smtp = new SmtpClient();
        // Never override certificate validation or log the SMTP protocol containing credentials.
        await ConnectSmtp(smtp, timeout.Token, cancellationToken);
        try { await smtp.SendAsync(message, timeout.Token); }
        catch (SmtpCommandException)
        { throw new EmailDeliveryFailure("SMTP từ chối thư hoặc người nhận. Kiểm tra email nhận và hạn mức gửi của Gmail."); }
        catch (Exception)
        { throw new EmailDeliveryUncertain("Mất kết nối khi gửi SMTP. Chưa xác định Gmail đã nhận thư hay chưa; Admin kiểm tra thư mục Đã gửi trước khi xử lý tiếp. Hệ thống không tự gửi lại thư này."); }
        // A failed QUIT must not turn an already accepted message into a retry.
        try { await smtp.DisconnectAsync(true, timeout.Token); } catch { }
        return message.MessageId;
    }
}
