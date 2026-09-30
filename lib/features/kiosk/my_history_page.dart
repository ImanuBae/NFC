import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/attendance/attendance_models.dart';
import '../admin/attendance/attendance_repository.dart';
import '../admin/employees/employee_detail_page.dart';
import '../admin/employees/employee_list_page.dart';
import '../admin/employees/employee_model.dart';
import '../auth/auth_repository.dart';

final myAttendanceEventsProvider =
    FutureProvider.family.autoDispose<List<AttendanceEventItem>, String>((
      ref,
      employeeId,
    ) async {
      final repo = ref.watch(attendanceRepositoryProvider);
      return repo.getEvents(employeeId: employeeId);
    });

class MyHistoryPage extends ConsumerStatefulWidget {
  const MyHistoryPage({super.key});

  @override
  ConsumerState<MyHistoryPage> createState() => _MyHistoryPageState();
}

class _MyHistoryPageState extends ConsumerState<MyHistoryPage> {
  String? _selectedEmployeeId;
  bool _isLinking = false;

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

  Widget _buildLinkEmployeeView(ThemeData theme) {
    final employeesAsync = ref.watch(employeeListProvider);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Liên kết hồ sơ nhân viên',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tài khoản này chưa liên kết với nhân viên nào. Vui lòng chọn hồ sơ nhân viên của bạn để xem lịch sử chấm công.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  employeesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (err, _) => Text('Lỗi tải nhân viên: $err'),
                    data: (employees) {
                      if (employees.isEmpty) {
                        return const Text('Chưa có nhân viên nào trên hệ thống.');
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Chọn nhân viên',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: employees.map((emp) {
                          return DropdownMenuItem<String>(
                            value: emp.id,
                            child: Text('${emp.code} - ${emp.fullName}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedEmployeeId = val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLinking || _selectedEmployeeId == null
                        ? null
                        : () async {
                            setState(() => _isLinking = true);
                            try {
                              await ref
                                  .read(authRepositoryProvider)
                                  .linkCurrentEmployee(_selectedEmployeeId!);
                              ref.invalidate(currentUserEmployeeIdProvider);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Lỗi: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isLinking = false);
                            }
                          },
                    icon: const Icon(Icons.link),
                    label: Text(_isLinking ? 'Đang liên kết...' : 'Xác nhận liên kết'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
                  final dateStr = DateFormat('dd/MM/yyyy').format(ev.occurredAt);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCheckIn
                            ? Colors.green[100]
                            : Colors.blue[100],
                        child: Icon(
                          isCheckIn ? Icons.login : Icons.logout,
                          color: isCheckIn
                              ? Colors.green[800]
                              : Colors.blue[800],
                        ),
                      ),
                      title: Text(
                        isCheckIn ? 'Check-in (Vào ca)' : 'Check-out (Ra ca)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCheckIn
                              ? Colors.green[800]
                              : Colors.blue[800],
                        ),
                      ),
                      subtitle: Text('$timeStr • $dateStr'),
                      trailing: ev.isVoided
                          ? const Chip(
                              label: Text(
                                'Đã hủy',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                              backgroundColor: Color(0xFFFFEBEE),
                              padding: EdgeInsets.zero,
                            )
                          : const Chip(
                              label: Text(
                                'Hợp lệ',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                ),
                              ),
                              backgroundColor: Color(0xFFE8F5E9),
                              padding: EdgeInsets.zero,
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
