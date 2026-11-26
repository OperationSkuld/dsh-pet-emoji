/// 对话意图。由语义分析的主导标签映射而来，用于选片时的分组加成。
enum DialogIntent {
  greeting('打招呼'),
  farewell('告别'),
  thanks('道谢'),
  apology('道歉'),
  praise('夸奖'),
  comfort('安慰'),
  refuse('拒绝'),
  question('提问'),
  food('吃喝'),
  work('工作'),
  code('写代码'),
  play('玩耍'),
  money('钱'),
  chat('闲聊');

  const DialogIntent(this.label);

  final String label;
}

/// 一次语义分析的结果：标签 → 权重（0~1），外加意图与强度。
class SemanticProfile {
  SemanticProfile({
    required Map<String, double> scores,
    required this.intent,
    required this.intensity,
    List<String> evidence = const [],
    this.source = 'local',
  }) : scores = Map.unmodifiable(scores),
       evidence = List.unmodifiable(evidence);

  /// 标签 → 权重。已裁剪到 0~1，并按权重降序去噪。
  final Map<String, double> scores;

  final DialogIntent intent;

  /// 情绪强度 0~1：感叹号、程度副词、文本长度共同决定。
  final double intensity;

  /// 命中依据，形如 `joy ← 开心`，用于「语义标签」调试面板。
  final List<String> evidence;

  /// local = 离线词典；llm = DeepSeek 辅助标注。
  final String source;

  bool get isEmpty => scores.isEmpty;

  /// 权重最高的标签。
  String? get dominant {
    if (scores.isEmpty) return null;
    var best = scores.keys.first;
    var bestScore = scores[best]!;
    scores.forEach((tag, score) {
      if (score > bestScore) {
        best = tag;
        bestScore = score;
      }
    });
    return best;
  }

  /// 前 N 个标签，按权重降序。
  List<MapEntry<String, double>> topTags([int limit = 5]) {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList(growable: false);
  }

  double scoreOf(String tagId) => scores[tagId] ?? 0;

  SemanticProfile merge(SemanticProfile other) {
    final merged = Map<String, double>.from(scores);
    other.scores.forEach((tag, score) {
      final current = merged[tag] ?? 0;
      if (score > current) merged[tag] = score;
    });
    return SemanticProfile(
      scores: merged,
      intent: other.scores.isEmpty ? intent : other.intent,
      intensity: other.intensity > intensity ? other.intensity : intensity,
      evidence: [...evidence, ...other.evidence].take(12).toList(),
      source: 'local+llm',
    );
  }

  static SemanticProfile empty() => SemanticProfile(
    scores: const {},
    intent: DialogIntent.chat,
    intensity: 0,
  );

  @override
  String toString() =>
      'SemanticProfile(intent: ${intent.name}, intensity: ${intensity.toStringAsFixed(2)}, '
      'tags: ${topTags().map((e) => '${e.key}=${e.value.toStringAsFixed(2)}').join(', ')})';
}
