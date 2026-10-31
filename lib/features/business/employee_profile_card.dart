import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_repository.dart';
import '../admin/employees/employee_model.dart';
import '../admin/employees/employee_repository.dart';
import '../admin/cards/card_repository.dart';
import '../admin/cards/card_model.dart';

final currentEmployeeProfileProvider = FutureProvider.autoDispose<Employee?>((
  ref,
) async {
  final id = await ref.watch(currentUserEmployeeIdProvider.future);
  if (id == null) return null;
  return ref.watch(employeeRepositoryProvider).getEmployeeById(id);
});

final currentEmployeeCardsProvider =
    FutureProvider.autoDispose<List<CardModel>>((ref) async {
      final id = await ref.watch(currentUserEmployeeIdProvider.future);
      if (id == null) return [];
      return ref.watch(cardRepositoryProvider).getCardsForEmployee(id);
    });

class EmployeeProfileCard extends ConsumerWidget {
  const EmployeeProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void refresh() {
      ref.invalidate(currentEmployeeProfileProvider);
      ref.invalidate(currentEmployeeCardsProvider);
    }

    final profile = ref.watch(currentEmployeeProfileProvider);
    final cards = ref.watch(currentEmployeeCardsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Hồ sơ nhân viên',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: refresh,
                  tooltip: 'Tải lại hồ sơ',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            profile.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text(
                'Chưa tải được hồ sơ. Bấm tải lại để kiểm tra thông tin.',
              ),
              data: (employee) {
                if (employee == null) {
                  return const Text('Tài khoản chưa liên kết hồ sơ nhân viên.');
                }
                String value(String? text) =>
                    text == null || text.isEmpty ? 'Chưa có thông tin' : text;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText('Mã NV: ${employee.code}'),
                    SelectableText('Họ và tên: ${employee.fullName}'),
                    SelectableText('Email: ${value(employee.email)}'),
                    SelectableText('Phòng ban: ${value(employee.department)}'),
                    SelectableText('Chức vụ: ${value(employee.jobTitle)}'),
                    SelectableText('Số điện thoại: ${value(employee.phone)}'),
                    Text(
                      'Ngày vào làm: ${employee.hireDate == null ? 'Chưa có thông tin' : DateFormat('dd/MM/yyyy').format(employee.hireDate!)}',
                    ),
                    Text(
                      'Đơn giá giờ: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(employee.hourlyRate)}/giờ',
                    ),
                  ],
                );
              },
            ),
            cards.when(
              loading: () => const Text('Đang tải thẻ NFC…'),
              error: (_, _) => const Text('Chưa tải được thẻ NFC.'),
              data: (values) {
                final active = values.where((card) => card.active).toList();
                return SelectableText(
                  active.isEmpty
                      ? 'Thẻ NFC: Chưa được cấp'
                      : 'UID thẻ NFC: ${active.map((card) => card.uid).join(', ')}',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
