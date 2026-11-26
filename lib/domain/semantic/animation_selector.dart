import 'dart:math' as math;

import '../../core/logger.dart';
import '../../data/models/animation_clip.dart';
import '../../data/models/balance_info.dart';
import '../../data/models/semantic_profile.dart';
import '../../data/repositories/animation_repository.dart';

/// 选片策略参数。
class SelectionPolicy {
  const SelectionPolicy({
    this.recentIds = const {},
    this.forcedTag,
    this.recentGroups = const {},
    this.minScore = 0.04,
  });

  /// 最近播放过的素材，用于防重复（同 id 权重 ×0.2）。
  final Set<String> recentIds;

  /// 系统事件强制标签（如 balance_low、tap、drag）。
  final String? forcedTag;

  /// 最近播放过的分组，轻微降权。
  final Set<String> recentGroups;

  final double minScore;
}

/// 语义选片器：语义向量 × 素材标签契合度 → 一段动画。
///
/// 打分公式见 docs/TAGS.md「映射规则」。结果在 top-K 内做加权随机，
/// 既保证相关又不会每次都一模一样。
class AnimationSelector {
  AnimationSelector({required this.repository, math.Random? random})
      : _random = random ?? math.Random();

  final AnimationRepository repository;
  final math.Random _random;

  /// 时令标签只做氛围加成，权重压低到 0.35：
  /// 否则「季节」这种永远存在的弱信号会在没有情绪时喧宾夺主。
  static const Set<String> _sceneTags = {
    'season_spring',
    'season_summer',
    'season_autumn',
    'season_winter',
    'night',
    'morning',
  };
  static const double _sceneFactor = 0.35;

  /// 得分低于该阈值说明只是被氛围标签带起来的，不如安静待机。
  static const double _meaningfulScore = 0.12;

  static const Map<DialogIntent, Set<String>> _intentGroups = {
    DialogIntent.greeting: {'social', 'emotion'},
    DialogIntent.farewell: {'social', 'sleep'},
    DialogIntent.thanks: {'social', 'emotion'},
    DialogIntent.apology: {'emotion', 'work'},
    DialogIntent.praise: {'emotion', 'social'},
    DialogIntent.comfort: {'emotion', 'idle'},
    DialogIntent.refuse: {'emotion'},
    DialogIntent.question: {'emotion', 'work'},
    DialogIntent.food: {'food'},
    DialogIntent.work: {'work'},
    DialogIntent.code: {'work'},
    DialogIntent.play: {'play'},
    DialogIntent.money: {'money'},
    DialogIntent.chat: {'emotion', 'idle'},
  };

  /// 主入口：返回一定可播放的动画（无匹配时退回待机）。
  AnimationClip select(
    SemanticProfile profile, {
    SelectionPolicy policy = const SelectionPolicy(),
  }) {
    if (policy.forcedTag != null) {
      final forced = selectForTag(
        policy.forcedTag!,
        recentIds: policy.recentIds,
        recentGroups: policy.recentGroups,
      );
      if (forced != null) return forced;
    }

    final scored = <_ScoredClip>[];
    for (final clip in repository.playableClips) {
      final score = _score(clip, profile, policy);
      if (score >= policy.minScore) {
        scored.add(_ScoredClip(clip, score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.isEmpty || scored.first.score < _meaningfulScore) {
      Log.d('AnimationSelector', '信号太弱，退回待机');
      return repository.idleClip;
    }
    // 只在「接近最佳」的素材里随机：保留多样性，但不让弱信号抢戏。
    final best = scored.first.score;
    final pool = scored
        .take(4)
        .where((item) => item.score >= best * 0.6)
        .toList(growable: false);
    return _pickWeighted(pool);
  }

  /// 按单一标签取片（系统事件、点击、拖拽）。
  AnimationClip? selectForTag(
    String tag, {
    Set<String> recentIds = const {},
    Set<String> recentGroups = const {},
  }) {
    final resolved = repository.resolveTag(tag);
    final candidates = repository.clipsWithTag(resolved, minAffinity: 0.8);
    if (candidates.isEmpty) return null;

    final scored = <_ScoredClip>[
      for (final clip in candidates)
        _ScoredClip(
          clip,
          clip.affinity(resolved) *
              (recentIds.contains(clip.id) ? 0.25 : 1.0) *
              (recentGroups.contains(clip.group) ? 0.8 : 1.0),
        ),
    ];
    scored.sort((a, b) => b.score.compareTo(a.score));
    return _pickWeighted(scored.take(3).toList(growable: false));
  }

  /// 余额档位 → 专属动画。
  AnimationClip? clipForBalanceTier(BalanceTier tier) =>
      selectForTag(tier.tagId);

  /// 空闲氛围动画。
  AnimationClip? pickAmbient({Set<String> recentIds = const {}}) {
    final pool = repository.ambientClips
        .where((clip) => !recentIds.contains(clip.id))
        .toList(growable: false);
    if (pool.isEmpty) return null;
    return pool[_random.nextInt(pool.length)];
  }

  /// 点击回应。
  AnimationClip? pickTap({Set<String> recentIds = const {}}) {
    final pool = repository.tapClips
        .where((clip) => !recentIds.contains(clip.id))
        .toList(growable: false);
    if (pool.isEmpty) return repository.tapClips.isEmpty ? null : repository.tapClips.first;
    return pool[_random.nextInt(pool.length)];
  }

  double _score(AnimationClip clip, SemanticProfile profile, SelectionPolicy policy) {
    var sum = 0.0;
    var matched = 0;
    profile.scores.forEach((tag, weight) {
      final affinity = clip.affinity(tag);
      if (affinity > 0) {
        sum += weight * affinity * (_sceneTags.contains(tag) ? _sceneFactor : 1.0);
        matched++;
      }
    });
    if (matched == 0) return 0;

    final coverage = matched / clip.tags.length;
    var score = sum * (1 + 0.2 * coverage);

    if (_intentGroups[profile.intent]?.contains(clip.group) ?? false) {
      score *= 1.12;
    }
    if (profile.intensity > 0.65 &&
        (clip.affinity('excited') >= 0.5 || clip.affinity('laugh') >= 0.5)) {
      score *= 1.1;
    }
    if (profile.intensity < 0.3 && clip.affinity('excited') >= 0.7) {
      score *= 0.7;
    }
    if (policy.recentIds.contains(clip.id)) score *= 0.2;
    if (policy.recentGroups.contains(clip.group)) score *= 0.85;
    return score;
  }

  AnimationClip _pickWeighted(List<_ScoredClip> candidates) {
    if (candidates.length == 1) return candidates.first.clip;
    final total = candidates.fold<double>(0, (sum, item) => sum + item.score);
    if (total <= 0) return candidates.first.clip;
    var threshold = _random.nextDouble() * total;
    for (final item in candidates) {
      threshold -= item.score;
      if (threshold <= 0) return item.clip;
    }
    return candidates.last.clip;
  }
}

class _ScoredClip {
  const _ScoredClip(this.clip, this.score);

  final AnimationClip clip;
  final double score;
}
