// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 藥品照片所在的私有 bucket（與查詢端 [DrugDictionaryService] 一致）。
const String drugImagesBucket = 'drug-images';

final drugDictionaryAdminProvider = Provider<DrugDictionaryAdminRepository>(
  (ref) => DrugDictionaryAdminRepository(Supabase.instance.client),
);

/// 志工端：新增／維護社區藥典（`drug_dictionary`）。
///
/// 與 [DrugDictionaryService]（純查詢）分開，避免把寫入混進查詢快取邏輯。
class DrugDictionaryAdminRepository {
  DrugDictionaryAdminRepository(this._client);

  final SupabaseClient _client;

  /// 新增一筆藥典。至少要有中文名或英文名其一。
  ///
  /// 若帶 [localPhotoPath]，會先上傳照片到 [drugImagesBucket]，並把
  /// `image_url` 存成 `drug-images/{uid}/{檔名}`（查詢端可直接解析成 signed URL）。
  Future<void> addEntry({
    String? nameZh,
    String? nameEn,
    String? genericName,
    String? manufacturer,
    String? localPhotoPath,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('尚未登入');

    final zh = nameZh?.trim() ?? '';
    final en = nameEn?.trim() ?? '';
    if (zh.isEmpty && en.isEmpty) {
      throw StateError('請至少填寫中文名或英文名其中一個。');
    }

    String? imageUrl;
    if (localPhotoPath != null && localPhotoPath.trim().isNotEmpty) {
      final objectPath =
          await _uploadPhoto(userId: user.id, localPath: localPhotoPath);
      // 存成「bucket/path」格式，查詢端 _resolveImageUrl 會用 signed URL 取圖。
      imageUrl = '$drugImagesBucket/$objectPath';
    }

    final gen = genericName?.trim() ?? '';
    final mfr = manufacturer?.trim() ?? '';

    await _client.from('drug_dictionary').insert({
      if (zh.isNotEmpty) 'name_zh': zh,
      if (en.isNotEmpty) 'name_en': en,
      if (gen.isNotEmpty) 'generic_name': gen,
      if (mfr.isNotEmpty) 'manufacturer': mfr,
      'image_url': ?imageUrl,
      'created_by': user.id,
    });
  }

  Future<String> _uploadPhoto({
    required String userId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('找不到剛剛挑的照片檔案，請再試一次。');
    }

    final ext = _safeExtension(localPath);
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${1000 + Random().nextInt(8999)}.$ext';
    final objectPath = '$userId/$filename';

    try {
      await _client.storage.from(drugImagesBucket).upload(
            objectPath,
            file,
            fileOptions: FileOptions(
              upsert: false,
              contentType: _mimeForExtension(ext),
            ),
          );
    } on StorageException catch (e) {
      throw StateError(_translateStorageError(e));
    }

    return objectPath;
  }

  String _safeExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot < 0 || lastDot == path.length - 1) return 'jpg';
    final ext = path.substring(lastDot + 1).toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
    return allowed.contains(ext) ? ext : 'jpg';
  }

  String _mimeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  String _translateStorageError(StorageException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('not found') || msg.contains('bucket')) {
      return '尚未建立藥品照片 bucket（$drugImagesBucket），請通知管理員執行 migration。';
    }
    if (msg.contains('row-level security') || msg.contains('policy')) {
      return '沒有上傳權限（請確認以志工帳號登入，且已套用 storage policy）。';
    }
    return '照片上傳失敗：${e.message}';
  }
}

/// 友善錯誤訊息（資料表不存在時提示跑 migration）。
String drugDictionaryFriendlyError(Object error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST205' ||
        (error.message.contains('drug_dictionary') &&
            error.message.contains('schema cache'))) {
      return '找不到 drug_dictionary 資料表。\n請到 Supabase SQL Editor 執行 migrations 內的 20260524100000_drug_dictionary_volunteer_contribute.sql';
    }
    if (error.code == '42501' ||
        error.message.toLowerCase().contains('row-level security')) {
      return '沒有新增權限：請確認以志工帳號登入，且已套用最新的 drug_dictionary RLS。';
    }
    return error.message;
  }
  if (error is StateError) return error.message;
  debugPrint('[DrugDictionaryAdmin] $error');
  return error.toString();
}
