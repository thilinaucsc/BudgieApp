import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/models/expense.dart';
import 'package:budgie/services/csv_export.dart';

Expense _expense(String note, {DateTime? date, double amount = 10}) => Expense(
      amount: amount,
      category: 'Food',
      date: date ?? DateTime(2026, 5, 1, 13, 30),
      note: note,
    );

List<String> _lines(String csv) => csv.split('\r\n');

void main() {
  test('starts with a byte order mark and header', () {
    expect(expensesToCsv([]), '﻿Date,Category,Amount,Note\r\n');
  });

  test('writes one row with a plain date and two decimals', () {
    final csv = expensesToCsv([_expense('Lunch', amount: 1250.5)]);
    expect(_lines(csv)[1], '2026-05-01,Food,1250.50,Lunch');
  });

  test('sorts rows oldest first', () {
    final csv = expensesToCsv([
      _expense('later', date: DateTime(2026, 5, 9)),
      _expense('earlier', date: DateTime(2026, 5, 2)),
    ]);
    expect(_lines(csv)[1], endsWith('earlier'));
    expect(_lines(csv)[2], endsWith('later'));
  });

  test('quotes commas, quotes and new lines', () {
    expect(_lines(expensesToCsv([_expense('Rice, dhal')]))[1],
        endsWith('"Rice, dhal"'));
    expect(_lines(expensesToCsv([_expense('The "big" shop')]))[1],
        endsWith('"The ""big"" shop"'));
    expect(expensesToCsv([_expense('line one\nline two')]),
        contains('"line one\nline two"'));
  });

  test('neutralises spreadsheet formulas', () {
    for (final note in ['=1+1', '+94771234567', '-5', '@SUM(A1)']) {
      expect(_lines(expensesToCsv([_expense(note)]))[1], endsWith(",'$note"));
    }
  });

  test('keeps Sinhala text unchanged', () {
    expect(_lines(expensesToCsv([_expense('කෑම')]))[1], endsWith(',කෑම'));
  });
}
