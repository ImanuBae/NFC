class DayReportItem {
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final DateTime workDate;
  final DateTime? firstIn;
  final DateTime? lastOut;
  final int workedMinutes;
  final bool missingCheckout;
  final bool isLate;

  DayReportItem({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.workDate,
    this.firstIn,
    this.lastOut,
    required this.workedMinutes,
    required this.missingCheckout,
    required this.isLate,
  });

  String get workedDurationFormatted {
    final hours = workedMinutes ~/ 60;
    final mins = workedMinutes % 60;
    return '${hours}h ${mins}m';
  }

  factory DayReportItem.fromJson(
    Map<String, dynamic> json, {
    String code = '',
    String name = '',
  }) {
    String empCode = code;
    String empName = name;

    if (json['employees'] is Map) {
      final empMap = json['employees'] as Map<String, dynamic>;
      empCode = empMap['code'] as String? ?? empCode;
      empName = empMap['full_name'] as String? ?? empName;
    }

    return DayReportItem(
      employeeId: json['employee_id'] as String,
      employeeCode: empCode,
      employeeName: empName,
      workDate: DateTime.parse(json['work_date'] as String),
      firstIn: json['first_in'] != null
          ? DateTime.parse(json['first_in'] as String).toLocal()
          : null,
      lastOut: json['last_out'] != null
          ? DateTime.parse(json['last_out'] as String).toLocal()
          : null,
      workedMinutes: (json['worked_minutes'] as num?)?.toInt() ?? 0,
      missingCheckout: json['missing_checkout'] as bool? ?? false,
      isLate: json['is_late'] as bool? ?? false,
    );
  }
}

class AttendanceEventItem {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String type;
  final DateTime occurredAt;
  final String source;
  final String? flag;
  final DateTime? voidedAt;
  final String? voidReason;

  bool get isVoided => voidedAt != null;

  AttendanceEventItem({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    required this.type,
    required this.occurredAt,
    required this.source,
    this.flag,
    this.voidedAt,
    this.voidReason,
  });

  factory AttendanceEventItem.fromJson(Map<String, dynamic> json) {
    String? name;
    String? code;

    if (json['employees'] is Map) {
      final emp = json['employees'] as Map<String, dynamic>;
      name = emp['full_name'] as String?;
      code = emp['code'] as String?;
    }

    return AttendanceEventItem(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName: name,
      employeeCode: code,
      type: json['type'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
      source: json['source'] as String? ?? 'nfc',
      flag: json['flag'] as String?,
      voidedAt: json['voided_at'] != null
          ? DateTime.parse(json['voided_at'] as String).toLocal()
          : null,
      voidReason: json['void_reason'] as String?,
    );
  }
}
