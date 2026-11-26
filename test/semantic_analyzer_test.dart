import 'package:dsh_pet_emoji/data/models/semantic_profile.dart';
import 'package:dsh_pet_emoji/data/models/tag_definition.dart';
import 'package:dsh_pet_emoji/data/repositories/tag_repository.dart';
import 'package:dsh_pet_emoji/domain/semantic/semantic_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SemanticAnalyzer analyzer;

  setUpAll(() async {
    final tags = await TagRepository.load();
    analyzer = SemanticAnalyzer.fromRepository(tags);
  });

  group('词典层', () {
    test('命中关键词给出对应标签', () {
      final profile = analyzer.analyze(userText: '我好开心啊', replyText: '那就好呀');
      expect(profile.scoreOf('joy'), greaterThan(0.4));
    });

    test('否定词会否决该次命中', () {
      final negative = analyzer.analyze(userText: '我不开心', replyText: '抱歉');
      final positive = analyzer.analyze(userText: '我很开心', replyText: '抱歉');
      expect(negative.scoreOf('joy'), lessThan(positive.scoreOf('joy')));
      expect(negative.scoreOf('joy'), lessThan(0.2));
    });

    test('程度副词放大权重', () {
      final strong = analyzer.analyze(userText: '我非常开心', replyText: '');
      final weak = analyzer.analyze(userText: '我有点开心', replyText: '');
      expect(strong.scoreOf('joy'), greaterThan(weak.scoreOf('joy')));
    });

    test('长词优先：余额不足不会被余额抢先切走', () {
      final profile = analyzer.analyze(userText: '我的余额不足了', replyText: '');
      expect(profile.scoreOf('money'), greaterThan(0.3));
    });
  });

  group('结构层', () {
    test('问号注入 question', () {
      final profile = analyzer.analyze(userText: '今天天气怎么样？', replyText: '晴');
      expect(profile.scoreOf('question'), greaterThan(0.3));
      expect(profile.intent, DialogIntent.question);
    });

    test('代码块注入 code', () {
      final profile = analyzer.analyze(
        userText: '帮我看看这段代码',
        replyText: '```dart\nvoid main() {}\n```',
      );
      expect(profile.scoreOf('code'), greaterThan(0.3));
      expect(profile.intent, DialogIntent.code);
    });

    test('金额表达式注入 money', () {
      final profile = analyzer.analyze(userText: '只花了 12 元', replyText: '');
      expect(profile.scoreOf('money'), greaterThan(0.3));
    });

    test('省略号注入 dazed', () {
      final profile = analyzer.analyze(userText: '嗯……', replyText: '');
      expect(profile.scoreOf('dazed'), greaterThan(0.2));
    });
  });

  group('情境层', () {
    test('深夜会带上夜晚与困倦', () {
      final profile = analyzer.analyze(
        userText: '还在吗',
        replyText: '在的',
        now: DateTime(2026, 3, 3, 2, 30),
      );
      expect(profile.scoreOf('night'), greaterThan(0.2));
      expect(profile.scoreOf('sleepy'), greaterThan(0.2));
    });

    test('圣诞当天注入节日', () {
      final profile = analyzer.analyze(
        userText: '今天做什么',
        replyText: '休息一下',
        now: DateTime(2026, 12, 25, 15),
      );
      expect(profile.scoreOf('festival'), greaterThan(0.5));
    });
  });

  group('意图与强度', () {
    test('问候识别为 greeting', () {
      final profile = analyzer.analyze(userText: '你好呀', replyText: '你好～');
      expect(profile.intent, DialogIntent.greeting);
    });

    test('道谢识别为 thanks', () {
      final profile = analyzer.analyze(userText: '谢谢你帮我', replyText: '不客气');
      expect(profile.intent, DialogIntent.thanks);
    });

    test('感叹号提升强度', () {
      final calm = analyzer.analyze(userText: '还行', replyText: '嗯');
      final excited = analyzer.analyze(userText: '太棒了！！', replyText: '好耶！！');
      expect(excited.intensity, greaterThan(calm.intensity));
    });

    test('分数被裁剪到 0~1 且按降序输出', () {
      final profile = analyzer.analyze(
        userText: '我今天特别开心，非常兴奋，哈哈哈哈哈！！',
        replyText: '太好了，恭喜你！',
      );
      for (final entry in profile.scores.entries) {
        expect(entry.value, inInclusiveRange(0, 1));
      }
      final top = profile.topTags(10);
      for (var i = 1; i < top.length; i++) {
        expect(top[i - 1].value, greaterThanOrEqualTo(top[i].value));
      }
      expect(profile.topTags(3), isNotEmpty);
    });

    test('合并 LLM 结果取较大权重', () {
      final local = SemanticProfile(
        scores: {'joy': 0.4},
        intent: DialogIntent.chat,
        intensity: 0.4,
      );
      final llm = SemanticProfile(
        scores: {'joy': 0.8, 'shy': 0.6},
        intent: DialogIntent.praise,
        intensity: 0.8,
        source: 'llm',
      );
      final merged = local.merge(llm);
      expect(merged.scoreOf('joy'), 0.8);
      expect(merged.scoreOf('shy'), 0.6);
      expect(merged.intent, DialogIntent.praise);
      expect(merged.source, 'local+llm');
    });
  });

  test('标签定义包含中文名与分组', () async {
    final tags = await TagRepository.load();
    expect(tags.tags.length, greaterThanOrEqualTo(40));
    expect(tags.labelOf('joy'), '开心');
    expect(tags.groupOf('joy'), TagGroup.emotion);
    expect(tags.groupOf('balance_rich'), TagGroup.system);
    expect(tags.byId('not-exist'), isNull);
  });
}
