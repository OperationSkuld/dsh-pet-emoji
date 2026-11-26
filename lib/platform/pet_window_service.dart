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
/// 关于置顶：本应用**不使用** always-on-top。桌宠常驻前台会挡住别的窗口，
/// 而 Flutter 桌面端又无法做逐像素透明合成，压在最上层反而是干扰。
///
/// 已知限制：`transparent` 背景在 Windows 上可能退化为不透明窗口，
/// 此时会自动回落到圆角卡片，见 docs/ARCHITECTURE.md「桌面窗口」。
class PetWindowService {
  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static const Size chatSize = Size(1120, 780);
  static const Size chatMinimumSize = Size(880, 620);
  static const Size compactSize = Size(384, 468);
  static const Size compactMinimumSize = Size(260, 300);

  bool _compact = false;

  bool get isCompact => _compact;

  Future<void> initialize(AppSettings settings) async {
    if (!supported) return;
    try {
      await windowManager.ensureInitialized();
      final options = WindowOptions(
        size: chatSize,
        minimumSize: chatMinimumSize,
        center: true,
        backgroundColor: const Color(0xFFFFFFFF),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: '大肥鱼桌宠',
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
        // 明确关掉置顶：旧版本会把它设成 true，这里覆盖掉历史状态
        await windowManager.setAlwaysOnTop(false);
      });
    } on Exception catch (error) {
      // 无桌面插件（例如在测试环境或未注册平台）时静默降级为普通窗口。
      debugPrint('窗口初始化跳过：$error');
    }
  }

  /// 切换到「桌面小窗」：无边框、紧凑尺寸。
  ///
  /// 顺序很关键：先放开最小尺寸限制再改尺寸。默认最小尺寸是 880×620，
  /// 不放开的话 Windows 会把 384×468 顶回去，小窗内容挤在超大窗口里，
  /// 看着就像「布局错乱」。
  Future<void> enterCompact(AppSettings settings) async {
    if (!supported) return;
    _compact = true;
    final zoom = settings.normalizedPetZoom;
    try {
      await windowManager.setMinimumSize(compactMinimumSize);
      await windowManager.setResizable(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setBackgroundColor(
        settings.petWindowBackground == PetWindowBackground.transparent
            ? Colors.transparent
            : const Color(0xFFF7F8FB),
      );
      // 桌宠放大时窗口同步放宽，避免角色被裁
      await windowManager.setSize(
        Size(
          compactSize.width + (zoom - 1) * 150,
          compactSize.height + (zoom - 1) * 110,
        ),
      );
      await windowManager.center();
      await windowManager.show();
    } catch (error) {
      debugPrint('切换到桌面小窗失败：$error');
    }
  }

  /// 回到完整对话窗口。
  ///
  /// 必须把标题栏样式恢复成 [TitleBarStyle.normal]，否则窗口会一直停在
  /// 无边框状态——最小化 / 还原 / 关闭按钮就再也不出现了。
  Future<void> exitCompact() async {
    if (!supported) return;
    _compact = false;
    try {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setResizable(true);
      await windowManager.setBackgroundColor(const Color(0xFFFFFFFF));
      await windowManager.setMinimumSize(chatMinimumSize);
      await windowManager.setSize(chatSize);
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    } catch (error) {
      debugPrint('退出桌面小窗失败：$error');
    }
  }

  /// 兜底：无论从哪里退出，都确保回到「有边框、可缩放」的完整窗口。
  Future<void> restoreDefaultWindow() async {
    if (!supported || !_compact) return;
    await exitCompact();
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
