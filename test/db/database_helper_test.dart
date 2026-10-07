import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/db/database_helper.dart';

void main() {
  test('hashPin returns consistent SHA-256 hex for same input', () {
    expect(hashPin('1234'), equals(hashPin('1234')));
    expect(hashPin('1234').length, equals(64));
    expect(hashPin('1234'), isNot(equals(hashPin('5678'))));
  });

  test('hashPin returns 64-char lowercase hex', () {
    final h = hashPin('0000');
    expect(h, matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}
