import 'package:flutter/material.dart';

import '../../data/models/animation_clip.dart';

/// 素材的原生像素尺寸，与 `assets/animations/*.gif` 完全一致。
///
/// 1× 显示时按 220×124 逻辑像素绘制，即「原版大小」——不做任何拉伸，
/// 所以不会再像之前 1.24×/1.65× 那样被双线性插值糊掉。
const double kPetNativeWidth = 220;
const double kPetNativeHeight = 124;

/// 桌宠本体：一张透明 GIF。
///
/// Flutter 的 `Image` 原生支持动态 GIF，三端表现一致，
/// 因此运行时不再依赖视频插件（WebM 母版的用途见 docs/ASSETS.md）。
///
/// 清晰度约定：
///   - [zoom] 为整数倍（2×/3×）时用 [FilterQuality.none]，放大后是一个像素
///     对应一个方块，边缘锐利——“放大但不模糊”；
///   - 1× 走默认双线性，在 100% 缩放下本身就是 1:1，不需要额外处理。
class PetView extends StatelessWidget {
  const PetView({
    super.key,
    required this.clip,
    this.zoom = 1,
    this.onTap,
    this.onDoubleTap,
    this.showShadow = true,
  });

  final AnimationClip clip;

  /// 整数倍放大（1 / 2 / 3）。非整数会被就近取整，避免出现半像素模糊。
  final double zoom;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final width = kPetNativeWidth * zoom;
    final height = kPetNativeHeight * zoom;
    // 整数倍放大用最近邻，保持像素锐利；1× 用双线性（此时基本是 1:1）
    final quality = zoom > 1.001 && _isInteger(zoom)
        ? FilterQuality.none
        : FilterQuality.medium;

    Widget image;
    if (clip.gifPath == null) {
      image = SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Text(
            '该动画暂无 GIF 预览',
            style: TextStyle(fontSize: 12, color: Color(0xFF9AA1AC)),
          ),
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
          fit: BoxFit.fill,
          filterQuality: quality,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: Text(
                '素材加载失败',
                style: TextStyle(fontSize: 12, color: Color(0xFF9AA1AC)),
              ),
            ),
          ),
        ),
      );
    }

    final content = SizedBox(
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
    );

    // 没有点击回调时不要包 GestureDetector：opaque 行为会把事件吞掉，
    // 使外层（表情库卡片）点不动。
    if (onTap == null && onDoubleTap == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: content,
    );
  }

  static bool _isInteger(double value) => (value - value.roundToDouble()).abs() < 0.001;
}
