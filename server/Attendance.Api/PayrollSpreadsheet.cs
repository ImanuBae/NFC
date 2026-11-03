using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Xml.Linq;

namespace Attendance.Api;

public static class PayrollSpreadsheet
{
    public static byte[] Write(PayrollRun run, IEnumerable<PayrollItem> entries)
    {
        var items = entries.OrderBy(i => i.EmployeeCode).ToList();
        XNamespace ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        var data = new XElement(ns + "sheetData");
        XElement Text(int row, int col, string text, int style = 0) => new(ns + "c",
            new XAttribute("r", $"{(char)('A' + col)}{row}"), new XAttribute("t", "inlineStr"), new XAttribute("s", style),
            new XElement(ns + "is", new XElement(ns + "t", text)));
        XElement Number(int row, int col, decimal value, int style = 2) => new(ns + "c",
            new XAttribute("r", $"{(char)('A' + col)}{row}"), new XAttribute("s", style),
            new XElement(ns + "v", value.ToString(CultureInfo.InvariantCulture)));
        void Row(int row, params XElement[] cells) => data.Add(new XElement(ns + "row", new XAttribute("r", row), cells));
        Row(1, Text(1, 0, "BẢNG LƯƠNG ĐÃ CHỐT", 4));
        Row(2, Text(2, 0, $"Kỳ: {run.StartDate:dd/MM/yyyy} – {run.EndDate.AddDays(-1):dd/MM/yyyy}"));
        Row(3, Text(3, 0, $"Chốt lúc: {run.CreatedAt.ToOffset(Business.Zone):dd/MM/yyyy HH:mm:ss} (giờ Việt Nam)"));
        string[] headers = ["Mã NV", "Họ và tên", "Phút công", "Giờ công", "Đơn giá VND/giờ", "Lương gộp VND"];
        Row(5, headers.Select((h, col) => Text(5, col, h, 1)).ToArray());
        var index = 6;
        foreach (var item in items)
        {
            Row(index, Text(index, 0, item.EmployeeCode), Text(index, 1, item.EmployeeName),
                Number(index, 2, item.WorkedMinutes, 3), Number(index, 3, item.WorkedMinutes / 60, 3),
                Number(index, 4, item.HourlyRate), Number(index, 5, item.GrossPay));
            index++;
        }
        Row(index, Text(index, 0, "TỔNG"), Number(index, 2, items.Sum(i => i.WorkedMinutes), 3),
            Number(index, 3, items.Sum(i => i.WorkedMinutes) / 60, 3), Number(index, 5, items.Sum(i => i.GrossPay)));
        Row(index + 2, Text(index + 2, 0, "Số liệu được lấy từ bảng lương đã chốt; chưa trừ thuế, bảo hiểm."));
        Row(index + 3, Text(index + 3, 0, $"Mã kỳ: {run.Id}"));
        var worksheet = new XDocument(new XElement(ns + "worksheet",
            new XElement(ns + "sheetViews", new XElement(ns + "sheetView", new XAttribute("workbookViewId", 0),
                new XElement(ns + "pane", new XAttribute("ySplit", 5), new XAttribute("topLeftCell", "A6"), new XAttribute("activePane", "bottomLeft"), new XAttribute("state", "frozen")))),
            new XElement(ns + "cols", Enumerable.Range(1, 6).Select(c => new XElement(ns + "col",
                new XAttribute("min", c), new XAttribute("max", c), new XAttribute("width", c == 2 ? 34 : 22), new XAttribute("customWidth", 1)))),
            data, new XElement(ns + "mergeCells", Enumerable.Range(1, 3).Select(r => new XElement(ns + "mergeCell", new XAttribute("ref", $"A{r}:F{r}")))),
            new XElement(ns + "pageSetup", new XAttribute("orientation", "landscape"), new XAttribute("paperSize", 9))));
        using var output = new MemoryStream();
        using (var zip = new ZipArchive(output, ZipArchiveMode.Create, true))
        {
            void Add(string path, string content) { using var writer = new StreamWriter(zip.CreateEntry(path).Open(), new UTF8Encoding(false)); writer.Write(content); }
            Add("[Content_Types].xml", """<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>""");
            Add("_rels/.rels", """<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>""");
            Add("xl/workbook.xml", """<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Luong da chot" sheetId="1" r:id="rId1"/></sheets></workbook>""");
            Add("xl/_rels/workbook.xml.rels", """<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>""");
            Add("xl/styles.xml", """<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="3"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font><font><b/><sz val="16"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF263C59"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="5"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/><xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>""");
            Add("xl/worksheets/sheet1.xml", worksheet.ToString());
        }
        return output.ToArray();
    }
}
