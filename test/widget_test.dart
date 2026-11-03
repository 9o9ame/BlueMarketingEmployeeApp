import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/blue_marketing_app.dart';

void main() {
  testWidgets('BlueMarketing login preview loads', (tester) async {
    await tester.pumpWidget(const BlueMarketingApp());

    expect(find.text('BlueMarketing'), findsOneWidget);
    expect(find.text('Employee Workspace'), findsOneWidget);
    expect(find.text('Preview dashboard'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('Dashboard preview opens', (tester) async {
    await tester.pumpWidget(const BlueMarketingApp());

    await tester.tap(find.text('Preview dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Employee Dashboard'), findsOneWidget);
    expect(find.text('Available modules'), findsOneWidget);
  });
}
