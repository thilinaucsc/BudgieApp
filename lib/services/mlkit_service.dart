import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/extracted_expense.dart';

class MlKitService {
  // Keywords that typically precede the payable total on a receipt.
  static final _totalKeywords = RegExp(
    r'\b(grand\s+total|total\s+due|amount\s+due|net\s+total|total\s+payable|total)\b',
    caseSensitive: false,
  );

  // Currency amount: optional symbol, digits, optional decimal part.
  static final _amountPattern = RegExp(r'[\d,]+(?:\.\d{1,2})?');

  static final _datePatterns = [
    // YYYY-MM-DD or YYYY/MM/DD
    RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b'),
    // DD/MM/YYYY or DD-MM-YYYY
    RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})\b'),
  ];

  static ExtractedExpense? parseReceiptText(String text) {
    if (text.trim().isEmpty) return null;

    final lines = text.split('\n');

    // 1. Look for a line with a total keyword and extract its last number.
    double? amount;
    for (final line in lines) {
      if (_totalKeywords.hasMatch(line)) {
        final matches = _amountPattern.allMatches(line).toList();
        if (matches.isNotEmpty) {
          amount = _parseAmount(matches.last.group(0)!);
          break;
        }
      }
    }

    // 2. Fallback: largest number in the entire receipt.
    if (amount == null) {
      double? largest;
      for (final match in _amountPattern.allMatches(text)) {
        final v = _parseAmount(match.group(0)!);
        if (v != null && (largest == null || v > largest)) largest = v;
      }
      if (largest == null) return null;
      amount = largest;
    }

    // 3. Date extraction.
    DateTime? date;
    outer:
    for (final pattern in _datePatterns) {
      for (final match in pattern.allMatches(text)) {
        final parsed = _parseDate(match, pattern);
        if (parsed != null) {
          date = parsed;
          break outer;
        }
      }
    }

    return ExtractedExpense(amount: amount, date: date);
  }

  static double? _parseAmount(String s) =>
      double.tryParse(s.replaceAll(',', ''));

  static DateTime? _parseDate(RegExpMatch m, RegExp pattern) {
    try {
      // YYYY-?-? pattern has 4-digit year first
      if (m.group(1)!.length == 4) {
        return DateTime(
          int.parse(m.group(1)!),
          int.parse(m.group(2)!),
          int.parse(m.group(3)!),
        );
      } else {
        // DD/MM/YYYY — day first, year last
        return DateTime(
          int.parse(m.group(3)!),
          int.parse(m.group(2)!),
          int.parse(m.group(1)!),
        );
      }
    } catch (_) {
      return null;
    }
  }

  Future<ExtractedExpense?> extractFromReceipt(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final result = await recognizer.processImage(inputImage);
      return parseReceiptText(result.text);
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
