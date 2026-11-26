import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../data/models/animation_clip.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_view.dart';
import '../widgets/tag_chip.dart';

/// 表情库：浏览全部素材、按标签筛选、点播一段动画。
///
/// 它同时是「语义标签 ↔ 动画」映射的活文档——每张卡片都能看到自己的标签。
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.services});

  final AppServices services;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  String _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final clips = services.animations.clips
        .where((clip) {
          if (clip.gifPath == null) return false;
          if (_group != null && clip.group != _group) return false;
          if (_query.isEmpty) return true;
          final keyword = _query.toLowerCase();
          final tagLabels = clip.tags.keys.map(services.tags.labelOf).join(' ');
          return clip.name.toLowerCase().contains(keyword) ||
              clip.id.contains(keyword) ||
              tagLabels.contains(keyword);
        })
        .toList(growable: false);

    final groups =
        services.animations.playableClips
            .map((clip) => clip.group)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              '表情库',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            SoftTag('${services.animations.animationCount} 段可播放'),
            const SizedBox(width: 6),
            SoftTag('${services.tags.tags.length} 个标签'),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索动画名或标签，例如「吃饭」「害羞」',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _GroupChip(
                  label: '全部',
                  selected: _group == null,
                  onTap: () => setState(() => _group = null),
                ),
                for (final group in groups)
                  _GroupChip(
                    label: _groupLabel(group),
                    selected: _group == group,
                    onTap: () => setState(() => _group = group),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: clips.isEmpty
                ? const Center(
                    child: Text(
                      '没有匹配的动画',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 210,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                    itemCount: clips.length,
                    itemBuilder: (context, index) {
                      final clip = clips[index];
                      return _ClipCard(
                        clip: clip,
                        labelOf: services.tags.labelOf,
                        onTap: () => _playAndReturn(clip),
                        onTagTap: (tag) => _playTagAndReturn(tag),
                        onInfo: () => _showDetail(context, clip),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 播放某段动画并退回主界面：桌宠就在主界面上，所以「回主界面」= 关闭表情库。
  ///
  /// 返回 `true` 让外壳知道「确实播了」，移动端据此切回桌宠页签。
  void _playAndReturn(AnimationClip clip) {
    widget.services.pet.play(clip, bubble: clip.name);
    Navigator.of(context).pop(true);
  }

  /// 点标签时按该标签挑一段动画播，然后同样回到主界面。
  void _playTagAndReturn(String tag) {
    final services = widget.services;
    services.pet.playTag(tag, bubble: services.tags.labelOf(tag));
    Navigator.of(context).pop(true);
  }

  String _groupLabel(String group) => switch (group) {
    'idle' => '待机',
    'emotion' => '情绪',
    'social' => '社交',
    'food' => '吃喝',
    'work' => '工作',
    'play' => '玩耍',
    'festival' => '节日',
    'money' => '余额',
    'sleep' => '睡眠',
    'interaction' => '交互',
    _ => group,
  };

  void _showDetail(BuildContext context, AnimationClip clip) {
    final services = widget.services;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          clip.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'id: ${clip.id}\n时长: ${(clip.durationMs / 1000).toStringAsFixed(1)}s'
              ' · 停留: ${clip.isLoop ? '循环' : '一次性'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in clip.tags.entries)
                  TagChip(
                    label: services.tags.labelOf(entry.key),
                    score: entry.value,
                    showScore: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (clip.webmPath != null)
              Text(
                '母版: ${clip.webmPath!.replaceFirst('assets/webm/', '')}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _playAndReturn(clip);
            },
            child: const Text('播放'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClipCard extends StatelessWidget {
  const _ClipCard({
    required this.clip,
    required this.labelOf,
    required this.onTap,
    required this.onTagTap,
    required this.onInfo,
  });

  final AnimationClip clip;
  final String Function(String) labelOf;
  final VoidCallback onTap;
  final ValueChanged<String> onTagTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final topTags = clip.tags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                // 缩略图 0.7×：缩小属于重采样，不会像放大那样发虚
                child: PetView(clip: clip, zoom: 0.7, showShadow: false),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    clip.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onInfo,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in topTags.take(2))
                  TagChip(
                    label: labelOf(entry.key),
                    dense: true,
                    onTap: () => onTagTap(entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
