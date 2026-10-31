namespace Attendance.Api;

// All attendance calculations use the company's UTC+7 day, independent of the host.
public sealed class AttendancePolicy
{
    public int StartMinute { get; set; } = 9 * 60;
    public int EndMinute { get; set; } = 18 * 60;
    public int BreakStartMinute { get; set; } = 12 * 60;
    public int BreakEndMinute { get; set; } = 13 * 60;
    public int RequiredMinutes => EndMinute - StartMinute - (BreakEndMinute - BreakStartMinute);

    public void Validate()
    {
        if (!(0 <= StartMinute && StartMinute <= BreakStartMinute && BreakStartMinute <= BreakEndMinute
            && BreakEndMinute <= EndMinute && EndMinute < 1440 && RequiredMinutes > 0))
            throw new InvalidOperationException("AttendancePolicy: invalid shift or break.");
    }

    public double Minutes(DateTimeOffset start, DateTimeOffset end)
    {
        double total = 0;
        for (var day = DateOnly.FromDateTime(start.ToOffset(Business.Zone).DateTime);
             Business.Bound(day) < end; day = day.AddDays(1))
        {
            var bound = Business.Bound(day);
            var from = start > bound ? start : bound;
            var to = end < bound.AddDays(1) ? end : bound.AddDays(1);
            if (to <= from) continue;
            var restFrom = from > bound.AddMinutes(BreakStartMinute) ? from : bound.AddMinutes(BreakStartMinute);
            var restTo = to < bound.AddMinutes(BreakEndMinute) ? to : bound.AddMinutes(BreakEndMinute);
            total += (to - from).TotalMinutes - Math.Max(0, (restTo - restFrom).TotalMinutes);
        }
        return total;
    }

    public DateTimeOffset? Completion(DateTimeOffset from, int remaining, DateOnly date)
    {
        var bound = Business.Bound(date);
        var at = from;
        var breakStart = bound.AddMinutes(BreakStartMinute);
        var breakEnd = bound.AddMinutes(BreakEndMinute);
        if (at >= breakStart && at < breakEnd) at = breakEnd;
        var result = at.AddMinutes(remaining);
        if (at < breakStart && result > breakStart) result = result.AddMinutes(BreakEndMinute - BreakStartMinute);
        return result < bound.AddDays(1) ? result : null;
    }
}

public static class AttendanceSummary
{
    public static object Day(Guid employeeId, DateOnly date, List<AttendanceEvent> events,
        Employee employee, AttendancePolicy policy, DateTimeOffset now)
    {
        var bound = Business.Bound(date);
        var rows = events.Where(e => e.EmployeeId == employeeId && e.VoidedAt == null
            && e.OccurredAt >= bound && e.OccurredAt < bound.AddDays(1) && e.OccurredAt <= now)
            .OrderBy(e => e.OccurredAt).ThenBy(e => e.Id).ToList();
        var allSessions = Business.Sessions(events.Where(e => e.EmployeeId == employeeId && e.OccurredAt <= now));
        var sessions = allSessions.Where(s => s.Start >= bound && s.Start < bound.AddDays(1)).ToList();
        var latest = rows.LastOrDefault();
        var active = date == DateOnly.FromDateTime(now.ToOffset(Business.Zone).DateTime)
            && latest?.Type == "check_in" && now - latest.OccurredAt <= TimeSpan.FromHours(16);
        var first = rows.FirstOrDefault(e => e.Type == "check_in");
        var lastOut = sessions.Where(s => s.End != null).Select(s => s.End).Max();
        var completed = (int)sessions.Where(s => s.End != null).Sum(s => policy.Minutes(s.Start, s.End!.Value));
        var worked = completed + (active ? (int)policy.Minutes(latest!.OccurredAt, now) : 0);
        var remaining = Math.Max(0, policy.RequiredMinutes - worked);
        var late = first == null ? 0 : Math.Max(0, (int)(first.OccurredAt - bound.AddMinutes(policy.StartMinute)).TotalMinutes);
        var missing = sessions.Any(s => s.End == null && (!active || s.Start != latest!.OccurredAt));
        var anomaly = missing || rows.Count(e => e.Type == "check_out") !=
            allSessions.Count(s => s.End >= bound && s.End < bound.AddDays(1));
        return new
        {
            employee_id = employeeId, work_date = date, first_in = first?.OccurredAt,
            last_out = lastOut, worked_minutes = worked, completed_minutes = completed,
            required_minutes = policy.RequiredMinutes, remaining_minutes = remaining,
            is_in_shift = active, missing_checkout = missing, needs_review = anomaly,
            is_late = late > 0, late_minutes = late,
            is_early_leave = !active && lastOut != null && lastOut < bound.AddMinutes(policy.EndMinute),
            expected_completion = active && !anomaly ? policy.Completion(now, remaining, date) : null,
            last_event_id = latest?.Id, last_event_type = latest?.Type,
            last_event_at = latest?.OccurredAt, last_event_source = latest?.Source,
            sessions = sessions.Select(s => new { start = s.Start, end = s.End }),
            employees = new { code = employee.Code, full_name = employee.FullName }
        };
    }
}
