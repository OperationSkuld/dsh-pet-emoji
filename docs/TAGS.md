# 语义标签与动画映射

> 本文档由 `python tool/gen_docs.py` 依据 `assets/manifest/*.json` 生成，请勿手改表格；要改标签或素材标注，改 `tool/gen_manifest.py` 后重新生成。

- 动画 **114** 段（可播放 109，仅 WebM 5）
- 语义标签 **60** 个，关键词 **424** 条
- 标签分组 **5** 类：情绪 / 社交 / 行为 / 时令 / 系统

## 1. 设计原则

1. **标签是有限的、可解释的**：60 个标签覆盖情绪、社交意图、行为领域、时令与系统事件，每个标签都有中文名与一句说明，便于标注时对齐语义。
2. **素材与标签是多对多**：一段动画可携带 1~6 个标签及契合度（0~1），一个标签可被多段动画共享。契合度表示「这段动画有多像这个标签」，不是概率。
3. **权重而非布尔**：选片时用 `语义分 × 契合度` 求和，所以「有点开心」和「狂喜」会落到不同动画上，而不是都命中同一段。
4. **没有专属素材的标签不算错**：`apology`、`comfort`、`refuse` 等通过回落链借用相近情绪素材，避免为一个低频情绪硬造一段动画。

## 2. 标签分组

| 分组 | id | 说明 | 标签数 |
| --- | --- | --- | --- |
| 情绪 | `emotion` | 由对话内容推断的情感状态，决定表情基调 | 18 |
| 社交 | `social` | 对话意图层面的社交行为 | 9 |
| 行为 | `action` | 正在进行的动作或话题领域 | 22 |
| 时令 | `scene` | 时间与季节情境，仅作氛围加成（权重 ×0.35） | 6 |
| 系统 | `system` | 由 App 事件直接注入（余额档位 / 错误 / 点击 / 拖拽），优先级最高 | 5 |

## 3. 标签全表

`基础强度` 是词典命中时的起始分（0~1），会再乘来源权重（用户 0.55 / 回复 0.45）、程度修饰与重复衰减。

