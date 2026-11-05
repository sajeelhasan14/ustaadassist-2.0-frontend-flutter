import 'package:supabase_flutter/supabase_flutter.dart';

/// Login goes straight to Supabase: the one thing the app doesn't send through
/// the backend, so a password never passes through our server.
abstract final class AuthService {
  static GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Fires whenever someone logs in or out. The app shell listens to this.
  static Stream<AuthState> get changes => _auth.onAuthStateChange;

  static bool get isLoggedIn => _auth.currentSession != null;

  /// Returns null if it worked, otherwise a message to show.
  static Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return "Can't reach the server. Check your connection and try again.";
    }
  }

  /// The database creates the teacher's row from `full_name` when the account appears.
  /// Returns true if the teacher is logged in, false if they must confirm their email first.
  static Future<bool> signUp(String fullName, String email, String password) async {
    final response = await _auth.signUp(email: email, password: password, data: {'full_name': fullName});
    return response.session != null;
  }

  static Future<void> signOut() => _auth.signOut();
}
