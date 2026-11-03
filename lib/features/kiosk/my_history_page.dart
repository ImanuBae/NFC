import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/attendance/attendance_models.dart';
import '../admin/attendance/attendance_repository.dart';
import '../admin/employees/employee_detail_page.dart';

import '../admin/employees/employee_model.dart';
import '../auth/auth_repository.dart';
import '../business/attendance_ticket_form.dart';
import '../business/attendance_tickets_page.dart';

final myAttendanceEventsProvider = FutureProvider.family
    .autoDispose<List<AttendanceEventItem>, String>((ref, employeeId) async {
      final repo = ref.watch(attendanceRepositoryProvider);
      return repo.getEvents(employeeId: employeeId);
    });

class MyHistoryPage extends ConsumerStatefulWidget {
  const MyHistoryPage({super.key});

  @override
  ConsumerState<MyHistoryPage> createState() => _MyHistoryPageState();
}

class _MyHistoryPageState extends ConsumerState<MyHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empIdAsync = ref.watch(currentUserEmployeeIdProvider);

    return empIdAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (employeeId) {
        if (employeeId == null || employeeId.isEmpty) {
          return _buildLinkEmployeeView(theme);
        }
        return _buildHistoryView(theme, employeeId);
      },
    );
  }

  Widget _buildLinkEmployeeView(ThemeData theme) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Tài khoản chưa liên kết hồ sơ nhân viên. Vui lòng liên hệ Admin để được cấp đúng hồ sơ.',
      ),
    ),
  );
  Widget _buildHistoryView(ThemeData theme, String employeeId) {
    final eventsAsync = ref.watch(myAttendanceEventsProvider(employeeId));
    final empAsync = ref.watch(employeeDetailProvider(employeeId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myAttendanceEventsProvider(employeeId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final sent = await AttendanceTicketForm.show(context);
                  if (sent == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã gửi ticket, đang chờ Admin/Quản lý xử lý.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Tạo ticket sửa công'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AttendanceTicketsPage(),
                  ),
                ),
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Ticket của tôi'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          empAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (Employee? emp) {
              if (emp == null) return const SizedBox.shrink();
              return Card(
                color: theme.colorScheme.primaryContainer,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          emp.code,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.fullName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              'Mã nhân viên: ${emp.code}',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ca làm việc: 09:00 - 18:00',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Vào ca sau 09:00: Đi trễ • Tan ca trước 18:00: Về sớm',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            'Lịch sử quẹt thẻ gần đây',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          eventsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
            data: (events) {
              if (events.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Bạn chưa có lần quẹt thẻ nào.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ev = events[index];
                  final isCheckIn = ev.type == 'check_in';
                  final timeStr = DateFormat('HH:mm:ss').format(ev.occurredAt);
                  final dateStr = DateFormat('dd/MM/yyyy')
                      .format(ev.occurredAt);

                  final isLate =
                      isCheckIn &&
                      (ev.occurredAt.hour > 9 ||
                          (ev.occurredAt.hour == 9 &&
                              ev.occurredAt.minute > 0));
                  final isEarlyLeave = !isCheckIn && (ev.occurredAt.hour < 18);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCheckIn
                            ? (isLate ? Colors.orange[100] : Colors.green[100])
                            : (isEarlyLeave
                                  ? Colors.amber[100]
                                  : Colors.blue[100]),
                        child: Icon(
                          isCheckIn ? Icons.login : Icons.logout,
                          color: isCheckIn
                              ? (isLate
                                    ? Colors.orange[800]
                                    : Colors.green[800])
                              : (isEarlyLeave
                                    ? Colors.amber[800]
                                    : Colors.blue[800]),
                        ),
                      ),
                      title: Text(
                        isCheckIn ? 'Check-in (Vào ca)' : 'Check-out (Ra ca)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCheckIn
                              ? (isLate
                                    ? Colors.orange[800]
                                    : Colors.green[800])
                              : (isEarlyLeave
                                    ? Colors.amber[900]
                                    : Colors.blue[800]),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$timeStr • $dateStr'),
                          if (!ev.isVoided)
                            TextButton(
                              onPressed: () =>
                                  AttendanceTicketForm.show(context, event: ev),
                              child: const Text('Yêu cầu sửa giờ'),
                            ),
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isLate)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Đi trễ',
                                style: TextStyle(
                                  color: Colors.orange[900],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (isEarlyLeave)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Về sớm',
                                style: TextStyle(
                                  color: Colors.amber[900],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Đúng giờ',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (ev.isVoided)
                            const Chip(
                              label: Text(
                                'Đã hủy',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                              backgroundColor: Color(0xFFFFEBEE),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
