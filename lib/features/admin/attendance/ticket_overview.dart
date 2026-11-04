import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../business/attendance_ticket_repository.dart';

class TicketOverview extends ConsumerWidget {
  const TicketOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(attendanceTicketsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Ticket sửa công',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () => context.go('/admin/tickets'),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Kiểm tra ticket'),
                ),
              ],
            ),
            if (tickets.isRefreshing)
              const LinearProgressIndicator(minHeight: 2),
            if (tickets.hasError && tickets.hasValue)
              const Text(
                'Chưa cập nhật được ticket. Đang hiển thị dữ liệu cũ.',
              ),
            tickets.when(
              skipError: true,
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => Row(
                children: [
                  const Expanded(
                    child: Text('Không tải được ticket sửa công.'),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(attendanceTicketsProvider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
              data: (rows) {
                final pending = rows
                    .where((ticket) => ticket['status'] == 'pending')
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tất cả ngày · ${pending.length} yêu cầu chờ xử lý',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Không có ticket đang chờ xử lý.'),
                      ),
                    for (final ticket in pending.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${ticket['employee_code']} · ${ticket['employee_name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${ticketKinds[ticket['kind']]} · ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse('${ticket['proposed_at']}').toLocal())}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/admin/tickets'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
