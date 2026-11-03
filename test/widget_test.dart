import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/live_employee_app.dart';

void main() {
  testWidgets('Employee login renders without starting a plugin session', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(onLogin: (email, password) async {}, error: null),
    ));
    await tester.pump();

    expect(find.text('BlueMarketing'), findsOneWidget);
    expect(find.text('Employee Workspace'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Secure sign in'), findsOneWidget);
  });

  testWidgets('Multiple projects require selection', (tester) async {
    int? chosen;
    await tester.pumpWidget(MaterialApp(
      home: ProjectSelectionScreen(
        profile: const {'projects': [
          {'id': 10, 'name': 'Project Alpha'},
          {'id': 20, 'name': 'Project Beta'},
        ]},
        onSelect: (id) async { chosen = id; },
        onLogout: () {},
      ),
    ));
    await tester.tap(find.text('Project Beta'));
    await tester.pump();
    expect(chosen, 20);
  });
}
