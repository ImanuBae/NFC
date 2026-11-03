using System.Text.Json.Nodes;
using System.Text.Json;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace Attendance.Api;

public static class ApiDocumentation
{
    public static void Configure(IServiceCollection services)
    {
        // Swagger's serializer resolver reads MVC options, whereas Minimal APIs
        // use HttpJsonOptions. Keep both on the actual snake_case wire contract.
        services.Configure<Microsoft.AspNetCore.Mvc.JsonOptions>(o =>
            o.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower);
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
        ["DELETE /api/employees/{id}"] = new("Nhân viên", "Xóa nhân viên và dữ liệu liên quan", "admin; xóa vĩnh viễn tài khoản nhân viên/quản lý, thẻ, mẫu mặt, lịch sử công, ticket, bằng chứng và chi tiết lương"),
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
    const string SamplePng = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=";
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

    static readonly BodyDoc[] Tickets =
    [
        Body("missing_in", "Bổ sung giờ vào; bằng chứng không bắt buộc, ví dụ là ảnh PNG 1 pixel hợp lệ", $$"""{"kind":"missing_in","proposed_at":"2026-11-02T09:00:00+07:00","reason":"Quen quet luot vao","original_event_id":null,"attachments":[{"file_name":"bang_chung.png","content_base64":"{{SamplePng}}"}]}""", "kind", "proposed_at", "reason"),
        Body("missing_out", "Bổ sung giờ ra; có thể gửi không kèm tệp", """{"kind":"missing_out","proposed_at":"2026-11-02T18:00:00+07:00","reason":"Quen quet luot ra","original_event_id":null,"attachments":[]}""", "kind", "proposed_at", "reason"),
        Body("incorrect_time", "Thay original_event_id bằng lượt của chính mình còn hiệu lực; giờ đề nghị phải ở quá khứ và chưa chốt lương", $$"""{"kind":"incorrect_time","proposed_at":"2026-11-02T09:00:00+07:00","reason":"De nghi kiem tra gio ghi nhan","original_event_id":"{{Id}}","attachments":[]}""", "kind", "proposed_at", "reason", "original_event_id")
    ];

    static readonly BodyDoc[] Reviews =
    [
        Body("approve", "Admin/Quản lý duyệt; không tự duyệt; giữ lượt gốc và ghi lượt thay thế khi sửa giờ", """{"decision":"approved","response":"Da doi chieu bang chung"}""", "decision"),
        Body("reject", "Admin/Quản lý từ chối; response bắt buộc và không được để trống", """{"decision":"rejected","response":"Chua du bang chung xac nhan"}""", "decision", "response")
    ];

    static readonly BodyDoc[] Actions =
    [
        Body("save_account", "admin — tạo hoặc cập nhật tài khoản; thêm id khi cập nhật; mật khẩu bắt buộc khi tạo, tối thiểu 12 ký tự", $$"""{"action":"save_account","email":"employee@example.com","password":"MatKhauTest!12345","role":"employee","employee_id":"{{Id}}","active":true}""", "action", "email", "role", "active"),
        Body("approve_face", "admin — kích hoạt mẫu chưa bị thu hồi", $$"""{"action":"approve_face","id":"{{Id}}"}""", "action", "id"),
        Body("revoke_face", "admin — thu hồi mẫu khuôn mặt", $$"""{"action":"revoke_face","id":"{{Id}}"}""", "action", "id"),
        Body("begin_face_enroll", "employee/manager — bắt đầu đăng ký mẫu đầu tiên; trả id và turn_first", """{"action":"begin_face_camera","purpose":"enroll"}""", "action", "purpose"),
        Body("begin_face_reenroll", "employee/manager — thay mẫu của chính mình; mẫu cũ còn hoạt động tới khi finish thành công", """{"action":"begin_face_camera","purpose":"reenroll"}""", "action", "purpose"),
        Body("begin_face_attendance", "kiosk — check_in hoặc check_out; thiết bị phải thuộc tài khoản kiosk", $$"""{"action":"begin_face_camera","purpose":"check_in","device_id":"{{Id}}"}""", "action", "purpose", "device_id"),
        Body("begin_face_checkout", "kiosk — chấm công ra; cần lượt vào hợp lệ và cách lượt trước ít nhất 60 giây", $$"""{"action":"begin_face_camera","purpose":"check_out","device_id":"{{Id}}"}""", "action", "purpose", "device_id"),
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
        foreach (var (status, description) in new[] { ("400", "Dữ liệu hoặc nghiệp vụ không hợp lệ"), ("401", "Chưa đăng nhập hoặc token hết hạn"), ("403", "Không có quyền"), ("404", "Không tìm thấy dữ liệu hoặc không được phép truy cập bằng chứng"), ("409", "Dữ liệu trùng, trạng thái đã thay đổi hoặc kỳ đã chốt"), ("413", "Vượt giới hạn request 8 MB của backend"), ("429", "Vượt giới hạn yêu cầu; phản hồi có thể không có JSON") })
        {
            operation.Responses.TryAdd(status, new OpenApiResponse
            {
                Description = description,
                Content = status is "413" or "429" ? null : new Dictionary<string, OpenApiMediaType>
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
                if (parameter.Name is "employeeId" or "runId" or "id" or "fileId")
                    parameter.Description = "UUID thực tế lấy từ endpoint danh sách tương ứng.";
                if (parameter.Name == "fileId") parameter.Description = "ID trong rows[].attachments[].id của GET /api/attendance/tickets; không phải tên tệp.";
                if (parameter.Name == "query") parameter.Description = "Tìm theo mã, họ tên, email hoặc phòng ban.";
                if (parameter.Name == "active") parameter.Description = "true: đang hoạt động; false: ngừng hoạt động; bỏ qua: tất cả.";
                if (parameter.Name == "end") parameter.Description = "Ngày kết thúc không bao gồm. Ví dụ tháng 10/2026: start=2026-10-01, end=2026-11-01.";
            }

        DescribeResponses(operation, key);
        if (key == "GET /api/employees/{id}")
            operation.Responses["204"] = new OpenApiResponse { Description = "Không có hồ sơ ứng với ID (backend trả null)." };
        if (path.Contains("/attendance/tickets"))
            operation.Description += " Ticket dùng snake_case; trạng thái pending/approved/rejected/cancelled. Tệp JPG/PNG/PDF: tối đa 3 tệp, 2 MB/tệp, tổng 5 MB; gửi base64 trong JSON, không dùng multipart. Giờ đề nghị không ở tương lai; không sửa kỳ lương đã chốt.";
        if (key == "GET /api/payroll/runs/{id}/export")
            operation.Description += " Xuất theo bản chốt PayrollItems, giữ nguyên khi đổi hồ sơ/đơn giá. Giải mã content_base64 để lưu .xlsx; kỳ không còn chi tiết trả 409.";
        if (key.Contains("/emails"))
            operation.Description += " Trạng thái email: pending, sending, sent, failed, cancelled, expired, needs_review. sent là dịch vụ SMTP đã tiếp nhận, chưa xác nhận thư đã vào Inbox.";

        if (key == "PUT /api/employees/{id}") key = "POST /api/employees";
        var docs = key switch {
            "POST /api/business" => Actions,
            "POST /api/attendance/tickets" => Tickets,
            "POST /api/attendance/tickets/{id}/review" => Reviews,
            _ => Bodies.TryGetValue(key, out var body) ? [body] : Array.Empty<BodyDoc>()
        };
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
                    purpose.Enum = [purpose.Example!.DeepClone()];
                }
            }
        }
        foreach (var schema in schemas)
        {
            if (schema.Properties!.TryGetValue("kind", out var kind))
            {
                ((OpenApiSchema)kind).Enum = [((OpenApiSchema)kind).Example!.DeepClone()];
                schema.Properties["attachments"] = EvidenceSchema();
                schema.Properties["original_event_id"].Description = "Lượt chấm công của chính nhân viên, chưa hủy; bắt buộc khi kind=incorrect_time, còn lại null hoặc bỏ qua.";
            }
            if (schema.Properties.TryGetValue("decision", out var decision))
                ((OpenApiSchema)decision).Enum = [((OpenApiSchema)decision).Example!.DeepClone()];
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

    static OpenApiSchema Schema(JsonNode? node, string[]? required = null, string? name = null)
    {
        if (node == null) return new OpenApiSchema { Type = JsonSchemaType.String | JsonSchemaType.Null,
            Format = name == "id" || name?.EndsWith("_id") == true ? "uuid" : null };
        if (node is JsonObject obj)
            return new OpenApiSchema
            {
                Type = JsonSchemaType.Object,
                Properties = obj.ToDictionary(p => p.Key, p => (IOpenApiSchema)Schema(p.Value, name: p.Key)),
                Required = (required ?? []).ToHashSet(), AdditionalPropertiesAllowed = false
            };
        if (node is JsonArray array)
            return name is "first" or "last"
                ? new OpenApiSchema { Type = JsonSchemaType.Array, Items = new OpenApiSchema { Type = JsonSchemaType.Number, Minimum = "-1", Maximum = "1" }, MinItems = 128, MaxItems = 128 }
                : new OpenApiSchema { Type = JsonSchemaType.Array, Items = array.Count > 0 ? Schema(array[0]) : new OpenApiSchema { Type = JsonSchemaType.Object } };
        var schema = new OpenApiSchema { Example = node.DeepClone() };
        var value = (JsonValue)node;
        if (value.TryGetValue<bool>(out _)) schema.Type = JsonSchemaType.Boolean;
        else if (value.TryGetValue<decimal>(out _)) schema.Type = JsonSchemaType.Number;
        else
        {
            schema.Type = JsonSchemaType.String;
            schema.Format = name == "id" || name?.EndsWith("_id") == true ? "uuid"
                : name is "start" or "end" || name?.EndsWith("_date") == true ? "date"
                : name is "device_time" || name?.EndsWith("_at") == true ? "date-time"
                : name == "email" ? "email" : null;
            if (name is "password" or "current_password" or "new_password") schema.Format = "password";
            if (name is "reason" or "response") { schema.MaxLength = 1000; schema.MinLength = name == "reason" ? 1 : null; }
            if (name == "proposed_at") schema.Description = "Giờ đề nghị có múi giờ, không ở tương lai và không thuộc kỳ lương đã chốt.";
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

    static OpenApiSchema EvidenceSchema() => new()
    {
        Type = JsonSchemaType.Array, MaxItems = 3,
        Description = "Không bắt buộc. Tối đa 3 tệp JPG/PNG/PDF; 2 MB mỗi tệp và tổng 5 MB. Server kiểm tra cả chữ ký nội dung.",
        Items = new OpenApiSchema { Type = JsonSchemaType.Object, AdditionalPropertiesAllowed = false,
            Required = new HashSet<string> { "file_name", "content_base64" },
            Properties = new Dictionary<string, IOpenApiSchema> {
                ["file_name"] = new OpenApiSchema { Type = JsonSchemaType.String, MaxLength = 200, Example = JsonValue.Create("bang_chung.png") },
                ["content_base64"] = new OpenApiSchema { Type = JsonSchemaType.String, Format = "byte", MaxLength = (2 * 1024 * 1024 + 2) / 3 * 4, Example = JsonValue.Create(SamplePng), Description = "Base64 thuần, không có tiền tố data URI." }
            }
        }
    };

    static void DescribeResponses(OpenApiOperation operation, string key)
    {
        if (key is "GET /api/payroll/runs/{id}/export" or "GET /api/employees/import/template" or "GET /api/employees/import/{id}/credentials")
        {
            operation.Responses!["200"] = new OpenApiResponse {
                Description = "Tệp XLSX trong JSON; giải mã content_base64 rồi lưu bằng file_name. Không phải response nhị phân hay URL tải công khai.",
                Content = new Dictionary<string, OpenApiMediaType> { ["application/json"] = new() {
                    Schema = new OpenApiSchema { Type = JsonSchemaType.Object, Required = new HashSet<string> { "file_name", "content_base64" },
                        Properties = new Dictionary<string, IOpenApiSchema> {
                            ["file_name"] = new OpenApiSchema { Type = JsonSchemaType.String, Description = "Tên tệp .xlsx do backend trả về." },
                            ["content_base64"] = new OpenApiSchema { Type = JsonSchemaType.String, Format = "byte", Description = "Toàn bộ nội dung XLSX mã hóa base64." }
                        }
                    }
                } }
            };
        }
        BodyDoc[] samples = key switch {
            "POST /api/scans" => [
                Body("recorded", "Lượt chấm công được ghi nhận", $$"""{"status":"ok","event_id":"{{Id}}","type":"check_in","employee_name":"Nhan vien test","employee_code":"NV_TEST","occurred_at":"2026-11-02T09:00:00+07:00"}"""),
                Body("duplicate", "client_scan_id đã được xử lý", """{"status":"duplicate"}"""),
                Body("ignored", "Lượt NFC quá gần lượt trước", """{"status":"ignored","employee_name":"Nhan vien test"}"""),
                Body("rejected", "UID không có hoặc không hoạt động", """{"status":"rejected","reason":"unknown_or_inactive_card"}""")
            ],
            "POST /api/business" => [
                Body("saved_account", "save_account trả ID; lấy thông tin tài khoản bằng GET /api/accounts", $$"""{"id":"{{Id}}"}"""),
                Body("ok", "Đã kích hoạt/thu hồi mẫu", """{"status":"ok"}"""),
                Body("camera_challenge", "begin_face_camera: dùng id cho finish_face_camera", $$"""{"id":"{{Id}}","turn_first":true}"""),
                Body("enrolled", "Đăng ký/đăng ký lại mặt thành công, dùng Kiosk ngay", $$"""{"status":"enrolled","credential_id":"{{Id}}"}"""),
                Body("attendance", "Kiosk nhận diện và ghi nhận chấm công", $$"""{"status":"ok","event_id":"{{Id}}","type":"check_in","employee_name":"Nhan vien test","employee_code":"NV_TEST","occurred_at":"2026-11-02T09:00:00+07:00"}"""),
                Body("sent", "Dịch vụ gửi email đã tiếp nhận báo cáo", """{"status":"sent"}"""),
                Body("already_sent", "Báo cáo kỳ này đã gửi trước đó", """{"status":"already_sent"}""")
            ],
            "GET /api/attendance/tickets/{id}/attachments/{fileId}" => [Body("evidence", "Nội dung tệp chỉ trả khi đúng quyền xem ticket", $$"""{"file_name":"bang_chung.png","content_type":"image/png","size_bytes":{{Convert.FromBase64String(SamplePng).Length}},"content_base64":"{{SamplePng}}"}""")],
            _ => []
        };
        if (samples.Length == 0) return;
        var schemas = samples.Select(s => {
            var node = JsonNode.Parse(s.Json)!.AsObject();
            var schema = Schema(node, node.Select(p => p.Key).ToArray());
            if (schema.Properties!.TryGetValue("status", out var status))
                ((OpenApiSchema)status).Enum = [((OpenApiSchema)status).Example!.DeepClone()];
            if (schema.Properties.TryGetValue("content_base64", out var content)) ((OpenApiSchema)content).Format = "byte";
            return schema;
        }).ToList();
        operation.Responses!["200"] = new OpenApiResponse {
            Description = "Các phản hồi thành công theo kết quả nghiệp vụ; kiểm tra status trước khi coi là đã ghi công/gửi thư.",
            Content = new Dictionary<string, OpenApiMediaType> { ["application/json"] = new() {
                Schema = schemas.Count == 1 ? schemas[0] : new OpenApiSchema { OneOf = schemas.Cast<IOpenApiSchema>().ToList() },
                Examples = samples.ToDictionary(s => s.Name, s => (IOpenApiExample)new OpenApiExample { Summary = s.Summary, Value = JsonNode.Parse(s.Json) })
            } }
        };
    }
}
