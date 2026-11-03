using Attendance.Api;
using System.Globalization;
using System.IO.Compression;
using System.Xml.Linq;

public static class PayrollSpreadsheetChecks
{
    public static int Run()
    {
        var checks = 0;
        void Check(bool condition, string message) { if (!condition) throw new Exception(message); checks++; }
        var run = new PayrollRun { StartDate = new(2026,10,1), EndDate = new(2026,11,1) };
        var items = new[] {
            new PayrollItem { EmployeeCode="NV04", EmployeeName="=HYPERLINK(\"bad\")", WorkedMinutes=10485, HourlyRate=45000, GrossPay=7863750 },
            new PayrollItem { EmployeeCode="NV01", EmployeeName="Nguyễn Văn A", WorkedMinutes=10560, HourlyRate=60000, GrossPay=10560000 }
        };
        using var zip = new ZipArchive(new MemoryStream(PayrollSpreadsheet.Write(run, items)));
        using var stream = zip.GetEntry("xl/worksheets/sheet1.xml")!.Open();
        var sheet = XDocument.Load(stream);
        XNamespace ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        XElement Cell(string address) => sheet.Descendants(ns+"c").Single(c => (string?)c.Attribute("r")==address);
        decimal Number(string address) => decimal.Parse(Cell(address).Element(ns+"v")!.Value,CultureInfo.InvariantCulture);
        Check(Cell("A6").Value=="NV01", "Export sorts saved employee codes");
        Check(Cell("B6").Value=="Nguyễn Văn A", "Vietnamese names retained");
        Check(Cell("B7").Attribute("t")?.Value=="inlineStr" && !sheet.Descendants(ns+"f").Any(), "Names cannot become Excel formulas");
        Check(Number("D7")==174.75m && Cell("D7").Attribute("t")==null, "Hours are numeric, preserving fractional hours");
        Check(Number("E6")==60000 && Number("F6")==10560000, "Saved rate and pay remain numeric");
        Check(Number("F8")==18423750 && Number("C8")==21045, "Saved totals reconcile");
        Check(Cell("A2").Value.Contains("31/10/2026"), "Display uses inclusive final date");
        Check(zip.GetEntry("xl/styles.xml")!=null, "Workbook includes formatting styles");
        return checks;
    }
}
