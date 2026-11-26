#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 assets/manifest/*.json。

本脚本是「语义标签 ↔ 动画素材」映射的唯一事实源：
  - TAGS   : 标签分类法（分组、中文名、说明、关键词词典、基础强度）
  - CLIPS  : 114 段动画的逐条标注（标签权重、停留策略）
  - WebP 解析: 直接从 RIFF 二进制读出画布尺寸、帧数与总时长，避免手写 duration 漂移

用法:
    python tool/gen_manifest.py            # 生成 manifest
    python tool/gen_manifest.py --check    # 只校验（CI 用，不写文件）

素材来源: assets/animations (由 tool/gen_webp.py 从 assets/webm 母版导出) 与 assets/webm。
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM_DIR = os.path.join(ROOT, "assets", "animations")
WEBM_DIR = os.path.join(ROOT, "assets", "webm")
# 每段动画的内容包围盒（由 tool/gen_boxes.py 用 Pillow 量出来并提交）。
# 界能据此把气泡与操作条贴着角色真实边缘摆，而不是贴着整张 640×360 画布。
BOXES_PATH = os.path.join(ROOT, "tool", "boxes.json")
OUT_DIR = os.path.join(ROOT, "assets", "manifest")


# --------------------------------------------------------------------------
# 标签分类法
# --------------------------------------------------------------------------
# group: emotion 情绪 / social 社交 / action 行为 / scene 时令 / system 系统事件
# base:  词典命中时的基础语义强度（0~1），可被程度副词放大或否定词翻转
TAGS = [
    # ---- 情绪 ----
    dict(id="joy", label="开心", group="emotion", base=0.75, desc="愉快、满足、被逗乐等正向情绪",
         keywords=["开心", "高兴", "快乐", "太好了", "真好", "喜欢", "棒", "幸福", "嘿嘿", "好耶"]),
    dict(id="excited", label="兴奋", group="emotion", base=0.85, desc="高唤醒的正向情绪，动作幅度大",
         keywords=["兴奋", "激动", "太棒了", "冲", "起飞", "燃", "哇塞", "迫不及待"]),
    dict(id="laugh", label="大笑", group="emotion", base=0.8, desc="被逗笑、咯咯笑",
         keywords=["哈哈", "笑哭", "笑死", "咯咯", "笑出声", "有趣", "好笑"]),
    dict(id="shy", label="害羞", group="emotion", base=0.7, desc="被夸奖、被注视时的羞怯",
         keywords=["害羞", "不好意思", "脸红", "羞涩", "羞", "别夸了", "讨厌啦"]),
    dict(id="love", label="亲昵", group="emotion", base=0.7, desc="撒娇、依恋、贴贴",
         keywords=["喜欢", "爱你", "贴贴", "抱抱", "想你", "陪", "蹭", "亲亲"]),
    dict(id="proud", label="得意", group="emotion", base=0.65, desc="自信、炫耀、小骄傲",
         keywords=["厉害", "厉害吧", "当然", "小意思", "看我的", "轻轻松松", "so easy", "炫耀"]),
    dict(id="calm", label="平静", group="emotion", base=0.5, desc="平稳、放松、无强情绪",
         keywords=["慢慢", "安静", "放心", "平稳", "还好", "随意", "轻松"]),
    dict(id="sleepy", label="困倦", group="emotion", base=0.8, desc="犯困、打哈欠、想睡",
         keywords=["困", "睡", "乏", "哈欠", "瞌睡", "熬夜", "晚安", "睡意"]),
    dict(id="tired", label="疲惫", group="emotion", base=0.75, desc="劳累、心累、力不从心",
         keywords=["累", "疲惫", "心累", "撑不住", "筋疲力尽", "摆烂", "干不动", "加班"]),
    dict(id="sad", label="难过", group="emotion", base=0.8, desc="失落、沮丧、遗憾",
         keywords=["难过", "伤心", "失落", "沮丧", "遗憾", "可惜", "emo", "委屈", "想哭"]),
    dict(id="angry", label="生气", group="emotion", base=0.85, desc="愤怒、暴躁、气急",
         keywords=["生气", "愤怒", "气死", "烦死", "可恶", "讨厌", "滚", "火大", "爆炸"]),
    dict(id="annoyed", label="不耐烦", group="emotion", base=0.7, desc="嫌弃、不耐、被打扰",
         keywords=["烦", "啰嗦", "别吵", "啧", "又来了", "催", "没完没了", "无语"]),
    dict(id="surprised", label="惊讶", group="emotion", base=0.8, desc="意外、错愕、被吓到",
         keywords=["惊讶", "没想到", "居然", "竟然", "天啊", "什么", "诶", "惊了", "突然"]),
    dict(id="scared", label="害怕", group="emotion", base=0.85, desc="恐惧、发怵、被吓",
         keywords=["害怕", "恐怖", "好可怕", "吓人", "发抖", "救命", "别过来", "毛骨悚然"]),
    dict(id="confused", label="困惑", group="emotion", base=0.75, desc="不明白、为难、选择困难",
         keywords=["不懂", "困惑", "为什么", "什么意思", "看不懂", "奇怪", "迷茫", "怎么办"]),
    dict(id="thinking", label="思考", group="emotion", base=0.8, desc="推理、专注、深度思考",
         keywords=["思考", "分析", "推理", "想一想", "让我想想", "逻辑", "推导", "原理", "思路"]),
    dict(id="dazed", label="发呆", group="emotion", base=0.6, desc="放空、走神、碎碎念",
         keywords=["发呆", "走神", "放空", "碎碎念", "念叨", "无聊", "空白", "出神"]),
    dict(id="guilty", label="心虚", group="emotion", base=0.7, desc="被抓包、理亏、偷偷摸摸",
         keywords=["被抓", "偷吃", "心虚", "糟糕", "说漏", "完蛋", "被发现", "溜了"]),

    # ---- 社交 ----
    dict(id="greet", label="问候", group="social", base=0.85, desc="打招呼、欢迎、回应呼唤",
         keywords=["你好", "您好", "hi", "hello", "嗨", "在吗", "早上好", "晚上好", "欢迎", "哈喽"]),
    dict(id="farewell", label="告别", group="social", base=0.8, desc="再见、道别、离开",
         keywords=["再见", "拜拜", "bye", "晚安", "下次见", "先走了", "下线", "回头聊"]),
    dict(id="thanks", label="感谢", group="social", base=0.8, desc="道谢、感激",
         keywords=["谢谢", "感谢", "多谢", "thank", "辛苦了", "麻烦你了", "感恩"]),
    dict(id="apology", label="道歉", group="social", base=0.75, desc="认错、致歉",
         keywords=["抱歉", "对不起", "不好意思", "我的错", "sorry", "失误", "搞错了"]),
    dict(id="praise", label="夸奖", group="social", base=0.8, desc="称赞、肯定、鼓励对方",
         keywords=["真棒", "厉害", "优秀", "聪明", "好看", "可爱", "牛", "佩服", "绝了"]),
    dict(id="comfort", label="安慰", group="social", base=0.7, desc="安抚、陪伴、给予支持",
         keywords=["别难过", "没关系", "抱抱", "会好的", "我在", "别怕", "慢慢来", "别担心"]),
    dict(id="refuse", label="拒绝", group="social", base=0.7, desc="拒绝、做不到、划清边界",
         keywords=["不行", "不能", "拒绝", "做不到", "不可以", "别想", "免谈", "no"]),
    dict(id="tease", label="傲娇", group="social", base=0.7, desc="嘴硬、调侃、口是心非",
         keywords=["才不是", "哼", "才不", "谁要", "别自作多情", "嘴上", "傲娇", "嘴硬"]),
    dict(id="cheer", label="庆祝", group="social", base=0.85, desc="庆祝、加油、欢呼",
         keywords=["恭喜", "庆祝", "加油", "成功", "完成", "通了", "赢了", "太强了", "耶"]),

    # ---- 行为 ----
    dict(id="eat", label="吃饭", group="action", base=0.85, desc="进食、食物、饿、点餐",
         keywords=["吃", "饭", "饿", "好吃", "外卖", "火锅", "零食", "早餐", "午餐", "晚餐", "夜宵", "奶茶"]),
    dict(id="sleep", label="睡觉", group="action", base=0.85, desc="入睡、休息",
         keywords=["睡觉", "睡了", "休息", "做梦", "躺", "打盹", "被窝"]),
    dict(id="play", label="玩耍", group="action", base=0.7, desc="玩耍、娱乐、消遣",
         keywords=["玩", "游戏", "玩具", "摸鱼", "划水", "消遣", "耍"]),
    dict(id="dance", label="跳舞", group="action", base=0.85, desc="跳舞、律动、表演",
         keywords=["跳舞", "舞", "律动", "蹦迪", "摇摆", "宅舞", "跳一段"]),
    dict(id="music", label="音乐", group="action", base=0.8, desc="音乐、演奏、哼唱",
         keywords=["音乐", "歌", "唱", "演奏", "钢琴", "小提琴", "笛子", "旋律", "听歌"]),
    dict(id="magic", label="魔法", group="action", base=0.8, desc="魔法、魔术、不可思议",
         keywords=["魔法", "魔术", "变", "奇迹", "咒语", "不可思议", "凭空"]),
    dict(id="work", label="工作", group="action", base=0.8, desc="上班、任务、忙",
         keywords=["工作", "上班", "任务", "项目", "需求", "开会", "加班", "ddl", "忙"]),
    dict(id="code", label="写代码", group="action", base=0.9, desc="编程、调试、代码",
         keywords=["代码", "编程", "bug", "debug", "函数", "报错", "编译", "重构", "python", "flutter", "接口"]),
    dict(id="study", label="学习", group="action", base=0.75, desc="学习、复盘、记录",
         keywords=["学习", "复习", "笔记", "记录", "背单词", "考试", "读书", "总结"]),
    dict(id="sport", label="运动", group="action", base=0.75, desc="跑步、锻炼、活跃",
         keywords=["运动", "跑", "健身", "锻炼", "散步", "跳绳", "出汗", "体育"]),
    dict(id="game", label="游戏", group="action", base=0.75, desc="下棋、玩局、竞技",
         keywords=["下棋", "五子棋", "对局", "开黑", "排位", "通关", "关卡", "扑克"]),
    dict(id="festival", label="节日", group="action", base=0.85, desc="节庆、年节、纪念日",
         keywords=["节日", "春节", "中秋", "端午", "圣诞", "万圣", "七夕", "重阳", "元宵", "过年", "红包", "烟花"]),
    dict(id="money", label="金钱", group="action", base=0.8, desc="钱、余额、花费、充值",
         keywords=["钱", "余额", "充值", "花销", "账单", "贵", "免费", "余额不足", "token", "额度"]),
    dict(id="cute", label="卖萌", group="action", base=0.6, desc="可爱、撒欢、软萌",
         keywords=["可爱", "萌", "软", "撒娇", "卖萌", "小可爱"]),
    dict(id="pet", label="撸猫", group="action", base=0.7, desc="猫、宠物、撸毛",
         keywords=["猫", "撸猫", "宠物", "毛茸茸", "喵", "吸猫"]),
    dict(id="idle", label="待机", group="action", base=0.3, desc="无事发生、等待、静置",
         keywords=["待机", "无聊", "随便", "嗯", "哦", "在", "没事"]),
    dict(id="tap", label="点击", group="action", base=0.9, desc="用户点击/触摸宠物",
         keywords=[]),
    dict(id="drag", label="拖拽", group="action", base=0.9, desc="用户拖拽宠物",
         keywords=[]),
    dict(id="error", label="出错", group="action", base=0.85, desc="请求失败、网络/鉴权异常",
         keywords=["错误", "失败", "异常", "超时", "连不上", "401", "403", "500", "报错", "重试"]),
    dict(id="waiting", label="等待", group="action", base=0.7, desc="请求进行中、等待结果",
         keywords=["稍等", "等待", "马上", "正在", "处理中", "加载", "请求中"]),
    dict(id="question", label="疑问", group="action", base=0.6, desc="用户在提问",
         keywords=["吗", "呢", "怎么", "如何", "什么", "为什么", "?", "？"]),
    dict(id="token", label="Token", group="action", base=0.8, desc="API token、计费单位",
         keywords=["token", "tokens", "计费", "消耗", "上下文长度"]),

    # ---- 时令 ----
    dict(id="season_spring", label="春天", group="scene", base=0.6, desc="春、花开、踏青",
         keywords=["春天", "春季", "花开", "踏青", "清明", "风筝", "发芽"]),
    dict(id="season_summer", label="夏天", group="scene", base=0.6, desc="夏、炎热、纳凉",
         keywords=["夏天", "夏季", "热", "西瓜", "空调", "纳凉", "冰"]),
    dict(id="season_autumn", label="秋天", group="scene", base=0.6, desc="秋、落叶、赏菊",
         keywords=["秋天", "秋季", "落叶", "赏菊", "重阳", "凉快"]),
    dict(id="season_winter", label="冬天", group="scene", base=0.6, desc="冬、雪、火锅",
         keywords=["冬天", "冬季", "下雪", "雪人", "火锅", "腊八", "圣诞"]),
    dict(id="night", label="夜晚", group="scene", base=0.5, desc="夜间时段",
         keywords=["晚上", "夜里", "深夜", "凌晨", "熬夜", "睡前"]),
    dict(id="morning", label="早晨", group="scene", base=0.5, desc="清晨时段",
         keywords=["早上", "早晨", "清晨", "起床", "早安", "刷牙"]),

    # ---- 系统事件（由 App 直接注入，不经词典）----
    dict(id="balance_empty", label="余额耗尽", group="system", base=1.0, desc="余额 ≤ 0", keywords=[]),
    dict(id="balance_low", label="余额偏低", group="system", base=1.0, desc="余额 < 5", keywords=[]),
    dict(id="balance_normal", label="余额正常", group="system", base=1.0, desc="5 ≤ 余额 < 20", keywords=[]),
    dict(id="balance_good", label="余额充足", group="system", base=1.0, desc="20 ≤ 余额 < 100", keywords=[]),
    dict(id="balance_rich", label="余额富余", group="system", base=1.0, desc="余额 ≥ 100", keywords=[]),
]

