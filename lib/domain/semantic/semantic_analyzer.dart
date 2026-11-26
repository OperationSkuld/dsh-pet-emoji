import 'dart:math' as math;

import '../../core/logger.dart';
import '../../data/models/semantic_profile.dart';
import '../../data/models/tag_definition.dart';
import '../../data/repositories/tag_repository.dart';

/// 离线语义分析器：把「用户这句 + 模型这段」压成一串语义标签。
///
/// 分四层，逐层叠加（详见 docs/TAGS.md「映射规则」）：
///   1. 词典层：关键词命中给出基础分，长词优先、命中区间去重；
///   2. 修饰层：程度副词放大 / 缩小，否定词直接否决该次命中；
///   3. 结构层：标点、代码块、金额、长度等非词典信号；
///   4. 情境层：时段、季节、公历节日。
///
/// 所有分值使用「软饱和」累加 `s = s + v * (1 - s)`，避免同义词堆叠把分打满。
class SemanticAnalyzer {
  SemanticAnalyzer(List<TagDefinition> tags) : _lexicon = _buildLexicon(tags);

  factory SemanticAnalyzer.fromRepository(TagRepository repository) =>
      SemanticAnalyzer(repository.tags);

  final List<_Lexeme> _lexicon;

  static const List<String> _negations = ['不', '没', '别', '未', '勿', '非', '无'];
  static const List<String> _intensifiers = [
    '非常', '特别', '超级', '超级无敌', '十分', '格外', '异常', '真的', '真的超级',
    '太', '很', '超', '巨', '贼', '极', '最', '好',
  ];
  static const List<String> _diminishers = ['有点', '有些', '稍微', '略微', '略', '一点点', '一点', '还算'];

  /// 用户输入与模型回复的权重：回复决定宠物当下的表情基调。
  static const double _userWeight = 0.55;
  static const double _replyWeight = 0.45;

  static List<_Lexeme> _buildLexicon(List<TagDefinition> tags) {
    final lexemes = <_Lexeme>[];
    for (final tag in tags) {
      if (tag.group == TagGroup.system) continue;
      for (final keyword in tag.keywords) {
        lexemes.add(_Lexeme(word: keyword.toLowerCase(), tagId: tag.id, base: tag.base));
      }
    }
    // 长词优先，保证「余额不足」不会被「余额」抢先命中。
    lexemes.sort((a, b) => b.word.length.compareTo(a.word.length));
    return lexemes;
  }

  SemanticProfile analyze({
    required String userText,
    required String replyText,
    DateTime? now,
    Map<String, double> injected = const {},
  }) {
    final scores = <String, double>{};
    final rawScores = <String, double>{};
    final evidence = <String>[];

    _scan(userText, _userWeight, scores, evidence, rawScores);
    _scan(replyText, _replyWeight, scores, evidence, rawScores);
    _structuralSignals(userText, replyText, scores, evidence);
    _situationalSignals(now ?? DateTime.now(), scores);

    injected.forEach((tag, value) => _saturate(scores, tag, value));

    final pruned = <String, double>{};
    scores.forEach((tag, value) {
      if (value >= 0.12) pruned[tag] = double.parse(value.toStringAsFixed(3));
    });

    final profile = SemanticProfile(
      scores: pruned,
      intent: _inferIntent(pruned, rawScores),
      intensity: _intensity(pruned, userText, replyText),
      evidence: evidence.take(10).toList(growable: false),
    );
    Log.d('SemanticAnalyzer', profile.toString());
    return profile;
  }

