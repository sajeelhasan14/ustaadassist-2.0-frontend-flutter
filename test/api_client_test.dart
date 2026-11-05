import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ustaad_assist/core/api/api_client.dart';

void main() {
  ApiClient clientFor(http.Response Function(http.Request request) handler, {String? token = 'abc'}) {
    return ApiClient(
      baseUrl: 'http://test/api/v1',
      token: () => token,
      client: MockClient((request) async => handler(request)),
    );
  }

  test('sends the login token and the JSON body', () async {
    late http.Request seen;
    final client = clientFor((request) {
      seen = request;
      return http.Response('{"ok":true}', 200);
    });

    final reply = await client.post('/things', {'name': 'x'});

    expect(reply, {'ok': true});
    expect(seen.url.toString(), 'http://test/api/v1/things');
    expect(seen.headers['authorization'], 'Bearer abc');
    expect(jsonDecode(seen.body), {'name': 'x'});
  });

  test('leaves the token out when nobody is logged in', () async {
    late http.Request seen;
    final client = clientFor((request) {
      seen = request;
      return http.Response('{}', 200);
    }, token: null);

    await client.get('/things');

    expect(seen.headers.containsKey('authorization'), isFalse);
  });

  test('an empty reply (204) is fine', () async {
    final client = clientFor((_) => http.Response('', 204));
    expect(await client.delete('/things/1'), isNull);
  });

  test('a field error shows the field message, not the general one', () async {
    final client = clientFor(
      (_) => http.Response(
        '{"error":{"code":"invalid_input","message":"Some fields are invalid.","fields":{"marks":["Must be more than 0."]}}}',
        400,
      ),
    );

    final error = await client.get('/things').then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

    expect(error!.status, 400);
    expect(error.code, 'invalid_input');
    expect(error.displayMessage, 'Must be more than 0.');
  });

  test('a crash page that is not JSON still gives a readable error', () async {
    final client = clientFor((_) => http.Response('<html>Internal Server Error</html>', 500));

    final error = await client.get('/things').then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

    expect(error!.status, 500);
    expect(error.displayMessage, 'Something went wrong. Please try again.');
  });

  test('no connection gives a readable error', () async {
    final client = ApiClient(
      baseUrl: 'http://test',
      token: () => null,
      client: MockClient((_) async => throw http.ClientException('no route')),
    );

    final error = await client.get('/things').then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

    expect(error!.code, 'offline');
  });
}
