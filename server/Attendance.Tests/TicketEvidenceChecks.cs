using Attendance.Api;

public static class TicketEvidenceChecks
{
    public static int Run()
    {
        var checks = 0;
        void Check(bool condition) { if (!condition) throw new Exception("Evidence validation failed"); checks++; }
        void Reject(List<EvidenceUpload> files) {
            try { AttendanceTickets.ReadEvidence(files); }
            catch (ApiError e) when (e.Status == 400) { checks++; return; }
            throw new Exception("Invalid evidence was accepted");
        }
        var png = new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 };
        var encoded = Convert.ToBase64String(png);
        Check(AttendanceTickets.ReadEvidence(null).Count == 0);
        Check(AttendanceTickets.ReadEvidence([new("photo.PNG", encoded)])[0].ContentType == "image/png");
        Check(AttendanceTickets.ReadEvidence([new("photo.jpeg", Convert.ToBase64String([255,216,255]))])[0].ContentType == "image/jpeg");
        Check(AttendanceTickets.ReadEvidence([new("note.pdf", Convert.ToBase64String("%PDF-1.4"u8.ToArray()))])[0].ContentType == "application/pdf");
        Reject([new("empty.png", "")]);
        Reject([new("invalid.png", "not-base64")]);
        Reject([new("fake.pdf", encoded)]);
        Reject([new("bad.exe", encoded)]);
        Reject([new("../photo.png", encoded)]);
        Reject([new("photo.png", encoded), new("photo.png", encoded), new("photo.png", encoded), new("photo.png", encoded)]);
        Reject([new("big.png", Convert.ToBase64String(new byte[2 * 1024 * 1024 + 1]))]);
        var large = new byte[2 * 1024 * 1024]; png.CopyTo(large, 0);
        var largeEncoded = Convert.ToBase64String(large);
        Reject([new("1.png", largeEncoded), new("2.png", largeEncoded), new("3.png", largeEncoded)]);
        return checks;
    }
}
