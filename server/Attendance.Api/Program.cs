using Attendance.Api;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddJsonFile(Path.GetFullPath(Path.Combine(builder.Environment.ContentRootPath,
    "..", "..", ".local-data", "email-settings.json")), optional: true, reloadOnChange: true);
builder.Configuration.AddEnvironmentVariables();
var attendancePolicy = builder.Configuration.GetSection("AttendancePolicy").Get<AttendancePolicy>() ?? new();
attendancePolicy.Validate();
builder.Services.AddSingleton(attendancePolicy);
ApiDocumentation.Configure(builder.Services);
builder.Services.AddDbContext<AttendanceDb>(o => o.UseSqlServer(builder.Configuration.GetConnectionString("Attendance")));
builder.Services.ConfigureHttpJsonOptions(o => o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower);
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.SetIsOriginAllowed(origin =>
    Uri.TryCreate(origin, UriKind.Absolute, out var u) && (u.Host is "localhost" or "127.0.0.1" || builder.Configuration.GetSection("AllowedOrigins").Get<string[]>()?.Contains(origin) == true)).AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddRateLimiter(o => { o.RejectionStatusCode = 429; o.AddPolicy("login", ctx => RateLimitPartition.GetFixedWindowLimiter(ctx.Connection.RemoteIpAddress?.ToString() ?? "local", _ => new FixedWindowRateLimiterOptions { PermitLimit = 12, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 })); });
