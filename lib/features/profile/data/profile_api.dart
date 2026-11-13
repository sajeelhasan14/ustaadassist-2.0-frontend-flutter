import '../../../core/api/api_client.dart';

/// Who is signed in, for the Me screen.
class Profile {
  Profile.fromJson(Map<String, dynamic> json)
      : fullName = json['fullName'] as String,
        email = json['email'] as String? ?? '';

  final String fullName;
  final String email;
}

abstract final class ProfileApi {
  static Future<Profile> me() async => Profile.fromJson((await api.get('/me'))['teacher'] as Map<String, dynamic>);
}
