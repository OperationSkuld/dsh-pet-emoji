import 'dart:math' as math;

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
    this.gifPath,
    this.webmPath,
    this.width,
    this.height,
  });

  /// 主键，与 `assets/animations/<id>.gif` 对应。
  final String id;

  /// 素材原名（中文），用于文档展示与定位 WebM 母版。
  final String name;

  /// 素材分组：idle / emotion / social / food / work / play / festival / money / sleep / interaction。
  final String group;

  final ClipHold hold;

  /// 标签 → 契合度（0~1）。
  final Map<String, double> tags;

  final int durationMs;
  final String? gifPath;
  final String? webmPath;
  final int? width;
  final int? height;

  /// 无 GIF 预览的素材（仅 WebM）不参与运行时调度。
  bool get playable => gifPath != null;

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
    return AnimationClip(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      group: json['group'] as String? ?? 'misc',
      hold: ClipHold.parse(json['hold']),
      tags: rawTags.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 3000,
      gifPath: json['gif'] as String?,
      webmPath: json['webm'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }

  @override
  String toString() => 'AnimationClip($id, tags: $tags)';
}
