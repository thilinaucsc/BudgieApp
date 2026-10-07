import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/extracted_expense.dart';

class MlKitService {
  static final _totalKeywords = RegExp(
    r'\b(grand\s+total|total\s+due|amount\s+due|net\s+total|total\s+payable|bill\s+total|sub\s*total|total)\b',
    caseSensitive: false,
  );

  // Matches numbers like 1234 / 1,234 / 1234.50 / 1,234.50
  static final _amountPattern = RegExp(r'\d[\d,]*(?:\.\d{1,2})?');

  static final _datePatterns = [
    RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b'),
    RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})\b'),
  ];

  static ExtractedExpense? parseReceiptText(String text) {
    if (text.trim().isEmpty) return null;

    final lines = text.split('\n');

    // 1. Find line with total keyword — prefer lines further down (last match wins)
    double? amount;
    for (final line in lines) {
      if (_totalKeywords.hasMatch(line)) {
        final matches = _amountPattern.allMatches(line).toList();
        for (final m in matches.reversed) {
          final v = _parseAmount(m.group(0)!);
          if (v != null && v > 0 && v < 10000000) {
            amount = v;
            break;
          }
        }
      }
    }

    // 2. Fallback: largest plausible price on the receipt
    if (amount == null) {
      double? largest;
      for (final match in _amountPattern.allMatches(text)) {
        final v = _parseAmount(match.group(0)!);
        // Skip barcodes / phone numbers (more than 7 significant digits)
        if (v == null || v <= 0 || v >= 10000000) continue;
        final digits = match.group(0)!.replaceAll(',', '').replaceAll('.', '');
        if (digits.length > 7) continue;
        if (largest == null || v > largest) largest = v;
      }
      if (largest == null) return null;
      amount = largest;
    }

    // 3. Date
    DateTime? date;
    outer:
    for (final pattern in _datePatterns) {
      for (final match in pattern.allMatches(text)) {
        final parsed = _parseDate(match);
        if (parsed != null) {
          date = parsed;
          break outer;
        }
      }
    }

    return ExtractedExpense(amount: amount, date: date);
  }

  static double? _parseAmount(String s) {
    final v = double.tryParse(s.replaceAll(',', ''));
    return (v != null && v > 0) ? v : null;
  }

  static DateTime? _parseDate(RegExpMatch m) {
    try {
      if (m.group(1)!.length == 4) {
        final y = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final d = int.parse(m.group(3)!);
        if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
        return DateTime(y, mo, d);
      } else {
        final d = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final y = int.parse(m.group(3)!);
        if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
        return DateTime(y, mo, d);
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
      debugPrint('[MlKit] OCR text (${result.text.length} chars): ${result.text}');
      return parseReceiptText(result.text);
    } catch (e) {
      debugPrint('[MlKit] Error: $e');
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
