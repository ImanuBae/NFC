using Attendance.Api;
using Microsoft.Extensions.Configuration;

public static class EmailSettingsChecks
{
    public static int Run()
    {
        var checks = 0;
        void Check(bool condition, string message) { if (!condition) throw new Exception(message); checks++; }
        var values = new Dictionary<string, string?> {
            ["Email:Provider"] = "Gmail", ["Email:Smtp:Username"] = "company@example.com",
            ["Email:Smtp:AppPassword"] = "abcd efgh\u00a0ijkl\tmnop", ["Email:From"] = "Company <company@example.com>"
        };
        IConfiguration Config() => new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        Check(EmailDeliveryService.Configured(Config()), "Gmail uses one sender account with one app password");
        Check(EmailDeliveryService.AppPassword(Config()) == "abcdefghijklmnop", "Strip formatting whitespace from Google app password");
        Check(EmailDeliveryService.Provider(Config()) == "Smtp", "Gmail selects SMTP without requiring a Resend API key");
        values["Email:From"] = "Other <other@example.com>";
        Check(!EmailDeliveryService.Configured(Config()), "Reject sender address that differs from authenticated Gmail");
        values["Email:From"] = "";
        Check(EmailDeliveryService.Sender(Config()) == "company@example.com", "Default From to SMTP sender when display address is omitted");
        values["Email:Smtp:AppPassword"] = "";
        Check(!EmailDeliveryService.Configured(Config()), "Incomplete SMTP settings leave the queue pending");
        values["Email:Provider"] = "Resend"; values["Email:ResendApiKey"] = "test-key";
        values["Email:From"] = "sender@example.com";
        Check(EmailDeliveryService.Configured(Config()), "Existing Resend option remains supported when explicitly selected");
        values["Email:Enabled"] = "false";
        Check(!EmailDeliveryService.Configured(Config()), "Test runs can disable all outgoing mail regardless of local secrets");
        return checks;
    }
}
