/// Configuration loaded from environment variables (--dart-define)
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const kioskExitPin = String.fromEnvironment(
    'KIOSK_PIN',
    defaultValue: '1234',
  );
  static const fakeNfc = bool.fromEnvironment('FAKE_NFC', defaultValue: false);

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
