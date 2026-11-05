import '../../../core/api/api_client.dart';

class CourseFile {
  CourseFile.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        topicId = json['topicId'] as String?,
        mimeType = json['mimeType'] as String,
        sizeBytes = json['sizeBytes'] as num;

  final String id;
  final String name;
  final String? topicId;
  final String mimeType;
  final num sizeBytes;

  /// "340 KB" or "2.4 MB".
  String get size => sizeBytes < 1024 * 1024 ? '${(sizeBytes / 1024).ceil()} KB' : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

abstract final class MaterialsApi {
  static Future<List<CourseFile>> list(String courseId) async {
    final reply = await api.get('/courses/$courseId/materials');
    return [for (final item in reply['materials'] as List) CourseFile.fromJson(item as Map<String, dynamic>)];
  }

  static Future<void> upload(String courseId, UploadFile file) => api.upload('/courses/$courseId/materials', [file]);

  /// A private link to the file that stops working after 10 minutes.
  static Future<String> link(String id) async => (await api.get('/materials/$id'))['url'] as String;

  static Future<void> rename(String id, String name) => api.patch('/materials/$id', {'name': name});
  static Future<void> setTopic(String id, String? topicId) => api.patch('/materials/$id', {'topicId': topicId});
  static Future<void> remove(String id) => api.delete('/materials/$id');
}
