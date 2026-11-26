# 素材目录与处理链

## 目录结构

```
assets/
├─ animations/            运行时素材，参与打包（pubspec 中声明）
│  ├─ daiji-huxi-xiuxian.webp    640×360 透明动画 WebP，114 段
│  ├─ chi-baifan.webp
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
| `assets/animations/` | ✅ | `AnimationClip.animPath` → `Image.asset` | 运行时就靠它，约 117MB |
| `assets/webm/` | ❌ | 无（人工与再生成流程使用） | 高清母版/源视频，56MB |
| `assets/manifest/` | ✅ | `AnimationRepository` / `TagRepository` | 语义匹配的全部依据 |

## 为什么运行时用动画 WebP，而不是直接播 WebM

母版 `assets/webm/*.webm` 是 VP9 + **真 alpha**（`ALPHA_MODE=1`，用 `-c:v libvpx-vp9`
解码可得 `yuva420p`）。理论上最理想的是直接播它，但 Flutter 三端做不到：

- Flutter 没有内置视频解码；`video_player` / `media_kit` 拿到的纹理是**不透明**的，
  无法逐像素把 alpha 合成进组件树，桌宠背后会出现一块黑底。
- **iOS 的 AVFoundation 不支持 VP9**，这条路在 iPhone 上直接走不通。

GIF 也不行：640×360 的 GIF 实测约 7 MB/段，114 段要 800 MB，而且只有 256 色。

所以运行时素材用**动画 WebP**：Flutter 的 `Image` 原生支持多帧 WebP 与 alpha，
三端一致、零额外插件，`Image.asset` 代码路径和普通图片完全相同。

| 方案 | 尺寸 | 体积 | 三端可用 | 透明 |
| --- | --- | --- | --- | --- |
| 直接播 WebM | 640×360 | 56 MB | ❌ iOS 无 VP9 | ❌ 视频纹理不透明 |
| GIF | 640×360 | ~800 MB | ✅ | ✅ 但仅 256 色 |
| **动画 WebP（当前）** | 640×360 | ~117 MB | ✅ | ✅ 真 alpha |
| 旧方案 GIF | 220×124 | 67 MB | ✅ | ✅ 但放大后发虚 |

## 从 WebM 重新导出运行时素材（需要 ffmpeg）

```bash
# 默认参数：640 宽 / 12fps / q45 / 6 秒，与母版同尺寸
python tool/gen_webp.py --ffmpeg /path/to/ffmpeg

# 只导几段、想换参数
python tool/gen_webp.py --only 吃白饭 放烟花 --width 480 --fps 12 --quality 50

# 只校验尺寸与帧数（CI 用，不需要 ffmpeg）
python tool/gen_webp.py --check
```

关键点：**必须显式 `-c:v libvpx-vp9`**，否则 ffmpeg 用默认解码器会丢掉 alpha，
拿到的是一张黑底不透明画面。脚本已经处理好了。

导出后重跑 `python tool/gen_manifest.py`（读取每个 WebP 的真实尺寸/时长）
与 `python tool/gen_docs.py`。

> 体积参考：640×360 / 12fps / q45 / 6s ≈ 1.0 MB/段，114 段合计约 117 MB。
> 母版是 10 秒 24fps，运行时只取前 6 秒——桌宠一次最多播 5 秒，更长的部分用不上。
>
> 帧率取 12 而非 15 是有原因的：母版 24fps，24→12 是**整数二分频**，每帧间隔均匀；
> 24→15 得到的是 1/2/1/2 的不均匀采样，同码率下 SSIM 反而更低（实测 0.9465 vs
> 0.9469），体积还大 20%。所以这一步是「更小且更准」，不是画质妥协。
> 分辨率始终保持 640×360 与母版一致，锐度不受影响。

仍想用 GIF 的话，`tool/rebuild_gifs.py` 保留了原来的导出流程，但注意体积会翻数倍。

## 命名规则

- **WebP 文件名 = clip id**：英文小写 + 连字符，取原中文名的拼音缩写，
  例如 `chi-baifan`（吃白饭）、`shuijiao-xunhuan`（睡觉-循环）。
  出现重名时加语义后缀：`dianji-huiying-aojiao-shengqi-ceshen-zhanshi`。
- **WebM 文件名 = clip 的 `name` 字段**（中文原名），两者必须一致，
  生成脚本会校验——对不上会直接报错退出。
- 114 段动画目前全部有运行时素材与母版，`playable` 均为 `true`。
  历史上「只有 WebM 没有 GIF」的 5 段（期待开饭、开心小跑、侧身急躁跑、
  吃饭·碗饭、吃饭团）已随 WebP 迁移补齐。

## 新增一段动画

1. WebM → `assets/webm/<中文原名>.webm`
2. 跑 `python tool/gen_webp.py --only <中文原名>` 生成 `assets/animations/<id>.webp`
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
