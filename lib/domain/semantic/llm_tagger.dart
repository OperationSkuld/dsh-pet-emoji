import 'dart:convert';

import '../../core/logger.dart';
import '../../data/models/semantic_profile.dart';
import '../../data/models/tag_definition.dart';
import '../../data/services/deepseek_client.dart';

/// 可选的「DeepSeek 辅助标注」：把同一段对话交给模型打标，
/// 与离线词典结果取并集（`SemanticProfile.merge`）。
///
/// 任何异常都静默降级为空结果——桌宠的表情绝不能因为标注失败而卡住。
class LlmTagger {
  LlmTagger({required this.client});

  final DeepSeekClient client;

  Future<SemanticProfile?> annotate({
    required String userText,
    required String replyText,
    required List<TagDefinition> tags,
    String model = 'deepseek-chat',
  }) async {
    final allowed = tags.map((tag) => '${tag.id}(${tag.label})').join('、');
    final system =
        '''
你是「桌面宠物表情」的语义标注器。根据用户与助手的对话，为宠物挑选 1~4 个语义标签。
只能使用下列标签 id：$allowed
另外给出 intent，取值：${DialogIntent.values.map((e) => e.name).join('/')}。
严格只输出 JSON，不要解释、不要 Markdown 代码块：
{"tags":[{"id":"joy","score":0.9}],"intent":"chat"}
score 取 0~1，表示该标签的显著程度。''';

    try {
      final raw = await client.complete(
        model: model,
        temperature: 0.1,
        maxTokens: 200,
        messages: [
          {'role': 'system', 'content': system},
          {
            'role': 'user',
            'content': '用户：${_truncate(userText)}\n助手：${_truncate(replyText)}',
          },
        ],
      );
      return _parse(raw, tags);
    } on DeepSeekException catch (error) {
      Log.e('LlmTagger', '辅助标注失败：$error');
      return null;
    }
  }

  SemanticProfile? _parse(String raw, List<TagDefinition> tags) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw.substring(start, end + 1));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final known = tags.map((tag) => tag.id).toSet();
    final scores = <String, double>{};
    final rawTags = decoded['tags'];
    if (rawTags is List) {
      for (final item in rawTags) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id']?.toString();
        if (id == null || !known.contains(id)) continue;
        final score = (item['score'] as num?)?.toDouble() ?? 0.7;
        scores[id] = score.clamp(0.0, 1.0);
      }
    }
    if (scores.isEmpty) return null;

    final intentName = decoded['intent']?.toString();
    final intent = DialogIntent.values.firstWhere(
      (value) => value.name == intentName,
      orElse: () => DialogIntent.chat,
    );

    return SemanticProfile(
      scores: scores,
      intent: intent,
      intensity: scores.values.reduce((a, b) => a > b ? a : b),
      evidence: ['llm ← 辅助标注'],
      source: 'llm',
    );
  }

  String _truncate(String text) =>
      text.length <= 600 ? text : '${text.substring(0, 600)}…';
}
