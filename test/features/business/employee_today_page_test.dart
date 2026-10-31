import 'package:demo_nfc/features/admin/attendance/attendance_models.dart';
import 'package:demo_nfc/features/business/employee_today_page.dart';
import 'package:demo_nfc/features/business/employee_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'today shows backend work totals and opens personal information',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? destination;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEmployeeProfileProvider.overrideWith((ref) async => null),
            myTodayProvider.overrideWith(
              (ref) async => DayReportItem(
                employeeId: 'e1',
                employeeCode: 'NV01',
                employeeName: 'Nhan vien',
                workDate: DateTime(2026, 10, 31),
                firstIn: DateTime(2026, 10, 31, 9, 30),
                workedMinutes: 120,
                completedMinutes: 0,
                missingCheckout: false,
                isLate: true,
                lateMinutes: 30,
                isInShift: true,
                remainingMinutes: 360,
                requiredMinutes: 480,
                expectedCompletion: DateTime(2026, 10, 31, 18, 30),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EmployeeTodayPage(
                onNavigate: (v) => destination = v,
                onChangePassword: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2h 0m'), findsOneWidget);
      expect(find.textContaining('Còn thiếu: 6h 0m'), findsOneWidget);
      expect(find.textContaining('Dự kiến đủ công lúc 18:30'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Hồ sơ, thẻ NFC và khuôn mặt'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Hồ sơ, thẻ NFC và khuôn mặt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hồ sơ, thẻ NFC và khuôn mặt'));
      expect(destination, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
