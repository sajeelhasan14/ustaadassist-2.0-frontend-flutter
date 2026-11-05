/// Settings that change between computers, read from dart_defines.json when
/// the app starts: `flutter run --dart-define-from-file=dart_defines.json`.
/// Keeping them out of the code means nothing secret or local is committed.
abstract final class Config {
  /// The backend. On a real phone this must be the computer's network address,
  /// not localhost, because localhost on a phone means the phone itself.
  static const apiUrl = String.fromEnvironment('API_URL');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isComplete => apiUrl.isNotEmpty && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
