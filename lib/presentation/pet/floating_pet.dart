import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../data/models/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_view.dart';
import 'pet_bubble.dart';

/// 浮动桌宠：悬浮在对话界面之上，可在窗口内任意拖动。
///
/// 取代了早先右侧固定 336px 的桌宠侧栏——对话区因此拿到整窗宽度。
/// 位置会写回设置（`petOffsetX/Y`），下次启动还在原处。
///
/// 交互：
///   - 拖动本体：整只宠物跟着走，拖的时候播「被拎起来」的表情；
///   - 单击：摸摸；双击：哄睡 / 叫醒；
///   - 悬停：浮出一排小按钮（摸摸 / 睡 / 余额 / 缩放 / 表情库）。
class FloatingPet extends StatefulWidget {
  const FloatingPet({
    super.key,
    required this.services,
    this.onOpenBalance,
    this.onOpenGallery,
  });

  final AppServices services;
  final VoidCallback? onOpenBalance;
  final VoidCallback? onOpenGallery;

  @override
  State<FloatingPet> createState() => _FloatingPetState();
}

class _FloatingPetState extends State<FloatingPet> {
  static const double _margin = 20;

  final GlobalKey _contentKey = GlobalKey();

  Offset? _pos;
  Size _content = const Size(kPetNativeWidth, kPetNativeHeight + 70);
  Size _viewport = Size.zero;
  bool _hovering = false;
  bool _dragging = false;

  AppServices get _services => widget.services;

  double get _zoom => _services.settings.normalizedPetZoom;

  @override
  void initState() {
    super.initState();
    final settings = _services.settings;
    if (settings.hasPetOffset) {
      _pos = Offset(settings.petOffsetX, settings.petOffsetY);
    }
    _services.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _services.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  /// 内容尺寸（气泡 + 本体 + 工具条）会随气泡开关变化，量一次用于边界钳制。
  void _measure() {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (box.size != _content) {
      // 布局期不能直接 setState，挪到帧末。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && box.hasSize) setState(() => _content = box.size);
      });
    }
  }

  Offset _clamp(Offset raw) {
    final maxX = math.max(0.0, _viewport.width - _content.width);
    final maxY = math.max(0.0, _viewport.height - _content.height);
    return Offset(
      raw.dx.clamp(0.0, maxX).toDouble(),
      raw.dy.clamp(0.0, maxY).toDouble(),
    );
  }

  Offset _defaultPosition() => Offset(
    math.max(0.0, _viewport.width - _content.width - _margin),
    math.max(0.0, _viewport.height - _content.height - _margin),
  );

  void _startDrag() {
    setState(() => _dragging = true);
    _services.pet.onDragStart();
  }

  void _updateDrag(Offset delta) {
    final current = _pos ?? _defaultPosition();
    setState(() => _pos = _clamp(current + delta));
  }

  Future<void> _endDrag() async {
    setState(() => _dragging = false);
    _services.pet.onDragEnd();
    final pos = _pos;
    if (pos == null) return;
    await _services.updateSettings(
      _services.settings.copyWith(petOffsetX: pos.dx, petOffsetY: pos.dy),
    );
  }

  /// 按 [AppSettings.petZoomSteps] 的档位步进，避免出现非整数倍率。
  Future<void> _stepZoom(int delta) async {
    final steps = AppSettings.petZoomSteps;
    final index = steps.indexOf(_zoom);
    final next = (index + delta).clamp(0, steps.length - 1);
    if (next == index) return;
    await _services.updateSettings(
      _services.settings.copyWith(petZoom: steps[next]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final pos = _clamp(_pos ?? _defaultPosition());
        _pos = pos;

        return Stack(
          children: [
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovering = true),
                onExit: (_) => setState(() => _hovering = false),
                child: AnimatedBuilder(
                  animation: _services.pet,
                  builder: (context, _) {
                    _measure();
                    return KeyedSubtree(
                      key: _contentKey,
                      child: SizedBox(
                        width: kPetNativeWidth * _zoom,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PetBubbleHost(text: _services.pet.bubble),
                            const SizedBox(height: 8),
                            _buildPetBody(),
                            const SizedBox(height: 4),
                            _buildToolbar(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPetBody() {
    final pet = _services.pet;
    return MouseRegion(
      cursor: _dragging
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: pet.onTap,
        onDoubleTap: pet.toggleSleep,
        onPanStart: (_) => _startDrag(),
        onPanUpdate: (details) => _updateDrag(details.delta),
        onPanEnd: (_) => _endDrag(),
        onPanCancel: _endDrag,
        child: PetView(clip: pet.current, zoom: _zoom, showShadow: true),
      ),
    );
  }

  Widget _buildToolbar() {
    final visible = _hovering || _dragging;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: IgnorePointer(
        ignoring: !visible,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            _PetAction(
              icon: Icons.pan_tool_alt_outlined,
              tooltip: '摸摸',
              onTap: _services.pet.onTap,
            ),
            _PetAction(
              icon: _services.pet.sleeping
                  ? Icons.wb_sunny_outlined
                  : Icons.bedtime_outlined,
              tooltip: _services.pet.sleeping ? '叫醒' : '睡一觉',
              onTap: _services.pet.toggleSleep,
            ),
            _PetAction(
              icon: Icons.zoom_out_rounded,
              tooltip: '缩小',
              onTap: _zoom <= AppSettings.petZoomSteps.first
                  ? null
                  : () => _stepZoom(-1),
            ),
            _PetAction(
              icon: Icons.zoom_in_rounded,
              tooltip: '放大',
              onTap: _zoom >= AppSettings.petZoomSteps.last
                  ? null
                  : () => _stepZoom(1),
            ),
            if (widget.onOpenBalance != null)
              _PetAction(
                icon: Icons.account_balance_wallet_outlined,
                tooltip: '余额',
                onTap: widget.onOpenBalance,
              ),
            if (widget.onOpenGallery != null)
              _PetAction(
                icon: Icons.grid_view_rounded,
                tooltip: '表情库',
                onTap: widget.onOpenGallery,
              ),
          ],
        ),
      ),
    );
  }
}

class _PetAction extends StatelessWidget {
  const _PetAction({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 15,
              color: enabled ? AppColors.textSecondary : AppColors.border,
            ),
          ),
        ),
      ),
    );
  }
}
