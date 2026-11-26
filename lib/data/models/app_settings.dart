import '../../core/app_links.dart';

/// 桌宠窗口背景策略。Windows 桌面合成不支持逐像素透明时的降级方案。
enum PetWindowBackground {
  card('圆角卡片', '始终可用，浅色卡片 + 投影'),
  transparent('尝试透明', '依赖平台合成能力，Windows 可能退化为卡片');

  const PetWindowBackground(this.label, this.description);

  final String label;
  final String description;

  static PetWindowBackground parse(Object? raw) => raw == 'transparent'
      ? PetWindowBackground.transparent
      : PetWindowBackground.card;
}

/// 用户设置。API Key 以明文存放于 SharedPreferences，详见 docs/ARCHITECTURE.md「安全」。
class AppSettings {
  const AppSettings({
    this.apiKey = '',
    this.baseUrl = kDefaultBaseUrl,
    this.model = kDefaultModel,
    this.ambientAnimations = true,
    this.llmSemanticTagging = false,
    this.showSemanticPanel = false,
    this.petZoom = 1,
    this.petOffsetX = -1,
    this.petOffsetY = -1,
    this.petWindowAlwaysOnTop = true,
    this.petWindowBackground = PetWindowBackground.card,
    this.speechBubble = true,
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  /// 空闲时自动播放氛围动画。
  final bool ambientAnimations;

  /// 用 DeepSeek 辅助打标（会多消耗一次极小的请求）。
  final bool llmSemanticTagging;

  /// 对话页显示「语义标签」调试面板。
  final bool showSemanticPanel;

  /// 桌宠显示倍率：1× 为素材原生尺寸（220×124），2×/3× 为整数倍放大。
  ///
  /// 只允许整数，避免半像素缩放把 GIF 插值糊掉——见 [normalizedPetZoom]。
  final double petZoom;

  /// 浮动桌宠在窗口内的左上角位置（逻辑像素）。-1 表示尚未拖动过，
  /// 由界面按「右下角留白 28」的默认位置摆放。
  final double petOffsetX;
  final double petOffsetY;
  final bool petWindowAlwaysOnTop;
  final PetWindowBackground petWindowBackground;

  /// 桌宠是否冒气泡转述回复。
  final bool speechBubble;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// 合法的显示倍率：把历史遗留的 0.8~1.6 小数吸附到 1/2/3。
  double get normalizedPetZoom => petZoom.roundToDouble().clamp(1.0, 3.0);

  /// 是否已经记录过浮动位置。
  bool get hasPetOffset => petOffsetX >= 0 && petOffsetY >= 0;

  AppSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    bool? ambientAnimations,
    bool? llmSemanticTagging,
    bool? showSemanticPanel,
    double? petZoom,
    double? petOffsetX,
    double? petOffsetY,
    bool? petWindowAlwaysOnTop,
    PetWindowBackground? petWindowBackground,
    bool? speechBubble,
  }) {
    return AppSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      ambientAnimations: ambientAnimations ?? this.ambientAnimations,
      llmSemanticTagging: llmSemanticTagging ?? this.llmSemanticTagging,
      showSemanticPanel: showSemanticPanel ?? this.showSemanticPanel,
      petZoom: petZoom ?? this.petZoom,
      petOffsetX: petOffsetX ?? this.petOffsetX,
      petOffsetY: petOffsetY ?? this.petOffsetY,
      petWindowAlwaysOnTop: petWindowAlwaysOnTop ?? this.petWindowAlwaysOnTop,
      petWindowBackground: petWindowBackground ?? this.petWindowBackground,
      speechBubble: speechBubble ?? this.speechBubble,
    );
  }
}
