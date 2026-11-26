import 'package:dsh_pet_emoji/data/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('桌宠倍率', () {
    test('合法倍率保持档位不变', () {
      for (final value in AppSettings.petZoomSteps) {
        final settings = AppSettings(petZoom: value);
        expect(settings.normalizedPetZoom, value);
      }
    });

    test('历史遗留的小数缩放被吸附到最近档位', () {
      // 旧版本存的是 0.8~1.6 的连续缩放
      expect(const AppSettings(petZoom: 1.24).normalizedPetZoom, 1);
      expect(const AppSettings(petZoom: 1.65).normalizedPetZoom, 1);
      expect(const AppSettings(petZoom: 0.8).normalizedPetZoom, 1);
    });

    test('已下线的 2× 档位回落到原尺寸', () {
      // 2× 在 1.2.0 移除：老用户存的 2 不应该把界面撑爆
      expect(const AppSettings(petZoom: 2).normalizedPetZoom, 1);
      expect(const AppSettings(petZoom: 5).normalizedPetZoom, 1);
      expect(const AppSettings(petZoom: 0.2).normalizedPetZoom, 0.5);
    });

    test('只保留半尺寸与原尺寸两档', () {
      expect(AppSettings.petZoomSteps, [0.5, 1]);
    });
  });

  group('浮动位置', () {
    test('默认未拖动时是 -1 哨兵', () {
      const settings = AppSettings();
      expect(settings.petOffsetX, -1);
      expect(settings.hasPetOffset, isFalse);
    });

    test('记录过后视为已定位', () {
      const settings = AppSettings(petOffsetX: 120, petOffsetY: 80);
      expect(settings.hasPetOffset, isTrue);
    });

    test('copyWith 能单独更新位置而保留倍率', () {
      const settings = AppSettings(petZoom: 0.5);
      final moved = settings.copyWith(petOffsetX: 40, petOffsetY: 60);
      expect(moved.petZoom, 0.5);
      expect(moved.hasPetOffset, isTrue);
    });
  });
}
