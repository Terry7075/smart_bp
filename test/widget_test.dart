import 'package:flutter_test/flutter_test.dart';
import 'package:mingde_transport/core/utils/price_calculator.dart';

void main() {
  test('price calculator smoke test', () {
    expect(calculatePrice(4), 20);
  });
}
