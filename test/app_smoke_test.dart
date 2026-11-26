import 'package:dsh_pet_emoji/app.dart';
import 'package:dsh_pet_emoji/app_services.dart';
import 'package:dsh_pet_emoji/data/repositories/animation_repository.dart';
import 'package:dsh_pet_emoji/data/repositories/settings_repository.dart';
import 'package:dsh_pet_emoji/data/repositories/tag_repository.dart';
import 'package:dsh_pet_emoji/platform/pet_window_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首页可渲染，并能切到桌宠页签', (tester) async {
    SharedPreferences.setMockInitialValues({'dsh.model': 'deepseek-chat'});
    final settings = await SettingsRepository.load();
    final animations = await AnimationRepository.load();
    final tags = await TagRepository.load();

    final services = AppServices(
      animations: animations,
      tags: tags,
      settingsRepository: settings,
    );

    await tester.pumpWidget(
      DshPetApp(services: services, window: PetWindowService()),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 欢迎页与未配置提示都应出现。
    expect(find.text('我是大肥鱼，今天想聊点什么？'), findsOneWidget);
    expect(find.textContaining('还没配置 DeepSeek API Key'), findsOneWidget);
    expect(find.text('对话'), findsOneWidget);

    // 切到桌宠页签，桌宠与快捷动作应在场。
    await tester.tap(find.text('桌宠'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('摸摸'), findsOneWidget);
    expect(find.text('睡一觉'), findsOneWidget);

    // 卸载并释放控制器，避免定时器泄漏。
    await tester.pumpWidget(const SizedBox.shrink());
    services.dispose();
  });
}
