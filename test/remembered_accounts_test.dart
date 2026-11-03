import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/remembered_accounts.dart';

void main() {
  test('recent accounts are deduplicated and latest account is first', () {
    expect(RememberedAccounts.recentFirst(
      ['old@example.com', 'new@example.com', 'old@example.com'],
      ' NEW@EXAMPLE.COM '),
      ['new@example.com', 'old@example.com']);
  });

  test('saved accounts have a strict maximum history size', () {
    final old = List.generate(15, (index) => 'user$index@example.com');
    final result = RememberedAccounts.recentFirst(old, 'latest@example.com');
    expect(result.length, 10);
    expect(result.first, 'latest@example.com');
    expect(result.last, 'user8@example.com');
  });

  test('credential keys use normalized encoded email rather than plain text', () {
    final first = RememberedAccounts.credentialKey('User@Example.com');
    final second = RememberedAccounts.credentialKey(' user@example.com ');
    expect(first, second);
    expect(first, isNot(contains('@')));
    expect(first, startsWith(RememberedAccounts.credentialPrefix));
  });
}
