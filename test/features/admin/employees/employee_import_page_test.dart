import 'dart:typed_data';

import 'package:demo_nfc/core/api_client.dart';
import 'package:demo_nfc/features/admin/employees/employee_import_page.dart';
import 'package:demo_nfc/features/admin/employees/employee_import_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockImportRepository extends Mock implements EmployeeImportRepository {}

class MockImportFiles extends Mock implements EmployeeImportFiles {}

void main() {
  late MockImportRepository repository;
  late MockImportFiles files;
  final file = EmployeeImportFile(
    'phong_kinh_doanh.xlsx',
    Uint8List.fromList([1, 2, 3]),
  );
  final download = <String, dynamic>{
    'file_name': 'tai_khoan.xlsx',
    'content_base64': 'AQID',
  };
  Map<String, dynamic> preview({bool invalid = false}) => {
    'create_count': invalid ? 0 : 1,
    'skip_count': 0,
    'error_count': invalid ? 1 : 0,
    'can_import': !invalid,
    'rows': [
      {
        'sheet': 'Kinh doanh',
        'row_number': 4,
        'code': 'KD01',
        'full_name': 'Nguyễn Văn A',
        'email': invalid ? 'bad email' : 'a.nguyen@company.example',
        'department': 'Kinh doanh',
        'job_title': 'Trưởng phòng',
        'phone': '0901234567',
        'hire_date': '2023-01-15',
        'hourly_rate': 60000,
        'status': invalid ? 'error' : 'create',
        'errors': invalid ? ['Email không hợp lệ.'] : [],
        'warnings': [],
      },
    ],
  };
  setUpAll(() {
    registerFallbackValue(file);
    registerFallbackValue(<String, dynamic>{});
  });
  setUp(() {
    repository = MockImportRepository();
    files = MockImportFiles();
    when(() => repository.recent()).thenAnswer((_) async => []);
    when(() => repository.emailSettings())
        .thenAnswer((_) async => {'configured': false});
    when(() => repository.emailStatus(any()))
        .thenAnswer((_) async => {'configured': false, 'rows': []});
    when(() => files.pick()).thenAnswer((_) async => file);
    when(() => repository.preview(any(), any()))
        .thenAnswer((_) async => preview());
    when(() => files.save(any())).thenAnswer((_) async {});
  });
  Widget app() => ProviderScope(
    overrides: [
      employeeImportRepositoryProvider.overrideWithValue(repository),
      employeeImportFilesProvider.overrideWithValue(files),
    ],
    child: const MaterialApp(home: EmployeeImportPage()),
  );

  testWidgets('file preview precedes import and account download', (
    tester,
  ) async {
    when(() => repository.commit(any(), any(), any())).thenAnswer(
      (_) async => {
        'import_id': 'batch-1',
        'created_count': 1,
        'skipped_count': 0,
      },
    );
    when(() => repository.credentials('batch-1'))
        .thenAnswer((_) async => download);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn file Excel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Tạo mới: 1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Tạo mới: 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Xem trước danh sách'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('KD01'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    verifyNever(() => repository.commit(any(), any(), any()));
    final create = find.text('Tạo 1 nhân viên và tài khoản');
    await tester.scrollUntilVisible(
      create,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Đã tạo 1 nhân viên và tài khoản.'),
      findsOneWidget,
    );
    final save = find.text('Tải tài khoản nhân viên (.xlsx)');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    verify(() => repository.credentials('batch-1')).called(1);
    verify(() => files.save(download)).called(1);
  });

  testWidgets('card-only import is available without creating an account', (
    tester,
  ) async {
    final data = preview();
    data['create_count'] = 0;
    data['card_count'] = 1;
    final row = (data['rows'] as List).first as Map<String, dynamic>;
    row['status'] = 'link_card';
    row['uid_the'] = '0004AA01';
    when(() => repository.preview(any(), any())).thenAnswer((_) async => data);
    when(() => repository.commit(any(), any(), any())).thenAnswer(
      (_) async => {
        'import_id': 'card-batch',
        'created_count': 0,
        'skipped_count': 0,
        'cards_assigned_count': 1,
      },
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn file Excel'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Danh sách đã có trong hệ thống.'),
      findsNothing,
    );
    final confirm = find.text('Nhập 0 nhân viên và gán 1 thẻ');
    await tester.scrollUntilVisible(
      confirm,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    verify(() => repository.commit(any(), any(), any())).called(1);
    expect(find.textContaining('Đã gán 1 thẻ NFC.'), findsOneWidget);
    final downloadButton = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text('Tải tài khoản nhân viên (.xlsx)'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          )
          .first,
    );
    expect(downloadButton.onPressed, isNull);
  });

  testWidgets('profile correction can be confirmed without creating accounts', (
    tester,
  ) async {
    final data = preview();
    data['create_count'] = 0;
    data['update_count'] = 1;
    data['card_count'] = 1;
    final row = (data['rows'] as List).first as Map<String, dynamic>;
    row['status'] = 'update';
    row['department'] = 'IT';
    row['uid_the'] = '0004AA01';
    row['warnings'] = ['Cập nhật: Phòng ban. Giữ nguyên mật khẩu.'];
    when(() => repository.preview(any(), any())).thenAnswer((_) async => data);
    when(() => repository.commit(any(), any(), any())).thenAnswer(
      (_) async => {
        'import_id': 'update-batch',
        'created_count': 0,
        'skipped_count': 0,
        'updated_count': 1,
        'cards_assigned_count': 1,
      },
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn file Excel'));
    await tester.pumpAndSettle();
    final confirm = find.text('Cập nhật 1 hồ sơ, tạo 0 và gán 1 thẻ');
    await tester.scrollUntilVisible(
      confirm,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    verify(() => repository.commit(any(), any(), any())).called(1);
    expect(find.textContaining('Đã cập nhật 1 hồ sơ.'), findsOneWidget);
  });

  testWidgets('invalid rows block the whole import', (tester) async {
    when(() => repository.preview(any(), any()))
        .thenAnswer((_) async => preview(invalid: true));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn file Excel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Dòng lỗi: 1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Dòng lỗi: 1'), findsOneWidget);
    expect(find.textContaining('Chưa nhập dữ liệu.'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final create = find.text('Tạo 0 nhân viên và tài khoản');
    await tester.scrollUntilVisible(
      create,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find
          .ancestor(
            of: create,
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          )
          .first,
    );
    expect(button.onPressed, isNull);
    verifyNever(() => repository.commit(any(), any(), any()));
  });

  testWidgets('retry after a lost response keeps the same operation identity', (
    tester,
  ) async {
    final ids = <String>[];
    when(() => repository.commit(any(), any(), any())).thenAnswer((
      invocation,
    ) async {
      ids.add(invocation.positionalArguments[2] as String);
      if (ids.length == 1) throw const ApiException('Mất kết nối', status: 0);
      return {'import_id': ids.last, 'created_count': 1, 'skipped_count': 0};
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn file Excel'));
    await tester.pumpAndSettle();
    final create = find.text('Tạo 1 nhân viên và tài khoản');
    await tester.scrollUntilVisible(
      create,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(EmployeeImportPage)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      create,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(ids, hasLength(2));
    expect(ids[0], ids[1]);
    expect(
      find.textContaining('Đã tạo 1 nhân viên và tài khoản.'),
      findsOneWidget,
    );
  });

  testWidgets('cancel file selection leaves data untouched', (tester) async {
    when(() => files.pick()).thenAnswer((_) async => null);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn file Excel'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.preview(any(), any()));
    verifyNever(() => repository.commit(any(), any(), any()));
    expect(find.byType(PaginatedDataTable), findsNothing);
  });
}
