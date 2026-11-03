import 'package:demo_nfc/features/business/business_repository.dart';
import 'package:demo_nfc/features/business/payroll_export_button.dart';
import 'package:demo_nfc/features/business/reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessRepository extends Mock implements BusinessRepository {}

class MockPayrollFiles extends Mock implements PayrollExportFiles {}

void main() {
  late MockBusinessRepository repository;
  late MockPayrollFiles files;
  final file = <String, dynamic>{
    'file_name': 'bang_luong.xlsx',
    'content_base64': 'AQID',
  };
  setUp(() {
    repository = MockBusinessRepository();
    files = MockPayrollFiles();
    when(() => repository.report(any(), any())).thenAnswer((_) async => []);
    when(() => repository.exportPayroll(any())).thenAnswer((_) async => file);
    when(() => files.save(any())).thenAnswer((_) async => true);
  });
  Widget app(Widget child) => ProviderScope(
    overrides: [
      businessRepositoryProvider.overrideWithValue(repository),
      payrollExportFilesProvider.overrideWithValue(files),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  testWidgets('selected closed period exposes Excel instead of closing again', (
    tester,
  ) async {
    final now = DateTime.now();
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-01';
    when(() => repository.payrollRuns()).thenAnswer(
      (_) async => [
        {
          'id': 'run-1',
          'start_date': date(DateTime(now.year, now.month)),
          'end_date': date(DateTime(now.year, now.month + 1)),
          'period': 'month',
        },
      ],
    );
    await tester.pumpWidget(app(const ReportsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Đã chốt'), findsOneWidget);
    expect(find.text('Chốt lương'), findsNothing);
    await tester.tap(find.text('Xuất Excel'));
    await tester.pumpAndSettle();
    verify(() => repository.exportPayroll('run-1')).called(1);
    verify(() => files.save(file)).called(1);
  });

  testWidgets('history lets admin export an earlier closed period', (
    tester,
  ) async {
    when(() => repository.payrollRuns()).thenAnswer(
      (_) async => [
        {
          'id': 'october',
          'start_date': '2026-10-01',
          'end_date': '2026-11-01',
          'period': 'month',
        },
      ],
    );
    await tester.pumpWidget(app(const ReportsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lương đã chốt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Xuất Excel kỳ lương đã chốt'));
    await tester.pumpAndSettle();
    verify(() => repository.exportPayroll('october')).called(1);
    verify(() => files.save(file)).called(1);
  });

  testWidgets('export error remains visible and permits retry', (tester) async {
    when(() => repository.exportPayroll(any()))
        .thenThrow(Exception('Mất kết nối'));
    await tester.pumpWidget(app(const PayrollExportButton(runId: 'run-1')));
    await tester.tap(find.text('Xuất Excel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không xuất được bảng lương'), findsOneWidget);
    verifyNever(() => files.save(any()));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('cancelled save does not announce successful export', (
    tester,
  ) async {
    when(() => files.save(any())).thenAnswer((_) async => false);
    await tester.pumpWidget(app(const PayrollExportButton(runId: 'run-1')));
    await tester.tap(find.text('Xuất Excel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã xuất'), findsNothing);
  });
}
