using System.Text.Json.Nodes;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace Attendance.Api;

public static class ApiDocumentation
{
    public static void Configure(IServiceCollection services)
    {
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc("v1", new OpenApiInfo
            {
                Title = "NFC Attendance API", Version = "v1",
                Description = "Đăng nhập bằng POST /api/auth/login, sao chép token rồi bấm Authorize và dán token (không thêm Bearer). " +
                    "Đổi token để test theo quyền admin, manager, employee hoặc kiosk. " +
                    "Các ví dụ dùng ID giả: thay bằng ID từ dữ liệu của bạn. Ngày end không được tính vào kỳ báo cáo. " +
                    "API ghi dữ liệu sẽ tác động trực tiếp tới database đang kết nối."
            });
            options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
            {
                Type = SecuritySchemeType.Http, Scheme = "bearer",
                Description = "Session token trả về từ /api/auth/login; đây không phải JWT. Chỉ dán token."
            });
            options.OperationFilter<AttendanceOperationFilter>();
        });
    }
}

public sealed class AttendanceOperationFilter : IOperationFilter
{
    const string Id = "11111111-1111-4111-8111-111111111111";
    record EndpointDoc(string Tag, string Summary, string Access);
    record BodyDoc(string Name, string Summary, string Json, string[] Required);

