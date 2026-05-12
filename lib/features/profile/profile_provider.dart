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
    // 當 Supabase auth 狀態（登入 / 登出）改變時，自動重抓 profile。
    ref.listen(authStateChangesProvider, (previous, next) {
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
  /// 失敗時會 rethrow 讓 UI 端用 try/catch 顯示錯誤訊息；
  /// 成功時 [state] 會是新的 [Profile]，畫面（如首頁）會自動重新渲染。
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

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client.from('profiles').update({
        'name': trimmedName,
        'phone': trimmedPhone,
      }).eq('id', user.id);
      return _fetchCurrent();
    });

    // 若寫入失敗（state 變成 AsyncError），rethrow 給上層處理。
    if (state.hasError) {
      throw state.error!;
    }
  }

  Future<Profile?> _fetchCurrent() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final data = await Supabase.instance.client
        .from('profiles')
        .select('id, name, phone, role')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromMap(data);
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
