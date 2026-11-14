import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/services/gemini_service.dart';

void main() {
  test('parseGeminiJson returns correct ExtractedExpense', () {
    const json = '{"amount":1250.50,"date":"2026-10-07","category":"Groceries","note":"Cargills"}';
    final result = GeminiService.parseJson(json);
    expect(result?.amount, equals(1250.50));
    expect(result?.date, equals(DateTime(2026, 10, 7)));
    expect(result?.category, equals('Groceries'));
    expect(result?.note, equals('Cargills'));
  });

  test('parseGeminiJson returns null on malformed JSON', () {
    expect(GeminiService.parseJson('not json'), isNull);
  });

  test('parseGeminiJson returns partial result when fields are null', () {
    const json = '{"amount":500,"date":null,"category":null,"note":null}';
    final result = GeminiService.parseJson(json);
    expect(result?.amount, equals(500.0));
    expect(result?.date, isNull);
    expect(result?.category, isNull);
  });

  test('parseGeminiJson returns null for invalid category string', () {
    const json = '{"amount":100,"date":"2026-01-01","category":"InvalidCat","note":"x"}';
    final result = GeminiService.parseJson(json);
    expect(result?.category, isNull);
  });

  test('parseJson strips markdown code fences', () {
    const raw = '```json\n{"amount":42,"date":"2026-03-04","category":"Food","note":"Lunch"}\n```';
    final result = GeminiService.parseJson(raw);
    expect(result?.amount, 42.0);
    expect(result?.date, DateTime(2026, 3, 4));
    expect(result?.category, 'Food');
    expect(result?.note, 'Lunch');
  });

  test('parseJson returns null when JSON is not an object', () {
    expect(GeminiService.parseJson('[1,2,3]'), isNull);
    expect(GeminiService.parseJson(''), isNull);
  });

  test('parseJson ignores non-numeric amount and bad date', () {
    const json = '{"amount":"abc","date":"yesterday","category":"Bills","note":5}';
    final result = GeminiService.parseJson(json);
    expect(result, isNotNull);
    expect(result?.amount, isNull);
    expect(result?.date, isNull);
    expect(result?.category, 'Bills');
    expect(result?.note, isNull);
  });

  test('parseJson accepts every app category', () {
    for (final c in ['Food', 'Groceries', 'Dining Out', 'Transport', 'Bills',
        'Shopping', 'Health', 'Entertainment', 'Education', 'Personal Care',
        'Savings', 'Other']) {
      final result = GeminiService.parseJson('{"category":"$c"}');
      expect(result?.category, c, reason: c);
    }
  });
}