    static readonly Dictionary<string, EndpointDoc> Endpoints = new()
    {
        ["GET /health"] = new("Hệ thống", "Kiểm tra API và kết nối SQL Server", "Công khai"),
        ["POST /api/auth/login"] = new("Xác thực", "Đăng nhập và lấy session token", "Công khai; giới hạn 12 lần/phút/IP"),
        ["GET /api/auth/me"] = new("Xác thực", "Thông tin tài khoản đang đăng nhập", "Mọi tài khoản đang hoạt động"),
        ["POST /api/auth/change-password"] = new("Xác thực", "Đổi mật khẩu của chính mình", "admin, manager, employee; thu hồi các phiên khác"),
        ["POST /api/auth/logout"] = new("Xác thực", "Đăng xuất phiên hiện tại", "Mọi tài khoản đang hoạt động"),
        ["GET /api/employees"] = new("Nhân viên", "Danh sách và tìm kiếm nhân viên", "admin/manager xem danh sách; tài khoản khác chỉ xem hồ sơ của mình"),
        ["GET /api/employees/{id}"] = new("Nhân viên", "Chi tiết nhân viên", "admin/manager hoặc chính nhân viên"),
        ["POST /api/employees"] = new("Nhân viên", "Tạo nhân viên", "admin"),
        ["PUT /api/employees/{id}"] = new("Nhân viên", "Cập nhật nhân viên", "admin; ngừng hoạt động sẽ khóa thẻ và thu hồi mẫu mặt"),
        ["DELETE /api/employees/{id}"] = new("Nhân viên", "Xóa nhân viên và dữ liệu liên quan", "admin; xóa vĩnh viễn tài khoản nhân viên/quản lý, thẻ, mẫu mặt, lịch sử công và chi tiết lương"),
        ["GET /api/cards"] = new("Thẻ NFC", "Danh sách thẻ theo nhân viên hoặc UID", "admin/manager xem danh sách; tài khoản khác chỉ xem thẻ của mình"),
        ["POST /api/cards"] = new("Thẻ NFC", "Gán UID thẻ cho nhân viên", "admin; UID phải là chuỗi hex duy nhất"),
        ["PUT /api/cards/{uid}"] = new("Thẻ NFC", "Khóa hoặc kích hoạt thẻ", "admin"),
        ["GET /api/attendance/events"] = new("Chấm công", "Lịch sử lượt vào/ra", "admin/manager hoặc lịch sử của chính nhân viên"),
        ["GET /api/attendance/tickets"] = new("Ticket sửa công", "Danh sách ticket", "admin/manager xem danh sách; employee chỉ xem của mình"),
        ["GET /api/attendance/tickets/{id}/attachments/{fileId}"] = new("Ticket sửa công", "Xem hoặc tải bằng chứng đính kèm", "admin/manager hoặc đúng nhân viên sở hữu ticket; không có URL công khai"),
        ["POST /api/attendance/tickets"] = new("Ticket sửa công", "Tạo ticket sửa công", "employee/manager; dùng hồ sơ của tài khoản; chưa thay đổi công"),
        ["POST /api/attendance/tickets/{id}/cancel"] = new("Ticket sửa công", "Hủy ticket đang chờ", "Người tạo và đúng hồ sơ nhân viên"),
        ["POST /api/attendance/tickets/{id}/review"] = new("Ticket sửa công", "Duyệt hoặc từ chối ticket", "admin/manager; không tự duyệt; không sửa kỳ lương đã chốt"),
        ["GET /api/attendance/days"] = new("Chấm công", "Bảng công ngày và tổng thời gian làm việc", "admin, manager, employee; employee chỉ xem bản thân"),
        ["POST /api/attendance/manual"] = new("Chấm công", "Thêm lượt chấm công thủ công", "admin/manager; cần lý do; không ghi vào kỳ đã chốt"),
        ["POST /api/attendance/{id}/void"] = new("Chấm công", "Hủy một lượt chấm công", "admin/manager; cần lý do; không hủy trong kỳ đã chốt"),
        ["POST /api/devices"] = new("Kiosk & NFC", "Đăng ký thiết bị kiosk", "kiosk hoặc admin"),
        ["POST /api/scans"] = new("Kiosk & NFC", "Gửi lượt quét NFC trực tuyến hoặc đồng bộ offline", "kiosk/admin; device_id phải thuộc thiết bị hợp lệ. client_scan_id dùng để chống ghi trùng"),
        ["GET /api/accounts"] = new("Tài khoản & khuôn mặt", "Danh sách tài khoản", "admin; không trả về password hash"),
        ["GET /api/faces"] = new("Tài khoản & khuôn mặt", "Trạng thái các mẫu khuôn mặt", "admin xem toàn bộ; người dùng khác chỉ xem mẫu của mình; không trả embedding"),
        ["GET /api/reports"] = new("Báo cáo & lương", "Báo cáo công và lương tạm tính trong khoảng ngày", "admin/manager; start bao gồm, end không bao gồm"),
        ["GET /api/payroll/runs"] = new("Báo cáo & lương", "Các kỳ lương đã chốt", "admin/manager; nhân viên chỉ xem kỳ có lương của mình"),
        ["GET /api/payroll/runs/{id}/export"] = new("Báo cáo & lương", "Xuất Excel bảng lương đã chốt", "admin/manager; số liệu từ bản chốt, không tính lại theo hồ sơ hiện tại"),
        ["GET /api/payroll/items"] = new("Báo cáo & lương", "Chi tiết lương đã chốt", "admin/manager; nhân viên chỉ xem bản thân"),
        ["POST /api/payroll/close"] = new("Báo cáo & lương", "Chốt một kỳ lương đã kết thúc", "admin/manager; tuần bắt đầu thứ Hai, tháng bắt đầu ngày 1; kỳ không được chồng nhau"),
        ["POST /api/business"] = new("Nghiệp vụ", "Tài khoản, mẫu khuôn mặt, camera và gửi báo cáo", "Theo action; chọn mẫu trong danh sách Examples ở phần Request body"),
        ["GET /api/employees/import/recent"] = new("Nhập Excel", "Các lần nhập gần đây của quản trị viên", "admin; 10 lần gần nhất trong 24 giờ"),
        ["GET /api/employees/import/template"] = new("Nhập Excel", "Tải file Excel mẫu dưới dạng base64", "admin"),
        ["POST /api/employees/import/preview"] = new("Nhập Excel", "Đọc Excel và kiểm tra trước khi nhập", "admin; file .xls/.xlsx tối đa 5 MB, tối đa 1000 nhân viên; chưa ghi dữ liệu"),
        ["POST /api/employees/import/commit"] = new("Nhập Excel", "Nhập nhân viên, tài khoản và thẻ từ Excel", "admin; tạo import_id UUID mới cho lần nhập và giữ nguyên khi thử lại cùng file"),
        ["GET /api/employees/import/email-settings"] = new("Nhập Excel", "Kiểm tra trạng thái cấu hình email", "admin; không trả bí mật email"),
        ["POST /api/employees/import/email-test"] = new("Nhập Excel", "Kiểm tra đăng nhập Gmail SMTP", "admin; chỉ kiểm tra kết nối, không gửi email"),
        ["GET /api/employees/import/{id}/emails"] = new("Nhập Excel", "Trạng thái gửi email của lần nhập", "admin; lần nhập thuộc quản trị viên hiện tại"),
        ["POST /api/employees/import/{id}/emails/retry"] = new("Nhập Excel", "Đưa các email lỗi về hàng đợi để gửi lại", "admin; lần nhập thuộc quản trị viên hiện tại"),
        ["GET /api/employees/import/{id}/credentials"] = new("Nhập Excel", "Tải Excel tài khoản và mật khẩu khởi tạo", "admin; chỉ lần nhập của mình trong vòng 24 giờ")
    };

