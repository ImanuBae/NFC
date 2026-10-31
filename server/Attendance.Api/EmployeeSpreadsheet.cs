using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Xml.Linq;
using ExcelDataReader;
using static Attendance.Api.Business;

namespace Attendance.Api;

public record EmployeeUpload(string FileName, string ContentBase64, string? Department, Guid? ImportId);
public record EmployeeImportRow(string Sheet, int RowNumber, string Code, string FullName, string Email,
    string? Department, string? JobTitle, string? Phone, string? HireDate, decimal HourlyRate,
    List<string> Errors, List<string> Warnings)
{
    public string Status { get; set; } = "create";
    public string? UidThe { get; set; }
    public bool HasHourlyRate { get; set; }
    public bool NeedsCard { get; set; }
    public List<string> UpdatedFields { get; set; } = [];
}

public static class EmployeeSpreadsheet
{
    public const int MaxBytes = 5 * 1024 * 1024;
    public const int MaxRows = 1000;
    static readonly Dictionary<string, string[]> Aliases = new()
    {
        ["code"] = ["Mã NV", "Mã nhân viên", "Mã số nhân viên", "Employee Code", "Code"],
        ["name"] = ["Họ và tên", "Họ tên", "Tên nhân viên", "Full Name", "Name"],
        ["email"] = ["Email", "E-mail", "Email công ty", "Địa chỉ email"],
        ["department"] = ["Phòng ban", "Bộ phận", "Phòng", "Department"],
        ["title"] = ["Chức vụ", "Chức danh", "Vị trí", "Job Title", "Position"],
        ["phone"] = ["Số điện thoại", "Điện thoại", "SĐT", "Phone", "Phone Number"],
        ["date"] = ["Ngày vào làm", "Ngày vào", "Ngày bắt đầu", "Ngày nhận việc", "Hire Date", "Start Date"],
        ["rate"] = ["Đơn giá giờ", "Đơn giá VND/giờ", "Lương giờ", "Hourly Rate"],
        ["uid"] = ["uid_the", "UID", "UID thẻ", "UID thẻ NFC", "UID NFC", "NFC UID", "Card UID"]
    };
    static string Normalize(string value) => new(value.Replace('đ', 'd').Replace('Đ', 'D')
        .Normalize(NormalizationForm.FormD).Where(char.IsLetterOrDigit).Select(char.ToLowerInvariant).ToArray());
    static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    public static byte[] Decode(EmployeeUpload upload)
    {
        Require(Path.GetExtension(upload.FileName ?? "").ToLowerInvariant() is ".xls" or ".xlsx", "Chọn file Excel .xls hoặc .xlsx.", 400);
        Require(upload.ContentBase64 != null && upload.ContentBase64.Length <= (MaxBytes + 2) / 3 * 4, "File tối đa 5 MB.", 400);
        byte[] bytes;
        try { bytes = Convert.FromBase64String(upload.ContentBase64!); }
        catch (FormatException) { throw new ApiError("Nội dung file không hợp lệ.", 400); }
        Require(bytes.Length > 0 && bytes.Length <= MaxBytes, "File trống hoặc lớn hơn 5 MB.", 400);
        return bytes;
    }

