import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../platform/pet_window_service.dart';
import '../balance/balance_sheet.dart';
import '../chat/chat_page.dart';
import '../gallery/gallery_page.dart';
import '../settings/settings_page.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';
import 'compact_pet_page.dart';
import 'pet_stage.dart';

/// 应用外壳：宽屏用「对话 + 桌宠侧栏」，窄屏用底部双页签。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.services, required this.window});

  final AppServices services;
  final PetWindowService window;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final TextEditingController _miniInput = TextEditingController();

  @override
  void dispose() {
    _miniInput.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          services: widget.services,
          onToggleCompact: widget.services.isDesktop ? _enterCompact : null,
        ),
      ),
    );
  }

  void _openGallery() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryPage(services: widget.services),
      ),
    );
  }

  void _openBalance() => showBalanceSheet(context, widget.services);

  Future<void> _enterCompact() async {
    final settings = widget.services.settings;
    await widget.window.enterCompact(settings, settings.petScale);
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            CompactPetPage(services: widget.services, window: widget.window),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    await widget.window.exitCompact();
  }

  Future<void> _sendFromPetTab() async {
    final text = _miniInput.text.trim();
    if (text.isEmpty) return;
    _miniInput.clear();
    setState(() => _tab = 0);
    await widget.services.chat.send(text);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000 && widget.services.isDesktop;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: ChatPage(
                    services: widget.services,
                    onOpenSettings: _openSettings,
                    onOpenBalance: _openBalance,
                    onOpenGallery: _openGallery,
                    onToggleCompactWindow: _enterCompact,
                  ),
                ),
                _PetSidebar(
                  services: widget.services,
                  onOpenBalance: _openBalance,
                  onOpenGallery: _openGallery,
                  onEnterCompact: _enterCompact,
                  onOpenSettings: _openSettings,
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              ChatPage(
                services: widget.services,
                onOpenSettings: _openSettings,
                onOpenBalance: _openBalance,
                onOpenGallery: _openGallery,
                onToggleCompactWindow: widget.services.isDesktop
                    ? _enterCompact
                    : null,
                compact: constraints.maxWidth < 520,
              ),
              _PetTab(
                services: widget.services,
                controller: _miniInput,
                onSend: _sendFromPetTab,
                onOpenBalance: _openBalance,
                onOpenGallery: _openGallery,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            height: 62,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.primarySoft,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
                selectedIcon: Icon(
                  Icons.chat_bubble_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                label: '对话',
              ),
              NavigationDestination(
                icon: Icon(Icons.pets_outlined, size: 20),
                selectedIcon: Icon(
                  Icons.pets_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                label: '桌宠',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PetSidebar extends StatelessWidget {
  const _PetSidebar({
    required this.services,
    required this.onOpenBalance,
    required this.onOpenGallery,
    required this.onEnterCompact,
    required this.onOpenSettings,
  });

  final AppServices services;
  final VoidCallback onOpenBalance;
  final VoidCallback onOpenGallery;
  final VoidCallback onEnterCompact;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    return Container(
      width: 336,
      decoration: const BoxDecoration(
        gradient: AppColors.stageGradient,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 6),
            child: Row(
              children: [
                const Text(
                  '桌宠',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                const SoftTag('本地语义驱动'),
                const Spacer(),
                IconButton(
                  tooltip: settings.petWindowAlwaysOnTop ? '取消置顶' : '始终置顶',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final next = settings.copyWith(
                      petWindowAlwaysOnTop: !settings.petWindowAlwaysOnTop,
                    );
                    await services.updateSettings(next);
                    await PetWindowService().setAlwaysOnTop(
                      next.petWindowAlwaysOnTop,
                    );
                  },
                  icon: Icon(
                    settings.petWindowAlwaysOnTop
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 16,
                    color: settings.petWindowAlwaysOnTop
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
                IconButton(
                  tooltip: '桌面小窗',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEnterCompact,
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
                IconButton(
                  tooltip: '设置',
                  visualDensity: VisualDensity.compact,
                  onPressed: onOpenSettings,
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: PetStage(
                  pet: services.pet,
                  tags: services.tags,
                  scale: 1.24 * settings.petScale.clamp(0.8, 1.6),
                  onBalance: onOpenBalance,
                  onGallery: onOpenGallery,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  '对话结束时，${services.animations.animationCount} 段动画里会有一段被语义挑中。'
                  '点她一下试试，双击可以哄睡。',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetTab extends StatelessWidget {
  const _PetTab({
    required this.services,
    required this.controller,
    required this.onSend,
    required this.onOpenBalance,
    required this.onOpenGallery,
  });

  final AppServices services;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onOpenBalance;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.stageGradient),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const Text(
                    '大肥鱼',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const SoftTag('语义表情桌宠'),
                  const Spacer(),
                  IconButton(
                    onPressed: onOpenGallery,
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    tooltip: '表情库',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PetStage(
                    pet: services.pet,
                    tags: services.tags,
                    scale: 1.65 * services.settings.petScale.clamp(0.8, 1.6),
                    onBalance: onOpenBalance,
                    onGallery: onOpenGallery,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: '和她说句话…',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onSend,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(34, 34),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