    static BodyDoc Body(string name, string summary, string json, params string[] required) => new(name, summary, json, required);
    static readonly Dictionary<string, BodyDoc> Bodies = new()
    {
        ["POST /api/auth/login"] = Body("login", "Dùng email và mật khẩu tài khoản của bạn", """{"email":"admin@example.com","password":"NhapMatKhauCuaBan"}""", "email", "password"),
        ["POST /api/auth/change-password"] = Body("password", "Mật khẩu mới 8–128 ký tự, khác mật khẩu cũ và mật khẩu mặc định", """{"current_password":"NhapMatKhauCu","new_password":"NhapMatKhauMoi!123"}""", "current_password", "new_password"),
        ["POST /api/employees"] = Body("employee", "Thông tin nhân viên; hourly_rate không âm", """{"code":"NV_TEST","full_name":"Nhan vien test","active":true,"hourly_rate":50000}""", "code", "full_name", "active"),
        ["POST /api/cards"] = Body("card", "Thay employee_id bằng ID nhân viên thực tế", $$"""{"uid":"04AABBCCDD","employee_id":"{{Id}}"}""", "uid", "employee_id"),
        ["PUT /api/cards/{uid}"] = Body("active", "false để khóa, true để kích hoạt", """{"active":false}""", "active"),
        ["POST /api/attendance/manual"] = Body("manual", "Thay ID và thời gian; thời gian phải ở quá khứ và chưa chốt lương", $$"""{"employee_id":"{{Id}}","type":"check_in","occurred_at":"2026-10-01T09:00:00+07:00","reason":"Bo sung luot bi thieu"}""", "employee_id", "type", "occurred_at", "reason"),
        ["POST /api/attendance/{id}/void"] = Body("void", "Lý do hủy lượt", """{"reason":"Luot quet nham"}""", "reason"),
        ["POST /api/devices"] = Body("device", "Đặt tên điểm chấm công", """{"name":"Kiosk test"}""", "name"),
        ["POST /api/scans"] = Body("scan", "Thay UID, device_id, thời gian và dùng UUID client_scan_id mới cho lượt mới", $$"""{"uid":"04AABBCCDD","device_id":"{{Id}}","client_scan_id":"22222222-2222-4222-8222-222222222222","device_time":"2026-10-31T09:00:00+07:00","is_replay":false}""", "uid", "device_id", "client_scan_id", "device_time", "is_replay"),
        ["POST /api/payroll/close"] = Body("payroll", "Chỉ chốt kỳ đã kết thúc; end được backend tự tính", """{"start":"2026-09-01","period":"month"}""", "start", "period"),
        ["POST /api/employees/import/preview"] = Body("preview", "content_base64 là nội dung file Excel, không kèm tiền tố data URI", """{"file_name":"nhan_vien.xlsx","content_base64":"THAY_BANG_BASE64_FILE_EXCEL","department":"IT"}""", "file_name", "content_base64"),
        ["POST /api/employees/import/commit"] = Body("commit", "Dùng cùng file đã preview; import_id là UUID cho lần nhập này", $$"""{"file_name":"nhan_vien.xlsx","content_base64":"THAY_BANG_BASE64_FILE_EXCEL","department":"IT","import_id":"{{Id}}"}""", "file_name", "content_base64", "import_id")
    };

