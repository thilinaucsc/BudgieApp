import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/services/mlkit_service.dart';

void main() {
  group('MlKitService.parseReceiptText', () {
    test('extracts amount from "Total" line', () {
      const text = '''
SUPERMART
Milk        Rs. 250.00
Bread       Rs. 180.00
Total       Rs. 430.00
''';
      final result = MlKitService.parseReceiptText(text);
      expect(result?.amount, equals(430.00));
    });

    test('extracts amount from "Grand Total" line', () {
      const text = '''
Items subtotal  1200.00
Tax              120.00
Grand Total     1320.00
''';
      final result = MlKitService.parseReceiptText(text);
      expect(result?.amount, equals(1320.00));
    });

    test('falls back to largest number when no total keyword', () {
      const text = '''
Item A   50.00
Item B   75.00
Item C  200.00
''';
      final result = MlKitService.parseReceiptText(text);
      expect(result?.amount, equals(200.00));
    });

    test('extracts date in DD/MM/YYYY format', () {
      const text = '''
Date: 07/10/2026
Total  500.00
''';
      final result = MlKitService.parseReceiptText(text);
      expect(result?.date, equals(DateTime(2026, 10, 7)));
    });

    test('extracts date in YYYY-MM-DD format', () {
      const text = 'Receipt 2026-10-07  Total 100.00';
      final result = MlKitService.parseReceiptText(text);
      expect(result?.date, equals(DateTime(2026, 10, 7)));
    });

    test('returns null for empty text', () {
      expect(MlKitService.parseReceiptText(''), isNull);
    });

    test('returns null when no numbers found', () {
      expect(MlKitService.parseReceiptText('Thank you for shopping'), isNull);
    });

    test('parses thousands separators', () {
      const text = 'Total   Rs. 12,345.50';
      expect(MlKitService.parseReceiptText(text)?.amount, equals(12345.50));
    });

    test('final Total wins over earlier Sub Total', () {
      const text = '''
Sub Total  1000.00
Discount    100.00
Total       900.00
''';
      expect(MlKitService.parseReceiptText(text)?.amount, equals(900.00));
    });

    test('total keyword is case-insensitive', () {
      expect(MlKitService.parseReceiptText('TOTAL 75.25')?.amount, 75.25);
    });

    test('fallback ignores barcode-like long numbers', () {
      const text = '''
1234567890123
Item  45.00
''';
      expect(MlKitService.parseReceiptText(text)?.amount, equals(45.00));
    });

    test('rejects impossible month', () {
      const text = 'Date 2026-13-01  Total 10.00';
      expect(MlKitService.parseReceiptText(text)?.date, isNull);
    });

    test('rejects impossible day such as 31 February', () {
      const text = 'Date 31/02/2026  Total 10.00';
      expect(MlKitService.parseReceiptText(text)?.date, isNull);
    });

    test('date is null when none present', () {
      expect(MlKitService.parseReceiptText('Total 10.00')?.date, isNull);
    });

    test('whitespace-only text returns null', () {
      expect(MlKitService.parseReceiptText('   \n  '), isNull);
    });
  });
}
