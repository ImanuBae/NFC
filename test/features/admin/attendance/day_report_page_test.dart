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

      expect(find.text('NV01 - Nguyen Van A'), findsOneWidget);
      expect(find.text('8h 45m'), findsOneWidget);
      expect(find.text(S.lateBadge), findsOneWidget);

      expect(find.text('NV02 - Tran Thi B'), findsOneWidget);
      expect(find.text(S.missingCheckoutBadge), findsOneWidget);
    });

    testWidgets('shows noAttendanceData when empty', (tester) async {
      when(() => mockAttendanceRepo.getDayReport(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text(S.noAttendanceData), findsOneWidget);
    });
  });
}