| 标签 | id | 分组 | 基础强度 | 关键词 | 说明 |
| --- | --- | --- | --- | --- | --- |
| **不耐烦** | `annoyed` | 情绪 | 0.70 | 烦、啰嗦、别吵、啧、又来了、催… | 嫌弃、不耐、被打扰 |
| **亲昵** | `love` | 情绪 | 0.70 | 喜欢、爱你、贴贴、抱抱、想你、陪… | 撒娇、依恋、贴贴 |
| **兴奋** | `excited` | 情绪 | 0.85 | 兴奋、激动、太棒了、冲、起飞、燃… | 高唤醒的正向情绪，动作幅度大 |
| **发呆** | `dazed` | 情绪 | 0.60 | 发呆、走神、放空、碎碎念、念叨、无聊… | 放空、走神、碎碎念 |
| **困倦** | `sleepy` | 情绪 | 0.80 | 困、睡、乏、哈欠、瞌睡、熬夜… | 犯困、打哈欠、想睡 |
| **困惑** | `confused` | 情绪 | 0.75 | 不懂、困惑、为什么、什么意思、看不懂、奇怪… | 不明白、为难、选择困难 |
| **大笑** | `laugh` | 情绪 | 0.80 | 哈哈、笑哭、笑死、咯咯、笑出声、有趣… | 被逗笑、咯咯笑 |
| **害怕** | `scared` | 情绪 | 0.85 | 害怕、恐怖、好可怕、吓人、发抖、救命… | 恐惧、发怵、被吓 |
| **害羞** | `shy` | 情绪 | 0.70 | 害羞、不好意思、脸红、羞涩、羞、别夸了… | 被夸奖、被注视时的羞怯 |
| **平静** | `calm` | 情绪 | 0.50 | 慢慢、安静、放心、平稳、还好、随意… | 平稳、放松、无强情绪 |
| **开心** | `joy` | 情绪 | 0.75 | 开心、高兴、快乐、太好了、真好、喜欢… | 愉快、满足、被逗乐等正向情绪 |
| **得意** | `proud` | 情绪 | 0.65 | 厉害、厉害吧、当然、小意思、看我的、轻轻松松… | 自信、炫耀、小骄傲 |
| **心虚** | `guilty` | 情绪 | 0.70 | 被抓、偷吃、心虚、糟糕、说漏、完蛋… | 被抓包、理亏、偷偷摸摸 |
| **思考** | `thinking` | 情绪 | 0.80 | 思考、分析、推理、想一想、让我想想、逻辑… | 推理、专注、深度思考 |
| **惊讶** | `surprised` | 情绪 | 0.80 | 惊讶、没想到、居然、竟然、天啊、什么… | 意外、错愕、被吓到 |
| **生气** | `angry` | 情绪 | 0.85 | 生气、愤怒、气死、烦死、可恶、讨厌… | 愤怒、暴躁、气急 |
| **疲惫** | `tired` | 情绪 | 0.75 | 累、疲惫、心累、撑不住、筋疲力尽、摆烂… | 劳累、心累、力不从心 |
| **难过** | `sad` | 情绪 | 0.80 | 难过、伤心、失落、沮丧、遗憾、可惜… | 失落、沮丧、遗憾 |
| **傲娇** | `tease` | 社交 | 0.70 | 才不是、哼、才不、谁要、别自作多情、嘴上… | 嘴硬、调侃、口是心非 |
| **告别** | `farewell` | 社交 | 0.80 | 再见、拜拜、bye、晚安、下次见、先走了… | 再见、道别、离开 |
| **夸奖** | `praise` | 社交 | 0.80 | 真棒、厉害、优秀、聪明、好看、可爱… | 称赞、肯定、鼓励对方 |
| **安慰** | `comfort` | 社交 | 0.70 | 别难过、没关系、抱抱、会好的、我在、别怕… | 安抚、陪伴、给予支持 |
| **庆祝** | `cheer` | 社交 | 0.85 | 恭喜、庆祝、加油、成功、完成、通了… | 庆祝、加油、欢呼 |
| **感谢** | `thanks` | 社交 | 0.80 | 谢谢、感谢、多谢、thank、辛苦了、麻烦你了… | 道谢、感激 |
| **拒绝** | `refuse` | 社交 | 0.70 | 不行、不能、拒绝、做不到、不可以、别想… | 拒绝、做不到、划清边界 |
| **道歉** | `apology` | 社交 | 0.75 | 抱歉、对不起、不好意思、我的错、sorry、失误… | 认错、致歉 |
| **问候** | `greet` | 社交 | 0.85 | 你好、您好、hi、hello、嗨、在吗… | 打招呼、欢迎、回应呼唤 |
| **Token** | `token` | 行为 | 0.80 | token、tokens、计费、消耗、上下文长度 | API token、计费单位 |
| **写代码** | `code` | 行为 | 0.90 | 代码、编程、bug、debug、函数、报错… | 编程、调试、代码 |
| **出错** | `error` | 行为 | 0.85 | 错误、失败、异常、超时、连不上、401… | 请求失败、网络/鉴权异常 |
| **卖萌** | `cute` | 行为 | 0.60 | 可爱、萌、软、撒娇、卖萌、小可爱 | 可爱、撒欢、软萌 |
| **吃饭** | `eat` | 行为 | 0.85 | 吃、饭、饿、好吃、外卖、火锅… | 进食、食物、饿、点餐 |
| **学习** | `study` | 行为 | 0.75 | 学习、复习、笔记、记录、背单词、考试… | 学习、复盘、记录 |
| **工作** | `work` | 行为 | 0.80 | 工作、上班、任务、项目、需求、开会… | 上班、任务、忙 |
| **待机** | `idle` | 行为 | 0.30 | 待机、无聊、随便、嗯、哦、在… | 无事发生、等待、静置 |
| **拖拽** | `drag` | 行为 | 0.90 | *无（由结构或事件注入）* | 用户拖拽宠物 |
| **撸猫** | `pet` | 行为 | 0.70 | 猫、撸猫、宠物、毛茸茸、喵、吸猫 | 猫、宠物、撸毛 |
| **游戏** | `game` | 行为 | 0.75 | 下棋、五子棋、对局、开黑、排位、通关… | 下棋、玩局、竞技 |
| **点击** | `tap` | 行为 | 0.90 | *无（由结构或事件注入）* | 用户点击/触摸宠物 |
| **玩耍** | `play` | 行为 | 0.70 | 玩、游戏、玩具、摸鱼、划水、消遣… | 玩耍、娱乐、消遣 |
| **疑问** | `question` | 行为 | 0.60 | 吗、呢、怎么、如何、什么、为什么… | 用户在提问 |
| **睡觉** | `sleep` | 行为 | 0.85 | 睡觉、睡了、休息、做梦、躺、打盹… | 入睡、休息 |
| **等待** | `waiting` | 行为 | 0.70 | 稍等、等待、马上、正在、处理中、加载… | 请求进行中、等待结果 |
| **节日** | `festival` | 行为 | 0.85 | 节日、春节、中秋、端午、圣诞、万圣… | 节庆、年节、纪念日 |
| **跳舞** | `dance` | 行为 | 0.85 | 跳舞、舞、律动、蹦迪、摇摆、宅舞… | 跳舞、律动、表演 |
| **运动** | `sport` | 行为 | 0.75 | 运动、跑、健身、锻炼、散步、跳绳… | 跑步、锻炼、活跃 |
| **金钱** | `money` | 行为 | 0.80 | 钱、余额、充值、花销、账单、贵… | 钱、余额、花费、充值 |
| **音乐** | `music` | 行为 | 0.80 | 音乐、歌、唱、演奏、钢琴、小提琴… | 音乐、演奏、哼唱 |
| **魔法** | `magic` | 行为 | 0.80 | 魔法、魔术、变、奇迹、咒语、不可思议… | 魔法、魔术、不可思议 |
| **冬天** | `season_winter` | 时令 | 0.60 | 冬天、冬季、下雪、雪人、火锅、腊八… | 冬、雪、火锅 |
| **夏天** | `season_summer` | 时令 | 0.60 | 夏天、夏季、热、西瓜、空调、纳凉… | 夏、炎热、纳凉 |
| **夜晚** | `night` | 时令 | 0.50 | 晚上、夜里、深夜、凌晨、熬夜、睡前 | 夜间时段 |
| **早晨** | `morning` | 时令 | 0.50 | 早上、早晨、清晨、起床、早安、刷牙 | 清晨时段 |
| **春天** | `season_spring` | 时令 | 0.60 | 春天、春季、花开、踏青、清明、风筝… | 春、花开、踏青 |
| **秋天** | `season_autumn` | 时令 | 0.60 | 秋天、秋季、落叶、赏菊、重阳、凉快 | 秋、落叶、赏菊 |
| **余额偏低** | `balance_low` | 系统 | 1.00 | *无（由结构或事件注入）* | 余额 < 5 |
| **余额充足** | `balance_good` | 系统 | 1.00 | *无（由结构或事件注入）* | 20 ≤ 余额 < 100 |
| **余额富余** | `balance_rich` | 系统 | 1.00 | *无（由结构或事件注入）* | 余额 ≥ 100 |
| **余额正常** | `balance_normal` | 系统 | 1.00 | *无（由结构或事件注入）* | 5 ≤ 余额 < 20 |
| **余额耗尽** | `balance_empty` | 系统 | 1.00 | *无（由结构或事件注入）* | 余额 ≤ 0 |

## 4. 标签 → 动画

按契合度降序。括号内为契合度，≥0.8 才允许被「系统事件」通道直接选中。

### 情绪

