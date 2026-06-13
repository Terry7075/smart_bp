class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;

  bool get isComplete =>
      (fullName?.trim().isNotEmpty ?? false) && (phone?.trim().isNotEmpty ?? false);
  bool get isElder => role == 'elder';
  bool get isDriver => role == 'driver';
  // 整合 smart_bp：志工(volunteer)在交通模組中視同管理員。
  bool get isAdmin => role == 'admin' || role == 'volunteer';
  String get roleLabel => switch (role) {
        'admin' => '管理員',
        'volunteer' => '管理員',
        'driver' => '司機',
        _ => '長者 / 家屬',
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        // smart_bp profiles 使用 name 欄位（相容舊欄位 full_name）。
        fullName: (json['name'] as String?) ?? json['full_name'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'elder',
        avatarUrl: json['avatar_url'] as String?,
        emergencyContactName: json['emergency_contact_name'] as String?,
        emergencyContactPhone: json['emergency_contact_phone'] as String?,
        emergencyContactRelation: json['emergency_contact_relation'] as String?,
      );
}
