import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../auth/change_password_dialog.dart';

import '../auth/auth_repository.dart';
import '../kiosk/my_history_page.dart';
import 'business_repository.dart';
import 'face_camera_card.dart';
import 'employee_profile_card.dart';
import 'employee_today_page.dart';

class EmployeeHomePage extends ConsumerStatefulWidget {
  const EmployeeHomePage({super.key});
  @override
  ConsumerState<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends ConsumerState<EmployeeHomePage> {
  int _tab = 0;
  Future<List<Map<String, dynamic>>>? _pay;

  Future<List<Map<String, dynamic>>> _loadPay() async {
    final id = await ref
        .read(authRepositoryProvider)
        .getCurrentUserEmployeeId();
    if (id == null) return [];
    return ref.read(businessRepositoryProvider).payrollItems(employeeId: id);
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
    }
  }

  void _navigate(int value) => setState(() {
    _tab = value;
    if (value == 2) _pay = _loadPay();
  });

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          1 => 'Lịch sử chấm công',
          2 => 'Lương của tôi',
          3 => 'Cá nhân',
          _ => 'Hôm nay',
        }),
        actions: [
          IconButton(
            onPressed: _changePassword,
            icon: const Icon(Icons.password),
            tooltip: 'Đổi mật khẩu',
          ),
          if (role == 'manager')
            IconButton(
              onPressed: () => context.go('/admin/days'),
              icon: const Icon(Icons.dashboard),
              tooltip: 'Quản lý',
            ),
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _navigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Hôm nay',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            label: 'Lương của tôi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Cá nhân',
          ),
        ],
      ),
      body: _tab == 0
          ? EmployeeTodayPage(
              onNavigate: _navigate,
              onChangePassword: _changePassword,
            )
          : _tab == 1
          ? const MyHistoryPage()
          : _tab == 2
          ? FutureBuilder<List<Map<String, dynamic>>>(
              future: _pay,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Chưa có bảng lương đã chốt.'),
                  );
                }
                final money = NumberFormat.currency(
                  locale: 'vi_VN',
                  symbol: '₫',
                  decimalDigits: 0,
                );
                return ListView(
                  children: snapshot.data!
                      .map(
                        (row) => Card(
                          child: ListTile(
                            title: Text(
                              '${row['payroll_runs']['start_date']} → ${row['payroll_runs']['end_date']} (không gồm ngày cuối)',
                            ),
                            subtitle: Text(
                              '${(num.parse('${row['worked_minutes']}') / 60).toStringAsFixed(2)} giờ · ${money.format(num.parse('${row['hourly_rate']}'))}/giờ',
                            ),
                            trailing: Text(
                              money.format(num.parse('${row['gross_pay']}')),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (ref
                        .watch(apiClientProvider)
                        .currentUser
                        ?.mustChangePassword ==
                    true)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tài khoản mới: hãy đổi mật khẩu ban đầu, sau đó đăng ký khuôn mặt của bạn để chấm công tại kiosk ngay.',
                          ),
                          TextButton.icon(
                            onPressed: _changePassword,
                            icon: const Icon(Icons.password),
                            label: const Text('Đổi mật khẩu'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const EmployeeProfileCard(),
                const SizedBox(height: 16),
                const FaceCameraCard(),
              ],
            ),
    );
  }
}
