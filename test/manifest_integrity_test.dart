import 'dart:io';
import 'dart:ui' as ui;

import 'package:dsh_pet_emoji/data/models/semantic_profile.dart';
import 'package:dsh_pet_emoji/data/models/tag_definition.dart';
import 'package:dsh_pet_emoji/data/models/animation_clip.dart';
import 'package:dsh_pet_emoji/data/repositories/animation_repository.dart';
import 'package:dsh_pet_emoji/data/repositories/tag_repository.dart';
import 'package:dsh_pet_emoji/domain/semantic/animation_selector.dart';
import 'package:dsh_pet_emoji/domain/semantic/semantic_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AnimationRepository animations;
  late TagRepository tags;

  setUpAll(() async {
    animations = await AnimationRepository.load();
    tags = await TagRepository.load();
  });

  group('清单完整性', () {
    test('114 段动画全部可播放', () {
      expect(animations.clips.length, 114);
      expect(animations.animationCount, 114);
      expect(animations.clips.every((c) => c.playable), isTrue);
    });

    test('运行时素材是 640×360 的动画 WebP', () {
      for (final clip in animations.clips) {
        expect(clip.animPath, endsWith('.webp'), reason: clip.id);
        expect(clip.width, 640, reason: clip.id);
        expect(clip.height, 360, reason: clip.id);
      }
    });

    test('每段动画的运行时素材与 WebM 母版都真实存在', () {
      for (final clip in animations.clips) {
        if (clip.animPath != null) {
          expect(
            File(clip.animPath!).existsSync(),
            isTrue,
            reason: '${clip.id} 缺少运行时素材',
          );
        }
        if (clip.webmPath != null) {
          expect(
            File(clip.webmPath!).existsSync(),
            isTrue,
            reason: '${clip.id} 缺少 WebM',
          );
        }
      }
    });

    test('素材引用的标签全部在分类法中定义', () {
      final known = tags.tags.map((tag) => tag.id).toSet();
      for (final clip in animations.clips) {
        for (final tag in clip.tags.keys) {
          expect(
            known.contains(tag),
            isTrue,
            reason: '${clip.id} 引用了未定义标签 $tag',
          );
        }
        expect(clip.tags, isNotEmpty, reason: '${clip.id} 没有任何标签');
      }
    });

    test('每个标签都能解析出可播放素材（允许走兜底链）', () {
      for (final tag in tags.tags) {
        final resolved = animations.resolveTag(tag.id);
        expect(
          animations.clipsWithTag(resolved, minAffinity: 0.8),
          isNotEmpty,
          reason: '标签 ${tag.id} 解析到 $resolved 后仍无素材',
        );
      }
    });

    test('待机动画可循环', () {
      expect(animations.idleClip.isLoop, isTrue);
      expect(animations.idleClip.animPath, isNotNull);
    });

    test('运行时素材能被引擎解码成多帧动画', () async {
      // 迁移到动画 WebP 后，这条守着「Image 真能播」这件事——只检查文件存在
      // 是不够的，格式不对会在运行时才炸。
      for (final clip in [animations.clips.first, animations.clips.last]) {
        final bytes = File(clip.animPath!).readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        expect(codec.frameCount, greaterThan(1), reason: clip.id);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 640, reason: clip.id);
        expect(frame.image.height, 360, reason: clip.id);
        frame.image.dispose();
        codec.dispose();
      }
    });

    test('素材路径缺失时才会被标记为不可播放', () {
      // 现实中 114 段都有素材；这里构造一条缺路径的，确认兜底判断还在
      final broken = AnimationClip(
        id: 'broken',
        name: '缺素材',
        group: 'idle',
        hold: ClipHold.once,
        tags: const {'idle': 1},
        durationMs: 3000,
      );
      expect(broken.playable, isFalse);
      expect(animations.clips.where((c) => !c.playable), isEmpty);
    });

    test('标签分类法包含全部五个分组', () {
      expect(tags.groups.length, TagGroup.values.length);
      for (final group in TagGroup.values) {
        expect(tags.byGroup(group), isNotEmpty, reason: '分组 ${group.name} 为空');
      }
    });
  });

  group('端到端：对话 → 语义 → 动画', () {
    late SemanticAnalyzer analyzer;
    late AnimationSelector selector;

    setUpAll(() {
      analyzer = SemanticAnalyzer.fromRepository(tags);
      selector = AnimationSelector(repository: animations);
    });

    // 固定时钟：仲夏下午三点，不落在任何时段分支（0-5 / 5-9 / 11-13 / 22+），
    // 也不是节日。这样情境层只会注入一个被 ×0.35 压到阈值以下的 season 标签，
    // 选片结果才不会随 CI 所在时区漂移。
    final neutralNow = DateTime(2026, 6, 15, 15);

    String pickFor(String user, String reply, {DateTime? now}) {
      final profile = analyzer.analyze(
        userText: user,
        replyText: reply,
        now: now ?? neutralNow,
      );
      return selector.select(profile).id;
    }

    test('被夸奖时给出正向或害羞类表情', () {
      final id = pickFor('你今天真可爱！', '嘿嘿，被夸到了');
      final clip = animations.byId(id)!;
      final positive = ['joy', 'excited', 'shy', 'laugh', 'praise', 'love'];
      expect(
        clip.tags.keys.any(positive.contains),
        isTrue,
        reason: '$id 未命中正向标签',
      );
    });

    test('余额不足时落到金钱或沮丧类表情', () {
      final id = pickFor('我的余额不足了，怎么办', '余额不足需要先充值');
      final clip = animations.byId(id)!;
      final expected = [
        'money',
        'sad',
        'balance_empty',
        'balance_low',
        'confused',
      ];
      expect(clip.tags.keys.any(expected.contains), isTrue, reason: id);
    });

    test('代码问题会挑到工作类表情', () {
      final id = pickFor(
        '这段 Flutter 代码报错了',
        '```dart\nvoid main() {}\n```\n这样改就行',
      );
      final clip = animations.byId(id)!;
      expect(clip.group, anyOf('work', 'emotion'), reason: id);
    });

    test('睡觉话题会落到犯困类素材', () {
      final id = pickFor('好困，我要睡觉了', '晚安，做个好梦');
      final clip = animations.byId(id)!;
      final expected = ['sleep', 'sleepy', 'tired', 'calm'];
      expect(clip.tags.keys.any(expected.contains), isTrue, reason: id);
    });

    test('没有情绪信号时不硬凑表情，回到待机', () {
      // 必须显式给时钟：否则 CI（UTC）与本地（UTC+8）跑出的时段不同，
      // 情境层注入的 morning / night 会把结果从待机抢走。
      final id = pickFor('18:30 的航班', '好的');
      expect(id, animations.idleClip.id);
    });

    test('凌晨即使没有情绪词，也会被情境层带到困倦类素材', () {
      final id = pickFor('18:30 的航班', '好的', now: DateTime(2026, 6, 15, 3));
      final clip = animations.byId(id)!;
      expect(
        clip.tags.keys.any(const ['night', 'sleepy'].contains),
        isTrue,
        reason: '$id 未命中夜晚 / 困倦标签',
      );
    });

    test('清晨会把表情带向早安类素材', () {
      final id = pickFor('18:30 的航班', '好的', now: DateTime(2026, 6, 15, 8));
      final clip = animations.byId(id)!;
      expect(clip.tags.containsKey('morning'), isTrue, reason: id);
    });

    test('每次选片都返回可播放素材', () {
      final samples = [
        ('你好', '你好呀'),
        ('今天吃什么', '火锅怎么样'),
        ('哈哈哈哈笑死我了', '别笑了'),
        ('我好难过', '抱抱你'),
      ];
      for (final sample in samples) {
        final id = pickFor(sample.$1, sample.$2);
        expect(animations.byId(id)?.playable, isTrue, reason: id);
      }
    });

    test('语义结果非空并带意图', () {
      final profile = analyzer.analyze(
        userText: '帮我看看这个 bug',
        replyText: '这段代码有问题',
      );
      expect(profile.isEmpty, isFalse);
      expect(profile.intent, isA<DialogIntent>());
      expect(profile.evidence, isNotEmpty);
    });
  });
}
