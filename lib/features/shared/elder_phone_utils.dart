import 'package:supabase_flutter/supabase_flutter.dart';

/// 長輩聯絡電話：顯示與撥號前正規化（台灣手機 09xxxxxxxx）。
abstract final class ElderPhoneUtils {
  /// 將各種輸入格式統一成可撥號的本地手機（優先 09 開頭 10 碼）。
  static String? normalizeForDial(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    var digits = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('+886')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('886') && digits.length >= 11) {
      digits = '0${digits.substring(3)}';
    } else if (digits.length == 9 && digits.startsWith('9')) {
      digits = '0$digits';
    }

    final local = digits.replaceAll(RegExp(r'\D'), '');
    if (local.length == 10 && local.startsWith('09')) return local;
    if (local.length >= 8) return local;
    return null;
  }

  static String? formatForDisplay(String? raw) {
    final dial = normalizeForDial(raw);
    if (dial == null) return null;
    if (dial.length == 10 && dial.startsWith('09')) {
      return '${dial.substring(0, 4)}-${dial.substring(4, 7)}-${dial.substring(7)}';
    }
    return dial;
  }

  /// 依長輩 user id 讀取最新 `profiles.phone`（志工撥號前使用）。
  static Future<String?> fetchLatestPhone(String elderUserId) async {
    final id = elderUserId.trim();
    if (id.isEmpty) return null;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('phone')
          .eq('id', id)
          .maybeSingle();
      final phone = row?['phone']?.toString().trim();
      if (phone == null || phone.isEmpty) return null;
      return normalizeForDial(phone) ?? phone;
    } catch (_) {
      return null;
    }
  }
}