- **不耐烦** `annoyed` — 用鲸鱼尾巴拍打地面（0.90）、玩游戏气急败坏（0.70）、点击回应-傲娇生气（0.60）、被落叶淹没（0.40）
- **亲昵** `love` — 撸猫（0.70）、鲸鱼吐泡泡特效（0.60）、动物环绕（0.60）、凭空生花（0.50）、蝴蝶蜜蜂环绕头顶开花（0.40）
- **兴奋** `excited` — 原地跳跃抓碎头顶物品（0.90）、点击回应-开心跃动（0.80）、蓝鲸现世（0.80）、放烟花（0.80）、工作状态-雀跃庆祝（0.70）、点击回应-元气挥手（0.60）、拆礼物（0.60）、三球抛接（0.60）、原地左转奔跑（0.60）、余额-钱袋满溢（0.60）、吹气球（0.50）、讨糖南瓜灯（0.50）
- **发呆** `dazed` — 碎碎念-发呆碎碎念（0.90）、碎碎念-对屏碎碎念（0.60）、原地漂浮踏步（0.40）、哈欠连天（0.40）、深度思考碎碎念（0.40）
- **困倦** `sleepy` — 哈欠连天（0.90）、原地小憩沉眠（0.90）、睡觉-开始（0.80）、打瞌睡被惊醒（0.70）、睡觉-起来（0.70）、超大伸懒腰（0.60）
- **困惑** `confused` — 是啊，吃什么（0.90）、余额-数金皱眉（0.50）、东张西望（0.40）、螃蟹走路（0.30）
- **大笑** `laugh` — 点击回应-挠痒咯咯笑（0.95）
- **害怕** `scared` — 被吓一跳（0.90）、打瞌睡被惊醒（0.40）
- **害羞** `shy` — 点击回应-害羞惊讶（0.90）、点击回应-挠痒咯咯笑（0.40）
- **平静** `calm` — 待机呼吸休闲（0.80）、悠闲哼歌（0.80）、超大伸懒腰（0.70）、摇扇纳凉（0.70）、睡觉-循环（0.70）、原地漂浮踏步（0.60）、荡秋千（0.60）、鲸鱼吐泡泡特效（0.60）、穿针乞巧（0.60）、吹笛子（0.60）、撸猫（0.60）、放孔明灯（0.60）、放河灯（0.60）、余额-钱袋如常（0.60）、原地小憩沉眠（0.60）、女仆屈膝礼仪（0.50）、中秋赏月吃月饼（0.50）、下五子棋（0.50）、原地专心玩魔方（0.50）、小提琴演奏（0.50）、动物环绕（0.50）、写福字（0.50）、插茱萸赏菊（0.50）、睡觉-起来（0.50）、吃午餐（0.40）、吃白饭（0.30）
- **开心** `joy` — 点击回应-开心跃动（0.95）、工作状态-雀跃庆祝（0.90）、点击回应-挠痒咯咯笑（0.85）、点击回应-元气挥手（0.80）、收红包（0.80）、原地跳跃抓碎头顶物品（0.70）、荡秋千（0.70）、蝴蝶蜜蜂环绕头顶开花（0.70）、拆礼物（0.70）、放烟花（0.70）、舞狮头（0.70）、轻快摇摆舞（0.70）、骑木马（0.60）、凭空生花（0.60）、大口吃零食（0.60）、涮火锅（0.60）、可爱宅舞（0.60）、放风筝（0.60）、堆雪人（0.60）、装点圣诞树（0.60）、余额-金袋叮当（0.60）、三球抛接（0.50）、吃糖葫芦（0.50）、吃长寿面（0.50）、悠闲哼歌（0.50）
- **得意** `proud` — 照镜子（0.80）、小幅度原地360度旋转展示（0.80）、蓝鲸现世（0.70）、整体换装试色（0.70）、扑克魔术（0.40）、小提琴演奏（0.40）
- **心虚** `guilty` — 偷吃零食被抓住（0.90）、大口吃零食（0.30）
- **思考** `thinking` — 深度思考碎碎念（1.00）、工作状态-思考冒泡（0.90）、原地专心玩魔方（0.80）、碎碎念-对屏碎碎念（0.70）、下五子棋（0.70）、写代码（0.50）、碎碎念-擦桌碎碎念（0.40）、工作状态-原地踱步张望（0.40）、工作状态-清点归档（0.40）、轻快记录（0.40）、碎碎念-发呆碎碎念（0.30）
- **惊讶** `surprised` — 被吓一跳（0.80）、打瞌睡被惊醒（0.80）、点击回应-害羞惊讶（0.70）、拆礼物（0.70）、变鸽子（0.60）、偷吃零食被抓住（0.50）、萌化小幽灵（0.40）、原地重力下蹲压缩（0.40）、被落叶淹没（0.40）、被鼠标拖拽悬空反馈（0.40）、东张西望（0.20）
- **生气** `angry` — 玩游戏气急败坏（0.90）、点击回应-傲娇生气（0.85）、用鲸鱼尾巴拍打地面（0.60）
- **疲惫** `tired` — 工作状态-垂头叹气冒汗（0.90）、哈欠连天（0.70）
- **难过** `sad` — 工作状态-垂头叹气冒汗（0.70）、余额-分文不剩（0.70）、余额-袋空如洗（0.60）

### 社交

- **傲娇** `tease` — 点击回应-傲娇生气（0.90）
- **告别** `farewell` — *无专属素材*
- **夸奖** `praise` — *无专属素材，回落：`shy` → `joy`*
- **安慰** `comfort` — *无专属素材，回落：`calm` → `love`*
- **庆祝** `cheer` — 工作状态-雀跃庆祝（0.95）、放烟花（0.90）、舞狮头（0.80）、吹气球（0.60）
- **感谢** `thanks` — 女仆屈膝礼仪（0.60）、收红包（0.60）
- **拒绝** `refuse` — *无专属素材，回落：`angry` → `tease`*
- **道歉** `apology` — 工作状态-垂头叹气冒汗（0.50）
- **问候** `greet` — 点击回应-元气挥手（0.90）、女仆屈膝礼仪（0.90）、优雅女仆舞（0.50）

### 行为

