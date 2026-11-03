import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/live_employee_app.dart';

void main() {
  testWidgets('Employee login loads when not authenticated', (tester) async {
    await tester.pumpWidget(const BlueMarketingLiveApp());
    await tester.pumpAndSettle();

    expect(find.text('BlueMarketing'), findsOneWidget);
    expect(find.text('Employee Workspace'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Secure sign in'), findsOneWidget);
  });
}
