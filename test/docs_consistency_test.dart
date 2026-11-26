import 'dart:io';

import 'package:dsh_pet_emoji/core/app_links.dart';
import 'package:dsh_pet_emoji/data/repositories/animation_repository.dart';
import 'package:dsh_pet_emoji/data/repositories/tag_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AnimationRepository animations;
  late TagRepository tags;
  late String tagsDoc;
  late String readme;

  setUpAll(() async {
    animations = await AnimationRepository.load();
    tags = await TagRepository.load();
    tagsDoc = File('docs/TAGS.md').readAsStringSync();
    readme = File('README.md').readAsStringSync();
  });

  group('文档与清单同步', () {
    test('docs/TAGS.md 覆盖全部动画', () {
      for (final clip in animations.clips) {
        expect(
          tagsDoc.contains('`${clip.id}`'),
          isTrue,
          reason: '缺少 ${clip.id}',
        );
        expect(
          tagsDoc.contains(clip.name),
          isTrue,
          reason: '缺少中文名 ${clip.name}',
        );
      }
    });

    test('docs/TAGS.md 覆盖全部标签', () {
      for (final tag in tags.tags) {
        expect(
          tagsDoc.contains('`${tag.id}`'),
          isTrue,
          reason: '缺少标签 ${tag.id}',
        );
      }
    });

    test('README 的标签总览包含每个标签的中文名', () {
      for (final tag in tags.tags) {
        expect(
          readme.contains(tag.label),
          isTrue,
          reason: 'README 缺少标签 ${tag.label}',
        );
      }
    });

    test('README 说明了映射规则与素材目录', () {
      expect(readme.contains('映射规则'), isTrue);
      expect(readme.contains('素材目录结构'), isTrue);
      expect(readme.contains('assets/manifest/'), isTrue);
      expect(readme.contains('assets/webm/'), isTrue);
    });
  });

  group('许可与署名不可丢失', () {
    test('README、LICENSE-ASSETS、NOTICE 都带原作者地址', () {
      for (final file in ['README.md', 'LICENSE-ASSETS.md', 'NOTICE.md']) {
        final content = File(file).readAsStringSync();
        expect(
          content.contains(kUpstreamRepoUrl),
          isTrue,
          reason: '$file 缺少原作者地址 $kUpstreamRepoUrl',
        );
      }
    });

    test('形象授权声明原文完整保留', () {
      for (final file in ['README.md', 'LICENSE-ASSETS.md']) {
        final content = File(file).readAsStringSync();
        expect(content.contains('不可以以任何形式商业化'), isTrue, reason: file);
        expect(content.contains('CC BY-NC-SA 4.0'), isTrue, reason: file);
      }
    });

    test('署名信息包含两位作者与「非官方」声明', () {
      for (final file in ['README.md', 'NOTICE.md', 'LICENSE-ASSETS.md']) {
        final content = File(file).readAsStringSync();
        expect(
          content.contains(kPrototypeAuthor.replaceFirst('B 站 ', '')),
          isTrue,
          reason: file,
        );
        expect(
          content.contains(kDeepSeekDesigner.replaceFirst('B 站 ', '')),
          isTrue,
          reason: file,
        );
      }
      expect(readme.contains('非 DeepSeek 官方形象'), isTrue);
      expect(
        File('LICENSE').readAsStringSync().contains('MIT License'),
        isTrue,
      );
    });

    test('应用内「许可与出处」引用了同一份常量', () {
      final page = File('lib/presentation/settings/settings_page.dart')
          .readAsStringSync();
      expect(page.contains('kUpstreamRepoUrl'), isTrue);
      expect(page.contains('kLicenseStatement'), isTrue);
      expect(page.contains('kPrototypeAuthor'), isTrue);
      expect(page.contains('kDeepSeekDesigner'), isTrue);
    });
  });
}
