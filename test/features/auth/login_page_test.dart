import 'dart:async';

import 'package:demo_nfc/core/strings.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:demo_nfc/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:demo_nfc/core/api_client.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepo;
  late StreamController<AppUser?> authStateController;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    authStateController = StreamController<AppUser?>.broadcast();
    when(() => mockAuthRepo.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() {
    authStateController.close();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(mockAuthRepo)],
      child: const MaterialApp(home: LoginPage()),
    );
  }

  testWidgets('renders email, password fields and login button', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text(S.loginTitle), findsOneWidget);
    expect(find.text(S.email), findsOneWidget);
    expect(find.text(S.password), findsOneWidget);
    expect(find.text(S.login), findsOneWidget);
  });

  testWidgets('shows validation errors when fields are empty', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.text(S.login));
    await tester.pump();

    expect(find.text(S.emailEmpty), findsOneWidget);
    expect(find.text(S.passwordEmpty), findsOneWidget);
  });

  testWidgets(
    'shows Vietnamese error message on ApiException (wrong password)',
    (tester) async {
      when(
        () => mockAuthRepo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const ApiException('Invalid login credentials'));

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, S.email),
        'admin@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, S.password),
        'wrongpass',
      );
      await tester.tap(find.text(S.login));
      await tester.pump(); // Start async login
      await tester.pump(); // Finish catch block

      expect(find.textContaining(S.loginFailed), findsOneWidget);
    },
  );

  testWidgets('shows noRoleAssigned when user has no role in profiles', (
    tester,
  ) async {
    when(
      () => mockAuthRepo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockAuthRepo.getCurrentUserRole()).thenAnswer((_) async => null);
    when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(
      find.widgetWithText(TextFormField, S.email),
      'norole@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, S.password),
      'password123',
    );
    await tester.tap(find.text(S.login));
    await tester.pump();
    await tester.pump();

    expect(find.text(S.noRoleAssigned), findsOneWidget);
    verify(() => mockAuthRepo.signOut()).called(1);
  });
}
