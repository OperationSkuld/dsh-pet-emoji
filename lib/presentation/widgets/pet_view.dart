import 'package:flutter/material.dart';

import '../../data/models/animation_clip.dart';

/// 运行时素材的原生像素尺寸：640×360 的动画 WebP，与 WebM 母版完全一致。
///
/// 1× 显示时按 640×360 逻辑像素绘制，即「和母版一样大小」——不做任何拉伸；
/// 0.5× 是降采样（依然锐利），2× 用最近邻整数放大（硬边不糊）。
const double kPetNativeWidth = 640;
const double kPetNativeHeight = 360;

/// 桌宠本体：一张透明 GIF。
///
/// Flutter 的 `Image` 原生支持动态 GIF，三端表现一致，
/// 因此运行时不再依赖视频插件（WebM 母版的用途见 docs/ASSETS.md）。
///
/// 清晰度约定：
///   - [zoom] ≥ 2 的整数倍用 [FilterQuality.none]，一个像素对应一个方块，
///     边缘锐利——“放大但不模糊”；
///   - 1×（1:1）与 0.5×（降采样）走双线性，前者本身就是 1:1，后者是缩小。
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

  /// 显示倍率：0.5（半尺寸）/ 1（原生尺寸）/ 2（整数放大）。
  final double zoom;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    // 容器比素材窄时等比缩小（只缩不放）：表情库缩略图、手机页签、小窗都靠这个
    // 兜底，避免 640 宽的素材把布局撑破。缩小属于降采样，不会糊。
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = kPetNativeWidth * zoom;
        final limit = constraints.maxWidth;
        if (limit.isFinite && limit > 0 && limit < width) {
          width = limit;
        }
        final height = width * kPetNativeHeight / kPetNativeWidth;
        // 整数倍放大用最近邻，保持像素锐利；其余（1:1 与缩小）用双线性
        final quality = zoom >= 2 && _isInteger(zoom)
            ? FilterQuality.none
            : FilterQuality.medium;
        return _buildContent(width, height, quality);
      },
    );
  }

  Widget _buildContent(double width, double height, FilterQuality quality) {

    Widget image;
    if (clip.animPath == null) {
      image = SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Text(
            '该动画暂无预览',
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
          clip.animPath!,
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

    final shadowHeight = showShadow ? 14.0 * (width / (kPetNativeWidth * zoom)) : 0.0;
    final content = SizedBox(
      width: width,
      height: height + shadowHeight,
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
