import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/shop_manual_voice_parser.dart';

void main() {
  group('ShopManualVoiceParser.parseMany', () {
    test('逗號分隔兩品項', () {
      final items = ShopManualVoiceParser.parseMany('鮮奶兩罐，衛生紙一包');
      expect(items.length, 2);
      expect(items[0].pxSearchKeyword, '鮮奶');
      expect(items[0].quantity, 2);
      expect(items[1].pxSearchKeyword, '衛生紙');
      expect(items[1].quantity, 1);
    });

    test('「然後」作分隔詞', () {
      final items =
          ShopManualVoiceParser.parseMany('幫我買雞蛋3盒然後洗碗精一瓶');
      expect(items.length, 2);
      expect(items[0].pxSearchKeyword, '雞蛋');
      expect(items[0].quantity, 3);
      expect(items[1].pxSearchKeyword, '洗碗精');
      expect(items[1].quantity, 1);
    });

    test('單品項退化正常', () {
      final items = ShopManualVoiceParser.parseMany('義美小泡芙');
      expect(items.length, 1);
      expect(items[0].pxSearchKeyword, '義美小泡芙');
    });

    test('頓號分隔三品項', () {
      final items = ShopManualVoiceParser.parseMany('蘋果2個、橘子3個、葡萄一袋');
      expect(items.length, 3);
      expect(items[2].pxSearchKeyword, '葡萄');
    });

    test('空字串回傳空清單', () {
      expect(ShopManualVoiceParser.parseMany(''), isEmpty);
    });
  });
}
