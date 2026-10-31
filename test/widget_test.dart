import 'package:demo_nfc/app.dart';
import 'package:demo_nfc/core/router.dart';
import 'package:demo_nfc/core/server_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final server in ['', 'https://demo.invalid']) {
    testWidgets('keeps lavender light theme with dark OS; server=$server', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const Scaffold())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialServerUrlProvider.overrideWithValue(server),
            routerProvider.overrideWithValue(router),
          ],
          child: const NfcAttendanceApp(),
        ),
      );
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(Scaffold).first));
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFE6E1F5));
    });
  }

  testWidgets('Offers server connection when API configuration is missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NfcAttendanceApp()));

    expect(find.text('Kết nối máy chủ'), findsOneWidget);
    expect(find.text('Địa chỉ máy chủ'), findsOneWidget);
  });
}