- **Token** `token` — 吃Token（1.00）
- **写代码** `code` — 写代码（1.00）、工作状态-忙碌点按（0.50）
- **出错** `error` — *无专属素材，回落：`sad` → `annoyed`*
- **卖萌** `cute` — 萌化小幽灵（0.90）、鲸鱼吐泡泡特效（0.80）、蝴蝶蜜蜂环绕头顶开花（0.80）、可爱宅舞（0.80）、整体换装试色（0.80）、动物环绕（0.80）、照镜子（0.70）、小幅度原地360度旋转展示（0.70）、讨糖南瓜灯（0.70）、螃蟹走路（0.60）、优雅女仆舞（0.60）、吃Token（0.60）、原地蹲下玩玩具汽车（0.60）、原地重力下蹲压缩（0.60）、骑木马（0.50）、女仆屈膝礼仪（0.50）、吃冰淇淋融化（0.50）、抽陀螺（0.50）、用鲸鱼尾巴拍打地面（0.40）
- **吃饭** `eat` — 吃早餐（0.90）、吃午餐（0.90）、吃晚餐（0.90）、吃白饭（0.90）、大口吃零食（0.90）、涮火锅（0.80）、吃冰淇淋融化（0.80）、吃西瓜（0.80）、吃饺子（0.80）、吃汤圆（0.80）、吃粽子（0.80）、吃年糕（0.80）、吃糖葫芦（0.80）、吃腊八粥（0.80）、吃重阳糕（0.80）、吃长寿面（0.80）、吃青团（0.80）、吃大闸蟹（0.80）、吃Token（0.70）、是啊，吃什么（0.70）、中秋赏月吃月饼（0.60）、偷吃零食被抓住（0.50）
- **学习** `study` — 轻快记录（0.90）、工作状态-清点归档（0.60）、穿针乞巧（0.60）、写福字（0.30）
- **工作** `work` — 工作状态-忙碌点按（0.90）、写代码（0.80）、工作状态-垂头叹气冒汗（0.70）、工作状态-思考冒泡（0.70）、工作状态-原地踱步张望（0.70）、工作状态-清点归档（0.70）、轻快记录（0.60）、碎碎念-擦桌碎碎念（0.40）
- **待机** `idle` — 待机呼吸休闲（1.00）、东张西望（0.80）、原地漂浮踏步（0.75）、碎碎念-擦桌碎碎念（0.70）、碎碎念-发呆碎碎念（0.60）、晨间刷牙（0.60）、碎碎念-对屏碎碎念（0.40）
- **拖拽** `drag` — 被鼠标拖拽悬空反馈（1.00）
- **撸猫** `pet` — 撸猫（0.90）
- **游戏** `game` — 下五子棋（0.90）、玩游戏气急败坏（0.80）、原地专心玩魔方（0.60）
- **点击** `tap` — 点击回应-开心跃动（0.90）、点击回应-元气挥手（0.90）、原地敲击桌面互动（0.90）、点击回应-挠痒咯咯笑（0.80）、点击回应-害羞惊讶（0.80）、点击回应-傲娇生气（0.80）
- **玩耍** `play` — 骑木马（0.80）、三球抛接（0.80）、抽陀螺（0.80）、原地蹲下玩玩具汽车（0.80）、玩水枪（0.80）、荡秋千（0.70）、吹气球（0.70）、踢毽子（0.70）、原地重力下蹲压缩（0.70）、放风筝（0.70）、堆雪人（0.70）、原地跳跃抓碎头顶物品（0.60）、螃蟹走路（0.60）、扑克魔术（0.60）、原地敲击桌面互动（0.60）、原地左转奔跑（0.50）、小幅度原地360度旋转展示（0.40）、整体换装试色（0.40）
- **疑问** `question` — *无专属素材*
- **睡觉** `sleep` — 睡觉-循环（1.00）、睡觉-开始（0.90）、原地小憩沉眠（0.90）
- **等待** `waiting` — 工作状态-原地踱步张望（0.90）、工作状态-思考冒泡（0.50）、深度思考碎碎念（0.40）、碎碎念-对屏碎碎念（0.30）、工作状态-忙碌点按（0.30）
- **节日** `festival` — 收红包（0.90）、舞狮头（0.90）、吃饺子（0.90）、中秋赏月吃月饼（0.90）、写福字（0.90）、装点圣诞树（0.90）、讨糖南瓜灯（0.90）、放烟花（0.80）、吃汤圆（0.80）、吃粽子（0.80）、吃年糕（0.80）、穿针乞巧（0.80）、插茱萸赏菊（0.80）、放孔明灯（0.80）、放河灯（0.80）、吃腊八粥（0.70）、吃重阳糕（0.70）、吃青团（0.70）、吃大闸蟹（0.70）、吃长寿面（0.60）、萌化小幽灵（0.50）、吃糖葫芦（0.50）
- **跳舞** `dance` — 优雅女仆舞（0.90）、可爱宅舞（0.90）、轻快摇摆舞（0.90）
- **运动** `sport` — 踢毽子（0.80）、原地左转奔跑（0.80）
- **金钱** `money` — 收红包（0.80）、余额-分文不剩（0.80）、余额-袋空如洗（0.80）、余额-数金皱眉（0.80）、余额-钱袋如常（0.80）、余额-金袋叮当（0.80）、余额-钱袋满溢（0.80）
- **音乐** `music` — 小提琴演奏（0.90）、吹笛子（0.90）、悠闲哼歌（0.60）、轻快摇摆舞（0.30）
- **魔法** `magic` — 扑克魔术（0.90）、变鸽子（0.90）、凭空生花（0.90）、蓝鲸现世（0.60）、鲸鱼吐泡泡特效（0.40）

### 时令

- **冬天** `season_winter` — 堆雪人（0.90）、涮火锅（0.70）、装点圣诞树（0.70）、吃腊八粥（0.50）
- **夏天** `season_summer` — 吃西瓜（0.80）、摇扇纳凉（0.80）、玩水枪（0.70）、吃冰淇淋融化（0.50）
- **夜晚** `night` — 中秋赏月吃月饼（0.50）、放孔明灯（0.50）、放河灯（0.50）、吃晚餐（0.40）
- **早晨** `morning` — 晨间刷牙（0.90）、超大伸懒腰（0.60）、吃早餐（0.60）、睡觉-起来（0.40）
- **春天** `season_spring` — 蝴蝶蜜蜂环绕头顶开花（0.80）、放风筝（0.80）、吃青团（0.60）
- **秋天** `season_autumn` — 被落叶淹没（0.90）、插茱萸赏菊（0.80）、吃重阳糕（0.60）、吃大闸蟹（0.50）

