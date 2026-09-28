import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import 'attendance_models.dart';
import 'attendance_repository.dart';
import 'manual_edit_sheet.dart';
import 'void_event_dialog.dart';

final eventListProvider = FutureProvider.family
    .autoDispose<List<AttendanceEventItem>, (String?, String?)>((
      ref,
      params,
    ) async {
      final repo = ref.watch(attendanceRepositoryProvider);
      final empId = params.$1;
      final dateStr = params.$2;
      DateTime? date;
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {}
      }
      return repo.getEvents(employeeId: empId, date: date);
    });

class EventListPage extends ConsumerWidget {
  final String? employeeId;
  final String? date;

  const EventListPage({super.key, this.employeeId, this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventListProvider((employeeId, date)));

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.eventsListTitle),
        actions: [
          if (employeeId != null || date != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  date ?? 'Lọc',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('${S.error}: $err')),
        data: (events) {
          if (events.isEmpty) {
            return const Center(
              child: Text(
                'Không có sự kiện chấm công nào',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(eventListProvider((employeeId, date)));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ev = events[index];
                final isCheckIn = ev.type == 'check_in';
                final timeStr = DateFormat('HH:mm:ss - dd/MM/yyyy')
                    .format(ev.occurredAt);

                return Card(
                  color: ev.isVoided ? Colors.grey[200] : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ev.isVoided
                          ? Colors.grey
                          : (isCheckIn ? Colors.green[100] : Colors.blue[100]),
                      child: Icon(
                        isCheckIn ? Icons.login : Icons.logout,
                        color: ev.isVoided
                            ? Colors.grey[800]
                            : (isCheckIn
                                  ? Colors.green[800]
                                  : Colors.blue[800]),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          isCheckIn ? S.checkIn : S.checkOut,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: ev.isVoided
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (ev.employeeName != null)
                          Text(
                            '(${ev.employeeCode ?? ''} ${ev.employeeName})',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(timeStr),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ev.source == 'manual'
                                    ? S.sourceManual
                                    : S.sourceNfc,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (ev.flag != null && ev.flag!.isNotEmpty) ...[
                              const SizedBox(width: 6),
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
                                  ev.flag!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (ev.isVoided) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${S.voided}: ${ev.voidReason ?? ''}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: ev.isVoided
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.block, color: Colors.red),
                            tooltip: S.voidEvent,
                            onPressed: () async {
                              final repo = ref.read(
                                attendanceRepositoryProvider,
                              );
                              final voided = await VoidEventDialog.show(
                                context,
                                eventId: ev.id,
                                repository: repo,
                              );
                              if (voided == true) {
                                ref.invalidate(
                                  eventListProvider((employeeId, date)),
                                );
                              }
                            },
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ManualEditSheet.show(
            context,
            initialEmployeeId: employeeId,
            onSaved: () {
              ref.invalidate(eventListProvider((employeeId, date)));
            },
          );
        },
        icon: const Icon(Icons.edit_calendar),
        label: const Text(S.addManualEvent),
      ),
    );
  }
}
