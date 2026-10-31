enum ReportPeriod { week, month, quarter, year }

class ReportRange {
  const ReportRange(this.start, this.end);
  final DateTime start;

  /// Exclusive end date in the business calendar (Asia/Ho_Chi_Minh).
  final DateTime end;

  factory ReportRange.forDate(DateTime date, ReportPeriod period) {
    final day = DateTime(date.year, date.month, date.day);
    return switch (period) {
      ReportPeriod.week => ReportRange(
        DateTime(day.year, day.month, day.day - day.weekday + 1),
        DateTime(day.year, day.month, day.day - day.weekday + 8),
      ),
      ReportPeriod.month => ReportRange(
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1),
      ),
      ReportPeriod.quarter => ReportRange(
        DateTime(day.year, ((day.month - 1) ~/ 3) * 3 + 1),
        DateTime(day.year, ((day.month - 1) ~/ 3) * 3 + 4),
      ),
      ReportPeriod.year => ReportRange(
        DateTime(day.year),
        DateTime(day.year + 1),
      ),
    };
  }

  static String dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String get startDate => dateString(start);
  String get endDate => dateString(end);
  String get label =>
      '$startDate — ${dateString(DateTime(end.year, end.month, end.day - 1))}';
}
