import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bluemarketing_employee/api_diagnostics_screen.dart';
import 'package:bluemarketing_employee/live_employee_app.dart';

void main() {
  testWidgets('Read-only API checks distinguish data and access restrictions',
      (tester) async {
    final called = <String>[];
    final api = ApiClient('https://dev.bluemarketing.com.pk',
      httpClient: MockClient((request) async {
        called.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/crm/leads')) {
          return http.Response(jsonEncode({
            'status': false, 'message': 'No permission',
          }), 403);
        }
        return http.Response(jsonEncode({
          'status': true, 'message': 'OK',
          'data': <dynamic>[],
          'meta': {'total': 4},
        }), 200);
      }));
    await tester.pumpWidget(MaterialApp(home: ApiDiagnosticsScreen(
      api: api, projectId: 3,
    )));
    await tester.tap(find.text('Run read-only checks'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connected · 4 total records'), findsWidgets);
    expect(find.textContaining('HTTP 403'), findsOneWidget);
    expect(called, isNotEmpty);
    expect(called.every((value) => value.startsWith('GET ')), isTrue);
    api.close();
  });

  testWidgets('Without a project, project-dependent calls are skipped',
      (tester) async {
    final called = <String>[];
    final api = ApiClient('https://dev.bluemarketing.com.pk',
      httpClient: MockClient((request) async {
        called.add(request.url.path);
        return http.Response(jsonEncode({
          'status': true, 'message': 'OK', 'data': <dynamic>[],
        }), 200);
      }));
    await tester.pumpWidget(MaterialApp(home: ApiDiagnosticsScreen(
      api: api, projectId: null,
    )));
    await tester.tap(find.text('Run read-only checks'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No selected project'), findsWidgets);
    expect(called.any((path) => path.endsWith('/crm/leads')), isFalse);
    expect(called.any((path) => path.endsWith('/stock/items')), isTrue);
    api.close();
  });
}
