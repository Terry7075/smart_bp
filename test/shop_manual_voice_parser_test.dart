import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/shop_manual_voice_parser.dart';

void main() {
  test('全聯口語與數量', () {
    final p = ShopManualVoiceParser.parse('全聯的鮮奶兩罐');
    expect(p.displayName, '鮮奶 2罐');
    expect(p.pxSearchKeyword, '鮮奶');
    expect(p.quantity, 2);
  });

  test('幫我買與阿拉伯數字', () {
    final p = ShopManualVoiceParser.parse('幫我買雞蛋3盒');
    expect(p.quantity, 3);
    expect(p.pxSearchKeyword, contains('雞蛋'));
  });

  test('簡單品名', () {
    final p = ShopManualVoiceParser.parse('義美小泡芙');
    expect(p.quantity, 1);
    expect(p.isValid, isTrue);
  });
}
