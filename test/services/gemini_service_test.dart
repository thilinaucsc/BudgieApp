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
}
