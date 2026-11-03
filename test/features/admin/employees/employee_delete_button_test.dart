import 'package:demo_nfc/features/admin/employees/employee_delete_button.dart';
import 'package:demo_nfc/features/admin/employees/employee_model.dart';
import 'package:demo_nfc/features/admin/employees/employee_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

void main() {
  final employee = Employee(
    id: 'employee-1',
    code: 'NV03',
    fullName: 'Trần Thiện Quân',
    active: true,
    createdAt: DateTime(2026),
  );
  late MockEmployeeRepository repository;
  late int deleted;
  Widget app() => ProviderScope(
    overrides: [employeeRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: Scaffold(
        body: EmployeeDeleteButton(
          employee: employee,
          onDeleted: () => deleted++,
        ),
      ),
    ),
  );
  setUp(() {
    repository = MockEmployeeRepository();
    deleted = 0;
    when(() => repository.deleteEmployee(any())).thenAnswer((_) async {});
  });

  testWidgets('cancel preserves employee, confirm deletes and refreshes', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip('Xóa nhân viên'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trần Thiện Quân (NV03)'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.deleteEmployee(any()));
    await tester.tap(find.byTooltip('Xóa nhân viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa vĩnh viễn'));
    await tester.pumpAndSettle();
    verify(() => repository.deleteEmployee('employee-1')).called(1);
    expect(deleted, 1);
  });

  testWidgets('failure shows error and leaves the row available', (
    tester,
  ) async {
    when(() => repository.deleteEmployee(any()))
        .thenThrow(Exception('Mất kết nối'));
    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip('Xóa nhân viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa vĩnh viễn'));
    await tester.pumpAndSettle();
    expect(deleted, 0);
    expect(find.textContaining('Không xóa được nhân viên'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
  });
}
