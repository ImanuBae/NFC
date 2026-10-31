import 'package:demo_nfc/features/business/report_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('week starts Monday and crosses year boundary', () {
    final range = ReportRange.forDate(DateTime(2026, 1, 1), ReportPeriod.week);
    expect(range.startDate, '2025-12-29');
    expect(range.endDate, '2026-01-05');
  });
  test('month includes leap day and uses exclusive end', () {
    final range = ReportRange.forDate(
      DateTime(2024, 2, 29),
      ReportPeriod.month,
    );
    expect(range.startDate, '2024-02-01');
    expect(range.endDate, '2024-03-01');
    expect(range.label, '2024-02-01 — 2024-02-29');
  });
  test('Q4 ends in the next year', () {
    final range = ReportRange.forDate(
      DateTime(2026, 12, 31),
      ReportPeriod.quarter,
    );
    expect(range.startDate, '2026-10-01');
    expect(range.endDate, '2027-01-01');
  });
  test('year is a calendar year', () {
    final range = ReportRange.forDate(DateTime(2026, 5), ReportPeriod.year);
    expect(range.startDate, '2026-01-01');
    expect(range.endDate, '2027-01-01');
  });
}
