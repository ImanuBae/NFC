import 'dart:async';

import 'package:demo_nfc/core/theme.dart';
import 'package:demo_nfc/features/admin/admin_shell.dart';
import 'package:demo_nfc/features/admin/attendance/day_report_page.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:demo_nfc/features/business/attendance_ticket_repository.dart';
import 'package:demo_nfc/features/business/attendance_tickets_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockTicketRepository extends Mock implements AttendanceTicketRepository {}

Map<String, dynamic> ticket(String id, {String status = 'pending'}) => {
  'id': id,
  'employee_id': 'employee-$id',
  'employee_code': 'NV$id',
  'employee_name': 'Nhân viên $id',
  'kind': 'missing_in',
  'status': status,
  'proposed_at': '2026-11-04T09:00:00+07:00',
  'reason': 'Quên chấm công vào ca',
};

void main() {
  late MockTicketRepository repository;

  setUp(() {
    repository = MockTicketRepository();
  });

  Future<void> openDashboard(
    WidgetTester tester, {
    String role = 'admin',
  }) async {
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
            GoRoute(
              path: '/admin/tickets',
              builder: (_, _) => const AttendanceTicketsPage(reviewMode: true),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceTicketRepositoryProvider.overrideWithValue(repository),
          currentRoleProvider.overrideWith((ref) async => role),
          currentUserEmployeeIdProvider.overrideWith((ref) async => null),
          dayReportProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final role in ['admin', 'manager']) {
    for (final width in [360.0, 1440.0]) {
      testWidgets('$role can inspect pending tickets at width $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        when(() => repository.list()).thenAnswer(
          (_) async => [
            ticket('closed', status: 'approved'),
            ticket('1'),
            ticket('2'),
            ticket('3'),
            ticket('4'),
          ],
        );
        await openDashboard(tester, role: role);
        expect(find.text('Tất cả ngày · 4 yêu cầu chờ xử lý'), findsOneWidget);
        expect(find.text('NV1 · Nhân viên 1'), findsOneWidget);
        expect(find.text('NV4 · Nhân viên 4'), findsNothing);
        expect(find.text('NVclosed · Nhân viên closed'), findsNothing);
        expect(
          find.byTooltip('Duyệt ticket sửa công · 4 chờ xử lý'),
          findsOneWidget,
        );
        expect(find.textContaining('vừa gửi ticket'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Kiểm tra ticket'));
        await tester.pumpAndSettle();
        expect(find.text('Duyệt ticket sửa công'), findsOneWidget);
        expect(find.text('Xem và xử lý'), findsWidgets);
        if (width >= 900) {
          expect(
            tester
                .widget<NavigationRail>(find.byType(NavigationRail))
                .selectedIndex,
            role == 'admin' ? 3 : 2,
          );
        } else {
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            role == 'admin' ? 3 : 2,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'new tickets notify once, link to review, and update pending count',
    (tester) async {
      var rows = [ticket('old')];
      when(() => repository.list()).thenAnswer((_) async => rows);
      await openDashboard(tester);
      expect(find.textContaining('vừa gửi ticket'), findsNothing);

      rows = [ticket('new'), ...rows];
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        find.text('Nhân viên new vừa gửi ticket sửa công.'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Duyệt ticket sửa công · 2 chờ xử lý'),
        findsOneWidget,
      );
      await tester.tap(find.text('Xem ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Duyệt ticket sửa công'), findsOneWidget);

      rows = [ticket('new', status: 'approved'), ticket('old')];
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Duyệt ticket sửa công · 1 chờ xử lý'),
        findsOneWidget,
      );
      expect(find.textContaining('vừa gửi ticket'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reviewing a ticket clears its pending badge', (tester) async {
    var status = 'pending';
    when(() => repository.list())
        .thenAnswer((_) async => [ticket('1', status: status)]);
    when(() => repository.review('1', 'approved', '')).thenAnswer((_) async {
      status = 'approved';
    });
    await openDashboard(tester);
    await tester.tap(find.text('Kiểm tra ticket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem và xử lý'));
    await tester.pumpAndSettle();
    expect(find.text('Lý do: Quên chấm công vào ca'), findsWidgets);
    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();
    verify(() => repository.review('1', 'approved', '')).called(1);
    expect(
      find.byTooltip('Duyệt ticket sửa công · 0 chờ xử lý'),
      findsOneWidget,
    );
    expect(find.text('Đã duyệt'), findsNothing);
    expect(find.text('Thiếu giờ vào · Đã duyệt'), findsOneWidget);
    expect(find.text('Xem và xử lý'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'polling waits for slow requests, preserves data and retries errors',
    (tester) async {
      var requests = 0;
      final slow = Completer<List<Map<String, dynamic>>>();
      when(() => repository.list()).thenAnswer((_) {
        requests++;
        if (requests == 2) return slow.future;
        return Future.value([ticket('1')]);
      });
      await openDashboard(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 6));
      expect(requests, 2);
      expect(find.text('NV1 · Nhân viên 1'), findsOneWidget);
      slow.completeError(Exception('Offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Chưa cập nhật được ticket'), findsOneWidget);
      expect(find.text('NV1 · Nhân viên 1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(requests, 3);
      expect(find.textContaining('Chưa cập nhật được ticket'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(requests, 3);
    },
  );

  testWidgets(
    'failed first load offers retry and recovers to the empty state',
    (tester) async {
      var failed = true;
      when(() => repository.list()).thenAnswer((_) async {
        if (failed) throw Exception('Offline');
        return [];
      });
      await openDashboard(tester);
      expect(find.text('Không tải được ticket sửa công.'), findsOneWidget);
      expect(find.textContaining('0 yêu cầu chờ xử lý'), findsNothing);
      failed = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Không có ticket đang chờ xử lý.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
