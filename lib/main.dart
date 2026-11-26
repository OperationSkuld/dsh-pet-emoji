import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';
import 'core/app_links.dart';
import 'core/logger.dart';
import 'data/repositories/animation_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/tag_repository.dart';
import 'platform/pet_window_service.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.verbose = kDebugMode;

  try {
    final animations = await AnimationRepository.load();
    final tags = await TagRepository.load();
    final settingsRepository = await SettingsRepository.load();

    final services = AppServices(
      animations: animations,
      tags: tags,
      settingsRepository: settingsRepository,
    );

    final window = PetWindowService();
    await window.initialize(settingsRepository.value);

    runApp(DshPetApp(services: services, window: window));
  } catch (error, stack) {
    Log.e('main', error, stack);
    runApp(_BootstrapErrorApp(message: '$error'));
  }
}

/// 素材或清单损坏时的兜底界面：直接把问题摊开，而不是白屏。
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🐳', style: TextStyle(fontSize: 42)),
                  const SizedBox(height: 14),
                  const Text(
                    '启动失败',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '请确认 assets/manifest/ 与 assets/animations/ 完整，'
                    '或重新执行 python tool/gen_manifest.py',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    kAppNameEn,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
