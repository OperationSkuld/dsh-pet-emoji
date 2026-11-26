import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../data/models/app_settings.dart';

/// 桌面窗口能力封装。
///
/// 只在 Windows / macOS / Linux 上真正调用原生接口；Android / iOS
/// 走空实现，因此 UI 层可以无平台判断地调用。
///
/// 已知限制：Flutter 桌面端不做逐像素透明合成，`transparent` 背景在
/// Windows 上可能退化为不透明窗口，此时会自动回落到圆角卡片，见
/// docs/ARCHITECTURE.md「桌面窗口」。
class PetWindowService {
  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static const Size chatSize = Size(1120, 780);
  static const Size compactSize = Size(384, 468);

  bool _compact = false;

  bool get isCompact => _compact;

  Future<void> initialize(AppSettings settings) async {
    if (!supported) return;
    try {
      await windowManager.ensureInitialized();
      final options = WindowOptions(
        size: chatSize,
        minimumSize: const Size(880, 620),
        center: true,
        backgroundColor: const Color(0xFFFFFFFF),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: '大肥鱼桌宠',
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setAlwaysOnTop(settings.petWindowAlwaysOnTop);
      });
    } on Exception catch (error) {
      // 无桌面插件（例如在测试环境或未注册平台）时静默降级为普通窗口。
      debugPrint('窗口初始化跳过：$error');
    }
  }

  /// 切换到「桌面小窗」：无边框、置顶、紧凑尺寸。
  Future<void> enterCompact(AppSettings settings, double scale) async {
    if (!supported) return;
    _compact = true;
    try {
      await windowManager.setResizable(false);
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(settings.petWindowAlwaysOnTop);
      await windowManager.setBackgroundColor(
        settings.petWindowBackground == PetWindowBackground.transparent
            ? Colors.transparent
            : const Color(0xFFF7F8FB),
      );
      await windowManager.setSize(
        Size(compactSize.width * scale.clamp(0.8, 1.4), compactSize.height * scale.clamp(0.8, 1.4)),
      );
      await windowManager.center();
      await windowManager.show();
    } catch (error) {
      debugPrint('切换到桌面小窗失败：$error');
    }
  }

  /// 回到完整对话窗口。
  Future<void> exitCompact() async {
    if (!supported) return;
    _compact = false;
    try {
      await windowManager.setResizable(true);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setBackgroundColor(const Color(0xFFFFFFFF));
      await windowManager.setSize(chatSize);
      await windowManager.center();
      await windowManager.show();
    } catch (error) {
      debugPrint('退出桌面小窗失败：$error');
    }
  }

  Future<void> setAlwaysOnTop(bool value) async {
    if (!supported) return;
    try {
      await windowManager.setAlwaysOnTop(value);
    } catch (error) {
      debugPrint('设置置顶失败：$error');
    }
  }

  /// 拖动无边框窗口（小窗模式下由标题区触发）。
  Future<void> startDragging() async {
    if (!supported) return;
    try {
      await windowManager.startDragging();
    } catch (error) {
      debugPrint('窗口拖动失败：$error');
    }
  }
}
