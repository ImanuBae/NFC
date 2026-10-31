import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import 'attendance_models.dart';

abstract class AttendanceRepository {
  Future<List<DayReportItem>> getDayReport(DateTime date);
  Future<List<AttendanceEventItem>> getEvents({
    String? employeeId,
    DateTime? date,
  });
  Future<void> voidEvent({required String eventId, required String reason});
  Future<void> addManualEvent({
    required String employeeId,
    required String type,
    required DateTime occurredAt,
    required String reason,
  });
}

class ApiAttendanceRepository implements AttendanceRepository {
  ApiAttendanceRepository(this.client);
  final ApiClient client;
  @override
  Future<List<DayReportItem>> getDayReport(DateTime date) async =>
      (await client.list(
        '/attendance/days',
        query: {'date': DateFormat('yyyy-MM-dd').format(date)},
      )).map((r) => DayReportItem.fromJson(r)).toList();
  @override
  Future<List<AttendanceEventItem>> getEvents({
    String? employeeId,
    DateTime? date,
  }) async => (await client.list(
    '/attendance/events',
    query: {
      'employeeId': employeeId,
      'date': date == null ? null : DateFormat('yyyy-MM-dd').format(date),
    },
  )).map(AttendanceEventItem.fromJson).toList();
  @override
  Future<void> voidEvent({
    required String eventId,
    required String reason,
  }) async {
    await client.request(
      'POST',
      '/attendance/$eventId/void',
      body: {'reason': reason},
    );
  }

  @override
  Future<void> addManualEvent({
    required String employeeId,
    required String type,
    required DateTime occurredAt,
    required String reason,
  }) async {
    await client.request(
      'POST',
      '/attendance/manual',
      body: {
        'employee_id': employeeId,
        'type': type,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'reason': reason,
      },
    );
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => ApiAttendanceRepository(ref.watch(apiClientProvider)),
);
