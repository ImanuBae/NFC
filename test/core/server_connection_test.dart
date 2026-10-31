import 'package:demo_nfc/core/api_client.dart';
import 'package:demo_nfc/core/server_connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('accepts HTTPS tunnel roots and local development URLs', () {
    expect(
      normalizeServerUrl(' https://demo.devtunnels.ms/ '),
      'https://demo.devtunnels.ms',
    );
    expect(normalizeServerUrl('http://10.0.2.2:5080'), 'http://10.0.2.2:5080');
    expect(
      normalizeServerUrl('http://127.0.0.1:5080'),
      'http://127.0.0.1:5080',
    );
  });

  test('rejects insecure remote URLs, credentials and API paths', () {
    for (final value in [
      'demo.devtunnels.ms',
      'http://demo.devtunnels.ms',
      'https://demo.devtunnels.ms/api',
      'https://demo.devtunnels.ms/health',
      'https://user:secret@demo.devtunnels.ms',
      'https://demo.devtunnels.ms?token=secret',
      'https://demo.devtunnels.ms#x',
    ]) {
      expect(
        () => normalizeServerUrl(value),
        throwsFormatException,
        reason: value,
      );
    }
  });

  test(
    'saves server and replaces API client without carrying signed-in user',
    () async {
      final container = ProviderContainer(
        overrides: [
          initialServerUrlProvider.overrideWithValue('http://127.0.0.1:5080'),
        ],
      );
      addTearDown(container.dispose);
      final previous = container.read(apiClientProvider);
      previous.currentUser = const AppUser(
        id: 'a',
        email: 'a@test.local',
        role: 'kiosk',
      );
      await container
          .read(serverUrlProvider.notifier)
          .save('https://demo.devtunnels.ms/');
      final current = container.read(apiClientProvider);
      expect(current.baseUrl, 'https://demo.devtunnels.ms');
      expect(current.currentUser, isNull);
      expect(current, isNot(same(previous)));
      expect(
        (await SharedPreferences.getInstance()).getString(
          serverUrlPreferenceKey,
        ),
        'https://demo.devtunnels.ms',
      );
    },
  );
}
