import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../auth/auth_repository.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider).value;
    final admin = role == 'admin';
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final location = GoRouterState.of(context).uri.path;
    final paths = [
      '/admin/days',
      if (admin) '/admin/employees',
      '/admin/events',
      '/admin/reports',
      if (admin) '/admin/accounts',
    ];
    final labels = [
      'Tổng quan',
      if (admin) S.navEmployees,
      S.navEvents,
      'Báo cáo & lương',
      if (admin) 'Tài khoản & thiết bị',
    ];
    final mobileLabels = [
      'Tổng quan',
      if (admin) 'Nhân viên',
      'Lượt quét',
      'Báo cáo',
      if (admin) 'Tài khoản',
    ];
    final icons = [
      Icons.dashboard_outlined,
      if (admin) Icons.people_outline,
      Icons.history_outlined,
      Icons.assessment_outlined,
      if (admin) Icons.manage_accounts_outlined,
    ];
    final match = paths.indexWhere((path) => location.startsWith(path));
    final selected = match < 0 ? 0 : match;
    void navigate(int index) => context.go(paths[index]);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text('Attendance', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (admin)
            if (MediaQuery.sizeOf(context).width >= 700)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => context.go('/admin/employees/import'),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Nhập Excel'),
                ),
              )
            else
              IconButton(
                onPressed: () => context.go('/admin/employees/import'),
                icon: const Icon(Icons.upload_file),
                tooltip: 'Nhập nhân viên từ Excel',
              ),
          if (role == 'manager')
            IconButton(
              onPressed: () => context.go('/me'),
              icon: const Icon(Icons.person_outline),
              tooltip: 'Cổng nhân viên',
            ),
          IconButton(
            tooltip: S.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  extended: MediaQuery.sizeOf(context).width >= 1200,
                  minExtendedWidth: 224,
                  selectedIndex: selected,
                  onDestinationSelected: navigate,
                  labelType: MediaQuery.sizeOf(context).width >= 1200
                      ? null
                      : NavigationRailLabelType.all,
                  destinations: List.generate(
                    paths.length,
                    (i) => NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                    ),
                    child: child,
                  ),
                ),
              ],
            )
          : child,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: navigate,
              destinations: List.generate(
                paths.length,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: mobileLabels[i],
                ),
              ),
            ),
    );
  }
}
