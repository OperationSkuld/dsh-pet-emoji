import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 桌宠头顶的气泡。浮动桌宠与「桌宠」页共用。
class PetBubble extends StatelessWidget {
  const PetBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1C1D1F).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// 气泡进出场：缩放 + 淡入。
class PetBubbleHost extends StatelessWidget {
  const PetBubbleHost({super.key, required this.text, this.placeholderHeight = 4});

  final String? text;
  final double placeholderHeight;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.94,
            end: 1,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: text == null
          // 宽度必须是 0 而不是「未指定」：浮动桌宠给气泡的是无界宽度约束，
          // 只给 height 的 SizedBox 会要求无限宽，进而把整个 Column 撑成无限宽。
          ? SizedBox(
              key: const ValueKey('empty'),
              width: 0,
              height: placeholderHeight,
            )
          : PetBubble(key: ValueKey(text), text: text!),
    );
  }
}
