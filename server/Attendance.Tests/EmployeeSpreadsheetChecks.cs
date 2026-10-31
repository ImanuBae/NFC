using Attendance.Api;

public static class EmployeeSpreadsheetChecks
{
    public static int Run()
    {
        var checks = 0;
        void Check(bool condition, string message) { if (!condition) throw new Exception(message); checks++; }
        void Reject(Action action, string message)
        {
            try { action(); } catch (ApiError e) { Check(e.Status == 400, message); return; }
            throw new Exception(message);
        }
        foreach (var extension in new[] { "xls", "xlsx" })
        {
            var file = File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Fixtures", "employees-valid." + extension));
            var rows = EmployeeSpreadsheet.Read(file, "Phòng dự phòng");
            Check(rows.Count == 4, $"Read genuine {extension} workbook with title before wrapped headers");
            Check(rows.All(r => r.Errors.Count == 0), $"Valid {extension} workbook has no errors: " + string.Join("; ", rows.Select(r => $"{r.RowNumber}: {string.Join(", ", r.Errors)}")));
            Check(rows[0].FullName == "Nguyễn Văn A" && rows[0].RowNumber == 4, $"Preserve Vietnamese and real row numbers in {extension}");
            Check(rows[0].Phone == "0901234567" && rows[1].Phone == "0902345678", $"Preserve text and zero-formatted numeric phones in {extension}");
            Check(rows[0].HireDate == "2023-01-15" && rows[3].HireDate == "2026-01-12", $"Parse native dates and dd/MM/yyyy in {extension}");
            Check(rows[0].Department == "Kinh doanh" && rows[1].Department == "Phòng dự phòng", $"Department fallback applies only to empty cells in {extension}");
            Check(rows[0].HourlyRate == 60000 && rows[0].JobTitle == "Trưởng phòng", $"Capture position and hourly rate in {extension}");
        }

        byte[] Workbook(params IReadOnlyList<string>[] data) => EmployeeSpreadsheet.Write(data);
        var ignoredSheets = new List<string>();
        var company = EmployeeSpreadsheet.Read(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Fixtures", "employees-multisheet.xlsx")), null, ignoredSheets);
        Check(company.Count == 2 && company.Select(r => r.Department).Distinct().Count() == 2, "Import whole-company workbook across department sheets");
        Check(ignoredSheets.SequenceEqual(new[] { "Huong dan" }), "Report sheets excluded for missing required headers");
        var header = new[] { "Mã NV", "Họ và tên", "Email", "Ngày vào làm", "Số điện thoại" };
        var valid = new[] { "nv01", "An", "AN@company.example", "15/01/2023", "0901234567" };
        var normalized = EmployeeSpreadsheet.Read(Workbook(header, valid), null).Single();
        var nfcHeader = new[] { "Mã NV", "Họ và tên", "Email", "uid_the" };
        var nfc = EmployeeSpreadsheet.Read(Workbook(nfcHeader, ["N1", "An", "n1@company.example", "00:04-aa 01"]), null).Single();
        Check(nfc.UidThe == "0004AA01" && nfc.Errors.Count == 0, "Normalize hex UID while preserving leading zeroes");
        var duplicateNfc = EmployeeSpreadsheet.Read(Workbook(nfcHeader,
            ["N1", "An", "n1@company.example", "04-AA-01"], ["N2", "Binh", "n2@company.example", "04aa01"]), null);
        Check(duplicateNfc.All(r => r.Errors.Count == 1), "Reject normalized duplicate UIDs across employees");
        foreach (var invalid in new[] { "123", "GG00", "--", new string('A', 66) })
            Check(EmployeeSpreadsheet.Read(Workbook(nfcHeader, ["N1", "An", "n1@company.example", invalid]), null).Single().Errors.Count == 1,
                "Reject invalid or incomplete hexadecimal UID: " + invalid);
        Check(normalized.UidThe == null, "Legacy files without NFC column remain compatible");
        var numericUid = EmployeeSpreadsheet.Read(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Fixtures", "employees-nfc-numeric.xlsx")), null).Single();
        Check(numericUid.Errors.Count > 0, "Reject numeric UID cells rather than bind a rounded or truncated UID");
        var legacyUid = EmployeeSpreadsheet.Read(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Fixtures", "employees-nfc.xls")), null).Single();
        Check(legacyUid.UidThe == "0004AA01" && legacyUid.Errors.Count == 0, "Legacy XLS supports NFC UID text column");
        var companyLayout = EmployeeSpreadsheet.Read(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Fixtures", "employees-company-layout.xlsx")), "Wrong department");
        Check(companyLayout.Count == 4 && companyLayout.All(r => r.Errors.Count == 0 && r.Department == "IT"), "Use department cell instead of sheet name or fallback in supplied layout");
        Check(companyLayout[1].Phone == "0902345678" && companyLayout[3].HireDate == "2026-01-12", "Supplied layout preserves numeric formatted phone and date-styled text date");
        Check(companyLayout[0].UidThe == "0004CC01" && companyLayout[0].JobTitle == "Trưởng phòng" && companyLayout[0].HasHourlyRate, "Read UID and all optional columns from row-three wrapped header");
        var existing = new Employee { Code = "N1", FullName = "Old name", Email = "n1@company.example", Department = "Old department", HourlyRate = 60000, Phone = "0900000000" };
        var update = EmployeeSpreadsheet.Read(Workbook(["Mã NV", "Họ và tên", "Email", "Phòng ban"], ["N1", "New name", "n1@company.example", "IT"]), null).Single();
        Check(EmployeeImport.ProfileChanges(existing, update).SequenceEqual(new[] { "Họ và tên", "Phòng ban" }), "Preview identifies the actual fields to update");
        EmployeeImport.ApplyProfile(existing, update);
        Check(existing.Department == "IT" && existing.FullName == "New name" && existing.Phone == "0900000000" && existing.HourlyRate == 60000, "Update provided profile fields without erasing omitted values or salary");
        Check(normalized.Code == "NV01" && normalized.Email == "an@company.example", "Normalize employee code and email");
        var duplicate = EmployeeSpreadsheet.Read(Workbook(header, valid, valid), null);
        Check(duplicate.All(r => r.Errors.Count == 2), "Flag every occurrence of duplicate code and email before import");
        var bad = EmployeeSpreadsheet.Read(Workbook(header, ["", "", "bad email", "31/02/2024", ""]), null).Single();
        Check(bad.Errors.Count == 4, "Missing identity, malformed email and impossible date are reported on row");
        var formula = EmployeeSpreadsheet.Read(Workbook(header, ["N2", "=1+1", "two@company.example", "", ""]), null).Single();
        Check(formula.FullName == "=1+1", "XLSX export writes literal text, never formulas");
        var ambiguousRate = EmployeeSpreadsheet.Read(Workbook(["Mã NV", "Họ và tên", "Email", "Đơn giá giờ"], ["NV03", "An", "three@company.example", "60.000"]), null).Single();
        Check(ambiguousRate.Errors.Count == 1, "Reject ambiguous salary separators instead of silently mispricing pay");
        Reject(() => EmployeeSpreadsheet.Read(Workbook(EmployeeSpreadsheet.Headers), null), "Reject header-only file");
        Reject(() => EmployeeSpreadsheet.Read(Workbook(["Name", "Email"], ["An", "an@company.example"]), null), "Require employee code header");
        Reject(() => EmployeeSpreadsheet.Read([1, 2, 3], null), "Corrupt file returns useful validation error");
        Reject(() => EmployeeSpreadsheet.Decode(new("list.csv", "AQID", null, null)), "Reject unsupported file types");
        Reject(() => EmployeeSpreadsheet.Decode(new("list.xlsx", "not-base64", null, null)), "Reject malformed encoded content");
        Reject(() => EmployeeSpreadsheet.Decode(new("list.xlsx", "", null, null)), "Reject empty file");
        Reject(() => EmployeeSpreadsheet.Decode(new("list.xlsx", new string('A', 7_100_000), null, null)), "Enforce file size bound before decoding");
        var large = new List<IReadOnlyList<string>> { header };
        large.AddRange(Enumerable.Range(0, 1001).Select(i => (IReadOnlyList<string>)new[] { "NV" + i, "An", $"person{i}@company.example", "", "" }));
        Reject(() => EmployeeSpreadsheet.Read(EmployeeSpreadsheet.Write(large), null), "Reject more than 1000 employees without a partial import");
        return checks;
    }
}
