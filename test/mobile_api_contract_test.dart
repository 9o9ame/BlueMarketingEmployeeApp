import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bluemarketing_employee/live_employee_app.dart';

void main() {
  test('API uses versioned mobile path, headers and bearer token', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(),
        'https://dev.bluemarketing.com.pk/api/v1/mobile/crm/leads?project_id=7');
      expect(request.headers['Authorization'], 'Bearer example-token');
      expect(request.headers['Accept'], 'application/json');
      return http.Response(jsonEncode({
        'status': true,
        'data': <dynamic>[],
        'meta': {'total': 0},
      }), 200);
    });
    final api = ApiClient('https://dev.bluemarketing.com.pk/', httpClient: client)
      ..token = 'example-token';
    final result = await api.call('GET', 'crm/leads',
      query: {'project_id': '7'});
    expect(result['status'], isTrue);
    api.close();
  });

  test('API sends JSON login credentials without project ID', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/mobile/auth/login');
      expect(jsonDecode(request.body), {
        'email': 'test@example.com',
        'password': 'fixture-only',
      });
      return http.Response(jsonEncode({
        'status': true, 'data': {'token': 'sample-token'},
      }), 200);
    });
    final api = ApiClient('https://dev.bluemarketing.com.pk', httpClient: client);
    final result = await api.call('POST', 'auth/login',
      data: {'email': 'test@example.com', 'password': 'fixture-only'});
    expect(objectOf(result['data'])['token'], 'sample-token');
    api.close();
  });

  test('API refuses non-HTTPS hosts before sending', () async {
    final api = ApiClient('http://example.com',
      httpClient: MockClient((_) async => http.Response('{}', 200)));
    await expectLater(api.call('GET', 'auth/me'), throwsFormatException);
    api.close();
  });

  test('API surfaces server validation failures', () async {
    final api = ApiClient('https://dev.bluemarketing.com.pk',
      httpClient: MockClient((_) async => http.Response(jsonEncode({
        'status': false, 'message': 'Invalid item quantity',
      }), 422)));
    await expectLater(api.call('POST', 'stock/entries/out',
      data: {'project_id': 1}), throwsA(
        predicate((error) => error.toString().contains('Invalid item quantity'))));
    api.close();
  });
}
