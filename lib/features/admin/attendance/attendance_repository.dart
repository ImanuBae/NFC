import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
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

class SupabaseAttendanceRepository implements AttendanceRepository {
  final SupabaseClient _client;

  SupabaseAttendanceRepository(this._client);

  @override
  Future<List<DayReportItem>> getDayReport(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Fetch employees for map lookup
    final empRes = await _client
        .from('employees')
        .select('id, code, full_name');
    final Map<String, (String, String)> empMap = {};
    for (final e in (empRes as List)) {
      final m = e as Map<String, dynamic>;
      empMap[m['id'] as String] = (
        m['code'] as String,
        m['full_name'] as String,
      );
    }

    final res = await _client
        .from('attendance_days')
        .select()
        .eq('work_date', dateStr);

    final list = res as List;
    return list.map((item) {
      final json = item as Map<String, dynamic>;
      final empId = json['employee_id'] as String;
      final info = empMap[empId] ?? ('', '');
      return DayReportItem.fromJson(json, code: info.$1, name: info.$2);
    }).toList();
  }

  @override
  Future<List<AttendanceEventItem>> getEvents({
    String? employeeId,
    DateTime? date,
  }) async {
    var query = _client
        .from('attendance_events')
        .select('*, employees(code, full_name)');

    if (employeeId != null && employeeId.isNotEmpty) {
      query = query.eq('employee_id', employeeId);
    }

    if (date != null) {
      final start = DateTime(
        date.year,
        date.month,
        date.day,
      ).toUtc().toIso8601String();
      final end = DateTime(
        date.year,
        date.month,
        date.day,
        23,
        59,
        59,
        999,
      ).toUtc().toIso8601String();
      query = query.gte('occurred_at', start).lte('occurred_at', end);
    }

    final res = await query.order('occurred_at', ascending: false);
    final list = res as List;
    return list
        .map((e) => AttendanceEventItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> voidEvent({
    required String eventId,
    required String reason,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    await _client
        .from('attendance_events')
        .update({
          'voided_at': DateTime.now().toUtc().toIso8601String(),
          'voided_by': currentUserId,
          'void_reason': reason.trim(),
        })
        .eq('id', eventId);
  }

  @override
  Future<void> addManualEvent({
    required String employeeId,
    required String type,
    required DateTime occurredAt,
    required String reason,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    await _client.from('attendance_events').insert({
      'employee_id': employeeId,
      'type': type,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'source': 'manual',
      'created_by': currentUserId,
      'client_scan_id': null,
      'flag': reason.trim().isNotEmpty ? reason.trim() : null,
    });
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAttendanceRepository(client);
});
