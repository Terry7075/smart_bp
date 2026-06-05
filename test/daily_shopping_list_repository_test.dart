import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/daily_shopping_list_repository.dart';

void main() {
  test('parses RPC jsonb array from List', () {
    final lines = parseDailyShoppingRpcPayload([
      {
        'group_key': 'tissue',
        'category_label': '衛生紙',
        'unit_label': '包',
        'total_qty': 3,
        'elder_lines': [
          {
            'item_id': 'a',
            'elder_user_id': 'u1',
            'elder_display': '王阿嬤',
            'quantity': 2,
            'demand_record_id': 'd1',
          },
        ],
      },
    ]);
    expect(lines.length, 1);
    expect(lines.first.totalQty, 3);
    expect(lines.first.elderLines.length, 1);
  });

  test('parses RPC jsonb array from JSON string', () {
    const json = '''
[{"group_key":"egg","category_label":"雞蛋","unit_label":"盒","total_qty":1,"elder_lines":[]}]
''';
    final lines = parseDailyShoppingRpcPayload(json);
    expect(lines.length, 1);
    expect(lines.first.categoryLabel, '雞蛋');
  });
}
