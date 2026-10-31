class DayReportItem {
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final DateTime workDate;
  final DateTime? firstIn;
  final DateTime? lastOut;
  final int workedMinutes;
  final int completedMinutes;
  final bool missingCheckout;
  final bool isLate;
  final bool isEarlyLeave;
  final bool isInShift;
  final bool needsReview;
  final int requiredMinutes;
  final int remainingMinutes;
  final int lateMinutes;
  final DateTime? expectedCompletion;
  final String? lastEventId;
  final String? lastEventType;
  final String? lastEventSource;
  final DateTime? lastEventAt;
  final List<AttendanceInterval> sessions;

  DayReportItem({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.workDate,
    this.firstIn,
    this.lastOut,
    required this.workedMinutes,
    this.completedMinutes = 0,
    required this.missingCheckout,
    required this.isLate,
    this.isEarlyLeave = false,
    this.isInShift = false,
    this.needsReview = false,
    this.requiredMinutes = 480,
    this.remainingMinutes = 0,
    this.lateMinutes = 0,
    this.expectedCompletion,
    this.lastEventId,
    this.lastEventType,
    this.lastEventSource,
    this.lastEventAt,
    this.sessions = const [],
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
      completedMinutes:
          (json['completed_minutes'] as num?)?.toInt() ??
          (json['worked_minutes'] as num?)?.toInt() ??
          0,
      missingCheckout: json['missing_checkout'] as bool? ?? false,
      isLate: json['is_late'] as bool? ?? false,
      isEarlyLeave: json['is_early_leave'] as bool? ?? false,
      isInShift: json['is_in_shift'] as bool? ?? false,
      needsReview: json['needs_review'] as bool? ?? false,
      requiredMinutes: (json['required_minutes'] as num?)?.toInt() ?? 480,
      remainingMinutes: (json['remaining_minutes'] as num?)?.toInt() ?? 0,
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      expectedCompletion: DateTime.tryParse('${json['expected_completion']}')
          ?.toLocal(),
      lastEventId: json['last_event_id'] as String?,
      lastEventType: json['last_event_type'] as String?,
      lastEventSource: json['last_event_source'] as String?,
      lastEventAt: DateTime.tryParse('${json['last_event_at']}')?.toLocal(),
      sessions: (json['sessions'] as List? ?? [])
          .map(
            (s) => AttendanceInterval(
              DateTime.parse(s['start'] as String).toLocal(),
              DateTime.tryParse('${s['end']}')?.toLocal(),
            ),
          )
          .toList(),
    );
  }
}

class AttendanceInterval {
  const AttendanceInterval(this.start, this.end);
  final DateTime start;
  final DateTime? end;
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
