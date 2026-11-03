import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'ticket_evidence.dart';

final attendanceTicketRepositoryProvider = Provider(
  (ref) => AttendanceTicketRepository(ref.watch(apiClientProvider)),
);
final attendanceTicketsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(attendanceTicketRepositoryProvider).list(),
);

const ticketKinds = {
  'missing_in': 'Thiếu giờ vào',
  'missing_out': 'Thiếu giờ ra',
  'incorrect_time': 'Giờ ghi nhận không đúng',
};
const ticketStatuses = {
  'pending': 'Chờ xử lý',
  'approved': 'Đã duyệt',
  'rejected': 'Từ chối',
  'cancelled': 'Đã hủy',
};

class AttendanceTicketRepository {
  AttendanceTicketRepository(this.client);
  final ApiClient client;
  Future<List<Map<String, dynamic>>> list() =>
      client.list('/attendance/tickets');
  Future<void> create({
    required String kind,
    required DateTime proposedAt,
    required String reason,
    String? originalEventId,
    List<TicketEvidence> attachments = const [],
  }) async {
    validateTicketEvidence(attachments);
    await client.request(
      'POST',
      '/attendance/tickets',
      body: {
        'kind': kind,
        'proposed_at': proposedAt.toUtc().toIso8601String(),
        'reason': reason.trim(),
        'original_event_id': originalEventId,
        'attachments': attachments.map((file) => file.toJson()).toList(),
      },
    );
  }

  Future<Map<String, dynamic>> evidence(String ticketId, String fileId) async =>
      Map<String, dynamic>.from(
        await client.request(
          'GET',
          '/attendance/tickets/$ticketId/attachments/$fileId',
        ) as Map,
      );

  Future<void> cancel(String id) async {
    await client.request('POST', '/attendance/tickets/$id/cancel');
  }

  Future<void> review(String id, String decision, String response) async {
    await client.request(
      'POST',
      '/attendance/tickets/$id/review',
      body: {'decision': decision, 'response': response.trim()},
    );
  }
}
