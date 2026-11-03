using Attendance.Api;
using System.Text.Json;

var policy = new AttendancePolicy();
policy.Validate();
var employee = new Employee { Code = "NV01", FullName = "An" };
var date = new DateOnly(2026, 10, 29);
DateTimeOffset At(int hour, int minute = 0) => Business.Bound(date).AddHours(hour).AddMinutes(minute);
AttendanceEvent Entry(string type, int hour, int minute = 0) => new()
    { EmployeeId = employee.Id, Type = type, OccurredAt = At(hour, minute) };
AttendanceEvent In(int h, int m = 0) => Entry("check_in", h, m);
AttendanceEvent Out(int h, int m = 0) => Entry("check_out", h, m);
JsonElement Summary(DateTimeOffset now, params AttendanceEvent[] events) => JsonSerializer.SerializeToElement(
    AttendanceSummary.Day(employee.Id, date, events.ToList(), employee, policy, now));
var checks = 0;
void Check(bool condition, string message)
{
    if (!condition) throw new Exception(message);
    checks++;
}
int Number(JsonElement row, string field) => row.GetProperty(field).GetInt32();
bool Flag(JsonElement row, string field) => row.GetProperty(field).GetBoolean();

Check(policy.Minutes(At(9), At(18)) == 480, "Standard shift subtracts lunch once");
Check(policy.Minutes(At(12, 15), At(12, 45)) == 0, "Lunch attendance earns no minutes");
Check(policy.Minutes(At(9), At(12, 30)) == 180, "Partial lunch overlap");
Check(policy.Minutes(At(12, 30), At(18)) == 300, "Arrival during lunch");
Check(policy.Minutes(At(8), At(9)) == 60, "Existing early attendance remains credited");
Check(policy.Minutes(At(23), At(27)) == 240, "Overnight attendance remains valid");
Check(policy.Completion(At(11), 60, date) == At(12), "Completion at break boundary");
Check(policy.Completion(At(12, 30), 60, date) == At(14), "Completion skips remaining break");
Check(policy.Completion(At(23), 120, date) == null, "No completion prediction beyond work day");

var late = Summary(At(9, 30), In(9, 30));
Check(Number(late, "late_minutes") == 30, "Late by 30 minutes");
Check(late.GetProperty("expected_completion").GetDateTimeOffset() == At(18, 30), "Late arrival projects 18:30");
Check(Flag(late, "is_in_shift") && !Flag(late, "missing_checkout"), "Open current attendance is active, not missing");
var interrupted = Summary(At(16), In(9, 30), Out(11), In(11, 30));
Check(Number(interrupted, "worked_minutes") == 300 && Number(interrupted, "remaining_minutes") == 180,
    "Live work excludes break and 30-minute interruption");
Check(interrupted.GetProperty("expected_completion").GetDateTimeOffset() == At(19), "Interruption moves completion to 19:00");
Check(interrupted.GetProperty("sessions").GetArrayLength() == 2, "Preserves individual intervals");
var complete = Summary(At(20), In(9), Out(12), In(13), Out(18));
Check(Number(complete, "worked_minutes") == 480 && Number(complete, "remaining_minutes") == 0, "Two intervals complete daily target");
Check(!Flag(complete, "is_in_shift") && !Flag(complete, "needs_review"), "Closed intervals are valid");
var outside = Summary(At(15), In(9), Out(11));
Check(Number(outside, "worked_minutes") == 120 && outside.GetProperty("expected_completion").ValueKind == JsonValueKind.Null,
    "No live accumulation or projection after checkout");
var duplicate = Summary(At(15), In(9), In(10));
Check(Flag(duplicate, "needs_review") && Flag(duplicate, "missing_checkout"), "Repeated entry keeps missing previous checkout");
Check(duplicate.GetProperty("expected_completion").ValueKind == JsonValueKind.Null, "Ambiguous attendance has no confident prediction");
var orphan = Summary(At(18), Out(17));
Check(Flag(orphan, "needs_review") && Number(orphan, "worked_minutes") == 0, "Orphan checkout earns no work and requests review");
var missing = Summary(At(34), In(9));
Check(!Flag(missing, "is_in_shift") && Flag(missing, "missing_checkout") && Number(missing, "worked_minutes") == 0,
    "Forgotten yesterday entry does not accrue endless hours");
var voided = In(9); voided.VoidedAt = At(10);
Check(Number(Summary(At(18), voided, Out(17)), "worked_minutes") == 0, "Voided events are excluded");
var mixedIn = In(9); mixedIn.Source = "nfc";
var mixedOut = Out(18); mixedOut.Source = "face_camera";
Check(Number(Summary(At(18), mixedIn, mixedOut), "worked_minutes") == 480, "NFC and face use one calculation");
Check(Summary(At(8)).GetProperty("last_event_id").ValueKind == JsonValueKind.Null, "Absent employee has no scan notification");
var overnight = Business.Sessions([In(23), Out(26)]);
Check(overnight.Single().End == At(26), "Pair overnight intervals within 16 hours");
Check(Business.Sessions([In(5), Out(23)]).Single().End == null, "Do not pair an implausible 18-hour interval");
Console.WriteLine($"Passed {checks} attendance business checks.");
Console.WriteLine($"Passed {EmployeeSpreadsheetChecks.Run()} Excel import checks.");
Console.WriteLine($"Passed {EmailSettingsChecks.Run()} email settings checks.");
Console.WriteLine($"Passed {TicketEvidenceChecks.Run()} ticket evidence checks.");
Console.WriteLine($"Passed {PayrollSpreadsheetChecks.Run()} payroll spreadsheet checks.");
