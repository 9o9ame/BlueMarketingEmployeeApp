import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stock source is not accidentally duplicated', () {
    final file = File('lib/stock_entry_form.dart');
    expect(file.existsSync(), isTrue);
    final source = file.readAsStringSync();
    for (final declaration in [
      'class StockEntryFormValidation {',
      'class StockEntryForm extends StatefulWidget {',
      'class _StockEntryFormState extends State<StockEntryForm> {',
      'String stockDate(DateTime date) =>',
    ]) {
      expect(declaration.allMatches(source).length, 1,
          reason: 'Source contains a missing/duplicate declaration: $declaration');
    }
  });
}
