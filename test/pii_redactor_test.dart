import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/health_ocr/pii_redactor.dart';

void main() {
  group('redactPrescriptionPii', () {
    test('遮罩身分證但保留領藥日與服藥時段', () {
      const raw = '臺大醫院\n'
          '姓名：王大明\n'
          '身分證：A123456789\n'
          '領藥日：115 年 5 月 10 日\n'
          '三餐飯後';
      final out = redactPrescriptionPii(raw);

      expect(out, contains('[身分證]'));
      expect(out, contains('姓名：[姓名]'));
      // 核心欄位必須保留，否則 Gemini 解析會壞掉。
      expect(out, contains('115 年 5 月 10 日'));
      expect(out, contains('三餐飯後'));
      expect(out, contains('臺大醫院'));
      // 原始 PII 不可殘留。
      expect(out, isNot(contains('A123456789')));
      expect(out, isNot(contains('王大明')));
    });

    test('容忍 OCR 在身分證中夾空白', () {
      const raw = '身分證 A 1 2 3 4 5 6 7 8 9';
      final out = redactPrescriptionPii(raw);
      expect(out, contains('[身分證]'));
      expect(out, isNot(contains('123456789')));
    });

    test('檢核碼不合法的英數字串不應被誤判為身分證', () {
      const raw = '藥品批號 X999999999';
      final out = redactPrescriptionPii(raw);
      expect(out, contains('X999999999'));
      expect(out, isNot(contains('[身分證]')));
    });

    test('遮罩手機與市話', () {
      const raw = '聯絡電話 0912-345-678\n醫院總機 02-23123456';
      final out = redactPrescriptionPii(raw);
      expect(out, contains('[電話]'));
      expect(out, isNot(contains('0912')));
      expect(out, isNot(contains('23123456')));
    });

    test('遮罩出生日期但不誤遮領藥日', () {
      const raw = '出生：民國 40 年 1 月 1 日\n領藥日：115 年 5 月 10 日';
      final out = redactPrescriptionPii(raw);
      expect(out, contains('出生：[生日]'));
      expect(out, contains('115 年 5 月 10 日'));
    });

    test('遮罩病歷號', () {
      const raw = '病歷號碼：12345678\n藥名：普拿疼 500mg';
      final out = redactPrescriptionPii(raw);
      expect(out, contains('病歷號碼：[病歷號]'));
      expect(out, contains('普拿疼 500mg'));
      expect(out, isNot(contains('12345678')));
    });

    test('空字串原樣回傳', () {
      expect(redactPrescriptionPii(''), '');
    });

    test('無個資的純藥單文字不應被更動', () {
      const raw = '長庚醫院\nOlmetec 雅脈 (Olmesartan)\n三餐飯後\n共 28 天';
      expect(redactPrescriptionPii(raw), raw);
    });
  });
}
