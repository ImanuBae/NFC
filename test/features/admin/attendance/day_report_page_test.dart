import 'dart:async';

import 'package:demo_nfc/core/strings.dart';
import 'package:demo_nfc/features/admin/attendance/attendance_models.dart';
import 'package:demo_nfc/features/admin/attendance/attendance_repository.dart';
import 'package:demo_nfc/features/admin/attendance/day_report_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  late MockAttendanceRepository mockAttendanceRepo;

  setUp(() {
    mockAttendanceRepo = MockAttendanceRepository();
  });

  Widget buildWidget() {
    return ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(mockAttendanceRepo),
      ],
      child: const MaterialApp(home: DayReportPage()),
    );
  }

  group('DayReportPage', () {
    testWidgets(
      'keeps dashboard visible during slow refresh and retries errors',
      (tester) async {
        var requests = 0;
        final pending = Completer<List<DayReportItem>>();
        final item = DayReportItem(
          employeeId: 'e',
          employeeCode: 'NV01',
          employeeName: 'An',
          workDate: DateTime.now(),
          workedMinutes: 120,
          missingCheckout: false,
          isLate: false,
        );
        when(() => mockAttendanceRepo.getDayReport(any())).thenAnswer((_) {
          requests++;
          if (requests == 1) return Future.value([item]);
          if (requests == 2) return pending.future;
          return Future.value([item]);
        });
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('NV01 - An'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('NV01 - An'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        pending.completeError(Exception('Network unavailable'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('NV01 - An'), findsOneWidget);
        expect(find.textContaining('Chưa cập nhật được'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chưa cập nhật được'), findsNothing);
        expect(requests, 3);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('dashboard announces new NFC and face scans only once', (
      tester,
    ) async {
      var event = 'initial';
      var source = 'nfc';
      var type = 'check_in';
      when(() => mockAttendanceRepo.getDayReport(any())).thenAnswer(
        (_) async => [
          DayReportItem(
            employeeId: 'emp-1',
            employeeCode: 'NV01',
            employeeName: 'An',
            workDate: DateTime.now(),
            firstIn: DateTime.now(),
            workedMinutes: 30,
            missingCheckout: false,
            isLate: true,
            isInShift: type == 'check_in',
            remainingMinutes: 450,
            lateMinutes: 30,
            expectedCompletion: DateTime(2026, 10, 30, 18, 30),
            lastEventId: event,
            lastEventSource: source,
            lastEventType: type,
            lastEventAt: DateTime(2026, 10, 30, 9, 30),
          ),
        ],
      );
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      expect(find.text('Chấm công mới'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Dự kiến đủ công lúc 18:30'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Dự kiến đủ công lúc 18:30'), findsOneWidget);
      event = 'nfc-scan';
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Chấm công mới'), findsOneWidget);
      expect(find.textContaining('Vào ca lúc 09:30 · NFC'), findsOneWidget);
      final notice = tester.getRect(
        find.byKey(const ValueKey('attendance-notice-nfc-scan')),
      );
      expect(
        notice.right,
        closeTo(
          tester.view.physicalSize.width / tester.view.devicePixelRatio - 12,
          1,
        ),
      );
      expect(notice.top, 12);
      await tester.tap(find.byTooltip('Đóng thông báo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Chấm công mới'), findsNothing);
      event = 'face-scan';
      source = 'face_camera';
      type = 'check_out';
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ra ca lúc 09:30 · Khuôn mặt'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Đã ra ca'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đã ra ca'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('Chấm công mới'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Chấm công mới'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'shows simultaneous scans on a narrow screen and clears on date change',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var scanned = false;
        when(() => mockAttendanceRepo.getDayReport(any())).thenAnswer(
          (_) async => [
            for (var i = 0; i < 2; i++)
              DayReportItem(
                employeeId: 'e$i',
                employeeCode: 'NV0$i',
                employeeName: i == 0 ? 'Hoài Hiếu' : 'Nhân viên B',
                workDate: DateTime.now(),
                workedMinutes: 0,
                missingCheckout: false,
                isLate: false,
                lastEventId: scanned ? 'scan-$i' : null,
                lastEventSource: i == 0 ? 'face_camera' : 'nfc',
                lastEventType: 'check_in',
                lastEventAt: scanned ? DateTime.now() : null,
              ),
          ],
        );
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        scanned = true;
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Chấm công mới'), findsNWidgets(2));
        expect(find.text('Vừa vào ca bằng khuôn mặt'), findsOneWidget);
        expect(find.text('Vừa vào ca bằng NFC'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(DayReportPage));
        ProviderScope.containerOf(context)
            .read(selectedDateProvider.notifier)
            .setDate(DateTime(2026, 1, 1));
        await tester.pumpAndSettle();
        expect(find.text('Chấm công mới'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('new attendance appears automatically without manual refresh', (
      tester,
    ) async {
      var hasScan = false;
      when(() => mockAttendanceRepo.getDayReport(any())).thenAnswer(
        (_) async => hasScan
            ? [
                DayReportItem(
                  employeeId: 'emp-new',
                  employeeCode: 'NV03',
                  employeeName: 'Nhan vien moi',
                  workDate: DateTime.now(),
                  firstIn: DateTime.now(),
                  workedMinutes: 0,
                  missingCheckout: true,
                  isLate: false,
                ),
              ]
            : [],
      );
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(S.noAttendanceData),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(S.noAttendanceData), findsOneWidget);
      hasScan = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('NV03 - Nhan vien moi'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('NV03 - Nhan vien moi'), findsOneWidget);
      expect(find.text(S.noAttendanceData), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'slow refresh does not overlap requests and stops after leaving',
      (tester) async {
        final pending = Completer<List<DayReportItem>>();
        var requests = 0;
        when(() => mockAttendanceRepo.getDayReport(any())).thenAnswer((_) {
          requests++;
          return requests == 1 ? Future.value([]) : pending.future;
        });
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 8));
        expect(requests, 2);
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete([]);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        expect(requests, 2);
      },
    );

    testWidgets('renders attendance items with badges correctly', (
      tester,
    ) async {
      when(() => mockAttendanceRepo.getDayReport(any())).thenAnswer(
        (_) async => [
          DayReportItem(
            employeeId: 'emp-1',
            employeeCode: 'NV01',
            employeeName: 'Nguyen Van A',
            workDate: DateTime.now(),
            firstIn: DateTime(2026, 9, 28, 8, 45), // Late (> 08:30)
            lastOut: DateTime(2026, 9, 28, 17, 30),
            workedMinutes: 525,
            missingCheckout: false,
            isLate: true,
          ),
          DayReportItem(
            employeeId: 'emp-2',
            employeeCode: 'NV02',
            employeeName: 'Tran Thi B',
            workDate: DateTime.now(),
            firstIn: DateTime(2026, 9, 28, 8, 15),
            lastOut: null,
            workedMinutes: 0,
            missingCheckout: true,
            isLate: false,
          ),
        ],
      );

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('NV01 - Nguyen Van A'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('NV01 - Nguyen Van A'), findsOneWidget);
      expect(find.text('8h 45m'), findsOneWidget);
      expect(find.text(S.lateBadge), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('NV02 - Tran Thi B'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('NV02 - Tran Thi B'), findsOneWidget);
      expect(find.text(S.missingCheckoutBadge), findsOneWidget);
    });

    testWidgets('shows noAttendanceData when empty', (tester) async {
      when(() => mockAttendanceRepo.getDayReport(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(S.noAttendanceData),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(S.noAttendanceData), findsOneWidget);
    });
  });
}
