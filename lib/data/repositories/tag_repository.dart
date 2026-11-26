import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/tag_definition.dart';

/// 标签仓库：读取分类法，供语义分析器与 UI（标签胶囊、说明气泡）共用。
class TagRepository {
  TagRepository(this.tags, this.groups);

  final List<TagDefinition> tags;
  final List<TagGroup> groups;

  late final Map<String, TagDefinition> _byId = {
    for (final tag in tags) tag.id: tag,
  };

  static Future<TagRepository> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(
      'assets/manifest/tags.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final tags = (decoded['tags'] as List<dynamic>)
        .map((item) => TagDefinition.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final groups = (decoded['groups'] as List<dynamic>? ?? const [])
        .map((item) => TagGroup.parse((item as Map<String, dynamic>)['id']))
        .toList(growable: false);
    return TagRepository(tags, groups.isEmpty ? TagGroup.values : groups);
  }

  TagDefinition? byId(String id) => _byId[id];

  String labelOf(String id) => _byId[id]?.label ?? id;

  TagGroup groupOf(String id) => _byId[id]?.group ?? TagGroup.action;

  String descriptionOf(String id) => _byId[id]?.description ?? '';

  List<TagDefinition> byGroup(TagGroup group) =>
      tags.where((tag) => tag.group == group).toList(growable: false);

  /// 词典标签（有自然语言关键词的）——系统标签不需要参与分词。
  Iterable<TagDefinition> get lexiconTags => tags.where(
    (tag) => tag.keywords.isNotEmpty && tag.group != TagGroup.system,
  );
}
