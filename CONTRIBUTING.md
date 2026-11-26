# 贡献指南

## 先读这两条

1. **素材不是随便能改的。** `assets/` 与角色形象按 CC BY-NC-SA 4.0 授权，
   任何素材改动都要保持署名、非商业、相同方式共享。见 [LICENSE-ASSETS.md](LICENSE-ASSETS.md)。
2. **不要移除署名。** 包括 README、应用内「设置 → 许可与出处」里的原作者地址与作者信息。

## 开发环境

```bash
flutter --version      # 需要 3.35+（Dart 3.9+），本项目在 3.47.4 验证
flutter pub get
flutter analyze        # 必须 0 issue
flutter test           # 必须全绿
flutter run -d windows # 或 android / ios 设备
```

## 提交前自检

- [ ] `flutter analyze` 无 issue
- [ ] `flutter test` 全绿
- [ ] 改了素材或标注 → 重跑 `python tool/gen_manifest.py`，并提交 `assets/manifest/*.json`
- [ ] 改了标签/动画 → 重跑 `python tool/gen_docs.py` 同步 README 与 docs/TAGS.md
- [ ] 新增动画 → 同时更新 [docs/ASSETS.md](docs/ASSETS.md) 的目录说明

## 新增一段动画

1. 高清母版放到 `assets/webm/<中文原名>.webm`（640×360、VP9、带 alpha）。
2. 用 `python tool/gen_webp.py --only <中文原名>` 导出运行时素材
   `assets/animations/<id>.webp`（`<id>` 用英文小写 + 连字符，例如 `chi-baifan`）。
   不要手工做 GIF——体积是 WebP 的 5 倍以上且只有 256 色。
3. 在 `tool/gen_manifest.py` 的 `CLIPS` 里加一行：分组、停留策略、1~6 个标签及契合度。
4. `python tool/gen_boxes.py` 重新量内容框，再 `python tool/gen_manifest.py`
   与 `python tool/gen_docs.py`。
5. `flutter test` —— 清单完整性测试会检查文件、标签与命名是否对得上。

## 新增一个语义标签

1. 在 `tool/gen_manifest.py` 的 `TAGS` 里定义：`id`（英文 snake_case）、`label`（中文）、
   `group`、`base`（基础强度）、`description`、`keywords`（关键词词典，可空）。
2. 至少给一段动画打上该标签，或在 `AnimationRepository.fallbackChain` 里声明回落标签。
3. 重新生成清单与文档，跑测试。

## 代码风格

- 目录分层：`data`（模型/仓库/服务）→ `domain`（语义分析与选片）→ `presentation`（UI）。
  领域逻辑不 import Flutter widget，保证可单测。
- 中文注释写「为什么」，英文标识符写「是什么」。
- 不引入状态管理框架；`ChangeNotifier` + 构造注入足够，别为小项目加抽象层。

## PR

- 一个 PR 只做一件事，标题写清楚改了什么。
- 涉及行为的改动请附带测试；涉及 UI 的请附截图。
