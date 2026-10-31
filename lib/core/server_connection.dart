import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const serverUrlPreferenceKey = 'attendance_server_url_v1';
final initialServerUrlProvider = Provider<String>(
  (ref) => AppConfig.apiBaseUrl,
);
final serverUrlProvider = NotifierProvider<ServerUrlController, String>(
  ServerUrlController.new,
);

String normalizeServerUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      (uri.scheme != 'https' &&
          !(uri.scheme == 'http' &&
              const [
                'localhost',
                '127.0.0.1',
                '10.0.2.2',
              ].contains(uri.host)))) {
    throw const FormatException(
      'Nhập URL gốc HTTPS của máy chủ, không thêm /api hoặc /health. '
      'HTTP chỉ dùng cho localhost, 127.0.0.1 hoặc 10.0.2.2.',
    );
  }
  return uri.replace(path: '').toString();
}

class ServerUrlController extends Notifier<String> {
  @override
  String build() => ref.watch(initialServerUrlProvider);

  Future<void> save(String value) async {
    final normalized = normalizeServerUrl(value);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(serverUrlPreferenceKey, normalized)) {
      throw StateError('Không lưu được địa chỉ máy chủ. Hãy thử lại.');
    }
    state = normalized;
  }
}
