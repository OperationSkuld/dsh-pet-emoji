<div align="center">

# 大肥鱼桌宠 · dsh-pet-emoji 🐳

**说一句话 → DeepSeek 回复 → 拆出语义标签 → 从 114 段动画里挑一段演给你看。**

Flutter 写的语义化表情桌宠，Windows / Android / iOS 三端同一套代码。

<img src="assets/animations/daiji-huxi-xiuxian.webp" width="150" alt="待机呼吸休闲">
<img src="assets/animations/dianji-huiying-kaixin-yuedong.webp" width="150" alt="开心跃动">
<img src="assets/animations/chi-token.webp" width="150" alt="吃Token">
<img src="assets/animations/xie-daima.webp" width="150" alt="写代码">

![platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android%20%7C%20iOS-4D6BFE)
![flutter](https://img.shields.io/badge/Flutter-3.35%2B-02569B?logo=flutter)
![code license](https://img.shields.io/badge/code-MIT-green)
![assets license](https://img.shields.io/badge/assets-CC%20BY--NC--SA%204.0-orange)
![animations](https://img.shields.io/badge/animations-114-ff69b4)
![tags](https://img.shields.io/badge/semantic%20tags-60-8A2BE2)

</div>

---

## 这是什么

一只住在对话框旁边的鲸鱼娘。你跟她聊天，她回答你；回答结束的一瞬间，
本地语义分析把这段对话拆成一组标签（开心、害羞、写代码、余额不足、深夜、中秋……），
再按标签去素材库里挑一段最贴的动画播出来——不是随机轮播，也不是关键词硬匹配一条。

三个设计取舍：

1. **表情由回复内容决定，而不是只由你说了什么决定**：用户输入占 55% 权重，
   模型回复占 45%。她说「抱抱你」的时候，你看到的是安慰的表情。
2. **语义分析默认全在本地**：60 个标签、424 个关键词、否定与程度修饰、时段与节日情境，
   一次对话零额外 token。想要更准可以打开「DeepSeek 辅助标注」，失败会自动退回本地结果。
3. **素材是数据，不是代码**：114 段动画的标签、权重、时长全在 `assets/manifest/*.json`，
   换素材不用改一行 Dart。

## 核心能力

| 能力 | 说明 |
| --- | --- |
| **语义对话** | DeepSeek `chat/completions` 流式输出，支持 `deepseek-chat` / `deepseek-reasoner`，可中途停止 |
| **语义标签** | 词典 + 程度副词 + 否定翻转 + 结构信号（标点/代码块/金额/长度）+ 情境（时段/季节/公历节日），输出标签权重、对话意图、情绪强度 |
| **表情匹配** | 契合度打分 + 覆盖率加成 + 意图分组加成 + 防重复 + 氛围降权；信号太弱时回待机而不是硬凑 |
| **余额查询** | `GET /user/balance`，按 6 档余额播放专属「钱袋」动画 |
| **桌宠表现** | 点击回应、拖拽悬停反馈、双击哄睡、12~26 秒随机氛围动作、气泡转述回复 |
| **表情库** | 按分组/关键词浏览全部素材，查看每段的标签与权重——映射关系的活文档 |
| **桌面小窗** | Windows 无边框置顶 384×468 紧凑模式，带迷你输入框 |

## 语义链路

```
        你：「今天好累啊……」
                    │
                    ▼
   ┌────────────────────────────────┐
   │  DeepSeek /chat/completions    │  SSE 流式
   │  「辛苦啦，先歇一会儿吧」        │
   └────────────────┬───────────────┘
                    ▼
   ┌────────────────────────────────────────────┐
   │ SemanticAnalyzer（本地，零 token）           │
   │  词典：累 → tired .75                       │
   │  结构：省略号 → dazed .40                    │
   │  情境：22:41 → night .45 / sleepy .30        │
   │  → {tired .71, sleepy .42, dazed .40, …}    │
   │  → intent: chat, intensity: .52             │
   └────────────────┬───────────────────────────┘
                    ▼
   ┌────────────────────────────────────────────┐
   │ AnimationSelector                           │
   │  score = Σ(语义分 × 契合度 × 氛围系数)        │
   │        × 覆盖率 × 意图加成 × 防重复           │
   └────────────────┬───────────────────────────┘
                    ▼
              「工作状态-垂头叹气冒汗」👈 播 5 秒，然后回待机呼吸
```

## 快速开始

### 用 Release 里的安装包

| 平台 | 文件 | 说明 |
| --- | --- | --- |
| Windows x64 | `dsh-pet-emoji-windows-x64.zip` | 解压运行 `dsh_pet_emoji.exe`（未做代码签名，SmartScreen 可能提示未知发布者） |
| Android | `dsh-pet-emoji-android.apk` | 允许未知来源后安装；使用 debug 密钥签名，可直接装但不可上架商店 |
| iOS | `dsh-pet-emoji-ios-unsigned.ipa` | 未签名，需 AltStore / Sideloadly 重签；另附 `ios-app.zip` 为原始 `Runner.app` |

### 从源码运行

```bash
flutter pub get
flutter run -d windows    # 或 android / ios
```

首次启动会提示填 API Key：设置 → DeepSeek 接入 → 粘贴 `sk-...` → 测试连接。
Key 只存在本机 SharedPreferences，不上报任何第三方（安全取舍见
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)）。

## 语义标签 ↔ 动画表情

60 个标签分五组：**情绪**（决定表情基调）、**社交**（对话意图）、**行为**（话题领域）、
**时令**（氛围加成）、**系统**（余额档位等 App 事件，优先级最高）。

下表是「标签 → 可播放动画」的完整索引。素材与标签是多对多：一段动画可同时拥有多个标签，
一个标签也可对应多段动画；逐条的反向清单见 [docs/TAGS.md](docs/TAGS.md)。

<!-- BEGIN:TAG_OVERVIEW -->
**情绪**（由对话内容推断的情感状态，决定表情基调）

| 标签 | id | 可用动画 | 代表表情 |
| --- | --- | --- | --- |
| **不耐烦** | `annoyed` | 5 | 用鲸鱼尾巴拍打地面、侧身急躁跑 |
| **亲昵** | `love` | 5 | 撸猫、鲸鱼吐泡泡特效 |
| **兴奋** | `excited` | 14 | 原地跳跃抓碎头顶物品、点击回应-开心跃动 |
| **发呆** | `dazed` | 5 | 碎碎念-发呆碎碎念、碎碎念-对屏碎碎念 |
| **困倦** | `sleepy` | 6 | 哈欠连天、原地小憩沉眠 |
| **困惑** | `confused` | 4 | 是啊，吃什么、余额-数金皱眉 |
| **大笑** | `laugh` | 1 | 点击回应-挠痒咯咯笑 |
| **害怕** | `scared` | 2 | 被吓一跳、打瞌睡被惊醒 |
| **害羞** | `shy` | 2 | 点击回应-害羞惊讶、点击回应-挠痒咯咯笑 |
| **平静** | `calm` | 27 | 待机呼吸休闲、悠闲哼歌 |
| **开心** | `joy` | 26 | 点击回应-开心跃动、工作状态-雀跃庆祝 |
| **得意** | `proud` | 6 | 照镜子、小幅度原地360度旋转展示 |
| **心虚** | `guilty` | 2 | 偷吃零食被抓住、大口吃零食 |
| **思考** | `thinking` | 11 | 深度思考碎碎念、工作状态-思考冒泡 |
| **惊讶** | `surprised` | 11 | 被吓一跳、打瞌睡被惊醒 |
| **生气** | `angry` | 3 | 玩游戏气急败坏、点击回应-傲娇生气 |
| **疲惫** | `tired` | 3 | 工作状态-垂头叹气冒汗、哈欠连天 |
| **难过** | `sad` | 3 | 工作状态-垂头叹气冒汗、余额-分文不剩 |

**社交**（对话意图层面的社交行为）

| 标签 | id | 可用动画 | 代表表情 |
| --- | --- | --- | --- |
| **傲娇** | `tease` | 1 | 点击回应-傲娇生气 |
| **告别** | `farewell` | — | *无专属素材，按回落链取相近表情* |
| **夸奖** | `praise` | — | *无专属素材，按回落链取相近表情* |
| **安慰** | `comfort` | — | *无专属素材，按回落链取相近表情* |
| **庆祝** | `cheer` | 4 | 工作状态-雀跃庆祝、放烟花 |
| **感谢** | `thanks` | 2 | 女仆屈膝礼仪、收红包 |
| **拒绝** | `refuse` | — | *无专属素材，按回落链取相近表情* |
| **道歉** | `apology` | 1 | 工作状态-垂头叹气冒汗 |
| **问候** | `greet` | 3 | 点击回应-元气挥手、女仆屈膝礼仪 |

**行为**（正在进行的动作或话题领域）

| 标签 | id | 可用动画 | 代表表情 |
| --- | --- | --- | --- |
| **Token** | `token` | 1 | 吃Token |
| **写代码** | `code` | 2 | 写代码、工作状态-忙碌点按 |
| **出错** | `error` | — | *无专属素材，按回落链取相近表情* |
| **卖萌** | `cute` | 20 | 萌化小幽灵、鲸鱼吐泡泡特效 |
| **吃饭** | `eat` | 25 | 吃早餐、吃午餐 |
| **学习** | `study` | 4 | 轻快记录、工作状态-清点归档 |
| **工作** | `work` | 8 | 工作状态-忙碌点按、写代码 |
| **待机** | `idle` | 7 | 待机呼吸休闲、东张西望 |
| **拖拽** | `drag` | 1 | 被鼠标拖拽悬空反馈 |
| **撸猫** | `pet` | 1 | 撸猫 |
| **游戏** | `game` | 3 | 下五子棋、玩游戏气急败坏 |
| **点击** | `tap` | 6 | 点击回应-开心跃动、点击回应-元气挥手 |
| **玩耍** | `play` | 18 | 骑木马、三球抛接 |
| **疑问** | `question` | — | *无专属素材，按回落链取相近表情* |
| **睡觉** | `sleep` | 3 | 睡觉-循环、睡觉-开始 |
| **等待** | `waiting` | 5 | 工作状态-原地踱步张望、工作状态-思考冒泡 |
| **节日** | `festival` | 22 | 收红包、舞狮头 |
| **跳舞** | `dance` | 3 | 优雅女仆舞、可爱宅舞 |
| **运动** | `sport` | 4 | 踢毽子、原地左转奔跑 |
| **金钱** | `money` | 7 | 收红包、余额-分文不剩 |
| **音乐** | `music` | 4 | 小提琴演奏、吹笛子 |
| **魔法** | `magic` | 5 | 扑克魔术、变鸽子 |

**时令**（时间与季节情境，仅作氛围加成（权重 ×0.35））

| 标签 | id | 可用动画 | 代表表情 |
| --- | --- | --- | --- |
| **冬天** | `season_winter` | 4 | 堆雪人、涮火锅 |
| **夏天** | `season_summer` | 4 | 吃西瓜、摇扇纳凉 |
| **夜晚** | `night` | 4 | 中秋赏月吃月饼、放孔明灯 |
| **早晨** | `morning` | 4 | 晨间刷牙、超大伸懒腰 |
| **春天** | `season_spring` | 3 | 蝴蝶蜜蜂环绕头顶开花、放风筝 |
| **秋天** | `season_autumn` | 4 | 被落叶淹没、插茱萸赏菊 |

**系统**（由 App 事件直接注入（余额档位 / 错误 / 点击 / 拖拽），优先级最高）

| 标签 | id | 可用动画 | 代表表情 |
| --- | --- | --- | --- |
| **余额偏低** | `balance_low` | 1 | 余额-数金皱眉 |
| **余额充足** | `balance_good` | 1 | 余额-金袋叮当 |
| **余额富余** | `balance_rich` | 1 | 余额-钱袋满溢 |
| **余额正常** | `balance_normal` | 1 | 余额-钱袋如常 |
| **余额耗尽** | `balance_empty` | 2 | 余额-分文不剩、余额-袋空如洗 |
<!-- END:TAG_OVERVIEW -->

## 映射规则

### 1. 文本 → 标签

| 层 | 规则 | 例子 |
| --- | --- | --- |
| 词典层 | 长词优先命中，命中区间去重；同一标签重复命中按 1.0 / 0.6 / 0.4 衰减 | 「余额不足」整体命中 `money`，不会被「余额」重复计分 |
| 修饰层 | 前 4 字出现程度副词 ×1.3；「有点/稍微」×0.7；出现否定词则本次命中作废 | 「非常开心」>「开心」>「有点开心」；「不开心」不计 `joy` |
| 累加 | `s = s + v × (1 - s)` 软饱和 | 同义词堆叠不会把分数刷满，排序仍稳定 |
| 结构层 | 连感叹号→`excited`；问号→`question`；代码块→`code`；金额→`money`；长回复→`thinking`；省略号→`dazed`；emoji→对应情绪 | 「```dart」直接给 `code` 0.7 |
| 情境层 | 深夜→`night`/`sleepy`；饭点→`eat`；季节→`season_*`(0.3)；公历节日→`festival` | 12/25 自动带 `festival` |
| 来源权重 | 用户输入 55%，模型回复 45% | 「我没事」+「抱抱你」→ 安慰类表情 |
| 兜底 | 分数 < 0.12 的标签丢弃；无标签时直接待机 | 纯事务性对话不会乱给表情 |

### 2. 标签 → 动画

```
score = Σ(语义分[t] × 契合度[t] × 氛围系数[t])     ← 时令标签的氛围系数 = 0.35
      × (1 + 0.2 × 覆盖率)                         ← 覆盖率 = 命中标签数 / 素材标签数
      × 意图分组加成 1.12                          ← 如 intent=food 时 food 组优先
      × 强度修正                                   ← 高强度偏向高唤醒动作，低强度压制
      × 防重复                                     ← 同 id ×0.2，同分组 ×0.85
```

- 取前 4 名，再剔除低于「最佳分 × 0.6」的，在剩下的里面加权随机——相关且不呆板。
- 最佳分 < 0.12：回待机，不硬凑。
- 系统事件（点击/拖拽/余额/错误）走另一条通道：只在该标签契合度 ≥ 0.8 的素材里挑。

### 3. 标签缺失时的回落链

有些标签没有专属动画（如 `apology`、`comfort`、`refuse`），会沿回落链找到相近素材：

```
apology → sad → tired         comfort → calm → love
refuse  → angry → tease       error   → sad → annoyed
sad     → tired → calm        praise  → shy → joy
```

### 4. 意图 → 分组

| 意图 | 优先分组 | 意图 | 优先分组 |
| --- | --- | --- | --- |
| greeting 问候 | social / emotion | code 写代码 | work |
| farewell 告别 | social / sleep | work 工作 | work |
| thanks 道谢 | social / emotion | food 吃喝 | food |
| apology 道歉 | emotion / work | play 玩耍 | play |
| praise 夸奖 | emotion / social | money 钱 | money |
| comfort 安慰 | emotion / idle | question 提问 | emotion / work |
| refuse 拒绝 | emotion | chat 闲聊 | emotion / idle |

## 余额档位 → 动画

| 余额（CNY） | 档位 | 动画 | 表现 |
| --- | --- | --- | --- |
| ≤ 0 | 余额耗尽 | `余额-分文不剩` / `余额-袋空如洗` | 空钱袋 |
| (0, 5) | 余额偏低 | `余额-数金皱眉` | 数金币皱眉 |
| [5, 20) | 余额正常 | `余额-钱袋如常` | 钱袋不响不瘪 |
| [20, 100) | 余额充足 | `余额-金袋叮当` | 金币叮当 |
| ≥ 100 | 余额富余 | `余额-钱袋满溢` | 钱袋满溢 |

## 素材目录结构

```
assets/
├─ animations/        114 段 640×360 透明动画 WebP —— 运行时素材，参与打包
│  ├─ daiji-huxi-xiuxian.webp    待机呼吸休闲
│  ├─ chi-baifan.webp            吃白饭
│  └─ …
├─ webm/              114 段 WebM 高清母版 —— 不打包，仅随仓库分发
│  ├─ 待机呼吸休闲.webm          与 clip 的 name 字段同名
│  └─ …
└─ manifest/          语义清单 —— 由 tool/gen_manifest.py 生成
   ├─ animations.json 114 段动画 × 标签契合度 × 时长 × 停留策略
   └─ tags.json       60 个标签的标题 / 分组 / 说明 / 关键词词典
```

对应到具体文件：`assets/animations/chi-baifan.webp`（吃白饭）、
`assets/webm/吃白饭.webm`（同一段的母版）、`assets/manifest/animations.json`（语义标注）。

- **文件名规则**：运行时素材用拼音连字符 id（`chi-baifan`），WebM 用中文原名，
  两者靠 `name` 字段对应，生成脚本会校验，不一致直接报错。
- **为什么运行时是动画 WebP 而不是 WebM**：Flutter 的 `Image` 原生支持多帧 WebP
  与 alpha，三端一致；而 VP9+alpha 的视频在 Flutter 里没有可用的透明管线
  （iOS 的 AVFoundation 根本不支持 VP9），直连会变成一块黑底。
  动画 WebP 与母版同为 640×360、保留真 alpha，12fps / q45 / 6 秒约 1.0 MB/段，
  由 `python tool/gen_webp.py` 从 WebM 批量导出。
- **帧率取 12 而不是 15**：母版是 24fps，24→12 是整数二分频、帧间隔均匀；
  24→15 是 1/2/1/2 的不均匀采样，同码率下 SSIM 更低且体积大 20%。
- 114 段动画**全部可播放**：原先只有 WebM、无 GIF 的 5 段（期待开饭、开心小跑、
  侧身急躁跑、吃饭·碗饭、吃饭团）已随 WebP 迁移补齐。

细节见 [docs/ASSETS.md](docs/ASSETS.md)。

## 项目结构

```
lib/
├─ main.dart / app.dart / app_services.dart   启动、本地化、依赖容器
├─ core/            仓库地址与署名、日志
├─ data/            models / repositories / deepseek_client
├─ domain/semantic/ semantic_analyzer · animation_selector · llm_tagger
├─ presentation/    chat · pet · balance · gallery · settings · theme
└─ platform/        桌面窗口能力（移动端空实现）
tool/
├─ gen_manifest.py  标注表 → assets/manifest/*.json（唯一事实源）
├─ gen_docs.py      清单 → README 表格 + docs/TAGS.md
├─ rebuild_gifs.py  WebM → 高分辨率 GIF（需 ffmpeg）
├─ gen_icons.py     一张 .ico → Windows/Android/iOS 全部图标尺寸
└─ set_owner.sh     一键把仓库地址改成你的账号（fork 后常用）
```

## 三端差异与已知限制

| | Windows | Android | iOS |
| --- | --- | --- | --- |
| 布局 | 对话铺满整窗 + 桌宠浮在最上层，可在窗口内任意拖动（≥1000px）；窄窗退化双页签 | 底部双页签 | 底部双页签 |
| 桌面小窗 | ✅ 无边框置顶 | — | — |
| 真·逐像素透明窗口 | ⚠️ 受 Flutter 桌面合成限制，可能退化为圆角卡片 | — | — |

- **桌宠清晰度**：运行时素材与母版同为 640×360，默认按「原尺寸」1:1 渲染、
  不做任何拉伸；可切半尺寸（降采样，仍锐利）或 2×（最近邻整数放大，硬边不糊）。
- **Windows 透明窗口**：Flutter 桌面端不支持逐像素 alpha，设置里的「尝试透明」
  在部分系统上会变成不透明窗口，此时请用「圆角卡片」。要真透明需接入
  `flutter_acrylic` 或改用 Web overlay，本仓库不默认引入。
- **API Key 明文存本地**：为保持三端零额外原生依赖，未使用系统钥匙串。
  请使用可随时吊销的独立 Key。
- **对话历史只在内存**：关闭应用即清空，不落盘。
- **无遥测**：不埋点、不上报。

## 开发

```bash
flutter analyze    # 0 issue
flutter test       # 语义分析 / 选片 / 余额分档 / 清单完整性 / 文档署名 / UI 冒烟
python tool/gen_manifest.py --check   # 清单与标注表是否同步
```

贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。发布流程见 [docs/RELEASING.md](docs/RELEASING.md)。

## 许可

本项目采用**双层许可**——代码与素材不同：

| 范围 | 许可 |
| --- | --- |
| **代码**（`lib/`、`tool/`、workflow 等） | [MIT](LICENSE) |
| **素材**（`assets/` 下的动画、提示词、源视频及角色形象） | [CC BY-NC-SA 4.0](LICENSE-ASSETS.md)（署名 · 非商业 · 相同方式共享） |

### 形象出处（不可移除）

- 宠物形象为**社区二创的 DeepSeek「大肥鱼」（鲸鱼娘），非 DeepSeek 官方形象**。
- 原型「溟月」出自 B 站 [@上善无形](https://space.bilibili.com/4456176)。
- DeepSeek 版（女仆鲸鱼娘）设计出自 B 站 [@ZipZipPipe](https://space.bilibili.com/4168597)。
- 上游项目（动画素材与素材生成链来源）：
  [https://github.com/PC2005-cloud/dsh-pet](https://github.com/PC2005-cloud/dsh-pet)

### 形象授权声明原文

> 大肥鱼是遵守CC BY-NC-SA 4.0协议的形象，不可以以任何形式商业化。若您非常喜爱该形象，希望其拥有实体，您可以自行定制。

（[声明出处](https://www.bilibili.com/opus/1247156596114456581)）

### 对衍生 / 改版 / 换皮作品的要求

基于本项目的衍生、改版、换皮作品，**必须在 GitHub 仓库说明、产品官网、应用商店描述
等公开渠道显著附上原作者 GitHub 地址**：

```
https://github.com/PC2005-cloud/dsh-pet
```

并保留上述全部署名与 CC BY-NC-SA 4.0 说明。**任何形式的商业化使用均不被允许。**

## 免责声明

本项目是非官方社区项目，与 DeepSeek 无隶属关系，未获官方背书。
对话内容由 DeepSeek 开放平台生成，请遵守其服务条款；API 费用由使用者自行承担。
