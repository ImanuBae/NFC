import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/server_connection.dart';
import 'features/auth/server_connection_page.dart';
import 'core/router.dart';
import 'core/strings.dart';
import 'core/theme.dart';

class NfcAttendanceApp extends ConsumerWidget {
  const NfcAttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Uri.tryParse(ref.watch(serverUrlProvider))?.hasAuthority != true) {
      return MaterialApp(
        title: S.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        darkTheme: AppTheme.darkTheme,
        home: const ServerConnectionPage(),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: S.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