GROUPS = {
    "emotion": dict(label="情绪", desc="由对话内容推断的情感状态，决定表情基调"),
    "social": dict(label="社交", desc="对话意图层面的社交行为"),
    "action": dict(label="行为", desc="正在进行的动作或话题领域"),
    "scene": dict(label="时令", desc="时间与季节情境，用于叠加氛围加成"),
    "system": dict(label="系统", desc="由 App 事件直接注入，优先级最高"),
}


# --------------------------------------------------------------------------
# 动画清单：每段动画的语义标注
#   id      : clip 主键，与 assets/animations/<id>.webp 对应
#   name    : 中文原名（同时用于定位 assets/webm/<name>.webm）
#   group   : 素材分组（仅用于文档归类）
#   hold    : "once" 播完回待机 / "loop" 长时间停留
#   tags    : 标签 → 契合度（0~1）
# --------------------------------------------------------------------------
CLIPS = [
    # ---- 待机 / 氛围 ----
    ("daiji-huxi-xiuxian", "待机呼吸休闲", "idle", "loop",
     dict(idle=1.0, calm=0.8)),
    ("yuandi-piaofu-tabu", "原地漂浮踏步", "idle", "loop",
     dict(idle=0.75, calm=0.6, dazed=0.4)),
    ("dongzhangxiwang", "东张西望", "idle", "loop",
     dict(idle=0.8, confused=0.4, surprised=0.2)),
    ("suisuinian-fadai-suisuinian", "碎碎念-发呆碎碎念", "idle", "loop",
     dict(dazed=0.9, idle=0.6, thinking=0.3)),
    ("suisuinian-duiping-suisuinian", "碎碎念-对屏碎碎念", "idle", "loop",
     dict(dazed=0.6, thinking=0.7, idle=0.4, waiting=0.3)),
    ("suisuinian-cazhuo-suisuinian", "碎碎念-擦桌碎碎念", "idle", "loop",
     dict(idle=0.7, work=0.4, thinking=0.4)),
    ("chaoda-shenlanyao", "超大伸懒腰", "idle", "once",
     dict(calm=0.7, sleepy=0.6, morning=0.6)),
    ("haqian-liantian", "哈欠连天", "idle", "once",
     dict(sleepy=0.9, tired=0.7, dazed=0.4)),
    ("chenjian-shuaya", "晨间刷牙", "idle", "once",
     dict(morning=0.9, idle=0.6)),
    ("zhao-jingzi", "照镜子", "idle", "once",
     dict(proud=0.8, cute=0.7)),
    ("xiaofudu-yuandi-360du-xuanzhuan-zhanshi", "小幅度原地360度旋转展示", "idle", "once",
     dict(proud=0.8, cute=0.7, play=0.4)),

    # ---- 情绪 ----
    ("dianji-huiying-kaixin-yuedong", "点击回应-开心跃动", "emotion", "once",
     dict(joy=0.95, excited=0.8, tap=0.9)),
    ("dianji-huiying-naoyang-gegexiao", "点击回应-挠痒咯咯笑", "emotion", "once",
     dict(laugh=0.95, joy=0.85, shy=0.4, tap=0.8)),
    ("dianji-huiying-haixiu-jingya", "点击回应-害羞惊讶", "emotion", "once",
     dict(shy=0.9, surprised=0.7, tap=0.8)),
    ("dianji-huiying-aojiao-shengqi-ceshen-zhanshi", "点击回应-傲娇生气", "emotion", "once",
     dict(angry=0.85, tease=0.9, annoyed=0.6, tap=0.8)),
    ("dianji-huiying-yuanqi-huishou", "点击回应-元气挥手", "emotion", "once",
     dict(greet=0.9, joy=0.8, excited=0.6, tap=0.9)),
    ("yuandi-tiaoyue-zhuasui-touding-wupin", "原地跳跃抓碎头顶物品", "emotion", "once",
     dict(excited=0.9, joy=0.7, play=0.6)),
    ("gongzuozhuangtai-queyue-qingzhu", "工作状态-雀跃庆祝", "emotion", "loop",
     dict(cheer=0.95, joy=0.9, excited=0.7)),
    ("gongzuozhuangtai-chuitou-tanqi-maohan", "工作状态-垂头叹气冒汗", "emotion", "loop",
     dict(tired=0.9, sad=0.7, work=0.7, apology=0.5)),
    ("wan-youxi-qijibaituai", "玩游戏气急败坏", "emotion", "once",
     dict(angry=0.9, game=0.8, annoyed=0.7)),
    ("yong-jingyu-weiba-paidadi", "用鲸鱼尾巴拍打地面", "emotion", "once",
     dict(annoyed=0.9, angry=0.6, cute=0.4)),
    ("beixiayitiao-zhamao", "被吓一跳", "emotion", "once",
     dict(scared=0.9, surprised=0.8)),
    ("da-keshui-bei-jingxing", "打瞌睡被惊醒", "emotion", "once",
     dict(surprised=0.8, sleepy=0.7, scared=0.4)),
    ("touchi-lingshi-bei-zhuazhu", "偷吃零食被抓住", "emotion", "once",
     dict(guilty=0.9, surprised=0.5, eat=0.5)),
    ("shendu-sikao-suisuinian", "深度思考碎碎念", "emotion", "loop",
     dict(thinking=1.0, dazed=0.4, waiting=0.4)),
    ("gongzuozhuangtai-sikao-maopao", "工作状态-思考冒泡", "emotion", "loop",
     dict(thinking=0.9, work=0.7, waiting=0.5)),
    ("qi-muma", "骑木马", "emotion", "once",
     dict(play=0.8, joy=0.6, cute=0.5)),
    ("dangqiuqian", "荡秋千", "emotion", "once",
     dict(play=0.7, joy=0.7, calm=0.6)),
    ("menghua-xiaoyouling", "萌化小幽灵", "emotion", "once",
     dict(cute=0.9, surprised=0.4, festival=0.5)),
    ("lanjing-xianshi", "蓝鲸现世", "emotion", "once",
     dict(excited=0.8, proud=0.7, magic=0.6)),
    ("jingyu-tu-paopao-texiao", "鲸鱼吐泡泡特效", "emotion", "once",
     dict(cute=0.8, love=0.6, calm=0.6, magic=0.4)),
    ("hudie-mifeng-huanrao-touding-kaihua", "蝴蝶蜜蜂环绕头顶开花", "emotion", "once",
     dict(season_spring=0.8, joy=0.7, cute=0.8, love=0.4)),
    ("pangxie-zoulu", "螃蟹走路", "emotion", "once",
     dict(play=0.6, cute=0.6, confused=0.3)),

    # ---- 社交 ----
    ("nvpu-quxi-liyi", "女仆屈膝礼仪", "social", "once",
     dict(greet=0.9, thanks=0.6, calm=0.5, cute=0.5)),
    ("youya-nvpuwu", "优雅女仆舞", "social", "loop",
     dict(dance=0.9, greet=0.5, cute=0.6)),
    ("shou-hongbao", "收红包", "social", "once",
     dict(money=0.8, joy=0.8, festival=0.9, thanks=0.6)),
    ("chai-liwu", "拆礼物", "social", "once",
     dict(surprised=0.7, joy=0.7, excited=0.6)),
    ("chui-qiqiu", "吹气球", "social", "once",
     dict(cheer=0.6, play=0.7, excited=0.5)),
    ("fang-yanhua", "放烟花", "social", "loop",
     dict(cheer=0.9, festival=0.8, excited=0.8, joy=0.7)),
    ("wu-shitou", "舞狮头", "social", "loop",
     dict(festival=0.9, cheer=0.8, joy=0.7)),
    ("sanqiu-paojie", "三球抛接", "social", "once",
     dict(play=0.8, excited=0.6, joy=0.5)),
    ("puke-moshu", "扑克魔术", "social", "once",
     dict(magic=0.9, play=0.6, proud=0.4)),
    ("bian-gezi", "变鸽子", "social", "once",
     dict(magic=0.9, surprised=0.6)),
    ("pingkong-shenghua", "凭空生花", "social", "once",
     dict(magic=0.9, joy=0.6, love=0.5)),

    # ---- 吃饭 ----
    ("chi-token", "吃Token", "food", "once",
     dict(token=1.0, eat=0.7, cute=0.6)),
    ("chi-zaocan", "吃早餐", "food", "once",
     dict(eat=0.9, morning=0.6)),
    ("chi-wucan", "吃午餐", "food", "once",
     dict(eat=0.9, calm=0.4)),
    ("chi-wancan", "吃晚餐", "food", "once",
     dict(eat=0.9, night=0.4)),
    ("chi-baifan", "吃白饭", "food", "once",
     dict(eat=0.9, calm=0.3)),
    ("dakou-chi-lingshi", "大口吃零食", "food", "once",
     dict(eat=0.9, joy=0.6, guilty=0.3)),
    ("shia-chishenme", "是啊，吃什么", "food", "once",
     dict(confused=0.9, eat=0.7)),
    ("shuan-huoguo", "涮火锅", "food", "loop",
     dict(eat=0.8, season_winter=0.7, joy=0.6)),
    ("chi-bingqilin-ronghua", "吃冰淇淋融化", "food", "once",
     dict(eat=0.8, season_summer=0.5, cute=0.5)),
    ("chi-xigua", "吃西瓜", "food", "once",
     dict(eat=0.8, season_summer=0.8)),
    ("chijiaozi", "吃饺子", "food", "once",
     dict(eat=0.8, festival=0.9)),
    ("chitangyuan", "吃汤圆", "food", "once",
     dict(eat=0.8, festival=0.8)),
    ("chi-zongzi", "吃粽子", "food", "once",
     dict(eat=0.8, festival=0.8)),
    ("chi-niangao", "吃年糕", "food", "once",
     dict(eat=0.8, festival=0.8)),
    ("chi-tanghulu", "吃糖葫芦", "food", "once",
     dict(eat=0.8, joy=0.5, festival=0.5)),
    ("chi-labazhou", "吃腊八粥", "food", "once",
     dict(eat=0.8, festival=0.7, season_winter=0.5)),
    ("chi-chongyanggao", "吃重阳糕", "food", "once",
     dict(eat=0.8, festival=0.7, season_autumn=0.6)),
    ("chi-changshoumian", "吃长寿面", "food", "once",
     dict(eat=0.8, festival=0.6, joy=0.5)),
    ("chi-qingtuan", "吃青团", "food", "once",
     dict(eat=0.8, festival=0.7, season_spring=0.6)),
    ("chi-dazhaxie", "吃大闸蟹", "food", "once",
     dict(eat=0.8, festival=0.7, season_autumn=0.5)),
    ("zhongqiu-shangyue-chi-yuebing", "中秋赏月吃月饼", "food", "loop",
     dict(festival=0.9, eat=0.6, calm=0.5, night=0.5)),
    ("qidai-kaifan", "期待开饭", "food", "once",
     dict(eat=0.8, excited=0.6)),

    # ---- 工作 / 学习 ----
    ("xie-daima", "写代码", "work", "loop",
     dict(code=1.0, work=0.8, thinking=0.5)),
    ("gongzuozhuangtai-manglu-dianan", "工作状态-忙碌点按", "work", "loop",
     dict(work=0.9, code=0.5, waiting=0.3)),
    ("gongzuozhuangtai-yuandi-duobu-zhangwang", "工作状态-原地踱步张望", "work", "loop",
     dict(waiting=0.9, work=0.7, thinking=0.4)),
    ("gongzuozhuangtai-qingdian-guidang", "工作状态-清点归档", "work", "loop",
     dict(work=0.7, study=0.6, thinking=0.4)),
    ("qingkuai-jilu", "轻快记录", "work", "loop",
     dict(study=0.9, work=0.6, thinking=0.4)),
    ("xiawuziqi", "下五子棋", "work", "once",
     dict(game=0.9, thinking=0.7, calm=0.5)),
    ("yuandi-zhuanxin-wan-mofang", "原地专心玩魔方", "work", "loop",
     dict(thinking=0.8, game=0.6, calm=0.5)),
    ("chuanzhenqiqiao", "穿针乞巧", "work", "once",
     dict(study=0.6, festival=0.8, calm=0.6)),

    # ---- 玩耍 ----
    ("keai-zhaiwu", "可爱宅舞", "play", "loop",
     dict(dance=0.9, cute=0.8, joy=0.6)),
    ("qingkuai-yaobaiwu", "轻快摇摆舞", "play", "loop",
     dict(dance=0.9, joy=0.7, music=0.3)),
    ("xiaotiqin-yanzou", "小提琴演奏", "play", "loop",
     dict(music=0.9, calm=0.5, proud=0.4)),
    ("chui-dizi", "吹笛子", "play", "loop",
     dict(music=0.9, calm=0.6)),
    ("youxian-hengga", "悠闲哼歌", "play", "loop",
     dict(music=0.6, calm=0.8, joy=0.5)),
    ("yuandi-qiaoji-zhuomian-hudong", "原地敲击桌面互动", "play", "once",
     dict(tap=0.9, play=0.6)),
    ("chou-tuoluo", "抽陀螺", "play", "once",
     dict(play=0.8, cute=0.5)),
    ("ti-jianzi", "踢毽子", "play", "once",
     dict(sport=0.8, play=0.7)),
    ("yuandi-zuozhuan-benpao", "原地左转奔跑", "play", "once",
     dict(sport=0.8, excited=0.6, play=0.5)),
    ("yuandi-dunxia-wan-wanju-qiche", "原地蹲下玩玩具汽车", "play", "loop",
     dict(play=0.8, cute=0.6)),
    ("yuandi-zhongli-xiadun-yasuo", "原地重力下蹲压缩", "play", "once",
     dict(play=0.7, cute=0.6, surprised=0.4)),
    ("wan-shuiqiang", "玩水枪", "play", "once",
     dict(play=0.8, season_summer=0.7)),
    ("zhengti-huanzhuang-shise", "整体换装试色", "play", "loop",
     dict(proud=0.7, cute=0.8, play=0.4)),
    ("fang-fengzheng", "放风筝", "play", "once",
     dict(season_spring=0.8, play=0.7, joy=0.6)),
    ("duixueren", "堆雪人", "play", "loop",
     dict(season_winter=0.9, play=0.7, joy=0.6)),
    ("yaoshan-naliang", "摇扇纳凉", "play", "loop",
     dict(season_summer=0.8, calm=0.7)),
    ("lu-mao", "撸猫", "play", "loop",
     dict(pet=0.9, love=0.7, calm=0.6)),
    ("dongwu-huanrao", "动物环绕", "play", "loop",
     dict(cute=0.8, love=0.6, calm=0.5)),
    ("beiluoye-yanmo", "被落叶淹没", "play", "once",
     dict(season_autumn=0.9, surprised=0.4, annoyed=0.4)),

    # ---- 节日 ----
    ("xie-fuzi", "写福字", "festival", "once",
     dict(festival=0.9, calm=0.5, study=0.3)),
    ("zhuangdian-shengdanshu", "装点圣诞树", "festival", "loop",
     dict(festival=0.9, season_winter=0.7, joy=0.6)),
    ("taotang-nanguadeng", "讨糖南瓜灯", "festival", "once",
     dict(festival=0.9, cute=0.7, excited=0.5)),
    ("cha-zhuyu-shangju", "插茱萸赏菊", "festival", "once",
     dict(festival=0.8, season_autumn=0.8, calm=0.5)),
    ("fang-kongmingdeng", "放孔明灯", "festival", "loop",
     dict(festival=0.8, calm=0.6, night=0.5)),
    ("fanghedeng", "放河灯", "festival", "loop",
     dict(festival=0.8, calm=0.6, night=0.5)),

    # ---- 余额 ----
    ("fen-wen-bu-sheng", "余额-分文不剩", "money", "loop",
     dict(balance_empty=1.0, money=0.8, sad=0.7)),
    ("dai-kong-ru-xi", "余额-袋空如洗", "money", "loop",
     dict(balance_empty=1.0, money=0.8, sad=0.6)),
    ("shu-jin-zhou-mei", "余额-数金皱眉", "money", "loop",
     dict(balance_low=1.0, money=0.8, confused=0.5)),
    ("qian-dai-ru-chang", "余额-钱袋如常", "money", "loop",
     dict(balance_normal=1.0, money=0.8, calm=0.6)),
    ("jin-dai-ding-dang", "余额-金袋叮当", "money", "loop",
     dict(balance_good=1.0, money=0.8, joy=0.6)),
    ("qian-dai-man-yi", "余额-钱袋满溢", "money", "loop",
     dict(balance_rich=1.0, money=0.8, excited=0.6)),

    # ---- 睡觉 ----
    ("shuijiao-kaishi", "睡觉-开始", "sleep", "once",
     dict(sleep=0.9, sleepy=0.8)),
    ("shuijiao-xunhuan", "睡觉-循环", "sleep", "loop",
     dict(sleep=1.0, calm=0.7)),
    ("shuijiao-qilai", "睡觉-起来", "sleep", "once",
     dict(sleepy=0.7, calm=0.5, morning=0.4)),
    ("yuandi-xiaoqi-chenmian", "原地小憩沉眠", "sleep", "loop",
     dict(sleep=0.9, sleepy=0.9, calm=0.6)),

    # ---- 交互反馈 ----
    ("beishubiao-tuozhuai-xuankong-fankui", "被鼠标拖拽悬空反馈", "interaction", "once",
     dict(drag=1.0, surprised=0.4)),

    # ---- 早期缺 GIF 预览、只有 WebM 的 5 段（现在都有运行时素材了）----
    ("kaixin-xiaopao", "开心小跑", "emotion", "once",
     dict(joy=0.9, excited=0.7, sport=0.4)),
    ("ceshen-jizao-pao", "侧身急躁跑", "emotion", "once",
     dict(annoyed=0.8, tired=0.5, sport=0.6)),
    ("chi-fan-wanfan", "吃饭·碗饭", "food", "once",
     dict(eat=0.9, calm=0.3)),
    ("chi-fantuan", "吃饭团", "food", "once",
     dict(eat=0.9, cute=0.3)),
]


