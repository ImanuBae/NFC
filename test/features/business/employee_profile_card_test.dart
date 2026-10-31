import 'package:demo_nfc/features/admin/cards/card_model.dart';
import 'package:demo_nfc/features/admin/employees/employee_model.dart';
import 'package:demo_nfc/features/business/employee_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'profile shows stored employee fields and reloads imported changes',
    (tester) async {
      var department = 'IT';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEmployeeProfileProvider.overrideWith(
              (ref) async => Employee(
                id: 'employee-1',
                code: 'NV01',
                fullName: 'Nhan vien mau',
                active: true,
                createdAt: DateTime(2026),
                department: department,
                email: 'employee@company.example',
                jobTitle: 'Lap trinh vien',
                phone: '0901234567',
                hireDate: DateTime(2023, 1, 15),
                hourlyRate: 60000,
              ),
            ),
            currentEmployeeCardsProvider.overrideWith(
              (ref) async => [
                CardModel(
                  uid: '0004AA01',
                  employeeId: 'employee-1',
                  active: true,
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: EmployeeProfileCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Phòng ban: IT'), findsOneWidget);
      expect(find.text('Chức vụ: Lap trinh vien'), findsOneWidget);
      expect(find.text('Số điện thoại: 0901234567'), findsOneWidget);
      expect(find.text('Ngày vào làm: 15/01/2023'), findsOneWidget);
      expect(find.text('UID thẻ NFC: 0004AA01'), findsOneWidget);
      department = 'Tai chinh';
      await tester.tap(find.byTooltip('Tải lại hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.text('Phòng ban: Tai chinh'), findsOneWidget);
      expect(find.text('Phòng ban: IT'), findsNothing);
    },
  );
}
