import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/chat_message.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';
import 'chat_controller.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';

/// 对话主界面。布局与配色参考 DeepSeek 官方：白底、单列、低干扰。
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.services,
    required this.onOpenSettings,
    required this.onOpenBalance,
    required this.onOpenGallery,
    this.onToggleCompactWindow,
    this.showHeader = true,
    this.compact = false,
  });

  final AppServices services;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenBalance;
  final VoidCallback onOpenGallery;
  final VoidCallback? onToggleCompactWindow;
  final bool showHeader;
  final bool compact;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  ChatController get _chat => widget.services.chat;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChatChanged);
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.maxScrollExtent - position.pixels > 220) return;
      _scroll.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _chat.isGenerating) return;
    _input.clear();
    await _chat.send(text);
  }

  Future<void> _updateSettings(AppSettings next) =>
      widget.services.updateSettings(next);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_chat, widget.services]),
      builder: (context, _) {
        final settings = widget.services.settings;
        final messages = _chat.messages;
        return Column(
          children: [
            if (widget.showHeader)
              _HeaderBar(
                chat: _chat,
                services: widget.services,
                onOpenSettings: widget.onOpenSettings,
                onOpenGallery: widget.onOpenGallery,
                onToggleCompact: widget.onToggleCompactWindow,
              ),
            if (!settings.isConfigured)
              _ConfigBanner(onTap: widget.onOpenSettings),
            Expanded(
              child: messages.isEmpty
                  ? _WelcomeView(
                      configured: settings.isConfigured,
                      onPick: (text) {
                        _input.text = text;
                        _send();
                      },
                      onOpenSettings: widget.onOpenSettings,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        widget.compact ? 16 : 24,
                        12,
                        widget.compact ? 16 : 24,
                        16,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 780),
                            child: MessageBubble(
                              message: message,
                              tagLabelOf: widget.services.tags.labelOf,
                              showSemantic: settings.showSemanticPanel,
                              onRetry: message.status == ChatStatus.failed
                                  ? _chat.retryLast
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                widget.compact ? 12 : 20,
                0,
                widget.compact ? 12 : 20,
                widget.compact ? 12 : 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Composer(
                        controller: _input,
                        isGenerating: _chat.isGenerating,
                        onSend: _send,
                        onStop: _chat.stop,
                        model: settings.model,
                        onModelChanged: (model) =>
                            _updateSettings(settings.copyWith(model: model)),
                        onBalance: widget.onOpenBalance,
                        settings: widget.onOpenSettings,
                        compact: widget.compact,
                      ),
                      _FooterHint(
                        chat: _chat,
                        tagLabelOf: widget.services.tags.labelOf,
                        showSemantic: settings.showSemanticPanel,
                        onToggleSemantic: () => _updateSettings(
                          settings.copyWith(
                            showSemanticPanel: !settings.showSemanticPanel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.chat,
    required this.services,
    required this.onOpenSettings,
    required this.onOpenGallery,
    this.onToggleCompact,
  });

  final ChatController chat;
  final AppServices services;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGallery;
  final VoidCallback? onToggleCompact;

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    final balance = chat.balance?.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 窄屏（手机竖屏）只留必要元素，避免标题栏溢出。
        final roomy = constraints.maxWidth >= 520;
        return Container(
          height: 58,
          padding: EdgeInsets.symmetric(horizontal: roomy ? 20 : 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4D6BFE), Color(0xFF7B93FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: const Text('🐳', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 10),
              const Text(
                '大肥鱼',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (roomy) const SoftTag('语义表情桌宠'),
              if (roomy && services.isDesktop) ...[
                const SizedBox(width: 8),
                SoftTag(
                  services.isWindows ? 'Windows' : 'Desktop',
                  icon: Icons.desktop_windows_outlined,
                ),
              ],
              const Spacer(),
              if (roomy && balance != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '余额 ${balance.formatted}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              IconButton(
                tooltip: settings.showSemanticPanel ? '隐藏语义标签' : '显示语义标签',
                onPressed: () => services.updateSettings(
                  settings.copyWith(
                    showSemanticPanel: !settings.showSemanticPanel,
                  ),
                ),
                icon: Icon(
                  Icons.local_offer_outlined,
                  size: 18,
                  color: settings.showSemanticPanel
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
              if (onToggleCompact != null)
                IconButton(
                  tooltip: '桌面小窗',
                  onPressed: onToggleCompact,
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                ),
              IconButton(
                tooltip: '表情库',
                onPressed: onOpenGallery,
                icon: const Icon(
                  Icons.grid_view_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              IconButton(
                tooltip: '设置',
                onPressed: onOpenSettings,
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfigBanner extends StatelessWidget {
  const _ConfigBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBEB),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF3E6C4))),
          ),
          child: const Row(
            children: [
              Icon(Icons.key_outlined, size: 15, color: Color(0xFF9A7B2E)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '还没配置 DeepSeek API Key，桌宠暂时只能卖萌。点这里填入。',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF8A6D24)),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF9A7B2E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({
    required this.chat,
    required this.tagLabelOf,
    required this.showSemantic,
    required this.onToggleSemantic,
  });

  final ChatController chat;
  final String Function(String tagId) tagLabelOf;
  final bool showSemantic;
  final VoidCallback onToggleSemantic;

  @override
  Widget build(BuildContext context) {
    final profile = chat.lastProfile;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (profile != null && !showSemantic) ...[
            InkWell(
              onTap: onToggleSemantic,
              borderRadius: BorderRadius.circular(999),
              child: Text(
                '本次语义：${profile.topTags(3).map((e) => tagLabelOf(e.key)).join(' · ')}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            '内容由 DeepSeek 生成，桌宠表情为本地语义匹配',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({
    required this.configured,
    required this.onPick,
    required this.onOpenSettings,
  });

  final bool configured;
  final ValueChanged<String> onPick;
  final VoidCallback onOpenSettings;

  static const List<String> _suggestions = [
    '今天有点累，陪我说说话',
    '帮我写一个 Flutter 的圆角按钮',
    '看看我的 DeepSeek 余额还剩多少',
    '晚饭吃什么好呢？',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4D6BFE), Color(0xFF8AA0FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4D6BFE).withValues(alpha: 0.25),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('🐳', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(height: 18),
              const Text(
                '我是大肥鱼，今天想聊点什么？',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '聊完之后，我会根据对话的语义挑一段动画给你看。',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final text in _suggestions)
                    _SuggestionCard(text: text, onTap: () => onPick(text)),
                ],
              ),
              if (!configured) ...[
                const SizedBox(height: 26),
                OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.key_outlined, size: 15),
                  label: const Text('填入 DeepSeek API Key'),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
