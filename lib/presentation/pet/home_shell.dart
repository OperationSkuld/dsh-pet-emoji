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
import 'floating_pet.dart';
import 'pet_stage.dart';

/// 应用外壳。
///
/// - 宽屏（桌面）：对话铺满整窗，桌宠是浮在最上层、可在窗口内任意拖动的一只；
///   右侧不再有固定的桌宠侧栏。
/// - 窄屏（移动端）：底部双页签「对话 / 桌宠」。
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

  /// 表情库点选后会自行 pop，并回传 `true` 表示「已开始播放」。
  /// 窄屏此时切到桌宠页签，否则动画播在看不见的地方。
  Future<void> _openGallery() async {
    final played = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => GalleryPage(services: widget.services),
      ),
    );
    if (!mounted || played != true) return;
    final wide =
        MediaQuery.sizeOf(context).width >= 1000 && widget.services.isDesktop;
    if (!wide && _tab != 1) setState(() => _tab = 1);
  }

  void _openBalance() => showBalanceSheet(context, widget.services);

  Future<void> _enterCompact() async {
    final settings = widget.services.settings;
    await widget.window.enterCompact(settings);
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
            body: Stack(
              children: [
                Positioned.fill(
                  child: ChatPage(
                    services: widget.services,
                    onOpenSettings: _openSettings,
                    onOpenBalance: _openBalance,
                    onOpenGallery: _openGallery,
                    onToggleCompactWindow: _enterCompact,
                  ),
                ),
                FloatingPet(
                  services: widget.services,
                  onOpenBalance: _openBalance,
                  onOpenGallery: _openGallery,
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
                    zoom: services.settings.normalizedPetZoom,
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