def parse_webp(path: str) -> tuple[int, int, int, int]:
    """返回 (宽, 高, 总时长毫秒, 帧数)。纯二进制解析 RIFF，不依赖 Pillow。

    动画 WebP 的结构：RIFF/WEBP 容器，VP8X 给出画布尺寸，每个 ANMF 块
    携带一帧的时长（3 字节，毫秒）。
    """
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError(f"不是合法 WebP: {path}")
    pos = 12
    width = height = 0
    total_ms = 0
    frames = 0
    while pos + 8 <= len(data):
        fourcc = data[pos : pos + 4]
        size = struct.unpack("<I", data[pos + 4 : pos + 8])[0]
        body = data[pos + 8 : pos + 8 + size]
        if fourcc == b"VP8X":
            width = int.from_bytes(body[4:7], "little") + 1
            height = int.from_bytes(body[7:10], "little") + 1
        elif fourcc == b"ANMF":
            total_ms += int.from_bytes(body[12:15], "little")
            frames += 1
            if not width:
                width = int.from_bytes(body[6:9], "little") + 1
                height = int.from_bytes(body[9:12], "little") + 1
        pos += 8 + size + (size & 1)
    if not width or frames == 0:
        raise ValueError(f"不是动画 WebP: {path}")
    return width, height, total_ms, frames


