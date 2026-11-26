import 'package:flutter/material.dart';

import '../../data/models/animation_clip.dart';
import '../../data/repositories/tag_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_view.dart';
import '../widgets/tag_chip.dart';
import 'pet_bubble.dart';
import 'pet_controller.dart';

/// 桌宠舞台：气泡 + 本体 + 快捷动作。
///
/// 移动端「桌宠」页与无边框小窗共用这一个组件；
/// 桌面宽屏改用可自由拖动的 [FloatingPet]，不再占用固定区域。
class PetStage extends StatelessWidget {
  const PetStage({
    super.key,
    required this.pet,
    required this.tags,
    this.zoom = 1,
    this.showActions = true,
    this.showTags = true,
    this.onBalance,
    this.onGallery,
    this.onTapPet,
  });

  final PetController pet;
  final TagRepository tags;

  /// 整数倍放大，1× 即素材原生尺寸。
  final double zoom;
  final bool showActions;
  final bool showTags;
  final VoidCallback? onBalance;
  final VoidCallback? onGallery;
  final VoidCallback? onTapPet;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pet,
      builder: (context, _) {
        final clip = pet.current;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            PetBubbleHost(text: pet.bubble),
            const SizedBox(height: 10),
            PetView(
              clip: clip,
              zoom: zoom,
              onTap: () {
                pet.onTap();
                onTapPet?.call();
              },
              onDoubleTap: pet.toggleSleep,
            ),
            const SizedBox(height: 6),
            if (showTags) _TagLine(clip: clip, tags: tags),
            if (showActions) ...[
              const SizedBox(height: 18),
              _ActionBar(pet: pet, onBalance: onBalance, onGallery: onGallery),
            ],
          ],
        );
      },
    );
  }
}

class _TagLine extends StatelessWidget {
  const _TagLine({required this.clip, required this.tags});

  final AnimationClip clip;
  final TagRepository tags;

  @override
  Widget build(BuildContext context) {
    final entries = clip.tags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in entries.take(3))
          TagChip(
            label: tags.labelOf(entry.key),
            score: entry.value,
            showScore: false,
            dense: true,
          ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.pet, this.onBalance, this.onGallery});

  final PetController pet;
  final VoidCallback? onBalance;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _Action(
          icon: Icons.pan_tool_alt_outlined,
          label: '摸摸',
          onTap: pet.onTap,
        ),
        _Action(
          icon: pet.sleeping ? Icons.wb_sunny_outlined : Icons.bedtime_outlined,
          label: pet.sleeping ? '叫醒' : '睡一觉',
          onTap: pet.toggleSleep,
        ),
        if (onBalance != null)
          _Action(
            icon: Icons.account_balance_wallet_outlined,
            label: '余额',
            onTap: onBalance!,
          ),
        if (onGallery != null)
          _Action(
            icon: Icons.grid_view_rounded,
            label: '表情库',
            onTap: onGallery!,
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
