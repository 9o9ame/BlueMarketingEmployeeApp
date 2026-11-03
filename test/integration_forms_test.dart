import 'package:flutter_test/flutter_test.dart';
import 'package:bluemarketing_employee/stock_entry_form.dart';
import 'package:bluemarketing_employee/project_reports.dart';
import 'package:bluemarketing_employee/labour_bulk.dart';

void main() {
  test('stock quantity matches backend three-decimal rule', () {
    expect(StockEntryFormValidation.checkQuantity('1'), isNull);
    expect(StockEntryFormValidation.checkQuantity('0.001'), isNull);
    expect(StockEntryFormValidation.checkQuantity('1.2345'), isNotNull);
    expect(StockEntryFormValidation.checkQuantity('0'), isNotNull);
    expect(StockEntryFormValidation.checkQuantity('-1'), isNotNull);
  });

  test('stock rate cannot be negative or nonnumeric', () {
    expect(StockEntryFormValidation.checkRate('0'), isNull);
    expect(StockEntryFormValidation.checkRate('75.5'), isNull);
    expect(StockEntryFormValidation.checkRate('-1'), isNotNull);
    expect(StockEntryFormValidation.checkRate('bad'), isNotNull);
  });

  test('PKR rates convert to backend paisa without floating-point rounding', () {
    expect(StockEntryFormValidation.rateMinor('100'), 10000);
    expect(StockEntryFormValidation.rateMinor('100.50'), 10050);
    expect(StockEntryFormValidation.rateMinor('0.01'), 1);
    expect(StockEntryFormValidation.rateMinor('100.555'), isNull);
    expect(StockEntryFormValidation.rateMinor('-1'), isNull);
    expect(StockEntryFormValidation.rateMinor('abc'), isNull);
  });

  test('date formatting used by labour and reports', () {
    final date = DateTime(2026, 11, 3);
    expect(stockDate(date), '2026-11-03');
    expect(reportDate(date), '2026-11-03');
    expect(bulkDate(date), '2026-11-03');
  });
}
