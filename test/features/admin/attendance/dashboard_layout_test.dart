import 'package:demo_nfc/core/theme.dart';
import 'package:demo_nfc/features/admin/admin_shell.dart';
import 'package:demo_nfc/features/admin/attendance/attendance_models.dart';
import 'package:demo_nfc/features/admin/attendance/day_report_page.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final width in [360.0, 1440.0]) {
    testWidgets('dashboard navigation and status filters at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/admin/days',
        routes: [
          ShellRoute(
            builder: (_, _, child) => AdminShell(child: child),
            routes: [
              GoRoute(
                path: '/admin/days',
                builder: (_, _) => const DayReportPage(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final items = List.generate(
        2,
        (i) => DayReportItem(
          employeeId: 'e$i',
          employeeCode: 'NV0$i',
          employeeName: i == 0 ? 'Dang lam' : 'Chua vao',
          workDate: DateTime.now(),
          firstIn: i == 0 ? DateTime.now() : null,
          workedMinutes: 120,
          missingCheckout: false,
          isLate: false,
          isInShift: i == 0,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoleProvider.overrideWith((ref) async => 'admin'),
            dayReportProvider.overrideWith((ref) async => items),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(NavigationRail),
        width >= 900 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(NavigationBar),
        width < 900 ? findsOneWidget : findsNothing,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Đang làm'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đang làm'));
      await tester.pumpAndSettle();
      expect(find.text('Hiển thị 1/2 nhân viên'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
