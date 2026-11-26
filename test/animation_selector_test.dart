import 'dart:math' as math;

import 'package:dsh_pet_emoji/data/models/animation_clip.dart';
import 'package:dsh_pet_emoji/data/models/balance_info.dart';
import 'package:dsh_pet_emoji/data/models/semantic_profile.dart';
import 'package:dsh_pet_emoji/data/repositories/animation_repository.dart';
import 'package:dsh_pet_emoji/domain/semantic/animation_selector.dart';
import 'package:flutter_test/flutter_test.dart';

AnimationClip _clip(
  String id,
  String group,
  Map<String, double> tags, {
  bool loop = false,
}) {
  return AnimationClip(
    id: id,
    name: id,
    group: group,
    hold: loop ? ClipHold.loop : ClipHold.once,
    tags: tags,
    durationMs: 3000,
    gifPath: 'assets/animations/$id.gif',
  );
}

SemanticProfile _profile(Map<String, double> scores, {double intensity = 0.5}) {
  return SemanticProfile(scores: scores, intent: DialogIntent.chat, intensity: intensity);
}

void main() {
  late AnimationRepository repository;
  late AnimationSelector selector;

  setUp(() {
    repository = AnimationRepository.fromClips([
      _clip('idle-a', 'idle', {'idle': 1.0, 'calm': 0.8}, loop: true),
      _clip('joy-a', 'emotion', {'joy': 0.95, 'excited': 0.8}),
      _clip('joy-b', 'emotion', {'joy': 0.9, 'laugh': 0.7}),
      _clip('sad-a', 'emotion', {'sad': 0.9, 'tired': 0.6}),
      _clip('eat-a', 'food', {'eat': 0.9, 'joy': 0.3}),
      _clip('money-empty', 'money', {'balance_empty': 1.0, 'sad': 0.7}, loop: true),
      _clip('money-rich', 'money', {'balance_rich': 1.0, 'excited': 0.6}, loop: true),
      _clip('tap-a', 'emotion', {'tap': 0.9, 'shy': 0.6}),
      _clip('tap-b', 'emotion', {'tap': 0.85, 'laugh': 0.5}),
      _clip('drag-a', 'interaction', {'drag': 1.0}),
    ]);
    selector = AnimationSelector(repository: repository, random: math.Random(7));
  });

  group('主选片', () {
    test('语义命中时挑中对应素材', () {
      final clip = selector.select(_profile({'joy': 0.9}));
      expect(clip.id, anyOf('joy-a', 'joy-b'));
      expect(clip.tags.containsKey('joy'), isTrue);
    });

    test('无匹配时退回待机', () {
      final clip = selector.select(_profile({'season_winter': 0.9}));
      expect(clip.id, 'idle-a');
    });

    test('近期播放过的素材被降权', () {
      final withoutHistory = selector.select(_profile({'joy': 0.8}));
      expect(withoutHistory.id, 'joy-a');

      final withHistory = selector.select(
        _profile({'joy': 0.8}),
        policy: const SelectionPolicy(recentIds: {'joy-a'}),
      );
      expect(withHistory.id, isNot('joy-a'));
    });

    test('强制标签优先于语义打分', () {
      final clip = selector.select(
        _profile({'joy': 0.9}),
        policy: const SelectionPolicy(forcedTag: 'balance_empty'),
      );
      expect(clip.id, 'money-empty');
    });

    test('高语义强度会偏向高唤醒素材', () {
      final clip = selector.select(_profile({'joy': 0.9}, intensity: 0.9));
      expect(clip.id, 'joy-a');
    });
  });

  group('系统事件', () {
    test('余额档位映射到对应动画', () {
      expect(selector.clipForBalanceTier(BalanceTier.empty)?.id, 'money-empty');
      expect(selector.clipForBalanceTier(BalanceTier.rich)?.id, 'money-rich');
    });

    test('点击反馈只从 tap 池里挑', () {
      for (var i = 0; i < 12; i++) {
        final clip = selector.pickTap();
        expect(clip, isNotNull);
        expect(clip!.tags.containsKey('tap'), isTrue);
      }
    });

    test('拖拽素材可解析', () {
      expect(repository.dragClip?.id, 'drag-a');
    });

    test('氛围池只包含可循环的待机/睡眠素材', () {
      expect(repository.ambientClips.map((clip) => clip.id), ['idle-a']);
      expect(selector.pickAmbient()?.id, 'idle-a');
    });
  });

  group('兜底链', () {
    test('缺失标签沿 fallbackChain 回落', () {
      expect(repository.hasTag('apology'), isFalse);
      expect(repository.resolveTag('apology'), 'sad');
    });

    test('完全无路可走时回到 idle', () {
      expect(repository.resolveTag('完全不存在'), 'idle');
    });
  });

  group('余额分档阈值', () {
    test('边界值', () {
      expect(BalanceTier.fromAmount(0), BalanceTier.empty);
      expect(BalanceTier.fromAmount(-1), BalanceTier.empty);
      expect(BalanceTier.fromAmount(0.01), BalanceTier.low);
      expect(BalanceTier.fromAmount(4.99), BalanceTier.low);
      expect(BalanceTier.fromAmount(5), BalanceTier.normal);
      expect(BalanceTier.fromAmount(19.99), BalanceTier.normal);
      expect(BalanceTier.fromAmount(20), BalanceTier.good);
      expect(BalanceTier.fromAmount(99.99), BalanceTier.good);
      expect(BalanceTier.fromAmount(100), BalanceTier.rich);
    });

    test('每个档位都带 balance_ 前缀标签', () {
      for (final tier in BalanceTier.values) {
        expect(tier.tagId, startsWith('balance_'));
        expect(tier.label, isNotEmpty);
        expect(repository.resolveTag(tier.tagId), isNotEmpty);
      }
    });
  });

  test('素材模型：一次性动作的停留时长被截断到 5 秒内', () {
    final once = _clip('x', 'emotion', {'joy': 1.0});
    expect(once.holdMs, lessThanOrEqualTo(5000));
    final loop = _clip('y', 'idle', {'idle': 1.0}, loop: true);
    expect(loop.holdMs, greaterThanOrEqualTo(1200));
    expect(loop.isLoop, isTrue);
  });
}
