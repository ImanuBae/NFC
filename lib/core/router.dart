import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_shell.dart';
import '../features/admin/attendance/day_report_page.dart';
import '../features/admin/attendance/event_list_page.dart';
import '../features/admin/cards/assign_card_page.dart';
import '../features/admin/employees/employee_detail_page.dart';
import '../features/admin/employees/employee_list_page.dart';
import '../features/admin/employees/employee_import_page.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/login_page.dart';
import '../features/business/accounts_page.dart';
import '../features/business/reports_page.dart';
import '../features/business/employee_home_page.dart';
import '../features/kiosk/device_config.dart';
import '../features/kiosk/kiosk_idle_page.dart';
import '../features/kiosk/kiosk_setup_page.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  String? _userRole;
  String? _deviceId;
  bool _isInitialized = false;
  StreamSubscription? _authSub;
  bool _disposed = false;
  int _generation = 0;

  RouterNotifier(this._ref) {
    _init();
  }

  bool get isInitialized => _isInitialized;
  String? get userRole => _userRole;
  String? get deviceId => _deviceId;

  Future<void> _init() async {
    final authRepo = _ref.read(authRepositoryProvider);
    _authSub = authRepo.authStateChanges.listen((_) async {
      await refreshState();
    });
    await refreshState();
  }

  Future<void> refreshState() async {
    if (_disposed) return;
    final generation = ++_generation;
    final authRepo = _ref.read(authRepositoryProvider);
    String? role;
    String? deviceId;
    role = await authRepo.getCurrentUserRole();
    if (authRepo.currentUser != null) {
      deviceId = await _ref.read(deviceConfigProvider).getDeviceId();
    }
    if (_disposed || generation != _generation) return;
    _userRole = role;
    _deviceId = deviceId;
    _isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    super.dispose();
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  // Rebind the auth subscription when switching API servers.
  ref.watch(authRepositoryProvider);
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = authRepo.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      final role = notifier.userRole;
      if (role == null) {
        return isLoggingIn ? null : '/login';
      }

      final hasDeviceId =
          notifier.deviceId != null && notifier.deviceId!.isNotEmpty;

      if (role == 'kiosk') {
        if (!state.matchedLocation.startsWith('/kiosk')) {
          return hasDeviceId ? '/kiosk' : '/kiosk/setup';
        }
        if (!hasDeviceId) {
          return state.matchedLocation == '/kiosk/setup'
              ? null
              : '/kiosk/setup';
        }
        if (state.matchedLocation.startsWith('/admin') ||
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/kiosk/setup') {
          return '/kiosk';
        }
        return null;
      }

      if (role == 'employee') {
        return state.matchedLocation == '/me' ? null : '/me';
      }

      if (role == 'admin' || role == 'manager') {
        if (role == 'manager' &&
            (state.matchedLocation.startsWith('/admin/accounts') ||
                state.matchedLocation.startsWith('/admin/employees'))) {
          return '/admin/days';
        }
        if (role == 'manager' && state.matchedLocation == '/me') return null;
        if (state.matchedLocation.startsWith('/kiosk') ||
            state.matchedLocation == '/me' ||
            state.matchedLocation == '/login') {
          return '/admin/days';
        }
        return null;
      }

      return isLoggingIn ? null : '/login';
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/me',
        builder: (context, state) => const EmployeeHomePage(),
      ),
      GoRoute(
        path: '/kiosk/setup',
        builder: (context, state) => const KioskSetupPage(),
      ),
      GoRoute(
        path: '/kiosk',
        builder: (context, state) => const KioskIdlePage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/admin/accounts',
            builder: (context, state) => const AccountsPage(),
          ),
          GoRoute(
            path: '/admin/days',
            builder: (context, state) => const DayReportPage(),
          ),
          GoRoute(
            path: '/admin/employees',
            builder: (context, state) => const EmployeeListPage(),
            routes: [
              GoRoute(
                path: 'import',
                builder: (context, state) => const EmployeeImportPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return EmployeeDetailPage(employeeId: id);
                },
                routes: [
                  GoRoute(
                    path: 'assign-card',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return AssignCardPage(employeeId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/admin/events',
            builder: (context, state) {
              final empId = state.uri.queryParameters['employee_id'];
              final date = state.uri.queryParameters['date'];
              return EventListPage(employeeId: empId, date: date);
            },
          ),
        ],
      ),
    ],
  );
});
