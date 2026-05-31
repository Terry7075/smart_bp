// 除智慧監控外，各模組「純邏輯」流程回歸測試（不需 Supabase / 裝置）。

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/core/notification_service.dart';
import 'package:smart_bp/features/learning/learning_content_models.dart';
import 'package:smart_bp/features/learning/learning_content_provider.dart';
import 'package:smart_bp/features/prescription/elder_prescription_sync.dart';
import 'package:smart_bp/features/prescription/prescription_models.dart';
import 'package:smart_bp/features/volunteer/batch_refill_models.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';

void main() {
  group('NotificationService notification id', () {
    test('同一 prescriptionId 產生穩定 base id', () {
      const id = '550e8400-e29b-41d4-a716-446655440000';
      expect(
        NotificationService.baseNotificationId(id),
        NotificationService.baseNotificationId(id),
      );
    });

    test('不同 prescriptionId 產生不同 base id', () {
      const a = '550e8400-e29b-41d4-a716-446655440000';
      const b = '660e8400-e29b-41d4-a716-446655440001';
      expect(
        NotificationService.baseNotificationId(a),
        isNot(NotificationService.baseNotificationId(b)),
      );
    });

    test('slot index 連續且 cancel 範圍大於排程 max', () {
      const id = '550e8400-e29b-41d4-a716-446655440000';
      final scheduled = NotificationService.allNotificationIdsFor(id);
      expect(scheduled.length,
          NotificationService.maxMedicationSlotsPerPrescription);
      expect(scheduled.first + scheduled.length - 1, scheduled.last);
    });
  });

  group('PrescriptionRecord', () {
    test('fromMap 保留 medications_detail 與 photo_storage_path', () {
      final rx = PrescriptionRecord.fromMap({
        'id': 'rx-1',
        'user_id': 'u-1',
        'medication_name': 'Aspirin',
        'pickup_date': '2026-06-01',
        'take_medicine_times': ['08:00', '19:00'],
        'medications_detail': [
          {'name': 'Aspirin', 'appearance': '白/圓形'},
        ],
        'photo_storage_path': 'uid/photo.jpg',
        'status': 'active',
        'source': 'ocr',
        'created_at': '2026-05-01T00:00:00Z',
      });
      expect(rx.medicationsDetail, hasLength(1));
      expect(rx.photoStoragePath, 'uid/photo.jpg');
      expect(rx.takeMedicineTimes, ['08:00', '19:00']);
    });

    test('copyWith 保留 photoStoragePath 與 medicationsDetail', () {
      final original = PrescriptionRecord.fromMap({
        'id': 'rx-1',
        'user_id': 'u-1',
        'medications_detail': [{'name': 'Metformin'}],
        'photo_storage_path': 'p.jpg',
        'status': 'active',
        'source': 'ocr',
        'created_at': '2026-05-01T00:00:00Z',
      });
      final updated = original.copyWith(medicationName: '新藥名');
      expect(updated.photoStoragePath, 'p.jpg');
      expect(updated.medicationsDetail, original.medicationsDetail);
      expect(updated.medicationName, '新藥名');
    });
  });

  group('elderHasPendingVerification', () {
    PrescriptionRecord rx({
      required String id,
      required String status,
      bool active = false,
    }) {
      return PrescriptionRecord(
        id: id,
        userId: 'elder-1',
        status: status,
        source: 'volunteer',
        createdAt: DateTime(2026, 5, 1),
      );
    }

    VolunteerTask task({
      required String id,
      VolunteerTaskStatus status = VolunteerTaskStatus.active,
    }) {
      return VolunteerTask.fromMap({
        'id': id,
        'elder_id': 'elder-1',
        'elder_name': '王伯伯',
        'raw_ocr_text': 'test',
        'status': status.dbValue,
        'created_at': '2026-05-01T00:00:00Z',
      });
    }

    test('pending_verification 藥單 → true', () {
      expect(
        elderHasPendingVerification(
          prescriptions: [rx(id: 't1', status: 'pending_verification')],
          tasks: const [],
        ),
        isTrue,
      );
    });

    test('任務 active 但藥單尚未同步 → true', () {
      expect(
        elderHasPendingVerification(
          prescriptions: const [],
          tasks: [task(id: 't1')],
        ),
        isTrue,
      );
    });

    test('任務 active 且藥單已 active → false', () {
      expect(
        elderHasPendingVerification(
          prescriptions: [rx(id: 't1', status: 'active', active: true)],
          tasks: [task(id: 't1')],
        ),
        isFalse,
      );
    });
  });

  group('groupPrescriptionsForBatchRefill', () {
    PrescriptionRecord activeRx({
      required String id,
      required DateTime pickup,
      String? hospital,
    }) {
      return PrescriptionRecord(
        id: id,
        userId: 'elder-$id',
        hospitalName: hospital,
        pickupDate: pickup,
        status: 'active',
        source: 'volunteer',
        createdAt: DateTime(2026, 1, 1),
      );
    }

    test('10 天內 active 藥單依領藥日分群', () {
      final today = DateTime(2026, 5, 31);
      final groups = groupPrescriptionsForBatchRefill(
        prescriptions: [
          activeRx(id: 'a', pickup: DateTime(2026, 6, 5), hospital: 'A 診所'),
          activeRx(id: 'b', pickup: DateTime(2026, 6, 5), hospital: 'B 診所'),
          activeRx(id: 'c', pickup: DateTime(2026, 7, 1)), // 超出 10 天
        ],
        elderNamesByUserId: const {'elder-a': '甲', 'elder-b': '乙', 'elder-c': '丙'},
        today: today,
      );
      expect(groups, hasLength(1));
      expect(groups.first.items, hasLength(2));
      expect(groups.first.pickupDate, DateTime(2026, 6, 5));
    });
  });

  group('LearningContent', () {
    test('fromMap 容忍 category/content_type 為 null', () {
      final item = LearningContent.fromMap({
        'id': 'lc-1',
        'created_at': '2026-05-01T00:00:00Z',
        'title': '測試',
        'category': null,
        'content_type': null,
        'url': 'https://example.com',
      });
      expect(item.category, '');
      expect(item.contentType, '');
      expect(item.title, '測試');
    });

    test('filterByCategories 只保留指定分類', () {
      final all = [
        LearningContent.fromMap({
          'id': '1',
          'created_at': '2026-05-01T00:00:00Z',
          'title': '防詐',
          'category': LearningCategory.antiFraud,
          'content_type': LearningContentType.article,
          'url': 'https://a.com',
        }),
        LearningContent.fromMap({
          'id': '2',
          'created_at': '2026-05-02T00:00:00Z',
          'title': '客語',
          'category': LearningCategory.hakkaVocab,
          'content_type': LearningContentType.article,
          'url': 'https://b.com',
        }),
      ];
      final filtered = filterByCategories(all, LearningCategory.communityLearning);
      expect(filtered, hasLength(1));
      expect(filtered.first.category, LearningCategory.antiFraud);
    });
  });
}
