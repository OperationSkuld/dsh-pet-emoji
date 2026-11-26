import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 语义标签胶囊。默认展示标签中文名；`showScore` 时附带权重。
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.score,
    this.showScore = false,
    this.dense = true,
    this.onTap,
  });

  final String label;
  final double? score;
  final bool showScore;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = showScore && score != null
        ? '$label ${score!.toStringAsFixed(2)}'
        : label;
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: dense ? 11.5 : 12.5,
          height: 1.2,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: chip,
    );
  }
}

/// 中性胶囊，用于模型名、状态等。
class SoftTag extends StatelessWidget {
  const SoftTag(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
