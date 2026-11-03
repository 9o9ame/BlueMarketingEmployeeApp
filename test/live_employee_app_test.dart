import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/live_employee_app.dart';

void main() {
  test('safe payload conversion', () {
    expect(objectOf(null), isEmpty);
    expect(objectOf({'a': 1})['a'], 1);
    expect(listOf(null), isEmpty);
    expect(numberOf('42'), 42);
  });

  test('non-admin only sees explicitly permitted modules', () {
    expect(allowedModules({}), isEmpty);
    final links = allowedModules({'read lead'}).map((e) => e.title).toList();
    expect(links, contains('CRM Leads'));
    expect(links, isNot(contains('Stock Items')));
  });

  test('superadmin can navigate all modules', () {
    expect(allowedModules({}, superadmin: true).length, modules.length);
  });

  test('approval visibility requires a server permission', () {
    expect(allowedModules({'direct-update'}).any((m) => m.title == 'Approvals'), isTrue);
    expect(allowedModules({'read lead'}).any((m) => m.title == 'Approvals'), isFalse);
  });
}