### 系统

- **余额偏低** `balance_low` — 余额-数金皱眉（1.00）
- **余额充足** `balance_good` — 余额-金袋叮当（1.00）
- **余额富余** `balance_rich` — 余额-钱袋满溢（1.00）
- **余额正常** `balance_normal` — 余额-钱袋如常（1.00）
- **余额耗尽** `balance_empty` — 余额-分文不剩（1.00）、余额-袋空如洗（1.00）

## 5. 动画 → 标签（全表）

| # | 动画 | id | 分组 | 停留 | 时长 | 标签（契合度） | 素材 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 待机呼吸休闲 | `daiji-huxi-xiuxian` | idle | 循环 | 10.0s | `idle` 1.00 · `calm` .80 | GIF+WebM |
| 2 | 原地漂浮踏步 | `yuandi-piaofu-tabu` | idle | 循环 | 10.0s | `idle` .75 · `calm` .60 · `dazed` .40 | GIF+WebM |
| 3 | 东张西望 | `dongzhangxiwang` | idle | 循环 | 10.0s | `idle` .80 · `confused` .40 · `surprised` .20 | GIF+WebM |
| 4 | 碎碎念-发呆碎碎念 | `suisuinian-fadai-suisuinian` | idle | 循环 | 10.0s | `dazed` .90 · `idle` .60 · `thinking` .30 | GIF+WebM |
| 5 | 碎碎念-对屏碎碎念 | `suisuinian-duiping-suisuinian` | idle | 循环 | 10.0s | `thinking` .70 · `dazed` .60 · `idle` .40 · `waiting` .30 | GIF+WebM |
| 6 | 碎碎念-擦桌碎碎念 | `suisuinian-cazhuo-suisuinian` | idle | 循环 | 10.0s | `idle` .70 · `work` .40 · `thinking` .40 | GIF+WebM |
| 7 | 超大伸懒腰 | `chaoda-shenlanyao` | idle | 一次性 | 10.0s | `calm` .70 · `sleepy` .60 · `morning` .60 | GIF+WebM |
| 8 | 哈欠连天 | `haqian-liantian` | idle | 一次性 | 10.0s | `sleepy` .90 · `tired` .70 · `dazed` .40 | GIF+WebM |
| 9 | 晨间刷牙 | `chenjian-shuaya` | idle | 一次性 | 10.0s | `morning` .90 · `idle` .60 | GIF+WebM |
| 10 | 照镜子 | `zhao-jingzi` | idle | 一次性 | 10.0s | `proud` .80 · `cute` .70 | GIF+WebM |
| 11 | 小幅度原地360度旋转展示 | `xiaofudu-yuandi-360du-xuanzhuan-zhanshi` | idle | 一次性 | 10.0s | `proud` .80 · `cute` .70 · `play` .40 | GIF+WebM |
| 12 | 点击回应-开心跃动 | `dianji-huiying-kaixin-yuedong` | emotion | 一次性 | 10.0s | `joy` .95 · `tap` .90 · `excited` .80 | GIF+WebM |
| 13 | 点击回应-挠痒咯咯笑 | `dianji-huiying-naoyang-gegexiao` | emotion | 一次性 | 10.0s | `laugh` .95 · `joy` .85 · `tap` .80 · `shy` .40 | GIF+WebM |
| 14 | 点击回应-害羞惊讶 | `dianji-huiying-haixiu-jingya` | emotion | 一次性 | 10.0s | `shy` .90 · `tap` .80 · `surprised` .70 | GIF+WebM |
| 15 | 点击回应-傲娇生气 | `dianji-huiying-aojiao-shengqi-ceshen-zhanshi` | emotion | 一次性 | 10.0s | `tease` .90 · `angry` .85 · `tap` .80 · `annoyed` .60 | GIF+WebM |
| 16 | 点击回应-元气挥手 | `dianji-huiying-yuanqi-huishou` | emotion | 一次性 | 10.0s | `greet` .90 · `tap` .90 · `joy` .80 · `excited` .60 | GIF+WebM |
| 17 | 原地跳跃抓碎头顶物品 | `yuandi-tiaoyue-zhuasui-touding-wupin` | emotion | 一次性 | 10.0s | `excited` .90 · `joy` .70 · `play` .60 | GIF+WebM |
| 18 | 工作状态-雀跃庆祝 | `gongzuozhuangtai-queyue-qingzhu` | emotion | 循环 | 10.0s | `cheer` .95 · `joy` .90 · `excited` .70 | GIF+WebM |
| 19 | 工作状态-垂头叹气冒汗 | `gongzuozhuangtai-chuitou-tanqi-maohan` | emotion | 循环 | 4.9s | `tired` .90 · `sad` .70 · `work` .70 · `apology` .50 | GIF+WebM |
| 20 | 玩游戏气急败坏 | `wan-youxi-qijibaituai` | emotion | 一次性 | 10.0s | `angry` .90 · `game` .80 · `annoyed` .70 | GIF+WebM |
| 21 | 用鲸鱼尾巴拍打地面 | `yong-jingyu-weiba-paidadi` | emotion | 一次性 | 10.0s | `annoyed` .90 · `angry` .60 · `cute` .40 | GIF+WebM |
| 22 | 被吓一跳 | `beixiayitiao-zhamao` | emotion | 一次性 | 10.0s | `scared` .90 · `surprised` .80 | GIF+WebM |
| 23 | 打瞌睡被惊醒 | `da-keshui-bei-jingxing` | emotion | 一次性 | 10.0s | `surprised` .80 · `sleepy` .70 · `scared` .40 | GIF+WebM |
| 24 | 偷吃零食被抓住 | `touchi-lingshi-bei-zhuazhu` | emotion | 一次性 | 10.0s | `guilty` .90 · `surprised` .50 · `eat` .50 | GIF+WebM |
| 25 | 深度思考碎碎念 | `shendu-sikao-suisuinian` | emotion | 循环 | 10.0s | `thinking` 1.00 · `dazed` .40 · `waiting` .40 | GIF+WebM |
| 26 | 工作状态-思考冒泡 | `gongzuozhuangtai-sikao-maopao` | emotion | 循环 | 10.0s | `thinking` .90 · `work` .70 · `waiting` .50 | GIF+WebM |
| 27 | 骑木马 | `qi-muma` | emotion | 一次性 | 10.0s | `play` .80 · `joy` .60 · `cute` .50 | GIF+WebM |
| 28 | 荡秋千 | `dangqiuqian` | emotion | 一次性 | 10.0s | `play` .70 · `joy` .70 · `calm` .60 | GIF+WebM |
| 29 | 萌化小幽灵 | `menghua-xiaoyouling` | emotion | 一次性 | 10.0s | `cute` .90 · `festival` .50 · `surprised` .40 | GIF+WebM |
| 30 | 蓝鲸现世 | `lanjing-xianshi` | emotion | 一次性 | 10.0s | `excited` .80 · `proud` .70 · `magic` .60 | GIF+WebM |
| 31 | 鲸鱼吐泡泡特效 | `jingyu-tu-paopao-texiao` | emotion | 一次性 | 10.0s | `cute` .80 · `love` .60 · `calm` .60 · `magic` .40 | GIF+WebM |
| 32 | 蝴蝶蜜蜂环绕头顶开花 | `hudie-mifeng-huanrao-touding-kaihua` | emotion | 一次性 | 10.0s | `season_spring` .80 · `cute` .80 · `joy` .70 · `love` .40 | GIF+WebM |
| 33 | 螃蟹走路 | `pangxie-zoulu` | emotion | 一次性 | 10.0s | `play` .60 · `cute` .60 · `confused` .30 | GIF+WebM |
| 34 | 女仆屈膝礼仪 | `nvpu-quxi-liyi` | social | 一次性 | 10.0s | `greet` .90 · `thanks` .60 · `calm` .50 · `cute` .50 | GIF+WebM |
| 35 | 优雅女仆舞 | `youya-nvpuwu` | social | 循环 | 10.0s | `dance` .90 · `cute` .60 · `greet` .50 | GIF+WebM |
| 36 | 收红包 | `shou-hongbao` | social | 一次性 | 10.0s | `festival` .90 · `money` .80 · `joy` .80 · `thanks` .60 | GIF+WebM |
| 37 | 拆礼物 | `chai-liwu` | social | 一次性 | 10.0s | `surprised` .70 · `joy` .70 · `excited` .60 | GIF+WebM |
| 38 | 吹气球 | `chui-qiqiu` | social | 一次性 | 10.0s | `play` .70 · `cheer` .60 · `excited` .50 | GIF+WebM |
| 39 | 放烟花 | `fang-yanhua` | social | 循环 | 10.0s | `cheer` .90 · `festival` .80 · `excited` .80 · `joy` .70 | GIF+WebM |
| 40 | 舞狮头 | `wu-shitou` | social | 循环 | 10.0s | `festival` .90 · `cheer` .80 · `joy` .70 | GIF+WebM |
| 41 | 三球抛接 | `sanqiu-paojie` | social | 一次性 | 10.0s | `play` .80 · `excited` .60 · `joy` .50 | GIF+WebM |
| 42 | 扑克魔术 | `puke-moshu` | social | 一次性 | 10.0s | `magic` .90 · `play` .60 · `proud` .40 | GIF+WebM |
| 43 | 变鸽子 | `bian-gezi` | social | 一次性 | 10.0s | `magic` .90 · `surprised` .60 | GIF+WebM |
| 44 | 凭空生花 | `pingkong-shenghua` | social | 一次性 | 10.0s | `magic` .90 · `joy` .60 · `love` .50 | GIF+WebM |
| 45 | 吃Token | `chi-token` | food | 一次性 | 10.0s | `token` 1.00 · `eat` .70 · `cute` .60 | GIF+WebM |
| 46 | 吃早餐 | `chi-zaocan` | food | 一次性 | 10.0s | `eat` .90 · `morning` .60 | GIF+WebM |
| 47 | 吃午餐 | `chi-wucan` | food | 一次性 | 10.0s | `eat` .90 · `calm` .40 | GIF+WebM |
| 48 | 吃晚餐 | `chi-wancan` | food | 一次性 | 10.0s | `eat` .90 · `night` .40 | GIF+WebM |
| 49 | 吃白饭 | `chi-baifan` | food | 一次性 | 10.0s | `eat` .90 · `calm` .30 | GIF+WebM |
| 50 | 大口吃零食 | `dakou-chi-lingshi` | food | 一次性 | 10.0s | `eat` .90 · `joy` .60 · `guilty` .30 | GIF+WebM |
| 51 | 是啊，吃什么 | `shia-chishenme` | food | 一次性 | 10.0s | `confused` .90 · `eat` .70 | GIF+WebM |
| 52 | 涮火锅 | `shuan-huoguo` | food | 循环 | 10.0s | `eat` .80 · `season_winter` .70 · `joy` .60 | GIF+WebM |
| 53 | 吃冰淇淋融化 | `chi-bingqilin-ronghua` | food | 一次性 | 10.0s | `eat` .80 · `season_summer` .50 · `cute` .50 | GIF+WebM |
| 54 | 吃西瓜 | `chi-xigua` | food | 一次性 | 10.0s | `eat` .80 · `season_summer` .80 | GIF+WebM |
| 55 | 吃饺子 | `chijiaozi` | food | 一次性 | 10.0s | `festival` .90 · `eat` .80 | GIF+WebM |
| 56 | 吃汤圆 | `chitangyuan` | food | 一次性 | 10.0s | `eat` .80 · `festival` .80 | GIF+WebM |
| 57 | 吃粽子 | `chi-zongzi` | food | 一次性 | 10.0s | `eat` .80 · `festival` .80 | GIF+WebM |
| 58 | 吃年糕 | `chi-niangao` | food | 一次性 | 10.0s | `eat` .80 · `festival` .80 | GIF+WebM |
| 59 | 吃糖葫芦 | `chi-tanghulu` | food | 一次性 | 10.0s | `eat` .80 · `joy` .50 · `festival` .50 | GIF+WebM |
| 60 | 吃腊八粥 | `chi-labazhou` | food | 一次性 | 10.0s | `eat` .80 · `festival` .70 · `season_winter` .50 | GIF+WebM |
| 61 | 吃重阳糕 | `chi-chongyanggao` | food | 一次性 | 10.0s | `eat` .80 · `festival` .70 · `season_autumn` .60 | GIF+WebM |
| 62 | 吃长寿面 | `chi-changshoumian` | food | 一次性 | 10.0s | `eat` .80 · `festival` .60 · `joy` .50 | GIF+WebM |
| 63 | 吃青团 | `chi-qingtuan` | food | 一次性 | 10.0s | `eat` .80 · `festival` .70 · `season_spring` .60 | GIF+WebM |
| 64 | 吃大闸蟹 | `chi-dazhaxie` | food | 一次性 | 10.0s | `eat` .80 · `festival` .70 · `season_autumn` .50 | GIF+WebM |
| 65 | 中秋赏月吃月饼 | `zhongqiu-shangyue-chi-yuebing` | food | 循环 | 10.0s | `festival` .90 · `eat` .60 · `calm` .50 · `night` .50 | GIF+WebM |
| 66 | 期待开饭 | `qidai-kaifan` | food | 一次性 | 3.0s | `eat` .80 · `excited` .60 | 仅 WebM |
| 67 | 写代码 | `xie-daima` | work | 循环 | 10.0s | `code` 1.00 · `work` .80 · `thinking` .50 | GIF+WebM |
| 68 | 工作状态-忙碌点按 | `gongzuozhuangtai-manglu-dianan` | work | 循环 | 10.0s | `work` .90 · `code` .50 · `waiting` .30 | GIF+WebM |
| 69 | 工作状态-原地踱步张望 | `gongzuozhuangtai-yuandi-duobu-zhangwang` | work | 循环 | 10.0s | `waiting` .90 · `work` .70 · `thinking` .40 | GIF+WebM |
| 70 | 工作状态-清点归档 | `gongzuozhuangtai-qingdian-guidang` | work | 循环 | 10.0s | `work` .70 · `study` .60 · `thinking` .40 | GIF+WebM |
| 71 | 轻快记录 | `qingkuai-jilu` | work | 循环 | 10.0s | `study` .90 · `work` .60 · `thinking` .40 | GIF+WebM |
| 72 | 下五子棋 | `xiawuziqi` | work | 一次性 | 10.0s | `game` .90 · `thinking` .70 · `calm` .50 | GIF+WebM |
| 73 | 原地专心玩魔方 | `yuandi-zhuanxin-wan-mofang` | work | 循环 | 10.0s | `thinking` .80 · `game` .60 · `calm` .50 | GIF+WebM |
| 74 | 穿针乞巧 | `chuanzhenqiqiao` | work | 一次性 | 10.0s | `festival` .80 · `study` .60 · `calm` .60 | GIF+WebM |
| 75 | 可爱宅舞 | `keai-zhaiwu` | play | 循环 | 10.0s | `dance` .90 · `cute` .80 · `joy` .60 | GIF+WebM |
| 76 | 轻快摇摆舞 | `qingkuai-yaobaiwu` | play | 循环 | 10.0s | `dance` .90 · `joy` .70 · `music` .30 | GIF+WebM |
| 77 | 小提琴演奏 | `xiaotiqin-yanzou` | play | 循环 | 10.0s | `music` .90 · `calm` .50 · `proud` .40 | GIF+WebM |
| 78 | 吹笛子 | `chui-dizi` | play | 循环 | 10.0s | `music` .90 · `calm` .60 | GIF+WebM |
| 79 | 悠闲哼歌 | `youxian-hengga` | play | 循环 | 10.0s | `calm` .80 · `music` .60 · `joy` .50 | GIF+WebM |
| 80 | 原地敲击桌面互动 | `yuandi-qiaoji-zhuomian-hudong` | play | 一次性 | 10.0s | `tap` .90 · `play` .60 | GIF+WebM |
| 81 | 抽陀螺 | `chou-tuoluo` | play | 一次性 | 10.0s | `play` .80 · `cute` .50 | GIF+WebM |
| 82 | 踢毽子 | `ti-jianzi` | play | 一次性 | 10.0s | `sport` .80 · `play` .70 | GIF+WebM |
| 83 | 原地左转奔跑 | `yuandi-zuozhuan-benpao` | play | 一次性 | 10.0s | `sport` .80 · `excited` .60 · `play` .50 | GIF+WebM |
| 84 | 原地蹲下玩玩具汽车 | `yuandi-dunxia-wan-wanju-qiche` | play | 循环 | 10.0s | `play` .80 · `cute` .60 | GIF+WebM |
| 85 | 原地重力下蹲压缩 | `yuandi-zhongli-xiadun-yasuo` | play | 一次性 | 10.0s | `play` .70 · `cute` .60 · `surprised` .40 | GIF+WebM |
| 86 | 玩水枪 | `wan-shuiqiang` | play | 一次性 | 10.0s | `play` .80 · `season_summer` .70 | GIF+WebM |
| 87 | 整体换装试色 | `zhengti-huanzhuang-shise` | play | 循环 | 10.0s | `cute` .80 · `proud` .70 · `play` .40 | GIF+WebM |
| 88 | 放风筝 | `fang-fengzheng` | play | 一次性 | 10.0s | `season_spring` .80 · `play` .70 · `joy` .60 | GIF+WebM |
| 89 | 堆雪人 | `duixueren` | play | 循环 | 10.0s | `season_winter` .90 · `play` .70 · `joy` .60 | GIF+WebM |
| 90 | 摇扇纳凉 | `yaoshan-naliang` | play | 循环 | 10.0s | `season_summer` .80 · `calm` .70 | GIF+WebM |
| 91 | 撸猫 | `lu-mao` | play | 循环 | 10.0s | `pet` .90 · `love` .70 · `calm` .60 | GIF+WebM |
| 92 | 动物环绕 | `dongwu-huanrao` | play | 循环 | 10.0s | `cute` .80 · `love` .60 · `calm` .50 | GIF+WebM |
| 93 | 被落叶淹没 | `beiluoye-yanmo` | play | 一次性 | 10.0s | `season_autumn` .90 · `surprised` .40 · `annoyed` .40 | GIF+WebM |
| 94 | 写福字 | `xie-fuzi` | festival | 一次性 | 10.0s | `festival` .90 · `calm` .50 · `study` .30 | GIF+WebM |
| 95 | 装点圣诞树 | `zhuangdian-shengdanshu` | festival | 循环 | 10.0s | `festival` .90 · `season_winter` .70 · `joy` .60 | GIF+WebM |
| 96 | 讨糖南瓜灯 | `taotang-nanguadeng` | festival | 一次性 | 10.0s | `festival` .90 · `cute` .70 · `excited` .50 | GIF+WebM |
| 97 | 插茱萸赏菊 | `cha-zhuyu-shangju` | festival | 一次性 | 10.0s | `festival` .80 · `season_autumn` .80 · `calm` .50 | GIF+WebM |
| 98 | 放孔明灯 | `fang-kongmingdeng` | festival | 循环 | 10.0s | `festival` .80 · `calm` .60 · `night` .50 | GIF+WebM |
| 99 | 放河灯 | `fanghedeng` | festival | 循环 | 10.0s | `festival` .80 · `calm` .60 · `night` .50 | GIF+WebM |
| 100 | 余额-分文不剩 | `fen-wen-bu-sheng` | money | 循环 | 10.0s | `balance_empty` 1.00 · `money` .80 · `sad` .70 | GIF+WebM |
| 101 | 余额-袋空如洗 | `dai-kong-ru-xi` | money | 循环 | 10.0s | `balance_empty` 1.00 · `money` .80 · `sad` .60 | GIF+WebM |
| 102 | 余额-数金皱眉 | `shu-jin-zhou-mei` | money | 循环 | 10.0s | `balance_low` 1.00 · `money` .80 · `confused` .50 | GIF+WebM |
| 103 | 余额-钱袋如常 | `qian-dai-ru-chang` | money | 循环 | 10.0s | `balance_normal` 1.00 · `money` .80 · `calm` .60 | GIF+WebM |
| 104 | 余额-金袋叮当 | `jin-dai-ding-dang` | money | 循环 | 10.0s | `balance_good` 1.00 · `money` .80 · `joy` .60 | GIF+WebM |
| 105 | 余额-钱袋满溢 | `qian-dai-man-yi` | money | 循环 | 10.0s | `balance_rich` 1.00 · `money` .80 · `excited` .60 | GIF+WebM |
| 106 | 睡觉-开始 | `shuijiao-kaishi` | sleep | 一次性 | 10.0s | `sleep` .90 · `sleepy` .80 | GIF+WebM |
| 107 | 睡觉-循环 | `shuijiao-xunhuan` | sleep | 循环 | 10.0s | `sleep` 1.00 · `calm` .70 | GIF+WebM |
| 108 | 睡觉-起来 | `shuijiao-qilai` | sleep | 一次性 | 10.0s | `sleepy` .70 · `calm` .50 · `morning` .40 | GIF+WebM |
| 109 | 原地小憩沉眠 | `yuandi-xiaoqi-chenmian` | sleep | 循环 | 10.0s | `sleep` .90 · `sleepy` .90 · `calm` .60 | GIF+WebM |
| 110 | 被鼠标拖拽悬空反馈 | `beishubiao-tuozhuai-xuankong-fankui` | interaction | 一次性 | 10.0s | `drag` 1.00 · `surprised` .40 | GIF+WebM |
| 111 | 开心小跑 | `kaixin-xiaopao` | emotion | 一次性 | 3.0s | `joy` .90 · `excited` .70 · `sport` .40 | 仅 WebM |
| 112 | 侧身急躁跑 | `ceshen-jizao-pao` | emotion | 一次性 | 3.0s | `annoyed` .80 · `sport` .60 · `tired` .50 | 仅 WebM |
| 113 | 吃饭·碗饭 | `chi-fan-wanfan` | food | 一次性 | 3.0s | `eat` .90 · `calm` .30 | 仅 WebM |
| 114 | 吃饭团 | `chi-fantuan` | food | 一次性 | 3.0s | `eat` .90 · `cute` .30 | 仅 WebM |

