import 'package:flutter_test/flutter_test.dart';
import 'package:budgie/services/premium_service.dart';

void main() {
  test('productId is com.thilina.budgie.premium', () {
    expect(PremiumService.productId, equals('com.thilina.budgie.premium'));
  });
}
