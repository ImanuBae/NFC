import 'package:demo_nfc/core/theme.dart';
import 'package:demo_nfc/features/admin/admin_shell.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final role in ['admin', 'manager']) {
    for (final dark in [false, true]) {
      testWidgets('$role mobile destinations stay selected; dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final paths = [
          '/admin/days',
          if (role == 'admin') '/admin/employees',
          '/admin/events',
          '/admin/reports',
          if (role == 'admin') '/admin/accounts',
        ];
        final router = GoRouter(
          initialLocation: paths.first,
          routes: [
            ShellRoute(
              builder: (_, _, child) => AdminShell(child: child),
              routes: [
                for (final path in paths)
                  GoRoute(
                    path: path,
                    builder: (_, _) => Center(child: Text('Page: $path')),
                  ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [currentRoleProvider.overrideWith((ref) async => role)],
            child: MaterialApp.router(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.3)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NavigationDestination), findsNWidgets(paths.length));
        for (var i = 0; i < paths.length; i++) {
          await tester.tap(find.byType(NavigationDestination).at(i));
          await tester.pumpAndSettle();
          expect(find.text('Page: ${paths[i]}'), findsOneWidget);
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            i,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
