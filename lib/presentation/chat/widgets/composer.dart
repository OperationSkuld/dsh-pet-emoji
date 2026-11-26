import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_links.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tag_chip.dart';

/// 输入区。Enter 发送、Shift+Enter 换行，风格贴近 DeepSeek 官方对话框。
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    required this.model,
    required this.onModelChanged,
    required this.onBalance,
    required this.settings,
    this.compact = false,
    this.hintText = '给大肥鱼发消息…',
  });

  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final String model;
  final ValueChanged<String> onModelChanged;
  final VoidCallback onBalance;
  final VoidCallback settings;
  final bool compact;
  final String hintText;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (shift) return KeyEventResult.ignored;
    widget.onSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1D1F).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Focus(
            onKeyEvent: _handleKey,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: widget.compact ? 4 : 7,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 15, height: 1.5),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ModelPicker(
                model: widget.model,
                onChanged: widget.onModelChanged,
              ),
              const SizedBox(width: 8),
              _PillButton(
                icon: Icons.account_balance_wallet_outlined,
                label: '余额',
                onTap: widget.onBalance,
              ),
              const Spacer(),
              Text(
                widget.compact ? '' : 'Enter 发送 · Shift+Enter 换行',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(
                isGenerating: widget.isGenerating,
                onSend: widget.onSend,
                onStop: widget.onStop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: isGenerating ? AppColors.surfaceAlt : AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isGenerating ? onStop : onSend,
          child: Icon(
            isGenerating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            size: 19,
            color: isGenerating ? AppColors.textSecondary : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({required this.model, required this.onChanged});

  final String model;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '切换模型',
      initialValue: model,
      onSelected: onChanged,
      offset: const Offset(0, -8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => [
        for (final option in kSupportedModels)
          PopupMenuItem(
            value: option,
            height: 38,
            child: Row(
              children: [
                Icon(
                  option == model ? Icons.check_rounded : Icons.circle_outlined,
                  size: 14,
                  color: option == model
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Text(option, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
      child: SoftTag(model, icon: Icons.auto_awesome_outlined),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
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
      ),
    );
  }
}
