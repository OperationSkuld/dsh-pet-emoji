import 'package:dsh_pet_emoji/app.dart';
import 'package:dsh_pet_emoji/app_services.dart';
import 'package:dsh_pet_emoji/data/repositories/animation_repository.dart';
import 'package:dsh_pet_emoji/data/repositories/settings_repository.dart';
import 'package:dsh_pet_emoji/data/repositories/tag_repository.dart';
import 'package:dsh_pet_emoji/platform/pet_window_service.dart';
import 'package:dsh_pet_emoji/presentation/widgets/pet_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 宽屏（桌面）布局的集成用例。
///
/// 单独成文件是有意的：同一个测试进程里第二次 pumpWidget 整个 App 会卡住
/// （GIF 解码 + 定时器叠加），拆开后 `flutter test` 会给每个文件独立 isolate。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('桌宠浮在最上层、可拖动，表情库点选后回主界面播放', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final services = AppServices(
      animations: await AnimationRepository.load(),
      tags: await TagRepository.load(),
      settingsRepository: await SettingsRepository.load(),
    );

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      DshPetApp(services: services, window: PetWindowService()),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 1) 右侧固定的桌宠侧栏已经移除
    expect(find.text('本地语义驱动'), findsNothing);

    // 2) 桌宠可在窗口内任意拖动，并记住位置
    final idleId = services.animations.idleClip.id;
    expect(services.pet.current.id, idleId, reason: '启动后先待机');

    final pet = find.byType(PetView).first;
    final before = tester.getTopLeft(pet);
    await tester.drag(pet, const Offset(-320, -260));
    // 不能用 pumpAndSettle：GIF 持续产帧，永远 settle 不了
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    final after = tester.getTopLeft(pet);
    expect(after.dx, lessThan(before.dx));
    expect(after.dy, lessThan(before.dy));
    expect(services.settings.hasPetOffset, isTrue, reason: '位置应写回设置');

    // 3) 表情库里点一张卡片 → 关闭表情库，主界面的桌宠开始播这一段
    final beforeGallery = services.pet.current.id;

    await tester.tap(find.byTooltip('表情库').hitTestable().first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GridView), findsOneWidget, reason: '表情库应已打开');

    // 直接点缩略图：PetView 没有点击回调时不再吞事件，应该穿透到卡片的 InkWell
    final thumb = find
        .descendant(of: find.byType(GridView), matching: find.byType(PetView))
        .first;
    await tester.tap(thumb);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GridView), findsNothing, reason: '应已回到主界面');
    // play() 会同时换片段与气泡，用它确认「是表情库触发的那一次播放」
    expect(services.pet.bubble, services.pet.current.name);
    expect(
      services.pet.current.id,
      isNot(beforeGallery),
      reason: '桌宠应换上新动画',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    services.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
