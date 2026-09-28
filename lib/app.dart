import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/strings.dart';
import 'core/theme.dart';

class NfcAttendanceApp extends ConsumerWidget {
  const NfcAttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConfig.isSupabaseConfigured) {
      return MaterialApp(
        title: S.appTitle,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Scaffold(
          appBar: AppBar(title: const Text(S.configErrorTitle)),
          body: const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 16),
                  Text(
                    S.configErrorTitle,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(S.configErrorMsg, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: S.appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
