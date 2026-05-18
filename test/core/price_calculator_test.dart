import 'package:flutter_test/flutter_test.dart';
import 'package:mingde_transport/core/utils/price_calculator.dart';

void main() {
  group('calculatePrice', () {
    test('returns 20 for distances up to 5 km', () {
      expect(calculatePrice(0), 20);
      expect(calculatePrice(5), 20);
    });

    test('returns 50 for distances greater than 5 and up to 10 km', () {
      expect(calculatePrice(5.1), 50);
      expect(calculatePrice(10), 50);
    });

    test('returns 100 for distances above 10 km', () {
      expect(calculatePrice(10.1), 100);
    });
  });
}
