import 'package:flutter/material.dart';

import '../../data/models/animation_clip.dart';

/// 桌宠本体：一张透明 GIF。
///
/// Flutter 的 `Image` 原生支持动态 GIF，三端表现一致，
/// 因此运行时不再依赖视频插件（WebM 母版的用途见 docs/ASSETS.md）。
class PetView extends StatelessWidget {
  const PetView({
    super.key,
    required this.clip,
    this.scale = 1.0,
    this.onTap,
    this.onDoubleTap,
    this.showShadow = true,
  });

  final AnimationClip clip;
  final double scale;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final width = 220 * scale;
    final height = 124 * scale;

    Widget image;
    if (clip.gifPath == null) {
      image = SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Text('该动画暂无 GIF 预览', style: TextStyle(fontSize: 12, color: Color(0xFF9AA1AC))),
        ),
      );
    } else {
      image = AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Image.asset(
          clip.gifPath!,
          key: ValueKey(clip.id),
          width: width,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: Text('素材加载失败', style: TextStyle(fontSize: 12, color: Color(0xFF9AA1AC))),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: SizedBox(
        width: width,
        height: height + (showShadow ? 14 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            image,
            if (showShadow)
              Container(
                width: width * 0.42,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4D6BFE).withValues(alpha: 0.14),
                      const Color(0xFF4D6BFE).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
