import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/blue_marketing_app.dart';

void main() {
  test('general employee sees shared modules only', () {
    expect(modulesFor({}).map((m) => m.name), ['Attendance', 'Projects']);
  });

  test('CRM employee sees leads but not stock', () {
    final visible = modulesFor({'read lead'}).map((m) => m.name).toList();
    expect(visible, contains('CRM'));
    expect(visible, isNot(contains('Stock')));
  });

  test('permission for approvals controls its visibility', () {
    expect(modulesFor({'can approve'}).map((m) => m.name), contains('Approvals'));
    expect(modulesFor({}).map((m) => m.name), isNot(contains('Approvals')));
  });
}
