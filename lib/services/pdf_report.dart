import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/category_budget.dart';
import '../models/expense.dart';
import '../models/income.dart';

class MonthlyReportData {
  final DateTime month;
  final String currency;
  final List<Expense> expenses;
  final MonthlyBalance balance;
  final double? budget;
  final Map<String, double> categoryLimits;

  const MonthlyReportData({
    required this.month,
    required this.currency,
    required this.expenses,
    required this.balance,
    this.budget,
    this.categoryLimits = const {},
  });
}

const _largestCount = 5;
const _teal = PdfColor.fromInt(0xFF00897B);

/// A one-page style summary of a month. Text in scripts the built-in PDF
/// font lacks, such as Sinhala, shows as blank boxes.
Future<Uint8List> buildMonthlyReport(MonthlyReportData d) {
  final money = NumberFormat('#,##0.00');
  String amount(double v) =>
      '${v < 0 ? '-' : ''}${d.currency} ${money.format(v.abs())}';

  final spent = d.balance.spent;
  final byCategory = <String, double>{};
  for (final e in d.expenses) {
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
  }
  final categoryRows = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final largest = [...d.expenses]
    ..sort((a, b) => b.amount.compareTo(a.amount));
  final budgets = CategoryBudgetStatus.summarize(d.categoryLimits, d.expenses);
  final monthName = DateFormat('MMMM yyyy').format(d.month);

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: _teal)),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        border: null,
        headerStyle:
            pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        rowDecoration: const pw.BoxDecoration(
          border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        ),
        cellAlignments: {headers.length - 1: pw.Alignment.centerRight},
        headerAlignments: {headers.length - 1: pw.Alignment.centerRight},
      );

  final doc = pw.Document(title: 'Budgie report $monthName', author: 'Budgie');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    footer: (context) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Made with Budgie on '
        '${DateFormat('d MMM yyyy').format(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ),
    build: (context) => [
      pw.Text('Monthly report',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      pw.Text(monthName,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      heading('Summary'),
      table(['', 'Amount'], [
        ['Income', amount(d.balance.income)],
        ['Spent', amount(spent)],
        ['Moved to savings goals', amount(d.balance.saved)],
        ['Left', amount(d.balance.left)],
        if (d.budget != null && d.budget! > 0) ...[
          ['Monthly budget', amount(d.budget!)],
          [
            spent > d.budget! ? 'Over budget by' : 'Budget left',
            amount((d.budget! - spent).abs()),
          ],
        ],
      ]),
      if (categoryRows.isNotEmpty) ...[
        heading('Spending by category'),
        table(['Category', 'Share', 'Amount'], [
          for (final e in categoryRows)
            [
              e.key,
              spent > 0 ? '${(e.value / spent * 100).round()}%' : '-',
              amount(e.value),
            ],
        ]),
      ],
      if (budgets.isNotEmpty) ...[
        heading('Category budgets'),
        table(['Category', 'Limit', 'Status', 'Spent'], [
          for (final b in budgets)
            [
              b.category,
              amount(b.limit),
              b.isOver
                  ? 'Over by ${amount(-b.remaining)}'
                  : '${amount(b.remaining)} left',
              amount(b.spent),
            ],
        ]),
      ],
      if (largest.isNotEmpty) ...[
        heading('Largest expenses'),
        table(['Date', 'Category', 'Note', 'Amount'], [
          for (final e in largest.take(_largestCount))
            [
              DateFormat('d MMM').format(e.date),
              e.category,
              e.note,
              amount(e.amount),
            ],
        ]),
      ],
      if (d.expenses.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18),
          child: pw.Text('No expenses were recorded this month.'),
        ),
    ],
  ));
  return doc.save();
}
