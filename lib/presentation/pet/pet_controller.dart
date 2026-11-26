import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/logger.dart';
import '../../data/models/animation_clip.dart';
import '../../data/models/semantic_profile.dart';
import '../../data/repositories/animation_repository.dart';
import '../../domain/semantic/animation_selector.dart';

/// 桌宠播放控制器：维护「当前动画 + 气泡 + 待机氛围」的时序。
///
/// 规则：
///   - 一次性动作播完（≤5s）自动回到待机；
///   - 循环动作停留到下一次调度；
///   - 空闲 12~26s 随机插入一段氛围动画；
///   - 最近 6 段动画参与防重复降权。
class PetController extends ChangeNotifier {
  PetController({
    required this.repository,
    required this.selector,
    bool ambient = true,
  }) : _ambientEnabled = ambient,
       _current = repository.idleClip;

  final AnimationRepository repository;
  final AnimationSelector selector;

  final math.Random _random = math.Random();
  final List<String> _recentIds = [];
  final List<String> _recentGroups = [];

  AnimationClip _current;
  SemanticProfile? _profile;
  String? _bubble;
  Timer? _holdTimer;
  Timer? _ambientTimer;
  Timer? _bubbleTimer;
  bool _ambientEnabled;
  bool _sleeping = false;
  bool _disposed = false;

  AnimationClip get current => _current;

  /// 当前动画的标签（UI 上展示为胶囊）。
  Map<String, double> get currentTags => _current.tags;

  SemanticProfile? get profile => _profile;

  String? get bubble => _bubble;

  bool get sleeping => _sleeping;

  bool get ambientEnabled => _ambientEnabled;

  /// 启动：进入待机并开启氛围调度。
  void start() {
    _play(repository.idleClip, resetAmbient: false);
    _scheduleAmbient();
  }

  void setAmbientEnabled(bool enabled) {
    _ambientEnabled = enabled;
    if (enabled) {
      _scheduleAmbient();
    } else {
      _ambientTimer?.cancel();
    }
    notifyListeners();
  }

  /// 对话回复完成后调用：按语义结果选片 + 冒泡。
  void react(SemanticProfile semantic, {String? bubble}) {
    _sleeping = false;
    _profile = semantic;
    final clip = selector.select(
      semantic,
      policy: SelectionPolicy(
        recentIds: _recentIds.toSet(),
        recentGroups: _recentGroups.toSet(),
      ),
    );
    _play(clip);
    if (bubble != null) say(bubble);
    Log.d('PetController', '语义 → ${clip.name}（${clip.id}）');
  }

  /// 按标签播放（点击、拖拽、余额、错误等系统事件）。
  void playTag(String tag, {String? bubble}) {
    _sleeping = false;
    final clip = selector.selectForTag(
      tag,
      recentIds: _recentIds.toSet(),
      recentGroups: _recentGroups.toSet(),
    );
    if (clip != null) _play(clip);
    if (bubble != null) say(bubble);
  }

  /// 指定素材播放。
  void play(AnimationClip clip, {String? bubble}) {
    _sleeping = false;
    _play(clip);
    if (bubble != null) say(bubble);
  }

  /// 点击宠物：优先播点击回应，没有就播任意一次性动作。
  void onTap() {
    if (_sleeping) {
      _wakeUp();
      return;
    }
    final clip = selector.pickTap(recentIds: _recentIds.toSet());
    if (clip != null) _play(clip);
  }

  void onDragStart() {
    final clip = repository.dragClip;
    if (clip != null) _play(clip);
  }

  void onDragEnd() {
    final clip = selector.pickTap(recentIds: _recentIds.toSet());
    _play(clip ?? repository.idleClip);
  }

  /// 入睡 / 唤醒（点两下或久置触发）。
  void toggleSleep() {
    if (_sleeping) {
      _wakeUp();
    } else {
      _sleeping = true;
      final sequence = repository.sleepSequence;
      if (sequence.isNotEmpty) {
        _play(sequence.first, resetAmbient: false);
        _holdTimer?.cancel();
        _holdTimer = Timer(const Duration(seconds: 4), () {
          if (_sleeping && sequence.length > 1) {
            _play(sequence[1], resetAmbient: false);
          }
        });
      }
      notifyListeners();
    }
  }

  void _wakeUp() {
    _sleeping = false;
    final sequence = repository.sleepSequence;
    if (sequence.length > 2) {
      _play(sequence.last, resetAmbient: false);
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: 2400), () {
        _play(repository.idleClip);
      });
    } else {
      _play(repository.idleClip);
    }
  }

  /// 冒一个短气泡，3 秒后消失。
  void say(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _bubble = trimmed.length <= 36 ? trimmed : '${trimmed.substring(0, 36)}…';
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(seconds: 4), () {
      _bubble = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void clearBubble() {
    _bubbleTimer?.cancel();
    _bubble = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 内部时序
  void _play(AnimationClip clip, {bool resetAmbient = true}) {
    _current = clip;
    _recentIds.add(clip.id);
    if (_recentIds.length > 6) _recentIds.removeAt(0);
    _recentGroups.add(clip.group);
    if (_recentGroups.length > 6) _recentGroups.removeAt(0);

    _holdTimer?.cancel();
    if (clip.isLoop) {
      _holdTimer = Timer(
        Duration(milliseconds: clip.holdMs + 6000),
        _backToIdle,
      );
    } else {
      _holdTimer = Timer(Duration(milliseconds: clip.holdMs), _backToIdle);
    }
    if (resetAmbient && _ambientEnabled) _scheduleAmbient();
    if (!_disposed) notifyListeners();
  }

  void _backToIdle() {
    if (_sleeping) return;
    if (_current.id == repository.idleClip.id) {
      _scheduleAmbient();
      return;
    }
    _current = repository.idleClip;
    if (!_disposed) notifyListeners();
    _scheduleAmbient();
  }

  void _scheduleAmbient() {
    _ambientTimer?.cancel();
    if (!_ambientEnabled || _disposed) return;
    final seconds = 12 + _random.nextInt(15);
    _ambientTimer = Timer(Duration(seconds: seconds), () {
      if (_sleeping) {
        _scheduleAmbient();
        return;
      }
      final clip = selector.pickAmbient(recentIds: _recentIds.toSet());
      if (clip != null) {
        _play(clip);
      } else {
        _scheduleAmbient();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _holdTimer?.cancel();
    _ambientTimer?.cancel();
    _bubbleTimer?.cancel();
    super.dispose();
  }
}
