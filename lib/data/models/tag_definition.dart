/// 标签分组。
enum TagGroup {
  emotion('情绪', '由对话内容推断的情感状态，决定表情基调'),
  social('社交', '对话意图层面的社交行为'),
  action('行为', '正在进行的动作或话题领域'),
  scene('时令', '时间与季节情境，用于叠加氛围加成'),
  system('系统', '由 App 事件直接注入，优先级最高');

  const TagGroup(this.label, this.description);

  final String label;
  final String description;

  static TagGroup parse(Object? raw) {
    for (final group in TagGroup.values) {
      if (group.name == raw) return group;
    }
    return TagGroup.action;
  }
}

/// 语义标签定义，来自 `assets/manifest/tags.json`。
///
/// 关键词词典是「离线语义分析」的燃料：命中即给出基础分，
/// 具体加权 / 否定 / 程度修饰由 `SemanticAnalyzer` 完成。
class TagDefinition {
  const TagDefinition({
    required this.id,
    required this.label,
    required this.group,
    required this.base,
    required this.description,
    required this.keywords,
  });

  final String id;
  final String label;
  final TagGroup group;

  /// 词典命中时的基础强度（0~1）。
  final double base;

  final String description;
  final List<String> keywords;

  static TagDefinition fromJson(Map<String, dynamic> json) {
    return TagDefinition(
      id: json['id'] as String,
      label: json['label'] as String? ?? json['id'] as String,
      group: TagGroup.parse(json['group']),
      base: (json['base'] as num?)?.toDouble() ?? 0.7,
      description: json['description'] as String? ?? '',
      keywords: (json['keywords'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  @override
  String toString() => 'TagDefinition($id/$label)';
}
