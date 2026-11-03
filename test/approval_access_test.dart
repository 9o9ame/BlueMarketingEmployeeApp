import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/approval_screens.dart';

void main() {
  test('admin can read but cannot perform approval action by role alone', () {
    expect(mayReadApprovals({}, {'admin'}), isTrue);
    expect(mayActOnApproval({}, {'admin'}), isFalse);
  });

  test('direct-update permission allows decisions', () {
    expect(mayReadApprovals({'direct-update'}, {}), isTrue);
    expect(mayActOnApproval({'direct-update'}, {}), isTrue);
  });

  test('superadmin approval action allowed', () {
    expect(mayActOnApproval({}, {'superadmin'}), isTrue);
    expect(mayActOnApproval({}, {'super-admin'}), isTrue);
  });

  test('ordinary user cannot see approvals', () {
    expect(mayReadApprovals({'read lead'}, {}), isFalse);
    expect(mayActOnApproval({'read lead'}, {}), isFalse);
  });
}