> 「仅 WebM」的动画没有 220×124 的 GIF 预览，运行时被标记为不可播放，不参与调度；补齐 GIF 后重跑 `python tool/gen_manifest.py` 即可启用。

## 6. 回落链

当某个标签没有任何契合度 ≥0.8 的素材时，按此顺序寻找替代标签；全都没有则回到 `idle`。

| 原标签 | 回落顺序 |
| --- | --- |
| `apology` | `sad` → `tired` |
| `comfort` | `calm` → `love` |
| `refuse` | `angry` → `tease` |
| `error` | `sad` → `annoyed` |
| `sad` | `tired` → `calm` |
| `tired` | `sleepy` → `calm` |
| `lonely` | `sad` → `calm` |
| `praise` | `shy` → `joy` |
| `grateful` | `thanks` → `joy` |
| `bored` | `dazed` → `idle` |

## 7. 如何调整

1. 改标签词典或基础强度：`tool/gen_manifest.py` 的 `TAGS`。
2. 改动画标注：`tool/gen_manifest.py` 的 `CLIPS`（分组、停留策略、标签与契合度）。
3. 改选片权重（氛围系数、覆盖率加成、防重复）：`lib/domain/semantic/animation_selector.dart`。
4. 重新生成：`python tool/gen_manifest.py && python tool/gen_docs.py`，再 `flutter test`。
