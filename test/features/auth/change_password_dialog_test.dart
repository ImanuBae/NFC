import 'package:demo_nfc/core/api_client.dart';
import 'package:demo_nfc/features/auth/change_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPasswordApi extends Mock implements ApiClient {}

void main() {
  late MockPasswordApi api;
  setUp(() {
    api = MockPasswordApi();
  });
  Widget app() => ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => const ChangePasswordDialog(),
            ),
            child: const Text('Mở đổi mật khẩu'),
          ),
        ),
      ),
    ),
  );

  Future<void> fill(
    WidgetTester tester,
    String password,
    String confirmation,
  ) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '12345678');
    await tester.enterText(fields.at(1), password);
    await tester.enterText(fields.at(2), confirmation);
    await tester.tap(find.text('Lưu mật khẩu mới'));
    await tester.pumpAndSettle();
  }

  testWidgets('reject default password and mismatched confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Mở đổi mật khẩu'));
    await tester.pumpAndSettle();
    await fill(tester, '12345678', '12345678');
    expect(
      find.text('Chọn mật khẩu khác mật khẩu hiện tại và mặc định.'),
      findsOneWidget,
    );
    await fill(tester, 'new-password-1', 'different-password');
    expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
    verifyNever(() => api.request(any(), any(), body: any(named: 'body')));
  });

  testWidgets('save current and new password and refresh account reminder', (
    tester,
  ) async {
    when(
      () => api.request(
        'POST',
        '/auth/change-password',
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => {'status': 'ok'});
    when(() => api.me()).thenAnswer(
      (_) async =>
          const AppUser(id: 'e', email: 'e@example.com', role: 'employee'),
    );
    await tester.pumpWidget(app());
    await tester.tap(find.text('Mở đổi mật khẩu'));
    await tester.pumpAndSettle();
    await fill(tester, 'new-password-1', 'new-password-1');
    verify(
      () => api.request(
        'POST',
        '/auth/change-password',
        body: {
          'current_password': '12345678',
          'new_password': 'new-password-1',
        },
      ),
    ).called(1);
    verify(() => api.me()).called(1);
    expect(find.byType(ChangePasswordDialog), findsNothing);
  });

  testWidgets(
    'wrong current password stays in dialog with server explanation',
    (tester) async {
      when(
        () => api.request(
          'POST',
          '/auth/change-password',
          body: any(named: 'body'),
        ),
      ).thenThrow(const ApiException('Mật khẩu hiện tại không đúng.'));
      await tester.pumpWidget(app());
      await tester.tap(find.text('Mở đổi mật khẩu'));
      await tester.pumpAndSettle();
      await fill(tester, 'new-password-1', 'new-password-1');
      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      expect(find.byType(ChangePasswordDialog), findsOneWidget);
      verifyNever(() => api.me());
    },
  );
}