    public static List<EmployeeImportRow> Read(byte[] bytes, string? department, List<string>? ignoredSheets = null)
    {
        Require(department?.Trim().Length is null or <= 200, "Phòng ban tối đa 200 ký tự.", 400);
        var previousCulture = CultureInfo.CurrentCulture;
        try
        {
            // The reader also parses strings in date-styled cells using CurrentCulture.
            // Keep dd/MM/yyyy semantics independent of the server's Windows language.
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("vi-VN");
            // Bound expanded XLSX content before passing it to the workbook reader.
            if (bytes.Length >= 2 && bytes[0] == 'P' && bytes[1] == 'K')
            {
                using var zip = new ZipArchive(new MemoryStream(bytes));
                Require(zip.Entries.Count <= 2000 && zip.Entries.Sum(e => e.Length) <= 40 * 1024 * 1024,
                    "File Excel có nội dung giải nén quá lớn.", 400);
            }
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
            using var reader = ExcelReaderFactory.CreateReader(new MemoryStream(bytes));
            var rows = new List<EmployeeImportRow>();
            var scanned = 0;
            do
            {
                Dictionary<string, int>? columns = null;
                while (reader.Read())
                {
                    Require(++scanned <= 20_000, "File có quá nhiều dòng trống hoặc dữ liệu; hãy tách file nhỏ hơn.", 400);
                    if (columns == null)
                    {
                        if (reader.Depth >= 30) break;
                        var candidates = new Dictionary<string, int>();
                        for (var i = 0; i < Math.Min(reader.FieldCount, 100); i++)
                        {
                            var header = Normalize(Convert.ToString(reader.GetValue(i), CultureInfo.InvariantCulture) ?? "");
                            foreach (var (key, aliases) in Aliases)
                                if (aliases.Any(a => Normalize(a) == header)) candidates.TryAdd(key, i);
                        }
                        if (new[] { "code", "name", "email" }.All(candidates.ContainsKey)) columns = candidates;
                        continue;
                    }
                    object? Value(string key) => columns.TryGetValue(key, out var i) ? reader.GetValue(i) : null;
                    string Text(string key)
                    {
                        var value = Value(key);
                        if (value is double number && columns.TryGetValue(key, out var column))
                        {
                            var format = reader.GetNumberFormatString(column);
                            if (!string.IsNullOrEmpty(format) && format.All(c => c == '0') && format.Length <= 30)
                                return number.ToString(format, CultureInfo.InvariantCulture);
                        }
                        return Convert.ToString(value, CultureInfo.InvariantCulture)?.Trim() ?? "";
                    }
                    if (new[] { "code", "name", "email", "department", "title", "phone", "date", "rate", "uid" }.All(k => string.IsNullOrWhiteSpace(Text(k)))) continue;
                    Require(rows.Count < MaxRows, $"Mỗi lần nhập tối đa {MaxRows} nhân viên.", 400);
                    var errors = new List<string>(); var warnings = new List<string>();
                    var code = Text("code").ToUpperInvariant();
                    var name = Text("name");
                    var email = Text("email").ToLowerInvariant();
                    var dept = Clean(Text("department")) ?? Clean(department);
                    var title = Clean(Text("title"));
                    var uid = Clean(Text("uid"));
                    if (uid != null)
                    {
                        uid = new string(uid.Where(c => !char.IsWhiteSpace(c) && c != ':' && c != '-').ToArray()).ToUpperInvariant();
                        if (Value("uid") is not string)
                            errors.Add("uid_the phải là ô Text để giữ số 0 đầu và tránh Excel làm mất độ chính xác. Đọc lại UID từ thẻ nếu ô đang là số.");
                        if (uid.Length < 2 || uid.Length > 64 || uid.Length % 2 != 0 || !uid.All(Uri.IsHexDigit))
                            errors.Add("uid_the phải là UID hexadecimal đầy đủ (0–9, A–F), số ký tự chẵn, tối đa 64 ký tự.");
                    }
                    var phone = Clean(Text("phone"));
                    if (Value("phone") is double or int or long)
                    {
                        var format = reader.GetNumberFormatString(columns["phone"]);
                        if (format != null && format.All(c => c == '0') && format.Length <= 15 && Value("phone") is double number)
                            phone = number.ToString(format, CultureInfo.InvariantCulture);
                        else warnings.Add("Số điện thoại đang ở dạng số; kiểm tra số 0 đầu. Nên đặt cột dạng Text trong Excel.");
                    }
                    string? hireDate = null;
                    if (Value("date") is DateTime dt) hireDate = DateOnly.FromDateTime(dt).ToString("yyyy-MM-dd");
                    else if (Value("date") is DateTimeOffset dto) hireDate = DateOnly.FromDateTime(dto.DateTime).ToString("yyyy-MM-dd");
                    else if (Clean(Text("date")) is string dateText)
                    {
                        if (DateOnly.TryParseExact(dateText, ["d/M/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "d-M-yyyy", "dd-MM-yyyy"], CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
                            hireDate = parsed.ToString("yyyy-MM-dd");
                        else if (Value("date") is double serial && serial is >= 1 and <= 146097)
                            hireDate = DateOnly.FromDateTime(DateTime.FromOADate(serial)).ToString("yyyy-MM-dd");
                        else errors.Add($"Ngày vào làm '{dateText}' không hợp lệ; dùng dd/MM/yyyy hoặc ô ngày Excel.");
                    }
                    decimal rate = 0;
                    if (Clean(Text("rate")) is string rateText &&
                        ((Value("rate") is string && !rateText.All(char.IsAsciiDigit)) ||
                        !decimal.TryParse(rateText, NumberStyles.Float, CultureInfo.InvariantCulture, out rate) || rate < 0 || rate > 999999999999m))
                        errors.Add("Đơn giá giờ phải là ô số không âm, tối đa 999999999999. Nếu nhập dạng chữ, chỉ dùng chữ số, không có dấu phân cách.");
                    if (code.Length == 0 || code.Length > 50) errors.Add("Mã NV bắt buộc, tối đa 50 ký tự.");
                    if (name.Length == 0 || name.Length > 200) errors.Add("Họ và tên bắt buộc, tối đa 200 ký tự.");
                    if (email.Length > 254 || !System.Net.Mail.MailAddress.TryCreate(email, out var address) || address.Address != email || !address.Host.Contains('.'))
                        errors.Add("Email đăng nhập không hợp lệ hoặc còn thiếu.");
                    if (dept?.Length > 200) errors.Add("Phòng ban tối đa 200 ký tự.");
                    if (title?.Length > 200) errors.Add("Chức vụ tối đa 200 ký tự.");
                    if (phone?.Length > 30) errors.Add("Số điện thoại tối đa 30 ký tự.");
                    rows.Add(new(reader.Name, reader.Depth + 1, code, name, email, dept, title, phone, hireDate, rate, errors, warnings)
                        { UidThe = uid, HasHourlyRate = Clean(Text("rate")) != null });
                }
                if (columns == null) ignoredSheets?.Add(reader.Name);
            } while (reader.NextResult());
            Require(rows.Count > 0, "Không tìm thấy danh sách. Cần hàng tiêu đề Mã NV, Họ và tên, Email và ít nhất một nhân viên. Tiêu đề nằm trong 30 dòng đầu của mỗi sheet.", 400);
            foreach (var duplicate in rows.Where(r => r.Code.Length > 0).GroupBy(r => r.Code, StringComparer.OrdinalIgnoreCase).Where(g => g.Count() > 1))
                foreach (var row in duplicate) row.Errors.Add("Mã NV bị lặp trong file.");
            foreach (var duplicate in rows.Where(r => r.Email.Length > 0).GroupBy(r => r.Email, StringComparer.OrdinalIgnoreCase).Where(g => g.Count() > 1))
                foreach (var row in duplicate) row.Errors.Add("Email bị lặp trong file.");
            foreach (var duplicate in rows.Where(r => r.UidThe != null).GroupBy(r => r.UidThe).Where(g => g.Count() > 1))
                foreach (var row in duplicate) row.Errors.Add("UID thẻ bị lặp trong file.");
            return rows;
        }
        catch (ApiError) { throw; }
        catch (Exception e) when (e is not OutOfMemoryException)
        {
            throw new ApiError("Không đọc được file Excel. Kiểm tra file .xls/.xlsx không bị hỏng, không đặt mật khẩu và không chứa giá trị lỗi.", 400);
        }
        finally { CultureInfo.CurrentCulture = previousCulture; }
    }

    // Minimal standards-based XLSX: text cells preserve phone zeroes and cannot execute formulas.
    public static byte[] Write(IEnumerable<IReadOnlyList<string>> data, string sheetName = "Nhan vien")
    {
        XNamespace ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        XNamespace rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
        var worksheet = new XDocument(new XElement(ns + "worksheet", new XElement(ns + "sheetData",
            data.Select((row, index) => new XElement(ns + "row", new XAttribute("r", index + 1), row.Select((value, col) =>
                new XElement(ns + "c", new XAttribute("r", $"{(char)('A' + col)}{index + 1}"), new XAttribute("t", "inlineStr"),
                    new XElement(ns + "is", new XElement(ns + "t", value)))))))));
        using var output = new MemoryStream();
        using (var zip = new ZipArchive(output, ZipArchiveMode.Create, true))
        {
            void Add(string path, string content) { using var writer = new StreamWriter(zip.CreateEntry(path).Open(), new UTF8Encoding(false)); writer.Write(content); }
            Add("[Content_Types].xml", """<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>""");
            Add("_rels/.rels", """<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>""");
            Add("xl/workbook.xml", new XDocument(new XElement(ns + "workbook", new XAttribute(XNamespace.Xmlns + "r", rel), new XElement(ns + "sheets",
                new XElement(ns + "sheet", new XAttribute("name", sheetName), new XAttribute("sheetId", 1), new XAttribute(rel + "id", "rId1"))))).ToString());
            Add("xl/_rels/workbook.xml.rels", """<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>""");
            Add("xl/worksheets/sheet1.xml", worksheet.ToString());
        }
        return output.ToArray();
    }
    public static readonly string[] Headers = ["STT", "Mã NV", "Họ và\ntên", "Chức\nvụ", "Số điện\nthoại", "Email", "Ngày vào\nlàm", "Phòng ban", "Đơn giá giờ", "uid_the"];
}
