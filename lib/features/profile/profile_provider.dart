import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 使用者個人資料（對應 Supabase `profiles` 資料表）。
///
/// 與 `auth.users` 透過 [id] 一對一關聯，由 [Profile.fromMap] 從 Supabase
/// row 反序列化，提供 [firstChar]、[isVolunteer] 之類給 UI / Router 直接用
/// 的派生欄位。
class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.phone,
    this.role = kRoleElder,
  });

  /// 「長輩」角色字串（資料庫端值），預設角色。
  static const String kRoleElder = 'elder';

  /// 「志工」角色字串（資料庫端值）。
  static const String kRoleVolunteer = 'volunteer';

  static const String kRoleFamily = 'family';

  static const String kRoleAdmin = 'admin';

  /// 「司機」角色字串（社區交通模組）。
  static const String kRoleDriver = 'driver';

  final String id;
  final String name;
  final String? phone;

  /// 使用者角色（對應 `profiles.role` 欄位）。
  ///
  /// 預設 [kRoleElder]，避免舊資料缺欄位時 UI / Router 走到 null branch。
  /// 寫入時請統一用 `UserRole.dbValue`，避免拼字漂移。
  final String role;

  /// 給頭像用：取姓氏第一個中文字（或英文首字）。
  /// 若名字是空字串、預設用「長」（取「長輩」之意）。
  String get firstChar {
    if (name.isEmpty) return '長';
    return name.substring(0, 1);
  }

  /// 是否為志工身分（給 Router / 首頁分流用）。
  bool get isVolunteer => role == kRoleVolunteer;

  /// 是否為長輩身分（預設角色）。
  bool get isElder => role == kRoleElder;

  bool get isFamily => role == kRoleFamily;

  bool get isAdmin => role == kRoleAdmin;

  /// 是否為司機身分（社區交通模組）。
  bool get isDriver => role == kRoleDriver;

  /// 志工端入口：含原 admin（據點管理者併入志工 UI）。
  bool get isVolunteerHub => isVolunteer || isAdmin;

  /// 不可變更新，方便編輯頁先做樂觀更新。
  Profile copyWith({String? name, String? phone, String? role}) => Profile(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        role: role ?? this.role,
      );

  /// 從 Supabase row 反序列化。
  ///
  /// `role` 是後加欄位，若舊資料缺欄位（例如資料表還沒做 alter）就 fallback
  /// 為長輩，不會把使用者卡在錯誤頁。
  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        phone: map['phone'] as String?,
        role: (map['role'] as String?) ?? kRoleElder,
      );

  /// JSON helper alias，呼叫端習慣 `fromJson` 也能用。
  factory Profile.fromJson(Map<String, dynamic> json) => Profile.fromMap(json);
}

/// 目前登入者的個人資料。
///
/// - 自動跟著 [authStateChangesProvider] 重新抓資料（登出 → null；登入 → fetch）。
/// - 提供 [ProfileNotifier.updateProfile] 寫回 Supabase 並刷新本地狀態。
final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // 當 Supabase auth 狀態（登入 / 登出 / 切換帳號）改變時，立刻清掉舊 profile
    // 並進 loading，避免 RoleGuard / 路由在重抓完成前仍用「上一個使用者」的 role。
    ref.listen(authStateChangesProvider, (previous, next) {
      state = const AsyncLoading();
      ref.invalidateSelf();
    });

    return _fetchCurrent();
  }

  /// 從 Supabase 重抓並更新本地狀態，外部頁面可呼叫做 pull-to-refresh。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchCurrent);
  }

  /// 將姓名 / 手機寫回 Supabase 並更新本地狀態。
  ///
  /// 儲存期間**不**把整個 provider 設成 AsyncLoading（否則 ProfilePage 的
  /// `when(loading: …)` 會把表單換成轉圈，失敗時連編輯內容都看不到）。
  /// 頁面端用 `_isSaving` overlay 即可；失敗時還原先前的 profile 並 rethrow。
  Future<void> updateProfile({
    required String name,
    String? phone,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('尚未登入，無法更新個人資料');
    }

    final trimmedName = name.trim();
    final trimmedPhone = phone?.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('姓名不可為空');
    }

    final previous = state.asData?.value;

    try {
      await Supabase.instance.client.from('profiles').update({
        'name': trimmedName,
        'phone': trimmedPhone,
      }).eq('id', user.id);
      state = AsyncData(await _fetchCurrent());
    } catch (e, st) {
      if (previous != null) {
        state = AsyncData(previous);
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Profile?> _fetchCurrent() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    var data = await _queryProfile(user.id);

    // OAuth 首次登入：auth 的 _ensureProfile 是非同步 fire-and-forget，
    // profileProvider 可能先查到 null 就讓角色決策頁永遠卡在 splash。
    // 這裡主動補建 + 短暫重試，與 auth 端邏輯互補。
    if (data == null) {
      await _bootstrapProfileIfMissing(user);
      for (var attempt = 0; attempt < 3 && data == null; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
        }
        data = await _queryProfile(user.id);
      }
    }

    if (data == null) return null;
    return Profile.fromMap(data);
  }

  Future<Map<String, dynamic>?> _queryProfile(String userId) async {
    return Supabase.instance.client
        .from('profiles')
        .select('id, name, phone, role')
        .eq('id', userId)
        .maybeSingle();
  }

  /// OAuth 第一次登入時若 profiles 列尚不存在，補建一筆 elder 預設資料。
  Future<void> _bootstrapProfileIfMissing(User user) async {
    try {
      final existing = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing != null) return;

      final meta = user.userMetadata ?? const <String, dynamic>{};
      final name = (meta['full_name'] as String?) ??
          (meta['name'] as String?) ??
          '社區長輩';

      await Supabase.instance.client.from('profiles').insert({
        'id': user.id,
        'name': name,
        if (user.phone != null && user.phone!.isNotEmpty) 'phone': user.phone,
        'role': Profile.kRoleElder,
      });
    } catch (_) {
      // 可能與 auth._ensureProfile 同時 insert（duplicate）— 忽略即可。
    }
  }
}

/// 給 UI 用的時段問候詞：早安 / 午安 / 晚安。
///
/// 切點參考一般長輩作息：
/// - 05:00–10:59 → 早安
/// - 11:00–17:59 → 午安
/// - 其餘（含半夜） → 晚安
String greetingForNow([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour >= 5 && hour < 11) return '早安';
  if (hour >= 11 && hour < 18) return '午安';
  return '晚安';
}
