/// Configuration loaded from environment variables (--dart-define)
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const kioskExitPin = String.fromEnvironment(
    'KIOSK_PIN',
    defaultValue: '1234',
  );
  static const fakeNfc = bool.fromEnvironment('FAKE_NFC', defaultValue: false);

  static bool get isApiConfigured =>
      Uri.tryParse(apiBaseUrl)?.hasAuthority == true;
}
