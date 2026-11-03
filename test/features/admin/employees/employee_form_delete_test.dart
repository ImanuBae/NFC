import 'package:demo_nfc/features/admin/employees/employee_form_dialog.dart';
import 'package:demo_nfc/features/admin/employees/employee_model.dart';
import 'package:demo_nfc/features/admin/employees/employee_repository.dart';
import 'package:demo_nfc/features/admin/employees/employee_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

void main() {
  late MockEmployeeRepository repository;
  final employee = Employee(
    id: 'e1',
    code: 'NV04',
    fullName: 'Trần Nguyễn Đức Trung',
    active: true,
    createdAt: DateTime(2026),
  );
  setUp(() {
    repository = MockEmployeeRepository();
    when(() => repository.deleteEmployee(any())).thenAnswer((_) async {});
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('employee list exposes delete at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeRepositoryProvider.overrideWithValue(repository),
            employeeListProvider.overrideWith((ref) async => [employee]),
          ],
          child: const MaterialApp(home: EmployeeListPage()),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byTooltip('Xóa nhân viên');
      expect(button, findsOneWidget);
      expect(tester.getRect(button).right, lessThanOrEqualTo(width));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Xóa vĩnh viễn'), findsOneWidget);
      verifyNever(() => repository.deleteEmployee(any()));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('edit dialog confirms deletion and reports deleted result', (
    tester,
  ) async {
    EmployeeFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await EmployeeFormDialog.show(
                context,
                employee: employee,
                repository: repository,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa nhân viên'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trần Nguyễn Đức Trung (NV04)'), findsOneWidget);
    verifyNever(() => repository.deleteEmployee(any()));
    await tester.tap(find.text('Xóa vĩnh viễn'));
    await tester.pumpAndSettle();
    verify(() => repository.deleteEmployee('e1')).called(1);
    expect(result, EmployeeFormResult.deleted);
    expect(find.text('Sửa nhân viên'), findsNothing);
  });

  testWidgets('cancel confirmation preserves unsaved form fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeFormDialog(employee: employee, repository: repository),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Tên đang sửa');
    await tester.tap(find.text('Xóa nhân viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hủy').last);
    await tester.pumpAndSettle();
    verifyNever(() => repository.deleteEmployee(any()));
    expect(find.text('Tên đang sửa'), findsOneWidget);
    expect(find.text('Lưu'), findsOneWidget);
  });

  testWidgets('failed delete stays in edit dialog and allows retry', (
    tester,
  ) async {
    when(() => repository.deleteEmployee(any()))
        .thenThrow(Exception('Mất kết nối'));
    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeFormDialog(employee: employee, repository: repository),
      ),
    );
    await tester.tap(find.text('Xóa nhân viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa vĩnh viễn'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không xóa được nhân viên'), findsOneWidget);
    expect(find.text(employee.fullName), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Xóa nhân viên'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('creation dialog does not expose deletion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: EmployeeFormDialog(repository: repository)),
    );
    expect(find.text('Xóa nhân viên'), findsNothing);
  });
}