  // ---------------------------------------------------------------- 词典层
  void _scan(
    String text,
    double sourceWeight,
    Map<String, double> scores,
    List<String> evidence,
    Map<String, double> rawScores,
  ) {
    if (text.isEmpty) return;
    final haystack = text.toLowerCase();
    final consumed = List<bool>.filled(haystack.length, false);

    for (final lexeme in _lexicon) {
      var cursor = 0;
      var hit = 0;
      while (true) {
        final index = haystack.indexOf(lexeme.word, cursor);
        if (index < 0) break;
        cursor = index + lexeme.word.length;
        if (_overlaps(consumed, index, cursor)) continue;

        final rawPrefix = haystack.substring(math.max(0, index - 4), index);
        // 「非常」「超级」这类程度副词里含「非」，必须先从否定窗口里剥离。
        var negWindow = rawPrefix;
        for (final word in [..._intensifiers, ..._diminishers]) {
          negWindow = negWindow.replaceAll(word, '');
        }
        if (_negations.any(negWindow.contains)) {
          evidence.add('${lexeme.tagId} ← 否定「${lexeme.word}」');
          continue;
        }

        double modifier = 1.0;
        if (_intensifiers.any(rawPrefix.contains)) modifier = 1.3;
        if (_diminishers.any(rawPrefix.contains)) modifier = 0.7;

        final decay = switch (hit) { 0 => 1.0, 1 => 0.6, _ => 0.4 };
        final value = lexeme.base * sourceWeight * modifier * decay;
        _saturate(scores, lexeme.tagId, value);
        _saturate(rawScores, lexeme.tagId, lexeme.base * modifier * decay);
        evidence.add('${lexeme.tagId} ← 「${lexeme.word}」');
        _markConsumed(consumed, index, cursor);
        hit++;
      }
    }
  }

  bool _overlaps(List<bool> consumed, int start, int end) {
    for (var i = start; i < end; i++) {
      if (consumed[i]) return true;
    }
    return false;
  }

  void _markConsumed(List<bool> consumed, int start, int end) {
    for (var i = start; i < end; i++) {
      consumed[i] = true;
    }
  }

  // ---------------------------------------------------------------- 结构层
  void _structuralSignals(
    String userText,
    String replyText,
    Map<String, double> scores,
    List<String> evidence,
  ) {
    final exclamations = _count(userText, '!') + _count(userText, '！');
    if (exclamations >= 2) {
      _saturate(scores, 'excited', 0.35);
      evidence.add('excited ← 连续感叹号');
    }

    if (userText.contains('?') || userText.contains('？')) {
      _saturate(scores, 'question', 0.6);
      evidence.add('question ← 疑问句');
    }

    if (replyText.contains('```') ||
        replyText.contains('def ') ||
        replyText.contains('function ') ||
        replyText.contains('class ')) {
      _saturate(scores, 'code', 0.7);
      evidence.add('code ← 代码块');
    }

    final moneyPattern = RegExp(r'[¥￥]\s*\d|\d+(\.\d+)?\s*(元|块|rmb|RMB)');
    if (moneyPattern.hasMatch(userText) || moneyPattern.hasMatch(replyText)) {
      _saturate(scores, 'money', 0.65);
      evidence.add('money ← 金额表达式');
    }

    if (replyText.length > 260) {
      _saturate(scores, 'thinking', 0.35);
      evidence.add('thinking ← 长回复');
    }

    if (userText.contains('……') || userText.contains('。。。')) {
      _saturate(scores, 'dazed', 0.4);
      evidence.add('dazed ← 省略号');
    }

    const emojiTags = {
      '😂': 'laugh',
      '🤣': 'laugh',
      '😊': 'joy',
      '😄': 'joy',
      '😭': 'sad',
      '😡': 'angry',
      '😅': 'shy',
      '❤': 'love',
      '🐟': 'cute',
      '🐳': 'love',
    };
    emojiTags.forEach((emoji, tag) {
      if (userText.contains(emoji) || replyText.contains(emoji)) {
        _saturate(scores, tag, 0.55);
        evidence.add('$tag ← 表情 $emoji');
      }
    });
  }

