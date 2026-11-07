import '../../../core/api/api_client.dart';

abstract final class ProfileApi {
  /// The percentage below which a student is short of attendance.
  static Future<num> attendanceLine() async => (await api.get('/me'))['teacher']['minAttendance'] as num? ?? 75;

  static Future<void> setAttendanceLine(num value) => api.patch('/me', {'minAttendance': value});
}
