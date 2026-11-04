import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_repository.dart';
import '../kiosk/my_history_page.dart';
import '../admin/attendance/day_report_page.dart';
import 'attendance_ticket_form.dart';
import 'attendance_ticket_repository.dart';
import 'employee_today_page.dart';
import 'ticket_evidence_list.dart';

class AttendanceTicketsPage extends ConsumerWidget {
  const AttendanceTicketsPage({super.key, this.reviewMode = false});
  final bool reviewMode;

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> ticket,
  ) async {
    var response = '';
    final form = GlobalKey<FormState>();
    final decision = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xử lý ticket sửa công'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ticket['employee_name']} · ${ticketKinds[ticket['kind']]}',
                ),
                if (ticket['original_occurred_at'] != null)
                  Text('Giờ gốc: ${_time(ticket['original_occurred_at'])}'),
                Text('Giờ đề nghị: ${_time(ticket['proposed_at'])}'),
                Text('Lý do: ${ticket['reason']}'),
                TicketEvidenceList(ticket: ticket),
                const SizedBox(height: 12),
                TextFormField(
                  onChanged: (value) => response = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập lý do từ chối.'
                      : null,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Phản hồi (bắt buộc khi từ chối)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, 'rejected');
              }
            },
            child: const Text('Từ chối'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'approved'),
            child: const Text('Duyệt'),
          ),
        ],
      ),
    );
    if (decision == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(attendanceTicketRepositoryProvider)
          .review('${ticket['id']}', decision, response),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(attendanceTicketsProvider);
      ref.invalidate(myAttendanceEventsProvider);
      ref.invalidate(myTodayProvider);
      ref.invalidate(dayReportProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã cập nhật ticket.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  static String _time(dynamic value) =>
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse('$value').toLocal());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(attendanceTicketsProvider);
    final myId = ref.watch(currentUserEmployeeIdProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(reviewMode ? 'Duyệt ticket sửa công' : 'Ticket của tôi'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => ref.invalidate(attendanceTicketsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: reviewMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => AttendanceTicketForm.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Tạo ticket'),
            ),
      body: tickets.when(
        skipError: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không tải được ticket: $error'),
              TextButton(
                onPressed: () => ref.invalidate(attendanceTicketsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (all) {
          final rows = reviewMode
              ? [
                  ...all.where((t) => t['status'] == 'pending'),
                  ...all.where((t) => t['status'] != 'pending'),
                ]
              : all.where((t) => t['employee_id'] == myId).toList();
          if (rows.isEmpty) {
            return const Center(child: Text('Chưa có ticket sửa công.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(attendanceTicketsProvider);
              await ref.read(attendanceTicketsProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final t = rows[index];
                final pending = t['status'] == 'pending';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ticketKinds[t['kind']]} · ${ticketStatuses[t['status']]}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (reviewMode)
                          Text('${t['employee_code']} · ${t['employee_name']}'),
                        if (t['original_occurred_at'] != null)
                          Text('Giờ gốc: ${_time(t['original_occurred_at'])}'),
                        Text('Giờ đề nghị: ${_time(t['proposed_at'])}'),
                        Text('Lý do: ${t['reason']}'),
                        TicketEvidenceList(ticket: t),
                        if (t['response'] != null &&
                            '${t['response']}'.isNotEmpty)
                          Text('Phản hồi: ${t['response']}'),
                        if (pending && reviewMode && t['employee_id'] != myId)
                          TextButton(
                            onPressed: () => _review(context, ref, t),
                            child: const Text('Xem và xử lý'),
                          ),
                        if (pending && !reviewMode)
                          TextButton(
                            onPressed: () => _run(
                              context,
                              ref,
                              () => ref
                                  .read(attendanceTicketRepositoryProvider)
                                  .cancel('${t['id']}'),
                            ),
                            child: const Text('Hủy ticket'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