def load_boxes() -> dict:
    """读 tool/boxes.json；缺文件时返回空表（各段按整幅画面处理）。"""
    if not os.path.exists(BOXES_PATH):
        print("⚠ 缺少 tool/boxes.json，内容框按整幅画面处理"
              "（运行 python tool/gen_boxes.py 可生成）")
        return {}
    with open(BOXES_PATH, encoding="utf-8") as file:
        return json.load(file).get("boxes", {})


def build() -> dict:
    tag_ids = {t["id"] for t in TAGS}
    anim_files = {f[:-5] for f in os.listdir(ANIM_DIR) if f.endswith(".webp")}
    webm_files = {f[:-5] for f in os.listdir(WEBM_DIR) if f.endswith(".webm")}

    clips = []
    boxes = load_boxes()
    seen_ids, seen_webm = set(), set()
    for cid, name, group, hold, tags in CLIPS:
        if not cid:
            continue
        if cid in seen_ids:
            raise SystemExit(f"重复 clip id: {cid}")
        seen_ids.add(cid)
        for tid in tags:
            if tid not in tag_ids:
                raise SystemExit(f"{cid}: 未定义的标签 {tid}")
        if not 0 < len(tags) <= 6:
            raise SystemExit(f"{cid}: 标签数量应在 1~6 之间，实际 {len(tags)}")

        if cid not in anim_files:
            raise SystemExit(
                f"{cid}: 缺少运行时素材 assets/animations/{cid}.webp，"
                f"请先运行 python tool/gen_webp.py"
            )
        if name not in webm_files:
            raise SystemExit(f"{cid}: 缺少同名 WebM 母版（{name}）")
        seen_webm.add(name)

        entry = dict(
            id=cid,
            name=name,
            group=group,
            hold=hold,
            tags={k: round(float(v), 2) for k, v in tags.items()},
        )
        w, h, ms, _frames = parse_webp(os.path.join(ANIM_DIR, f"{cid}.webp"))
        box = boxes.get(cid) or [0, 0, w, h]
        if not (0 <= box[0] and 0 <= box[1]
                and box[2] > 0 and box[3] > 0
                and box[0] + box[2] <= w and box[1] + box[3] <= h):
            raise SystemExit(f"{cid}: 内容框 {box} 超出画面 {w}×{h}")
        entry.update(
            anim=f"assets/animations/{cid}.webp",
            width=w,
            height=h,
            box=list(box),
            durationMs=max(1200, ms),
            webm=f"assets/webm/{name}.webm",
        )
        clips.append(entry)

    missing_anim = anim_files - seen_ids
    if missing_anim:
        raise SystemExit(f"以下运行时素材未标注: {sorted(missing_anim)}")
    missing_webm = webm_files - seen_webm
    if missing_webm:
        raise SystemExit(f"以下 WebM 未标注: {sorted(missing_webm)}")

    manifest = dict(
        schemaVersion=1,
        generator="tool/gen_manifest.py",
        frame=dict(width=640, height=360),
        clips=clips,
    )
    tags_doc = dict(
        schemaVersion=1,
        generator="tool/gen_manifest.py",
        groups=[dict(id=k, **v) for k, v in GROUPS.items()],
        tags=[
            dict(
                id=t["id"],
                label=t["label"],
                group=t["group"],
                base=t["base"],
                description=t["desc"],
                keywords=t["keywords"],
            )
            for t in TAGS
        ],
    )
    return dict(manifest=manifest, tags=tags_doc)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只校验不写文件")
    args = ap.parse_args()

    docs = build()
    man_path = os.path.join(OUT_DIR, "animations.json")
    tag_path = os.path.join(OUT_DIR, "tags.json")

    if args.check:
        ok = True
        for path, key in ((man_path, "manifest"), (tag_path, "tags")):
            if not os.path.exists(path):
                print(f"缺少 {path}")
                ok = False
                continue
            with open(path, encoding="utf-8") as fh:
                if json.load(fh) != docs[key]:
                    print(f"{path} 与标注表不一致，请重跑 python tool/gen_manifest.py")
                    ok = False
        return 0 if ok else 1

    os.makedirs(OUT_DIR, exist_ok=True)
    for path, key in ((man_path, "manifest"), (tag_path, "tags")):
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(docs[key], fh, ensure_ascii=False, indent=2)
            fh.write("\n")

    clips = docs["manifest"]["clips"]
    playable = [c for c in clips if c.get("anim")]
    print(f"标签 {len(TAGS)} 个 / 动画 {len(clips)} 段（全部可播放 {len(playable)}）")
    print(f"平均时长 {sum(c['durationMs'] for c in playable) / len(playable) / 1000:.1f}s")
    print(f"写出: {os.path.relpath(man_path, ROOT)} / {os.path.relpath(tag_path, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
