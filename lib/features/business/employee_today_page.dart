import '../../core/widgets/page_header.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/widgets/work_summary_card.dart';
import '../admin/attendance/attendance_models.dart';
import '../admin/attendance/attendance_repository.dart';
import '../auth/auth_repository.dart';
import 'employee_profile_card.dart';

DateTime attendanceToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime(now.year, now.month, now.day);
}

final myTodayProvider = FutureProvider.autoDispose<DayReportItem?>((ref) async {
  Timer? refresh;
  ref.onDispose(() => refresh?.cancel());
  final repository = ref.watch(attendanceRepositoryProvider);
  final id = await ref.watch(currentUserEmployeeIdProvider.future);
  if (id == null || !ref.mounted) return null;
  try {
    final rows = await repository.getDayReport(attendanceToday());
    return rows.where((row) => row.employeeId == id).firstOrNull;
  } finally {
    if (ref.mounted) {
      refresh = Timer(const Duration(seconds: 2), ref.invalidateSelf);
    }
  }
}, retry: (_, _) => null);

class EmployeeTodayPage extends ConsumerWidget {
  const EmployeeTodayPage({
    super.key,
    required this.onNavigate,
    required this.onChangePassword,
  });
  final ValueChanged<int> onNavigate;
  final VoidCallback onChangePassword;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(myTodayProvider);
    final profile = ref.watch(currentEmployeeProfileProvider).value;
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentEmployeeProfileProvider);
        final refreshed = await ref.refresh(myTodayProvider.future);
        if (refreshed == null) return;
      },
      child: LayoutBuilder(
        builder: (context, box) => ListView(
          padding: EdgeInsets.symmetric(
            horizontal: box.maxWidth > 1000 ? (box.maxWidth - 960) / 2 : 20,
            vertical: 24,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PageHeader(
              title: profile == null
                  ? 'Ngày làm việc của bạn'
                  : 'Xin chào, ${profile.fullName}',
              description:
                  '${DateFormat('dd/MM/yyyy').format(attendanceToday())}${profile?.department == null ? '' : ' · ${profile!.department}'}',
            ),
            const SizedBox(height: 24),
            if (ref.watch(apiClientProvider).currentUser?.mustChangePassword ==
                true)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hoàn tất tài khoản của bạn',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Đổi mật khẩu ban đầu và đăng ký khuôn mặt trong mục Cá nhân để sẵn sàng chấm công.',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: onChangePassword,
                              child: const Text('Đổi mật khẩu'),
                            ),
                            TextButton(
                              onPressed: () => onNavigate(3),
                              child: const Text('Đăng ký khuôn mặt'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Công hôm nay',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => ref.invalidate(myTodayProvider),
                  tooltip: 'Cập nhật công hôm nay',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (today.hasError && today.hasValue)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Chưa cập nhật được. Đang hiển thị dữ liệu lần tải trước.',
                ),
              ),
            today.when(
              skipError: true,
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: LinearProgressIndicator(),
                ),
              ),
              error: (_, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'Chưa tải được công hôm nay. Kiểm tra kết nối rồi thử lại.',
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(myTodayProvider),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (item) => item == null
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Chưa có dữ liệu công hôm nay. Nếu chưa được cấp hồ sơ, hãy liên hệ Admin.',
                        ),
                      ),
                    )
                  : WorkSummaryCard(
                      item: item,
                      showName: false,
                      onTap: () => onNavigate(1),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              'Chấm công tại kiosk bằng thẻ NFC hoặc khuôn mặt. Thời gian đang làm là tạm tính.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Text(
              'Truy cập nhanh',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Lịch sử chấm công'),
                    subtitle: const Text('Xem từng lượt vào và ra'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onNavigate(1),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Hồ sơ, thẻ NFC và khuôn mặt'),
                    subtitle: const Text(
                      'Kiểm tra thông tin và đăng ký nhận diện',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onNavigate(3),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Bảng lương của tôi'),
                    subtitle: const Text('Xem các kỳ lương đã chốt'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onNavigate(2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
