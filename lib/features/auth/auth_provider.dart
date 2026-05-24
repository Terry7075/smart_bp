import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 「明德 e 達人」使用者角色（RBAC）。
///
/// 寫入 Supabase `profiles.role` 欄位時請使用 [dbValue]，避免 enum 名稱
/// 直接序列化造成跨版本不相容。
enum UserRole {
  /// 一般長輩使用者（預設）。
  elder('elder'),

  /// 社區志工：須持村辦公室發放的邀請碼才能註冊。
  volunteer('volunteer'),

  /// 家屬：可綁定長輩、查看代購進度。
  family('family'),

  /// 管理員：物資統計後台。
  admin('admin');

  const UserRole(this.dbValue);

  /// 對應到 Supabase `profiles.role` 的字串值。
  final String dbValue;
}

/// 寫死在 App 端的志工邀請碼（通關密語）。
///
/// 之後若要改成「從 Supabase 動態讀取」，把 [AuthNotifier.signUp] 內的比對
/// 邏輯改抓 RPC 即可，呼叫端不需要動。
const String kVolunteerInviteCode = 'MINDU-V-2026';

/// 註冊志工身分時邀請碼錯誤所拋出的例外。
///
/// 與 [AuthException] 分開，UI 端可單獨捕捉並顯示專屬的中文錯誤訊息，
/// 避免和登入失敗 / 密碼太短等錯誤混在一起。
class InvalidInviteCodeException implements Exception {
  const InvalidInviteCodeException();

  /// 給 UI 直接顯示用的長輩友善訊息。
  String get message => '志工邀請碼錯誤，請與村辦公室確認喔！';

  @override
  String toString() => message;
}

/// 與 [Supabase.instance.client.auth.onAuthStateChange] 同步，供外部監聽。
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// 目前登入 Session（由 [AuthNotifier] 與 Supabase auth stream 同步更新）。
final authProvider = NotifierProvider<AuthNotifier, Session?>(AuthNotifier.new);

class AuthNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    final client = Supabase.instance.client;
    final sub = client.auth.onAuthStateChange.listen((data) {
      state = data.session;

      // 第三方登入（或第一次登入）回來時，補齊 profiles 基本資料。
      if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
        _ensureProfile(data.session!.user);
      }
    });
    ref.onDispose(() => sub.cancel());
    return client.auth.currentSession;
  }

  Future<void> signIn(String email, String password) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// 帳號密碼註冊。
  ///
  /// [role] 預設為 [UserRole.elder]；若指定 [UserRole.volunteer]，必須在
  /// [inviteCode] 帶入正確的志工邀請碼（[kVolunteerInviteCode]），否則會在
  /// 真正呼叫 Supabase 之前先拋出 [InvalidInviteCodeException]，避免錯誤
  /// 角色被誤建立到資料庫裡。
  Future<void> signUp(
    String email,
    String password,
    String name,
    String phone, {
    UserRole role = UserRole.elder,
    String? inviteCode,
  }) async {
    // 志工註冊：先在 client 端把關，邀請碼錯就完全不打 Supabase。
    if (role == UserRole.volunteer) {
      final trimmedCode = inviteCode?.trim() ?? '';
      if (trimmedCode != kVolunteerInviteCode) {
        throw const InvalidInviteCodeException();
      }
    }

    final client = Supabase.instance.client;
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('註冊失敗：無法取得使用者資料');
    }

    // 將基本資料寫入 profiles。採 upsert 以相容於 trigger 先建好 row 的情境，
    // 並一併把 role 寫入，作為後續 RBAC 的依據。
    await client.from('profiles').upsert({
      'id': user.id,
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role.dbValue,
    });
  }

  /// 使用 Google OAuth 登入。成功後會透過 [onAuthStateChange] 收到事件，
  /// 由 [_ensureProfile] 自動補上 profiles 預設資料。
  Future<void> signInWithGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
    );
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  /// 若 profiles 尚未有此使用者，建立一筆基礎資料（OAuth 第一次登入用）。
  ///
  /// OAuth 流程沒有走 [signUp]，所以這裡一律以 [UserRole.elder] 預設帶入；
  /// 志工身分一律走「Email + 邀請碼」註冊路徑，避免 OAuth 自動晉升的風險。
  Future<void> _ensureProfile(User user) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

    final meta = user.userMetadata ?? const <String, dynamic>{};
    final name = (meta['full_name'] as String?) ??
        (meta['name'] as String?) ??
        '社區長輩';

    await client.from('profiles').insert({
      'id': user.id,
      'name': name,
      if (user.phone != null && user.phone!.isNotEmpty) 'phone': user.phone,
      'role': UserRole.elder.dbValue,
    });
  }
}
