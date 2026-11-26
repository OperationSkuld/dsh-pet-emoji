import 'dart:math' as math;
import 'dart:ui' show Rect;

/// 动画停留策略。
enum ClipHold {
  /// 一次性动作：播完（或到达上限）后回到待机。
  once,

  /// 可长时间停留：循环播放，直到下一次调度。
  loop;

  static ClipHold parse(Object? raw) =>
      raw == 'loop' ? ClipHold.loop : ClipHold.once;
}

/// 一段动画素材，以及它在语义空间中的坐标。
///
/// 数据来自 `assets/manifest/animations.json`，由 `tool/gen_manifest.py`
/// 从标注表生成，不在 Dart 侧硬编码。
class AnimationClip {
  const AnimationClip({
    required this.id,
    required this.name,
    required this.group,
    required this.hold,
    required this.tags,
    required this.durationMs,
    this.animPath,
    this.webmPath,
    this.width,
    this.height,
    this.boxX,
    this.boxY,
    this.boxWidth,
    this.boxHeight,
  });

  /// 主键，与 `assets/animations/<id>.webp` 对应。
  final String id;

  /// 素材原名（中文），用于文档展示与定位 WebM 母版。
  final String name;

  /// 素材分组：idle / emotion / social / food / work / play / festival / money / sleep / interaction。
  final String group;

  final ClipHold hold;

  /// 标签 → 契合度（0~1）。
  final Map<String, double> tags;

  final int durationMs;

  /// 运行时素材：带透明通道的动画 WebP（640×360），由 WebM 母版导出。
  final String? animPath;
  final String? webmPath;
  final int? width;
  final int? height;

  /// 内容包围盒（画面像素坐标）：这段素材里真正有像素的区域。
  ///
  /// 640×360 是统一画布，角色本身往往只占中间一小块；按它排版才能让气泡、
  /// 操作条贴着角色边缘，而不是贴着透明的画布边缘。
  /// 由 `tool/gen_boxes.py` 量出，经 `tool/gen_manifest.py` 写进清单。
  final int? boxX;
  final int? boxY;
  final int? boxWidth;
  final int? boxHeight;

  /// 内容框在画面中的归一化矩形（0~1）。数据缺失时退化为整幅画面。
  Rect get contentRect {
    final frameWidth = width;
    final frameHeight = height;
    final boxW = boxWidth;
    final boxH = boxHeight;
    if (frameWidth == null ||
        frameHeight == null ||
        frameWidth <= 0 ||
        frameHeight <= 0 ||
        boxW == null ||
        boxH == null ||
        boxW <= 0 ||
        boxH <= 0) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    return Rect.fromLTWH(
      (boxX ?? 0) / frameWidth,
      (boxY ?? 0) / frameHeight,
      boxW / frameWidth,
      boxH / frameHeight,
    );
  }

  /// 有运行时素材才参与调度。现在 114 段全部都有，保留这个判断是为了
  /// 在素材缺失时能安静跳过而不是崩在 `Image.asset`。
  bool get playable => animPath != null;

  bool get isLoop => hold == ClipHold.loop;

  /// 一次性动作的实际展示时长：素材普遍为 10s 长循环，
  /// 截断到 5s 以内，避免表情「僵在半路」。
  int get holdMs => hold == ClipHold.loop
      ? durationMs
      : math.min(durationMs, 5000).clamp(1200, 5000);

  double affinity(String tagId) => tags[tagId] ?? 0;

  /// 该素材最主导的标签（契合度最高者），用于调试与文档。
  String? get dominantTag {
    String? best;
    var bestScore = -1.0;
    tags.forEach((tag, score) {
      if (score > bestScore) {
        bestScore = score;
        best = tag;
      }
    });
    return best;
  }

  static AnimationClip fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as Map<String, dynamic>? ?? const {};
    final box = (json['box'] as List<dynamic>?)?.cast<num>();
    return AnimationClip(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      group: json['group'] as String? ?? 'misc',
      hold: ClipHold.parse(json['hold']),
      tags: rawTags.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 3000,
      animPath: json['anim'] as String?,
      webmPath: json['webm'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      boxX: box != null && box.length == 4 ? box[0].toInt() : null,
      boxY: box != null && box.length == 4 ? box[1].toInt() : null,
      boxWidth: box != null && box.length == 4 ? box[2].toInt() : null,
      boxHeight: box != null && box.length == 4 ? box[3].toInt() : null,
    );
  }

  @override
  String toString() => 'AnimationClip($id, tags: $tags)';
}
