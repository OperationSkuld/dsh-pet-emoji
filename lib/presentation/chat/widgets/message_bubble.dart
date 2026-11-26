import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/chat_message.dart';
import '../../../data/models/semantic_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rich_text_view.dart';
import '../../widgets/tag_chip.dart';

/// 对话气泡。用户靠右、浅蓝底；助手靠左、无底色纯文本 —— 与 DeepSeek 官方一致。
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.tagLabelOf,
    this.showSemantic = false,
    this.onRetry,
  });

  final ChatMessage message;
  final String Function(String tagId) tagLabelOf;
  final bool showSemantic;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 24,
        top: 10,
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[const _AssistantAvatar(), const SizedBox(width: 12)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (isUser)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: RichTextView(
                      text: message.content,
                      style: AppTheme.body,
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: message.content.isEmpty && message.isStreaming
                        ? const _TypingIndicator()
                        : RichTextView(
                            text: message.content,
                            style: AppTheme.body,
                          ),
                  ),
                if (!isUser && message.status == ChatStatus.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 15,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '回复中断',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.danger,
                          ),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: onRetry,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              foregroundColor: AppColors.primary,
                            ),
                            child: const Text(
                              '重试',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (!isUser && showSemantic && message.profile != null)
                  _SemanticStrip(
                    profile: message.profile!,
                    tagLabelOf: tagLabelOf,
                  ),
                if (!isUser && message.content.isNotEmpty)
                  _ActionRow(message: message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      alignment: Alignment.center,
      child: const Text('🐳', style: TextStyle(fontSize: 15)),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 5, top: 8, bottom: 8),
                child: Opacity(
                  opacity: 0.25 + 0.75 * _dotOpacity(i),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _dotOpacity(int index) {
    final phase = (_controller.value * 3 - index).clamp(0.0, 2.0);
    final value = phase <= 1 ? phase : 2 - phase;
    return value.clamp(0.0, 1.0);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _MiniAction(
            icon: Icons.copy_rounded,
            label: '复制',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: message.content));
              if (context.mounted) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('已复制'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemanticStrip extends StatelessWidget {
  const _SemanticStrip({required this.profile, required this.tagLabelOf});

  final SemanticProfile profile;
  final String Function(String tagId) tagLabelOf;

  @override
  Widget build(BuildContext context) {
    final tags = profile.topTags(6);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SoftTag('意图 ${profile.intent.label}', icon: Icons.bolt_rounded),
          SoftTag('强度 ${(profile.intensity * 100).round()}%'),
          for (final entry in tags)
            TagChip(
              label: tagLabelOf(entry.key),
              score: entry.value,
              showScore: true,
            ),
        ],
      ),
    );
  }
}
