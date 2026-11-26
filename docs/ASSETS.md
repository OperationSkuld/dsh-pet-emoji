# 素材目录与处理链

## 目录结构

```
assets/
├─ animations/            运行时素材，参与打包（pubspec 中声明）
│  ├─ daiji-huxi-xiuxian.gif     220×124 透明 GIF，109 段
│  ├─ chi-baifan.gif
│  └─ …
├─ webm/                  高清母版，不参与打包（仅随仓库分发）
│  ├─ 待机呼吸休闲.webm          与 clip 的 name 字段同名
│  ├─ 吃白饭.webm
│  └─ …                          114 段
└─ manifest/              语义清单，由 tool/gen_manifest.py 生成
   ├─ animations.json     114 段动画 × 标签契合度 × 时长
   └─ tags.json           60 个标签的标题、分组、说明、关键词词典
```

三个目录的分工：

| 目录 | 是否打进应用 | 谁在读 | 说明 |
| --- | --- | --- | --- |
| `assets/animations/` | ✅ | `AnimationClip.gifPath` → `Image.asset` | 运行时就靠它 |
| `assets/webm/` | ❌ | 无（人工与再生成流程使用） | 高清母版/源视频，56MB |
| `assets/manifest/` | ✅ | `AnimationRepository` / `TagRepository` | 语义匹配的全部依据 |

## 为什么运行时用 GIF 而不是 WebM

- Flutter 的 `Image` 原生支持动态 GIF，Windows / Android / iOS 表现一致，无需视频插件。
- WebM（VP9 + alpha）在 Flutter 桌面端没有官方播放器，社区插件对透明通道的支持不稳定；
  引入视频管线会显著增加三端联调成本。
- 因此：**GIF 负责「能不能播」，WebM 负责「画质上限」**。想要更高画质时，
  用下面的命令从 WebM 重新导出更高分辨率的 GIF，覆盖 `assets/animations/<id>.gif` 即可，
  代码与清单都不需要改（`width`/`height` 仅作展示参考）。

## 从 WebM 重新导出 GIF（需要 ffmpeg）

```bash
# 单个：中文文件名 → clip id，注意 reserve_transparent 保住透明通道
ffmpeg -i "assets/webm/吃白饭.webm" \
  -vf "fps=20,scale=440:-1:flags=lanczos,split[a][b];[a]palettegen=reserve_transparent=1:stats_mode=full[p];[b][p]paletteuse=alpha_threshold=128" \
  -loop 0 "assets/animations/chi-baifan.gif"

# 批量：按 name → id 的映射导出（映射来自 assets/manifest/animations.json）
python tool/rebuild_gifs.py --width 440
```

导出后重跑 `python tool/gen_manifest.py` 让时长字段与新 GIF 对齐。

> 尺寸放大到 440 宽时体积约为原来的 4 倍，109 段合计 ~270MB。除非确实需要，
> 建议保持 220 宽——运行时按 1× 原生尺寸渲染（220×124），放大交给界面做整数倍
> 最近邻缩放；换成高分辨率素材后无需改代码，但整套体积会翻数倍。

## 命名规则

- **GIF 文件名 = clip id**：英文小写 + 连字符，取原中文名的拼音缩写，
  例如 `chi-baifan`（吃白饭）、`shuijiao-xunhuan`（睡觉-循环）。
  出现重名时加语义后缀：`dianji-huiying-aojiao-shengqi-ceshen-zhanshi`。
- **WebM 文件名 = clip 的 `name` 字段**（中文原名），两者必须一致，
  生成脚本会校验——对不上会直接报错退出。
- 一个 clip 可以有 WebM 而没有 GIF（缺预览），此时 `gif: null`，
  运行时会被 `playable == false` 过滤掉。当前有 5 段属于这种情况：
  期待开饭、开心小跑、侧身急躁跑、吃饭·碗饭、吃饭团。

## 新增一段动画

1. GIF → `assets/animations/<id>.gif`（220×124，透明背景，循环）
2. WebM → `assets/webm/<中文原名>.webm`
3. 在 `tool/gen_manifest.py` 的 `CLIPS` 里加一行：
   ```python
   ("chi-hanbao", "吃汉堡", "food", "once", dict(eat=0.9, joy=0.5, cute=0.4)),
   ```
   - 第 3 列是分组：`idle / emotion / social / food / work / play / festival / money / sleep / interaction`
   - 第 4 列是停留策略：`once`（播完回待机）/ `loop`（长时间停留）
   - 第 5 列是 1~6 个标签及契合度（0~1）
4. `python tool/gen_manifest.py` → `python tool/gen_docs.py`
5. `flutter test` —— 清单完整性测试会检查文件是否存在、标签是否已定义、命名是否对得上

## 素材加工链（上游）

本仓库的 GIF / WebM 来自上游 [dsh-pet](https://github.com/PC2005-cloud/dsh-pet) 的
素材生成链：提示词 → AI 生成源视频 → 抠像 → 透明 WebM → 导出 GIF 预览。
本仓库只做「使用 + 语义标注」，不重复实现生成链；如需从零造一套自己的宠物，
请阅读上游仓库的 `prompts/` 与 `MAKE-YOUR-OWN-PET.md`。

## 授权

素材与形象不是 MIT：**CC BY-NC-SA 4.0，不可商用，必须署名**。
详见 [../LICENSE-ASSETS.md](../LICENSE-ASSETS.md)。替换素材做成自己的角色时，
请确认新素材本身的授权，并保留上游署名要求。
