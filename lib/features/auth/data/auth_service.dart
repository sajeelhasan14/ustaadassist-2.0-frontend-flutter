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

  /// Forgot password, step 1: Supabase emails a 6-digit code. We use the code, not the
  /// email's link, because a link would need the phone to open the app from a web
  /// address (deep links). Returns null if it worked, otherwise a message to show.
  static Future<String?> sendResetCode(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return "Can't reach the server. Check your connection and try again.";
    }
  }

  /// Forgot password, step 2: the code proves it's their email, which also signs them in;
  /// then the new password is saved. Returns null if it worked, otherwise a message.
  static Future<String?> resetPassword(String email, String code, String newPassword) async {
    try {
      await _auth.verifyOTP(type: OtpType.recovery, email: email, token: code);
      await _auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return "Can't reach the server. Check your connection and try again.";
    }
  }
}
