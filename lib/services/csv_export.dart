import 'package:intl/intl.dart';
import '../models/expense.dart';

/// Builds a CSV of [expenses], oldest first. Starts with a UTF-8 byte order
/// mark so Excel shows Sinhala and Tamil notes correctly.
String expensesToCsv(List<Expense> expenses) {
  final dateFormat = DateFormat('yyyy-MM-dd');
  final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));
  final buffer = StringBuffer('﻿Date,Category,Amount,Note\r\n');
  for (final e in sorted) {
    buffer.write('${dateFormat.format(e.date)},'
        '${_csvCell(e.category)},'
        '${e.amount.toStringAsFixed(2)},'
        '${_csvCell(e.note)}\r\n');
  }
  return buffer.toString();
}

String _csvCell(String value) {
  // Spreadsheets run cells starting with these characters as formulas.
  final safe = value.startsWith(RegExp(r'[=+\-@\t\r]')) ? "'$value" : value;
  if (safe.contains(RegExp(r'[",\r\n]'))) {
    return '"${safe.replaceAll('"', '""')}"';
  }
  return safe;
}
