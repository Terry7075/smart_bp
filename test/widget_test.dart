// 純函式單元測試：不需啟動 Supabase / Flutter binding，跑得快又穩。

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_bp/features/learning/learning_content_models.dart';
import 'package:smart_bp/features/medication/drug_dictionary_service.dart';
import 'package:smart_bp/features/prescription/prescription_models.dart';

void main() {
  group('youtubeVideoIdFromUrl', () {
    test('解析標準 watch?v= 連結', () {
      expect(
        youtubeVideoIdFromUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('解析短網址 youtu.be', () {
      expect(
        youtubeVideoIdFromUrl('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('解析 shorts / embed 路徑', () {
      expect(
        youtubeVideoIdFromUrl('https://www.youtube.com/shorts/abc123DEF45'),
        'abc123DEF45',
      );
      expect(
        youtubeVideoIdFromUrl('https://www.youtube.com/embed/abc123DEF45'),
        'abc123DEF45',
      );
    });

    test('非白名單 host（music.youtube.com）回 null', () {
      expect(
        youtubeVideoIdFromUrl('https://music.youtube.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
    });

    test('亂字串 / 空字串回 null', () {
      expect(youtubeVideoIdFromUrl(''), isNull);
      expect(youtubeVideoIdFromUrl('not a url'), isNull);
      expect(youtubeVideoIdFromUrl('https://example.com/watch?v=x'), isNull);
    });
  });

  group('buildDrugLookupCandidates', () {
    test('排除占位藥名與重複項', () {
      final candidates = buildDrugLookupCandidates(
        medicationName: kMedicationNamePlaceholder,
      );
      expect(candidates, isEmpty);
    });

    test('多藥名以分隔符切分並去重', () {
      final candidates = buildDrugLookupCandidates(
        medicationName: 'Amlodipine、Aspirin',
      );
      expect(candidates, contains('Amlodipine'));
      expect(candidates, contains('Aspirin'));
    });

    test('medicationsDetail 內的藥名也會被納入', () {
      final candidates = buildDrugLookupCandidates(
        medicationName: 'Aspirin',
        medicationsDetail: const [
          {'name': 'Metformin'},
        ],
      );
      expect(candidates, contains('Metformin'));
      expect(candidates, contains('Aspirin'));
    });
  });
}
