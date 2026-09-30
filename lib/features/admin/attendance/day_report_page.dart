import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import 'attendance_models.dart';
import 'attendance_repository.dart';

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void setDate(DateTime date) => state = date;
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

final dayReportProvider = FutureProvider.autoDispose<List<DayReportItem>>((
  ref,
) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  return repo.getDayReport(date);
});

class DayReportPage extends ConsumerWidget {
  const DayReportPage({super.key});

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final reportAsync = ref.watch(dayReportProvider);
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd/MM/yyyy').format(selectedDate);
    final dateParam = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: Text(
                  '${S.selectDate}: $dateStr',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: TextButton.icon(
                  onPressed: () => _pickDate(context, ref, selectedDate),
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Đổi ngày'),
                ),
              ),
            ),
          ),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('${S.error}: $err')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      S.noAttendanceData,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dayReportProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final firstInStr = item.firstIn != null
                          ? DateFormat('HH:mm').format(item.firstIn!)
                          : '--:--';
                      final lastOutStr = item.lastOut != null
                          ? DateFormat('HH:mm').format(item.lastOut!)
                          : '--:--';

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            context.go(
                              '/admin/events?employee_id=${item.employeeId}&date=$dateParam',
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.employeeCode} - ${item.employeeName}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      item.workedDurationFormatted,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${S.checkIn}: $firstInStr',
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${S.checkOut}: $lastOutStr',
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.isLate || item.isEarlyLeave || item.missingCheckout) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (item.isLate)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[100],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            S.lateBadge,
                                            style: TextStyle(
                                              color: Colors.orange[900],
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (item.isEarlyLeave)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber[100],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Về sớm (< 18:00)',
                                            style: TextStyle(
                                              color: Color(0xFFB78103),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (item.missingCheckout)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            S.missingCheckoutBadge,
                                            style: TextStyle(
                                              color: Colors.red[900],
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