    static readonly BodyDoc[] Actions =
    [
        Body("save_account", "admin — tạo hoặc cập nhật tài khoản; thêm id khi cập nhật; mật khẩu bắt buộc khi tạo, tối thiểu 12 ký tự", $$"""{"action":"save_account","email":"employee@example.com","password":"MatKhauTest!12345","role":"employee","employee_id":"{{Id}}","active":true}""", "action", "email", "role", "active"),
        Body("approve_face", "admin — kích hoạt mẫu chưa bị thu hồi", $$"""{"action":"approve_face","id":"{{Id}}"}""", "action", "id"),
        Body("revoke_face", "admin — thu hồi mẫu khuôn mặt", $$"""{"action":"revoke_face","id":"{{Id}}"}""", "action", "id"),
        Body("begin_face_enroll", "employee/manager — bắt đầu đăng ký mẫu đầu tiên; trả id và turn_first", """{"action":"begin_face_camera","purpose":"enroll"}""", "action", "purpose"),
        Body("begin_face_reenroll", "employee/manager — thay mẫu của chính mình; mẫu cũ còn hoạt động tới khi finish thành công", """{"action":"begin_face_camera","purpose":"reenroll"}""", "action", "purpose"),
        Body("begin_face_attendance", "kiosk — check_in hoặc check_out; thiết bị phải thuộc tài khoản kiosk", $$"""{"action":"begin_face_camera","purpose":"check_in","device_id":"{{Id}}"}""", "action", "purpose", "device_id"),
        Body("finish_face_camera", "Hoàn tất challenge. first/last phải là hai vector 128 phần tử từ model SFace trên Android; Swagger không thay thế bước chụp camera", $$"""{"action":"finish_face_camera","challenge_id":"{{Id}}","model":"sface-2021dec-v1","first":[] ,"last":[]}""", "action", "challenge_id", "model", "first", "last"),
        Body("email_report", "admin/manager — gửi báo cáo thật tới email tài khoản nhân viên; end không bao gồm", $$"""{"action":"email_report","employee_id":"{{Id}}","start":"2026-09-01","end":"2026-10-01"}""", "action", "employee_id", "start", "end")
    ];

    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        var path = "/" + context.ApiDescription.RelativePath!.Split('?')[0].Replace(":guid", "");
        var key = context.ApiDescription.HttpMethod + " " + path;
        if (!Endpoints.TryGetValue(key, out var doc))
            throw new InvalidOperationException($"Missing API documentation: {key}");
        operation.Tags = new HashSet<OpenApiTagReference> { new(doc.Tag, context.Document) };
        operation.Summary = doc.Summary;
        operation.Description = "Quyền: " + doc.Access + ".";
        operation.OperationId = context.ApiDescription.HttpMethod!.ToLowerInvariant() + "_" + path.Trim('/').Replace('/', '_').Replace("{", "").Replace("}", "").Replace('-', '_');
        var publicEndpoint = path == "/health" || path == "/api/auth/login";
        operation.Security = publicEndpoint ? [] : [new OpenApiSecurityRequirement { [new OpenApiSecuritySchemeReference("Bearer", context.Document)] = [] }];
        operation.Responses ??= new OpenApiResponses();
        foreach (var (status, description) in new[] { ("400", "Dữ liệu hoặc nghiệp vụ không hợp lệ"), ("401", "Chưa đăng nhập hoặc token hết hạn"), ("403", "Không có quyền"), ("409", "Dữ liệu trùng, trạng thái đã thay đổi hoặc kỳ đã chốt"), ("429", "Vượt giới hạn yêu cầu") })
        {
            operation.Responses.TryAdd(status, new OpenApiResponse
            {
                Description = description,
                Content = new Dictionary<string, OpenApiMediaType>
                {
                    ["application/json"] = new() { Schema = Schema(JsonNode.Parse("""{"error":"Thông báo lỗi"}""")!, ["error"]) }
                }
            });
        }
        if (operation.Parameters != null)
            foreach (var parameter in operation.Parameters.OfType<OpenApiParameter>())
            {
                if (parameter.Name is "date" or "start" or "end")
                    parameter.Example = JsonValue.Create(parameter.Name == "end" ? "2026-10-01" : "2026-09-01");
                if (parameter.Name is "employeeId" or "runId" or "id")
                    parameter.Description = "UUID thực tế lấy từ endpoint danh sách tương ứng.";
            }

