import 'package:flutter_test/flutter_test.dart';
import 'package:mingde_transport/models/profile.dart';

void main() {
  group('Profile', () {
    Profile profileWithRole(String role) => Profile(
          id: 'user-id',
          email: 'user@example.com',
          fullName: '測試使用者',
          phone: '0912345678',
          role: role,
        );

    test('maps database roles to user-facing Chinese labels', () {
      expect(profileWithRole('elder').roleLabel, '長者 / 家屬');
      expect(profileWithRole('driver').roleLabel, '司機');
      expect(profileWithRole('admin').roleLabel, '管理員');
    });

    test('falls back to elder label for unknown roles', () {
      expect(profileWithRole('unexpected').roleLabel, '長者 / 家屬');
    });

    test('parses emergency contact fields', () {
      final profile = Profile.fromJson({
        'id': 'user-id',
        'email': 'user@example.com',
        'full_name': '測試使用者',
        'phone': '0912345678',
        'role': 'elder',
        'emergency_contact_name': '王小明',
        'emergency_contact_phone': '0987654321',
        'emergency_contact_relation': '家屬',
      });

      expect(profile.emergencyContactName, '王小明');
      expect(profile.emergencyContactPhone, '0987654321');
      expect(profile.emergencyContactRelation, '家屬');
    });
  });
}
