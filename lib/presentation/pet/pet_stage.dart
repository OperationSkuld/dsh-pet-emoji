import 'package:flutter/material.dart';

import '../../data/models/animation_clip.dart';
import '../../data/repositories/tag_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_view.dart';
import '../widgets/tag_chip.dart';
import 'pet_controller.dart';

/// 桌宠舞台：气泡 + 本体 + 快捷动作。
///
/// 桌面侧边栏、移动端「桌宠」页、无边框小窗共用这一个组件，
/// 只通过 [scale] 与 [showActions] 调整密度。
class PetStage extends StatelessWidget {
  const PetStage({
    super.key,
    required this.pet,
    required this.tags,
    this.scale = 1.0,
    this.showActions = true,
    this.showTags = true,
    this.onBalance,
    this.onGallery,
    this.onTapPet,
  });

  final PetController pet;
  final TagRepository tags;
  final double scale;
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
            _BubbleHost(text: pet.bubble),
            const SizedBox(height: 10),
            PetView(
              clip: clip,
              scale: scale,
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

class _BubbleHost extends StatelessWidget {
  const _BubbleHost({required this.text});

  final String? text;

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
          ? const SizedBox(height: 4, key: ValueKey('empty'))
          : _Bubble(key: ValueKey(text), text: text!),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.text});

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
