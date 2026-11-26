import 'dart:io';

import 'package:flutter/foundation.dart';

import 'core/app_links.dart';
import 'data/models/app_settings.dart';
import 'data/repositories/animation_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/tag_repository.dart';
import 'data/services/deepseek_client.dart';
import 'domain/semantic/animation_selector.dart';
import 'domain/semantic/semantic_analyzer.dart';
import 'presentation/chat/chat_controller.dart';
import 'presentation/pet/pet_controller.dart';

/// 应用级依赖容器：仓库、领域服务与两个控制器。
///
/// 刻意不引入状态管理框架：`ChangeNotifier` + `InheritedNotifier` 足够，
/// 也让「语义 → 动画」的链路保持可读。
class AppServices extends ChangeNotifier {
  AppServices({
    required this.animations,
    required this.tags,
    required this.settingsRepository,
  }) {
    analyzer = SemanticAnalyzer.fromRepository(tags);
    selector = AnimationSelector(repository: animations);
    pet = PetController(
      repository: animations,
      selector: selector,
      ambient: settingsRepository.value.ambientAnimations,
    );
    chat = ChatController(
      analyzer: analyzer,
      tags: tags,
      pet: pet,
      clientFactory: clientFor,
      settingsReader: () => settingsRepository.value,
    );
    pet.start();
  }

  final AnimationRepository animations;
  final TagRepository tags;
  final SettingsRepository settingsRepository;

  late final SemanticAnalyzer analyzer;
  late final AnimationSelector selector;
  late final PetController pet;
  late final ChatController chat;

  AppSettings get settings => settingsRepository.value;

  bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  bool get isWindows => !kIsWeb && Platform.isWindows;

  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  DeepSeekClient clientFor(AppSettings value) => DeepSeekClient(
    baseUrl: value.baseUrl.isEmpty ? kDefaultBaseUrl : value.baseUrl,
    apiKey: value.apiKey,
  );

  Future<void> updateSettings(AppSettings next) async {
    await settingsRepository.save(next);
    pet.setAmbientEnabled(next.ambientAnimations);
    notifyListeners();
  }

  @override
  void dispose() {
    pet.dispose();
    chat.dispose();
    super.dispose();
  }
}