  // ---------------------------------------------------------------- 情境层
  void _situationalSignals(DateTime now, Map<String, double> scores) {
    final hour = now.hour;
    if (hour >= 0 && hour < 5) {
      _saturate(scores, 'night', 0.5);
      _saturate(scores, 'sleepy', 0.4);
    } else if (hour >= 5 && hour < 9) {
      _saturate(scores, 'morning', 0.5);
    } else if (hour >= 11 && hour < 13) {
      _saturate(scores, 'eat', 0.35);
    } else if (hour >= 22) {
      _saturate(scores, 'night', 0.45);
      _saturate(scores, 'sleepy', 0.3);
    }

    final month = now.month;
    final day = now.day;
    final seasonTag = switch (month) {
      3 || 4 || 5 => 'season_spring',
      6 || 7 || 8 => 'season_summer',
      9 || 10 || 11 => 'season_autumn',
      _ => 'season_winter',
    };
    _saturate(scores, seasonTag, 0.3);

    final festivalHits = <String>[];
    if (month == 12 && (day == 24 || day == 25)) festivalHits.add('christmas');
    if (month == 10 && day == 31) festivalHits.add('halloween');
    if (month == 1 && day == 1) festivalHits.add('new_year');
    if (month == 10 && day == 1) festivalHits.add('national_day');
    if (month == 6 && day == 1) festivalHits.add('childrens_day');
    if (month == 2 && day == 14) festivalHits.add('valentine');
    if (festivalHits.isNotEmpty) {
      _saturate(scores, 'festival', 0.75);
      if (festivalHits.contains('valentine')) _saturate(scores, 'love', 0.45);
      if (festivalHits.contains('christmas')) _saturate(scores, 'season_winter', 0.35);
    }
  }

  // ---------------------------------------------------------------- 汇总
  void _saturate(Map<String, double> scores, String tag, double value) {
    if (value <= 0) return;
    final current = scores[tag] ?? 0;
    scores[tag] = math.min(1.0, current + value * (1 - current));
  }

  int _count(String text, String pattern) {
    var count = 0;
    var index = text.indexOf(pattern);
    while (index >= 0) {
      count++;
      index = text.indexOf(pattern, index + pattern.length);
    }
    return count;
  }

  DialogIntent _inferIntent(Map<String, double> scores, Map<String, double> raw) {
    const threshold = 0.6;
    double at(String tag) => math.max(scores[tag] ?? 0, raw[tag] ?? 0);

    if (at('greet') >= threshold) return DialogIntent.greeting;
    if (at('farewell') >= threshold) return DialogIntent.farewell;
    if (at('thanks') >= threshold) return DialogIntent.thanks;
    if (at('apology') >= threshold) return DialogIntent.apology;
    if (at('comfort') >= threshold) return DialogIntent.comfort;
    if (at('refuse') >= threshold) return DialogIntent.refuse;
    if (at('praise') >= threshold) return DialogIntent.praise;
    if (at('question') >= threshold) return DialogIntent.question;
    if (at('code') >= threshold) return DialogIntent.code;
    if (at('work') >= threshold) return DialogIntent.work;
    if (at('eat') >= threshold) return DialogIntent.food;
    if (at('money') >= threshold) return DialogIntent.money;
    if (at('play') >= threshold || at('dance') >= threshold || at('game') >= threshold) {
      return DialogIntent.play;
    }
    return DialogIntent.chat;
  }

  double _intensity(
    Map<String, double> scores,
    String userText,
    String replyText,
  ) {
    var top = 0.0;
    for (final value in scores.values) {
      if (value > top) top = value;
    }
    final exclamations =
        _count(userText, '!') + _count(userText, '！') + _count(replyText, '!');
    final punctuation = math.min(1.0, exclamations * 0.2);
    final length = math.min(1.0, (userText.length + replyText.length) / 260);
    return math.min(1.0, top * 0.75 + punctuation * 0.15 + length * 0.15);
  }
}

class _Lexeme {
  const _Lexeme({required this.word, required this.tagId, required this.base});

  final String word;
  final String tagId;
  final double base;
}
