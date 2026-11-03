import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/crm_screens.dart';

void main() {
  test('CRM displays full lead name', () {
    expect(displayLeadName({'first_name': 'Ali', 'last_name': 'Khan'}),
        'Ali Khan');
  });

  test('CRM mobile validation matches Laravel 11-digit rule', () {
    expect(validateMobile(''), isNull);
    expect(validateMobile('03001234567'), isNull);
    expect(validateMobile('0300123456'), isNotNull);
    expect(validateMobile('0300123456x'), isNotNull);
  });

  test('CRM date formatting matches API required date', () {
    expect(isoDate(DateTime(2026, 11, 3)), '2026-11-03');
    expect(isoDate(DateTime(2026, 1, 9)), '2026-01-09');
  });
}