builder.Services.AddHttpClient();
builder.Services.AddSingleton<EmailDeliveryService>();
builder.Services.AddDataProtection();
builder.Services.AddHostedService<OnboardingEmailService>();
builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 8 * 1024 * 1024);
var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AttendanceDb>();
    await db.Database.EnsureCreatedAsync();
    // Additive upgrade for existing installations; preserve accounts and attendance.
    await db.Database.ExecuteSqlRawAsync("IF COL_LENGTH('Challenges', 'DeviceId') IS NULL ALTER TABLE [Challenges] ADD [DeviceId] uniqueidentifier NULL;");
    await db.Database.ExecuteSqlRawAsync("""
        IF COL_LENGTH('Employees', 'Department') IS NULL ALTER TABLE [Employees] ADD [Department] nvarchar(200) NULL;
        IF COL_LENGTH('Employees', 'JobTitle') IS NULL ALTER TABLE [Employees] ADD [JobTitle] nvarchar(200) NULL;
        IF COL_LENGTH('Employees', 'Phone') IS NULL ALTER TABLE [Employees] ADD [Phone] nvarchar(30) NULL;
        IF COL_LENGTH('Employees', 'HireDate') IS NULL ALTER TABLE [Employees] ADD [HireDate] date NULL;
        IF OBJECT_ID('EmployeeImports', 'U') IS NULL CREATE TABLE [EmployeeImports] (
            [Id] uniqueidentifier NOT NULL PRIMARY KEY,
            [CreatedBy] uniqueidentifier NOT NULL,
            [PayloadHash] nvarchar(64) NOT NULL,
            [ProtectedResult] nvarchar(max) NOT NULL,
            [CreatedAt] datetimeoffset NOT NULL
        );
        UPDATE [EmployeeImports] SET [ProtectedResult] = N'' WHERE [CreatedAt] < DATEADD(hour, -24, SYSDATETIMEOFFSET()) AND [ProtectedResult] <> N'';
        IF COL_LENGTH('Accounts', 'MustChangePassword') IS NULL ALTER TABLE [Accounts] ADD [MustChangePassword] bit NOT NULL CONSTRAINT [DF_Accounts_MustChangePassword] DEFAULT 0;
        IF OBJECT_ID('OnboardingEmails', 'U') IS NULL
        BEGIN
            CREATE TABLE [OnboardingEmails] (
                [Id] uniqueidentifier NOT NULL PRIMARY KEY, [ImportId] uniqueidentifier NOT NULL,
                [AccountId] uniqueidentifier NOT NULL, [EmployeeId] uniqueidentifier NOT NULL,
                [FullName] nvarchar(200) NOT NULL, [Recipient] nvarchar(254) NOT NULL,
                [Sender] nvarchar(500) NULL, [Status] nvarchar(20) NOT NULL, [Attempts] int NOT NULL,
                [CreatedAt] datetimeoffset NOT NULL, [NextAttemptAt] datetimeoffset NOT NULL,
                [FirstAttemptAt] datetimeoffset NULL, [LeaseUntil] datetimeoffset NULL,
                [SentAt] datetimeoffset NULL, [ProviderId] nvarchar(200) NULL, [LastError] nvarchar(500) NULL
            );
            CREATE UNIQUE INDEX [IX_OnboardingEmails_AccountId] ON [OnboardingEmails] ([AccountId]);
            CREATE INDEX [IX_OnboardingEmails_ImportId] ON [OnboardingEmails] ([ImportId]);
        END;
        IF COL_LENGTH('OnboardingEmails', 'Transport') IS NULL ALTER TABLE [OnboardingEmails] ADD [Transport] nvarchar(20) NULL;
        IF OBJECT_ID('AttendanceTickets', 'U') IS NULL
        BEGIN
            CREATE TABLE [AttendanceTickets] (
                [Id] uniqueidentifier NOT NULL PRIMARY KEY, [EmployeeId] uniqueidentifier NOT NULL,
                [CreatedBy] uniqueidentifier NOT NULL, [Kind] nvarchar(30) NOT NULL,
                [OriginalEventId] uniqueidentifier NULL, [OriginalOccurredAt] datetimeoffset NULL,
                [EventType] nvarchar(20) NOT NULL, [ProposedAt] datetimeoffset NOT NULL,
                [Reason] nvarchar(1000) NOT NULL, [Status] nvarchar(20) NOT NULL,
                [Response] nvarchar(1000) NULL, [ReviewedBy] uniqueidentifier NULL,
                [AppliedEventId] uniqueidentifier NULL, [CreatedAt] datetimeoffset NOT NULL,
                [ReviewedAt] datetimeoffset NULL
            );
            CREATE INDEX [IX_AttendanceTickets_EmployeeId_CreatedAt] ON [AttendanceTickets] ([EmployeeId], [CreatedAt]);
        END;
        IF OBJECT_ID('TicketEvidence', 'U') IS NULL
        BEGIN
            CREATE TABLE [TicketEvidence] (
                [Id] uniqueidentifier NOT NULL PRIMARY KEY,
                [TicketId] uniqueidentifier NOT NULL,
                [FileName] nvarchar(200) NOT NULL,
                [ContentType] nvarchar(50) NOT NULL,
                [Content] varbinary(max) NOT NULL,
                [SizeBytes] int NOT NULL,
                CONSTRAINT [FK_TicketEvidence_AttendanceTickets_TicketId]
                    FOREIGN KEY ([TicketId]) REFERENCES [AttendanceTickets] ([Id]) ON DELETE CASCADE
            );
            CREATE INDEX [IX_TicketEvidence_TicketId] ON [TicketEvidence] ([TicketId]);
        END;
        """);
    // Activate legacy pending enrollments; keep revoked/inactive identities excluded.
    await db.Faces.Where(f => !f.Approved && !f.Revoked && f.Model == "sface-2021dec-v1"
        && db.Accounts.Any(a => a.Id == f.UserId && a.Active && a.EmployeeId == f.EmployeeId
            && (a.Role == "employee" || a.Role == "manager"))
        && db.Employees.Any(e => e.Id == f.EmployeeId && e.Active))
        .ExecuteUpdateAsync(s => s.SetProperty(f => f.Approved, true));
    await Bootstrap.Initialize(db, app.Configuration, app.Environment.ContentRootPath);
    var path = Path.Combine(app.Environment.ContentRootPath, "..", "sql"); Directory.CreateDirectory(path);
    await File.WriteAllTextAsync(Path.Combine(path, "001_schema.sql"), db.Database.GenerateCreateScript());
    if (args.Contains("--write-schema")) return;
}
app.UseCors(); app.UseRateLimiter();
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("v1/swagger.json", "NFC Attendance API v1");
    options.DocumentTitle = "NFC Attendance — Swagger";
    options.EnableFilter();
    options.DisplayRequestDuration();
});
app.Use(async (ctx, next) =>
{
    try
    {
        if (ctx.Request.Method == "OPTIONS" || ctx.Request.Path == "/health" || ctx.Request.Path == "/api/auth/login") { await next(); return; }
        var token = ctx.Request.Headers.Authorization.ToString(); Business.Require(token.StartsWith("Bearer "), "Vui lòng đăng nhập.", 401);
        var db = ctx.RequestServices.GetRequiredService<AttendanceDb>(); var hash = Business.Hash(token[7..]);
        var session = await db.Sessions.AsNoTracking().SingleOrDefaultAsync(s => s.TokenHash == hash && s.ExpiresAt > DateTimeOffset.UtcNow);
        Business.Require(session != null, "Phiên đăng nhập đã hết hạn.", 401);
        var account = await db.Accounts.AsNoTracking().SingleOrDefaultAsync(a => a.Id == session!.AccountId && a.Active);
        Business.Require(account != null, "Tài khoản đã bị khóa.", 401); ctx.Items["account"] = account; ctx.Items["token_hash"] = hash; await next();
    }
    catch (ApiError e) { ctx.Response.StatusCode = e.Status; await ctx.Response.WriteAsJsonAsync(new { error = e.Message }); }
    catch (Exception e) when (e is JsonException or FormatException or InvalidOperationException or KeyNotFoundException or ArgumentException) { ctx.Response.StatusCode = 400; await ctx.Response.WriteAsJsonAsync(new { error = "Dữ liệu yêu cầu không hợp lệ." }); }
    catch (DbUpdateException e) { app.Logger.LogWarning(e, "Database constraint rejected request"); ctx.Response.StatusCode = 409; await ctx.Response.WriteAsJsonAsync(new { error = "Dữ liệu trùng hoặc tham chiếu không hợp lệ." }); }
    catch (Exception e) { app.Logger.LogError(e, "Request failed"); ctx.Response.StatusCode = 500; await ctx.Response.WriteAsJsonAsync(new { error = "Máy chủ gặp lỗi. Vui lòng thử lại." }); }
});
Endpoints.Register(app);
EmployeeImport.Register(app);
AttendanceTickets.Register(app);
app.Run();
