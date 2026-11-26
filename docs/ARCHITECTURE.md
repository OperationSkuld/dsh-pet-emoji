# 架构说明

## 一句话数据流

```
用户输入 ──▶ ChatController ──▶ DeepSeekClient(/chat/completions, SSE)
                    │                      │
                    │◀──── 流式增量 ────────┘
                    ▼
          SemanticAnalyzer（本地词典 + 结构 + 情境）
                    │  （可选）LlmTagger 二次标注 → merge
                    ▼
             SemanticProfile {tag: 0~1, intent, intensity}
                    ▼
          AnimationSelector（契合度打分 + 防重复 + 氛围降权）
                    ▼
             AnimationClip ──▶ PetController ──▶ Image.asset(GIF)
```

余额链路独立：`BalanceSheet → ChatController.refreshBalance() →
DeepSeekClient(/user/balance) → BalanceTier → playTag(balance_*)`。

## 目录结构

```
lib/
├─ main.dart                     启动：加载清单 → 组装依赖 → 初始化窗口
├─ app.dart                      MaterialApp（中文 Material 本地化）
├─ app_services.dart             依赖容器 + 设置热更新（ChangeNotifier）
├─ core/
│  ├─ app_links.dart             仓库地址、署名、许可证原文、API 常量
│  └─ logger.dart                调试日志（release 静默）
├─ data/
│  ├─ models/                    纯数据：clip / tag / profile / balance / message / settings
│  ├─ repositories/              清单加载与索引、设置持久化
│  └─ services/deepseek_client.dart  流式对话 + 余额 + 补全 + 错误映射
├─ domain/semantic/
│  ├─ semantic_analyzer.dart     词典 / 修饰 / 结构 / 情境四层分析
│  ├─ animation_selector.dart    选片打分与随机池
│  └─ llm_tagger.dart            可选的模型辅助标注
├─ presentation/
│  ├─ chat/                      对话页、气泡、输入区、控制器
│  ├─ pet/                       舞台、浮动桌宠、桌面小窗、PetController
│  ├─ balance/                   余额面板
│  ├─ gallery/                   表情库
│  ├─ settings/                  设置 + 许可
│  ├─ theme/ widgets/            配色、通用组件
└─ platform/pet_window_service.dart  桌面窗口能力（桌面端启用，移动端空实现）
```

## 分层约定

- **domain 不依赖 widget**：`semantic_analyzer` 与 `animation_selector` 只吃模型对象，
  因此能在纯 Dart 测试里跑（`test/semantic_analyzer_test.dart`）。
- **数据驱动**：动画与标签全部来自 `assets/manifest/*.json`，Dart 侧没有硬编码的素材表。
  改素材 = 改标注表 + 重跑生成脚本，不动代码。
- **无状态管理框架**：`ChangeNotifier` + 构造注入。页面用 `AnimatedBuilder` 订阅，
  数据流是一棵树，不需要 Provider/Riverpod 的抽象层。

## 语义分析的实现细节

1. **词典层**：把 `tags.json` 的 424 个关键词按长度降序建表，长词优先命中，
   命中区间用布尔数组标记，避免「余额不足」被「余额」重复计数。
2. **修饰层**：命中词前 4 个字符内出现程度副词 → ×1.3；出现「有点/稍微」→ ×0.7；
   出现否定词 → 该次命中作废。程度副词里的「非」（非常）会先从否定窗口剥离再判否定。
3. **累加**：`s = s + v × (1 - s)`（软饱和），同义词堆叠不会把分数刷满，但排序稳定。
4. **结构层**：连感叹号 → excited；问号 → question；代码块 → code；金额 → money；
   超长回复 → thinking；省略号 → dazed；几个高频 emoji → 对应情绪。
5. **情境层**：深夜 → night/sleepy；饭点 → eat；季节 → season_*（权重 0.3，很低）；
   公历节日（元旦/劳动/儿童/国庆/万圣/圣诞/情人节）→ festival。
6. **意图**：用「原始命中强度」而非最终权重判定，阈值 0.6，避免被来源权重稀释
   （用户输入只占 0.55）。
7. **强度**：主导标签分 × 0.75 + 感叹号密度 × 0.15 + 文本长度 × 0.15，裁剪到 0~1。

## 选片打分

```
score = Σ(语义分[tag] × 契合度[tag] × 氛围系数[tag])    氛围系数：时令类 0.35，其余 1.0
      × (1 + 0.2 × 覆盖率)                              覆盖率 = 命中标签数 / 素材标签数
      × 意图分组加成 1.12
      × 强度修正（高唤醒加分 / 低强度压制高唤醒）
      × 防重复（同 id ×0.2，同分组 ×0.85）
```

- 取前 4 名，再过滤掉低于「最佳分 ×0.6」的，做加权随机 —— 相关性与新鲜感兼顾。
- 最佳分 < 0.12 时直接回待机：宁可安静，也不硬凑一个不相干的表情。
- 系统事件（点击/拖拽/余额/错误）走 `selectForTag`，只在契合度 ≥0.8 的素材里挑。

## 桌宠时序

- 一次性动作：`min(素材时长, 5s)` 后回待机（素材普遍是 10s 长循环，截断防止僵住）。
- 循环动作：停留 `时长 + 6s` 后回待机。
- 空闲 12~26 秒随机插一段氛围动画；最近 6 段参与防重复。

## 桌面窗口

- `window_manager` 只在 Windows / macOS / Linux 上真正调用；Android / iOS 走空实现，
  UI 层不需要平台判断。
- 完整窗口 1120×780；「桌面小窗」384×468、无边框、置顶。
- **已知限制**：Flutter 桌面端没有逐像素透明合成。`透明` 背景选项在部分 Windows
  版本上会退化为不透明窗口，此时请切回「圆角卡片」。真正的透明桌宠需要接入
  `flutter_acrylic` 或改用 Web overlay，本仓库不默认引入。

## 安全边界

- **API Key 存在 SharedPreferences（明文）**。这是有意的取舍：不引入
  `flutter_secure_storage` 之类的原生依赖，保持三端零额外配置。
  本机被攻破时 Key 会泄露——请使用独立的、可随时吊销的 Key。
- Key 只在 `Authorization` 头里发给用户填写的 Base URL，不上报任何第三方。
- 对话历史只存在内存，关掉应用即消失；不写本地数据库。
- 没有遥测、没有埋点、没有崩溃上报。

## 错误处理

| 场景 | 行为 |
| --- | --- |
| 401 | 桌宠困惑表情 + 气泡「API Key 无效或已失效」，提示去设置 |
| 402 | 播放 `balance_empty` 空钱袋 + 气泡提示充值 |
| 429 / 5xx / 网络错误 | 播放 `error`（回落 sad/annoyed）+ 气泡显示原因 |
| 用户点停止 | 保留已生成片段，标记完成，桌宠回到待机 |
| 语义标注失败 | 静默退回离线分析，不影响表情 |
| 素材/清单损坏 | 启动时直接报错界面，指出缺失文件与修复命令 |
