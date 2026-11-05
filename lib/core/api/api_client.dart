import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// What went wrong with a request, in words a teacher can read.
/// `fields` holds messages for single form fields, e.g. {"marks": ["Must be more than 0."]}.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.fields = const {}]);

  final int status; // 0 = the request never reached the server
  final String code;
  final String message;
  final Map<String, List<String>> fields;

  /// For a form error, the first field message, because it says more than "Some fields are invalid."
  /// Other errors keep their own message: their fields are data such as student ids, not sentences.
  String get displayMessage => (code == 'invalid_input' ? fields.values.expand((list) => list).firstOrNull : null) ?? message;

  @override
  String toString() => displayMessage;
}

/// A file on its way to the backend. [field] is the name the route reads it under.
class UploadFile {
  UploadFile({required this.field, required this.name, required this.bytes});

  final String field;
  final String name;
  final Uint8List bytes;

  /// The backend refuses some types, so each file must say honestly what it is.
  /// A phone's picker doesn't always know, so it's worked out from the name.
  MediaType get type => MediaType.parse(_types[name.split('.').last.toLowerCase()] ?? 'application/octet-stream');

  static const _types = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
  };
}

/// The one place that talks to the backend. It adds the login token to every
/// request and turns every failure into an [ApiException], so screens don't
/// repeat any of that.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, String? Function()? token})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Config.apiUrl,
        _token = token ?? (() => Supabase.instance.client.auth.currentSession?.accessToken);

  final http.Client _client;
  final String _baseUrl;
  final String? Function() _token;

  /// Long enough for a normal request. AI requests pass their own, longer limit.
  static const defaultTimeout = Duration(seconds: 30);

  /// AI requests try up to three models in turn, so a slow answer is normal.
  static const aiTimeout = Duration(seconds: 200);

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body, Duration? timeout]) => _send('POST', path, body, timeout);
  Future<dynamic> put(String path, Object? body) => _send('PUT', path, body);
  Future<dynamic> patch(String path, Object? body) => _send('PATCH', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Sends files, with any plain text [fields] beside them.
  Future<dynamic> upload(String path, List<UploadFile> files, {Map<String, String> fields = const {}, Duration? timeout}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'))..fields.addAll(fields);
    for (final file in files) {
      request.files.add(http.MultipartFile.fromBytes(file.field, file.bytes, filename: file.name, contentType: file.type));
    }
    return _read(await _run(request, timeout ?? const Duration(seconds: 90)));
  }

  /// Fetches a file (a PDF or Excel sheet) instead of JSON. Errors still arrive as JSON.
  Future<Uint8List> download(String path) async {
    final response = await _run(http.Request('GET', Uri.parse('$_baseUrl$path')), const Duration(seconds: 60));
    if (response.statusCode >= 200 && response.statusCode < 300) return response.bodyBytes;
    throw _errorFrom(response.statusCode, _decode(response.body));
  }

  Future<dynamic> _send(String method, String path, [Object? body, Duration? timeout]) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _read(await _run(request, timeout ?? defaultTimeout));
  }

  /// Every kind of request goes through here, so all of them carry the login
  /// token and all of them fail in the same readable way.
  Future<http.Response> _run(http.BaseRequest request, Duration timeout) async {
    final token = _token();
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    try {
      final streamed = await _client.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(0, 'timeout', 'This is taking too long. Please try again.');
    } on http.ClientException {
      throw ApiException(0, 'offline', "Can't reach the server. Check your connection and try again.");
    }
  }

  dynamic _read(http.Response response) {
    final decoded = response.body.isEmpty ? null : _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw _errorFrom(response.statusCode, decoded);
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null; // A crash page rather than JSON. Handled as an unknown error.
    }
  }

  ApiException _errorFrom(int status, dynamic decoded) {
    final error = decoded is Map ? decoded['error'] : null;
    if (error is! Map) return ApiException(status, 'unknown', 'Something went wrong. Please try again.');
    final fields = <String, List<String>>{};
    if (error['fields'] case final Map raw) {
      raw.forEach((key, value) {
        // Only lists of sentences. The import's `problems` are objects, and printing one means nothing to a teacher.
        if (value is List && value.every((item) => item is String)) fields['$key'] = value.cast<String>();
      });
    }
    return ApiException(status, '${error['code']}', '${error['message']}', fields);
  }
}

/// The app's one client, used by every feature's data code.
/// Not final so tests can swap it for a fake backend.
ApiClient api = ApiClient();