        if (key == "PUT /api/employees/{id}") key = "POST /api/employees";
        var docs = key == "POST /api/business" ? Actions : Bodies.TryGetValue(key, out var body) ? [body] : Array.Empty<BodyDoc>();
        if (docs.Length == 0) return;
        var schemas = docs.Select(d => Schema(JsonNode.Parse(d.Json)!, d.Required)).ToList();
        // JsonElement bodies have no discoverable fields; describe the actual wire payload.
        if (key == "POST /api/business")
        {
            schemas[0].Properties!["id"] = new OpenApiSchema { Type = JsonSchemaType.String, Format = "uuid", Description = "Tùy chọn: ID tài khoản cần cập nhật; bỏ qua để tạo mới." };
            foreach (var schema in schemas)
            {
                var action = (OpenApiSchema)schema.Properties!["action"];
                action.Enum = [action.Example!.DeepClone()];
                if (schema.Properties.TryGetValue("purpose", out var purposeSchema))
                {
                    var purpose = (OpenApiSchema)purposeSchema;
                    purpose.Enum = purpose.Example!.GetValue<string>() == "check_in"
                        ? [JsonValue.Create("check_in")!, JsonValue.Create("check_out")!]
                        : [purpose.Example.DeepClone()];
                }
            }
        }
        operation.RequestBody = new OpenApiRequestBody
        {
            Required = true,
            Content = new Dictionary<string, OpenApiMediaType>
            {
                ["application/json"] = new()
                {
                    Schema = schemas.Count == 1 ? schemas[0] : new OpenApiSchema { OneOf = schemas.Cast<IOpenApiSchema>().ToList() },
                    Examples = docs.ToDictionary(d => d.Name, d => (IOpenApiExample)new OpenApiExample { Summary = d.Summary, Value = JsonNode.Parse(d.Json) })
                }
            }
        };
    }

    static OpenApiSchema Schema(JsonNode node, string[]? required = null, string? name = null)
    {
        if (node is JsonObject obj)
            return new OpenApiSchema
            {
                Type = JsonSchemaType.Object,
                Properties = obj.ToDictionary(p => p.Key, p => (IOpenApiSchema)Schema(p.Value!, name: p.Key)),
                Required = (required ?? []).ToHashSet(), AdditionalPropertiesAllowed = false
            };
        if (node is JsonArray)
            return new OpenApiSchema { Type = JsonSchemaType.Array, Items = new OpenApiSchema { Type = JsonSchemaType.Number, Minimum = "-1", Maximum = "1" }, MinItems = 128, MaxItems = 128 };
        var schema = new OpenApiSchema { Example = node.DeepClone() };
        var value = (JsonValue)node;
        if (value.TryGetValue<bool>(out _)) schema.Type = JsonSchemaType.Boolean;
        else if (value.TryGetValue<decimal>(out _)) schema.Type = JsonSchemaType.Number;
        else
        {
            schema.Type = JsonSchemaType.String;
            schema.Format = name == "id" || name?.EndsWith("_id") == true ? "uuid"
                : name is "start" or "end" ? "date"
                : name is "occurred_at" or "device_time" ? "date-time"
                : name == "email" ? "email" : null;
            if (name is "password" or "current_password" or "new_password") schema.Format = "password";
            var choices = name switch
            {
                "purpose" => new[] { "enroll", "reenroll", "check_in", "check_out" },
                "type" => ["check_in", "check_out"],
                "role" => ["admin", "manager", "employee", "kiosk"],
                "period" => ["week", "month"],
                _ => null
            };
            if (choices != null) schema.Enum = choices.Select(x => (JsonNode)JsonValue.Create(x)!).ToList();
        }
        return schema;
    }
}
