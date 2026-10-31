import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/server_connection.dart';
import 'core/config.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);

  final prefs = await SharedPreferences.getInstance();
  final serverUrl =
      prefs.getString(serverUrlPreferenceKey) ?? AppConfig.apiBaseUrl;
  runApp(
    ProviderScope(
      overrides: [initialServerUrlProvider.overrideWithValue(serverUrl)],
      child: const NfcAttendanceApp(),
    ),
  );
}
