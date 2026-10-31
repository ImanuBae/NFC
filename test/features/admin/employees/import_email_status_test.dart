import 'package:demo_nfc/features/admin/employees/employee_import_repository.dart';
import 'package:demo_nfc/features/admin/employees/import_email_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEmailImportRepository extends Mock
    implements EmployeeImportRepository {}

void main() {
  testWidgets(
    'Gmail connection check authenticates without requesting a message send',
    (tester) async {
      final repo = MockEmailImportRepository();
      when(() => repo.emailSettings())
          .thenAnswer((_) async => {'configured': true, 'provider': 'Smtp'});
      when(() => repo.verifyEmail()).thenAnswer(
        (_) async => {
          'status': 'connected',
          'message': 'Đăng nhập SMTP thành công.',
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [employeeImportRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: ImportEmailStatus())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra kết nối Gmail'));
      await tester.pumpAndSettle();
      verify(() => repo.verifyEmail()).called(1);
      expect(find.text('Đăng nhập SMTP thành công.'), findsOneWidget);
      verifyNever(() => repo.retryEmails(any()));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ambiguous SMTP result asks for review and offers no automatic resend',
    (tester) async {
      final repo = MockEmailImportRepository();
      when(() => repo.emailStatus('batch')).thenAnswer(
        (_) async => {
          'configured': true,
          'provider': 'Smtp',
          'rows': [
            {'recipient': 'employee@example.com', 'status': 'needs_review'},
          ],
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [employeeImportRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(body: ImportEmailStatus(importId: 'batch')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chi tiết từng email'));
      await tester.pumpAndSettle();
      expect(find.text('Cần kiểm tra thư mục Đã gửi'), findsOneWidget);
      expect(find.text('Thử gửi lại email lỗi'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pending mail without configuration is never presented as sent', (
    tester,
  ) async {
    final repo = MockEmailImportRepository();
    when(() => repo.emailStatus('batch')).thenAnswer(
      (_) async => {
        'configured': false,
        'rows': [
          {'recipient': 'an@example.com', 'status': 'pending'},
        ],
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [employeeImportRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: ImportEmailStatus(importId: 'batch')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('0/1 thư được dịch vụ tiếp nhận'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Chưa gửi email vì thiếu cấu hình'),
      findsOneWidget,
    );
    await tester.tap(find.text('Chi tiết từng email'));
    await tester.pumpAndSettle();
    expect(find.text('Chờ cấu hình email'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('retry targets failed mail and refreshes provider status', (
    tester,
  ) async {
    final repo = MockEmailImportRepository();
    var sent = false;
    when(() => repo.emailStatus('batch')).thenAnswer(
      (_) async => {
        'configured': true,
        'rows': [
          {'recipient': 'an@example.com', 'status': sent ? 'sent' : 'failed'},
        ],
      },
    );
    when(() => repo.retryEmails('batch')).thenAnswer((_) async {
      sent = true;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [employeeImportRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: ImportEmailStatus(importId: 'batch')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thử gửi lại email lỗi'));
    await tester.pumpAndSettle();
    verify(() => repo.retryEmails('batch')).called(1);
    expect(
      find.textContaining('1/1 thư được dịch vụ tiếp nhận'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
