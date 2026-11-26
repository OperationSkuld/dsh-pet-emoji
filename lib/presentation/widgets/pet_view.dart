import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/animation_clip.dart';

/// 运行时素材的原生画布尺寸：640×360 的动画 WebP，与 WebM 母版完全一致。
///
/// 注意这是**画布**尺寸，不是角色尺寸。角色实际占多大由每段素材的
/// `contentRect` 决定（见 [AnimationClip.contentRect]），排版用的是角色尺寸，
/// 否则气泡与操作条会离角色很远。
const double kPetNativeWidth = 640;
const double kPetNativeHeight = 360;

/// 角色脚下的柔和投影，随缩放等比变化（相对内容高度的比例）。
const double kPetShadowHeight = 14;

/// 桌宠本体：一张带 alpha 的动画 WebP。
///
/// Flutter 的 `Image` 原生支持多帧 WebP + alpha，三端表现一致，
/// 因此运行时不再依赖视频插件（WebM 母版的用途见 docs/ASSETS.md）。
///
/// 两个尺寸概念要分清：
///   - **画布**：640×360，图像按它绘制，1:1 时就是母版像素；
///   - **内容框**：角色真正占据的矩形，布局只占这么大，画布上多余的
///     透明区域被裁掉——这样「角色到按钮的距离」才是可预期的。
///
/// 清晰度约定：
///   - 有效倍率 ≥ 2 且为整数时用 [FilterQuality.none]，一个像素一个方块，
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

  /// 显示倍率：0.5（半尺寸）/ 1（原生尺寸）。
  final double zoom;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rect = clip.contentRect;
        final naturalWidth = kPetNativeWidth * rect.width;
        final naturalHeight = kPetNativeHeight * rect.height;
        final shadowNatural = showShadow ? kPetShadowHeight : 0.0;

        // 有效倍率：先取设定倍率，再按容器可用空间等比缩小（只缩不放）。
        // 宽和高都要算进去——只按宽缩会在「高度受限」的容器里溢出
        // （表情库缩略图、手机桌宠页都踩过）。
        var scale = zoom;
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        if (maxWidth.isFinite && maxWidth > 0 && naturalWidth > 0) {
          scale = math.min(scale, maxWidth / naturalWidth);
        }
        if (maxHeight.isFinite && maxHeight > 0) {
          scale = math.min(scale, maxHeight / (naturalHeight + shadowNatural));
        }
        scale = math.max(scale, 0.01);

        final contentWidth = naturalWidth * scale;
        final contentHeight = naturalHeight * scale;
        final shadowHeight = shadowNatural * scale;
        // 整数倍放大用最近邻，保持像素锐利；其余（1:1 与缩小）用双线性
        final quality = scale >= 2 && _isInteger(scale)
            ? FilterQuality.none
            : FilterQuality.medium;

        return _buildContent(
          contentWidth: contentWidth,
          contentHeight: contentHeight,
          shadowHeight: shadowHeight,
          scale: scale,
          rect: rect,
          quality: quality,
        );
      },
    );
  }

  Widget _buildContent({
    required double contentWidth,
    required double contentHeight,
    required double shadowHeight,
    required double scale,
    required Rect rect,
    required FilterQuality quality,
  }) {
    final fullWidth = kPetNativeWidth * scale;
    final fullHeight = kPetNativeHeight * scale;

    Widget placeholder(String text) => SizedBox(
      width: contentWidth,
      height: contentHeight,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9AA1AC)),
        ),
      ),
    );

    Widget image;
    if (clip.animPath == null) {
      image = placeholder('该动画暂无预览');
    } else {
      image = AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Image.asset(
          clip.animPath!,
          key: ValueKey(clip.id),
          width: fullWidth,
          height: fullHeight,
          fit: BoxFit.fill,
          filterQuality: quality,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => placeholder('素材加载失败'),
        ),
      );
    }

    // 只露出内容框那一块：图像仍按画布尺寸绘制，靠负偏移把内容框挪到原点，
    // 外层 ClipRect 裁掉画布上多余的透明区域。
    final cropped = SizedBox(
      width: contentWidth,
      height: contentHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(-rect.left * fullWidth, -rect.top * fullHeight),
            child: image,
          ),
        ),
      ),
    );

    // 阴影的高度必须与 content 的高度算法严格一致，否则 Column 会溢出
    final content = SizedBox(
      width: contentWidth,
      height: contentHeight + shadowHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cropped,
          if (shadowHeight > 0)
            Container(
              width: contentWidth * 0.42,
              height: shadowHeight * (10 / kPetShadowHeight),
              margin: EdgeInsets.only(top: shadowHeight * (4 / kPetShadowHeight)),
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

  static bool _isInteger(double value) =>
      (value - value.roundToDouble()).abs() < 0.001;
}
