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
  /// 桌宠到窗口边缘、以及气泡/操作条到角色本体的间距，统一 20。
  ///
  /// 这里的 20 是「角色边缘」到目标边缘的距离——PetView 已经裁掉了画布上的
  /// 透明留白，所以摆出来就是眼睛看到的 20，不会被素材边距放大。
  static const double _margin = 20;
  static const double _gapAbovePet = 20;
  static const double _gapBelowPet = 20;

  final GlobalKey _contentKey = GlobalKey();

  Offset? _pos;
  /// 内容尺寸的初始估值（气泡 + 本体 + 两段 20 间距 + 工具条），
  /// 首帧之后由 [_measure] 用真实尺寸覆盖。
  Size _content = const Size(250, 380);
  Size _viewport = Size.zero;
  bool _hovering = false;
  bool _dragging = false;

  AppServices get _services => widget.services;

  double get _zoom => _services.settings.normalizedPetZoom;

  /// 浮动块的宽度：至少容得下气泡（240），但不超过窗口可用宽度。
  ///
  /// 气泡与操作条都以角色为中心居中，所以取两者的较大值即可。
  double get _columnWidth {
    final limit = math.max(160.0, _viewport.width - _margin * 2);
    return math.min(math.max(_petWidth, 240.0), limit);
  }

  /// 角色本体在当前倍率下的目标宽度，并兜底不超过窗口可用宽度。
  double get _petWidth {
    final rect = _services.pet.current.contentRect;
    final natural = kPetNativeWidth * rect.width * _zoom;
    final limit = math.max(120.0, _viewport.width - _margin * 2);
    return math.min(natural, limit);
  }

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

  /// 量出内容尺寸（气泡 + 本体 + 工具条），用于边界钳制与默认位置。
  ///
  /// 整个浮动块是**底边锚定**的（气泡出现时向上长，不推着桌宠往下跑），
  /// 所以尺寸变化时同步把 [_pos] 上移同样的量，底边保持不动。
  void _measure() {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (size == _content) return;
    // 布局期不能直接 setState，挪到帧末。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !box.hasSize) return;
      setState(() {
        final grew = box.size.height - _content.height;
        _content = box.size;
        final pos = _pos;
        if (pos != null && grew != 0) {
          _pos = _clamp(Offset(pos.dx, math.max(0.0, pos.dy - grew)));
        }
      });
    });
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
              // 用 bottom 而不是 top：只给 left/bottom 时 Stack 不会限制高度，
              // 内容（气泡变高、换更大的素材）向上生长，永远不会 overflow。
              bottom: math.max(
                0.0,
                _viewport.height - (pos.dy + _content.height),
              ),
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
                        // 宽度必须显式给定：Positioned 只给 left/top 时，
                        // Stack 不会给子树任何宽度约束，Column 会被撑成无限宽。
                        width: _columnWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PetBubbleHost(text: _services.pet.bubble),
                            const SizedBox(height: _gapAbovePet),
                            _buildPetBody(),
                            const SizedBox(height: _gapBelowPet),
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
        child: SizedBox(
          width: _petWidth,
          child: PetView(clip: pet.current, zoom: _zoom, showShadow: true),
        ),
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
