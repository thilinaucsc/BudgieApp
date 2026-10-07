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
  });
}
