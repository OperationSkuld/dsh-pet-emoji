import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../data/models/app_settings.dart';
import '../../platform/pet_window_service.dart';
import '../theme/app_theme.dart';
import 'pet_stage.dart';

/// 桌面小窗模式：无边框、置顶，只留宠物与一个迷你输入框。
class CompactPetPage extends StatefulWidget {
  const CompactPetPage({super.key, required this.services, required this.window});

  final AppServices services;
  final PetWindowService window;

  @override
  State<CompactPetPage> createState() => _CompactPetPageState();
}

class _CompactPetPageState extends State<CompactPetPage> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await widget.services.chat.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    final transparent = settings.petWindowBackground == PetWindowBackground.transparent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: widget.services.pet,
        builder: (context, _) {
          return Container(
            decoration: transparent
                ? null
                : BoxDecoration(
                    gradient: AppColors.stageGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1C1D1F).withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => widget.window.startDragging(),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '回到对话窗口',
                          onPressed: () => Navigator.of(context).pop(),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: PetStage(
                        pet: widget.services.pet,
                        tags: widget.services.tags,
                        scale: 1.2 * settings.petScale.clamp(0.8, 1.4),
                        showActions: true,
                        onBalance: () {},
                        onGallery: () {},
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: '说点什么…',
                              hintStyle: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _send,
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(30, 30),
                          ),
                          icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
