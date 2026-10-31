import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/server_connection.dart';
import '../auth/auth_repository.dart';

class DeviceConfig {
  const DeviceConfig({required String? accountId, required String projectUrl})
    : this._(accountId, projectUrl, null);
  const DeviceConfig.live({
    required String projectUrl,
    required String? Function() accountIdResolver,
  }) : this._(null, projectUrl, accountIdResolver);
  const DeviceConfig._(
    this._accountId,
    this.projectUrl,
    this._accountIdResolver,
  );
  final String? _accountId;
  final String? Function()? _accountIdResolver;
  String? get accountId =>
      _accountIdResolver == null ? _accountId : _accountIdResolver();
  final String projectUrl;

  // Legacy IDs predate device ownership checks and must be registered again.
  String? get _deviceIdKey {
    final id = accountId;
    return id == null ? null : 'device_id_v2:$projectUrl:$id';
  }

  Future<String?> getDeviceId() async {
    final key = _deviceIdKey;
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    // Remove only the obsolete registration, never auth/session or scan data.
    await prefs.remove('device_id');
    return prefs.getString(key);
  }

  Future<void> saveDeviceId(String deviceId) async {
    final key = _deviceIdKey;
    if (key == null) {
      throw StateError('Vui lòng đăng nhập trước khi đăng ký máy.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, deviceId);
  }

  Future<void> clearDeviceId({String? expectedDeviceId}) async {
    final key = _deviceIdKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (expectedDeviceId != null && prefs.getString(key) != expectedDeviceId) {
      return;
    }
    await prefs.remove(key);
    await prefs.remove('device_id');
  }
}

final deviceConfigProvider = Provider<DeviceConfig>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return DeviceConfig.live(
    // Session restoration does not necessarily emit a login event. Resolve the
    // account at each operation instead of retaining a signed-out snapshot.
    accountIdResolver: () => auth.currentUser?.id,
    projectUrl: ref.watch(serverUrlProvider),
  );
});
