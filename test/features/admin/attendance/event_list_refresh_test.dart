import 'package:demo_nfc/features/admin/attendance/attendance_models.dart';
import 'package:demo_nfc/features/admin/attendance/attendance_repository.dart';
import 'package:demo_nfc/features/admin/attendance/event_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('event cards fit width $width at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = MockAttendanceRepository();
        when(() => repo.getEvents()).thenAnswer(
          (_) async => [
            for (final voided in [false, true])
              AttendanceEventItem(
                id: 'event-$voided',
                employeeId: 'emp-1',
                employeeCode: 'NV04',
                employeeName: 'Trần Nguyễn Đức Trung',
                type: voided ? 'check_out' : 'check_in',
                occurredAt: DateTime(2026, 11, 4, 11, 7),
                source: 'face_camera',
                flag: 'Dữ liệu mẫu chấm công có ghi chú rất dài để kiểm tra',
                voidedAt: voided ? DateTime(2026, 11, 4, 12) : null,
                voidReason: voided
                    ? 'Nhân viên quét nhầm, quản lý đã kiểm tra và hủy lượt'
                    : null,
              ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [attendanceRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const EventListPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.block), findsOneWidget);
        // The complete name remains available even when its visible text is cut.
        expect(find.byTooltip('NV04 Trần Nguyễn Đức Trung'), findsNWidgets(2));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('event list automatically refreshes with the original filters', (
    tester,
  ) async {
    final repo = MockAttendanceRepository();
    var scanned = false;
    when(
      () => repo.getEvents(employeeId: 'emp-1', date: DateTime(2026, 10, 30)),
    ).thenAnswer(
      (_) async => scanned
          ? [
              AttendanceEventItem(
                id: 'event-new',
                employeeId: 'emp-1',
                employeeCode: 'NV01',
                employeeName: 'Nhan vien',
                type: 'check_in',
                occurredAt: DateTime(2026, 10, 30, 8),
                source: 'nfc',
              ),
            ]
          : [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attendanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: EventListPage(employeeId: 'emp-1', date: '2026-10-30'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scanned = true;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('NV01'), findsOneWidget);
    verify(
      () => repo.getEvents(employeeId: 'emp-1', date: DateTime(2026, 10, 30)),
    ).called(2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
