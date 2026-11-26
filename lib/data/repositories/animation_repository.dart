import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/logger.dart';
import '../models/animation_clip.dart';

/// 动画素材仓库：加载语义清单，建立「标签 → 素材」倒排索引。
class AnimationRepository {
  AnimationRepository.fromClips(
    List<AnimationClip> clips, {
    this.frameWidth = 220,
    this.frameHeight = 124,
  }) : clips = List.unmodifiable(clips),
       _byId = {for (final clip in clips) clip.id: clip},
       _byTag = _buildIndex(clips) {
    if (_idleClip == null) {
      throw StateError('素材清单缺少可用的待机动画（需含 idle 标签且带 GIF）');
    }
  }

  final List<AnimationClip> clips;
  final int frameWidth;
  final int frameHeight;

  final Map<String, AnimationClip> _byId;
  final Map<String, List<AnimationClip>> _byTag;

  /// 标签缺失时的兜底顺序。选中链上第一个有素材的标签。
  static const Map<String, List<String>> fallbackChain = {
    'apology': ['sad', 'tired'],
    'comfort': ['calm', 'love'],
    'refuse': ['angry', 'tease'],
    'error': ['sad', 'annoyed'],
    'sad': ['tired', 'calm'],
    'tired': ['sleepy', 'calm'],
    'lonely': ['sad', 'calm'],
    'praise': ['shy', 'joy'],
    'grateful': ['thanks', 'joy'],
    'bored': ['dazed', 'idle'],
  };

  static Map<String, List<AnimationClip>> _buildIndex(
    List<AnimationClip> clips,
  ) {
    final index = <String, List<AnimationClip>>{};
    for (final clip in clips) {
      if (!clip.playable) continue;
      for (final tag in clip.tags.keys) {
        index.putIfAbsent(tag, () => <AnimationClip>[]).add(clip);
      }
    }
    for (final entry in index.entries) {
      entry.value.sort(
        (a, b) => b.affinity(entry.key).compareTo(a.affinity(entry.key)),
      );
    }
    return index;
  }

  static Future<AnimationRepository> load({AssetBundle? bundle}) async {
    final source = bundle ?? rootBundle;
    final raw = await source.loadString('assets/manifest/animations.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final frame = decoded['frame'] as Map<String, dynamic>? ?? const {};
    final list = (decoded['clips'] as List<dynamic>)
        .map((item) => AnimationClip.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    Log.d('AnimationRepository', '已加载 ${list.length} 段动画');
    return AnimationRepository.fromClips(
      list,
      frameWidth: (frame['width'] as num?)?.toInt() ?? 220,
      frameHeight: (frame['height'] as num?)?.toInt() ?? 124,
    );
  }

  Iterable<AnimationClip> get playableClips =>
      clips.where((clip) => clip.playable);

  AnimationClip? byId(String id) => _byId[id];

  /// 拥有该标签的素材，按契合度降序。
  List<AnimationClip> clipsWithTag(String tag, {double minAffinity = 0.0}) {
    final list = _byTag[tag];
    if (list == null || list.isEmpty) return const [];
    if (minAffinity <= 0) return list;
    return list
        .where((clip) => clip.affinity(tag) >= minAffinity)
        .toList(growable: false);
  }

  bool hasTag(String tag) => clipsWithTag(tag, minAffinity: 0.85).isNotEmpty;

  /// 按兜底链解析出一个真实存在的标签。
  String resolveTag(String tag) {
    if (hasTag(tag)) return tag;
    final chain = fallbackChain[tag] ?? const <String>[];
    for (final alternative in chain) {
      if (hasTag(alternative)) return alternative;
    }
    return 'idle';
  }

  AnimationClip get idleClip => _idleClip!;

  AnimationClip? get _idleClip {
    final candidates = clipsWithTag(
      'idle',
      minAffinity: 0.8,
    ).where((clip) => clip.isLoop).toList(growable: false);
    if (candidates.isNotEmpty) return candidates.first;
    final onlyIdle = clipsWithTag('idle');
    if (onlyIdle.isNotEmpty) return onlyIdle.first;
    return null;
  }

  /// 空闲时自动播放的素材池：只有「可长时间停留」的安静动作。
  late final List<AnimationClip> ambientClips = playableClips
      .where(
        (clip) =>
            clip.isLoop && (clip.group == 'idle' || clip.group == 'sleep'),
      )
      .where((clip) => !clip.tags.containsKey('money'))
      .toList(growable: false);

  /// 点击反馈池。
  late final List<AnimationClip> tapClips = clipsWithTag('tap')
      .toList(growable: false);

  /// 拖拽反馈。
  AnimationClip? get dragClip {
    final list = clipsWithTag('drag', minAffinity: 0.8);
    return list.isEmpty ? null : list.first;
  }

  /// 入睡序列：开始 → 循环 → 起床。
  List<AnimationClip> get sleepSequence => [
    for (final id in ['shuijiao-kaishi', 'shuijiao-xunhuan', 'shuijiao-qilai'])
      if (_byId[id] != null) _byId[id]!,
  ];

  int get animationCount => playableClips.length;
  int get tagCount => _byTag.keys.length;
}
