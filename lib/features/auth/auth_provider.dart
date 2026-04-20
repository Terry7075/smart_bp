import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> signUp(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    final client = Supabase.instance.client;
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('註冊失敗：無法取得使用者資料');
    }

    // 將基本資料寫入 profiles。採 upsert 以相容於 trigger 先建好 row 的情境。
    await client.from('profiles').upsert({
      'id': user.id,
      'name': name.trim(),
      'phone': phone.trim(),
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

  /// 若 profiles 尚未有此使用者，建立一筆基礎資料。
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
    });
  }
}
