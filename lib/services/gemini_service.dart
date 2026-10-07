import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/expense_category.dart';
import '../models/extracted_expense.dart';

class GeminiService {
  final String apiKey;
  GeminiService({required this.apiKey});

  static const _validCategories = [
    'Food','Groceries','Dining Out','Transport','Bills','Shopping',
    'Health','Entertainment','Education','Personal Care','Savings','Other',
  ];

  static ExtractedExpense? parseJson(String raw) {
    try {
      // Strip markdown code fences if present
      final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final map = jsonDecode(cleaned) as Map<String, dynamic>;

      final amount = switch (map['amount']) {
        num n => n.toDouble(),
        _ => null,
      };

      DateTime? date;
      if (map['date'] is String) {
        date = DateTime.tryParse(map['date'] as String);
      }

      String? category;
      if (map['category'] is String) {
        final c = map['category'] as String;
        category = _validCategories.contains(c) ? c : null;
      }

      final note = map['note'] is String ? map['note'] as String : null;

      return ExtractedExpense(amount: amount, date: date, category: category, note: note);
    } catch (_) {
      return null;
    }
  }

  Future<ExtractedExpense?> extractFromReceipt(File imageFile) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final imageBytes = await imageFile.readAsBytes();
      final mimeType = _mimeType(imageFile.path);
      const prompt = '''You are a receipt parser. Extract from this receipt image and return ONLY valid JSON with these keys:
- amount: number (the total amount paid)
- date: ISO8601 date string (e.g. "2026-10-07")
- category: one of exactly: Food, Groceries, Dining Out, Transport, Bills, Shopping, Health, Entertainment, Education, Personal Care, Savings, Other
- note: merchant name or brief description

Use null for any field you cannot determine. Return JSON only, no explanation.''';
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ]),
      ]);
      final text = response.text;
      if (text == null) return null;
      return parseJson(text);
    } catch (_) {
      return null;
    }
  }

  String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
