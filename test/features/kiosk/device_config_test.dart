import 'package:demo_nfc/features/kiosk/device_config.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthForDevice extends Mock implements AuthRepository {}

void main() {
  const alice = DeviceConfig(accountId: 'alice', projectUrl: 'project-a');
  const bob = DeviceConfig(accountId: 'bob', projectUrl: 'project-a');
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'legacy registration requires setup after ownership migration',
    () async {
      SharedPreferences.setMockInitialValues({
        'device_id': 'legacy-id',
        'auth-session': 'keep-session',
      });
      expect(await alice.getDeviceId(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('device_id'), isFalse);
      expect(prefs.getString('auth-session'), 'keep-session');
    },
  );
  test('accounts do not reuse each others registration', () async {
    await alice.saveDeviceId('device-alice');
    expect(await bob.getDeviceId(), isNull);
    await bob.saveDeviceId('device-bob');
    expect(await alice.getDeviceId(), 'device-alice');
    await alice.clearDeviceId();
    expect(await bob.getDeviceId(), 'device-bob');
  });
  test('changing backend requires a new registration', () async {
    await alice.saveDeviceId('device-alice');
    const other = DeviceConfig(accountId: 'alice', projectUrl: 'project-b');
    expect(await other.getDeviceId(), isNull);
  });
  test('late rejection cannot delete a newer registration', () async {
    await alice.saveDeviceId('new-device');
    await alice.clearDeviceId(expectedDeviceId: 'old-device');
    expect(await alice.getDeviceId(), 'new-device');
    await alice.clearDeviceId(expectedDeviceId: 'new-device');
    expect(await alice.getDeviceId(), isNull);
  });
  test('signed out sessions cannot register a device', () async {
    const signedOut = DeviceConfig(accountId: null, projectUrl: 'project-a');
    expect(await signedOut.getDeviceId(), isNull);
    await expectLater(signedOut.saveDeviceId('device'), throwsStateError);
  });

  test('device config created before session restore uses restored account without an auth event', () async {
    AppUser? current;
    final auth = MockAuthForDevice();
    when(() => auth.currentUser).thenAnswer((_) => current);
    when(() => auth.authStateChanges).thenAnswer((_) => const Stream.empty());
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    final config = container.read(deviceConfigProvider);
    expect(await config.getDeviceId(), isNull);
    current = const AppUser(
      id: 'restored-kiosk',
      email: 'kiosk@test.local',
      role: 'kiosk',
    );
    await config.saveDeviceId('registered-device');
    expect(await config.getDeviceId(), 'registered-device');
  });

  test('retained device config follows account switch and blocks registration after logout', () async {
    AppUser? current = const AppUser(
      id: 'kiosk-a',
      email: 'a@test.local',
      role: 'kiosk',
    );
    final auth = MockAuthForDevice();
    when(() => auth.currentUser).thenAnswer((_) => current);
    when(() => auth.authStateChanges).thenAnswer((_) => const Stream.empty());
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    final config = container.read(deviceConfigProvider);
    await config.saveDeviceId('device-a');
    current = const AppUser(
      id: 'kiosk-b',
      email: 'b@test.local',
      role: 'kiosk',
    );
    expect(await config.getDeviceId(), isNull);
    await config.saveDeviceId('device-b');
    current = null;
    await expectLater(config.saveDeviceId('invalid'), throwsStateError);
    current = const AppUser(
      id: 'kiosk-a',
      email: 'a@test.local',
      role: 'kiosk',
    );
    expect(await config.getDeviceId(), 'device-a');
  });
}
