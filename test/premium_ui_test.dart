import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bluemarketing_employee/live_employee_app.dart';
import 'package:bluemarketing_employee/premium_design.dart';

void main() {
  testWidgets('Premium login shows biometric retry but no social login',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(home: LoginScreen(
      error: 'Unlock cancelled',
      rememberedEmail: 'staff@example.com',
      onLogin: (_, _) async {},
      showFingerprint: true,
      onFingerprint: () => attempts++,
    )));
    expect(find.text('BlueMarketing'), findsOneWidget);
    expect(find.text('Employee Workspace'), findsOneWidget);
    expect(find.text('Secure sign in'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Google'), findsNothing);
    expect(find.text('Microsoft'), findsNothing);
    final retry = find.text('Sign in with fingerprint / face');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(attempts, 1);
    expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller?.text, 'staff@example.com');
  });

  testWidgets('Fingerprint button hidden without a reusable session',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(
      onLogin: (_, _) async {}, error: null,
    )));
    expect(find.text('Sign in with fingerprint / face'), findsNothing);
  });

  testWidgets('Multi-project chooser searches real assigned projects',
      (tester) async {
    int? chosen;
    await tester.pumpWidget(MaterialApp(home: ProjectSelectionScreen(
      profile: const {'projects': [
        {'id': 1, 'name': 'Alpha Site'},
        {'id': 2, 'name': 'Beta Estate'},
      ]},
      onSelect: (id) async { chosen = id; },
      onLogout: () {},
    )));
    await tester.enterText(find.byType(TextField).first, 'Beta');
    await tester.pumpAndSettle();
    expect(find.text('Beta Estate'), findsOneWidget);
    expect(find.text('Alpha Site'), findsNothing);
    await tester.tap(find.text('Beta Estate'));
    expect(chosen, 2);
  });

  testWidgets('Animated drawer opens and includes permission modules',
      (tester) async {
    final api = ApiClient('https://dev.bluemarketing.com.pk',
      httpClient: MockClient((request) async {
        final payload = request.url.path.endsWith('/dashboard')
          ? {'crm': {'total_leads': 11, 'today_followups': 2}}
          : {'status': 'present', 'check_in_time': '09:00'};
        return http.Response(jsonEncode({'status': true, 'data': payload}), 200);
      }));
    await tester.pumpWidget(MaterialApp(home: BmDashboard(
      api: api,
      profile: const {
        'user': {'name': 'Test Employee'},
        'role_names': ['Employee'],
        'projects': [{'id': 3, 'name': 'Blue Plaza'}],
      },
      projectId: 3,
      modules: const [
        ModuleLink('CRM Leads', 'crm/leads',
          Icons.people_alt_outlined, {'read lead'}),
      ],
      biometricsEnabled: false,
      onBiometricsChanged: (_) async {},
      onModule: (_) {},
      onAttendance: () {},
      onProject: (_) {},
      onLogout: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Performance snapshot'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();
    api.close();
  });

  testWidgets('Biometric setting changes only on user interaction',
      (tester) async {
    bool? selected;
    await tester.pumpWidget(MaterialApp(home: BmSettings(
      enabled: true,
      onChanged: (value) async { selected = value; },
    )));
    expect(selected, isNull);
    final toggle = find.byType(SwitchListTile);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(selected, false);
  });

  test('Do not silently delete biometric preference during logout', () {
    final source = File('lib/live_employee_app.dart').readAsStringSync();
    expect(source.contains('tokenStorage.delete(key: biometricFlagKey)'), isFalse);
    expect(source.contains('tokenStorage.delete(key: tokenKey)'), isTrue);
  });
}
