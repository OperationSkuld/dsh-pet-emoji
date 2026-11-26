#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从语义清单生成文档表格。

  - README.md 的 `<!-- BEGIN:TAG_OVERVIEW -->` 区块（标签 → 动画总览）
  - docs/TAGS.md 全文（标签全表、标签→动画索引、动画→标签全表、回落链）

用法:
    python tool/gen_docs.py
    python tool/gen_docs.py --check   # 只检查文档是否与清单同步（CI 用）
"""

from __future__ import annotations

import argparse
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "manifest", "animations.json")
TAGS_JSON = os.path.join(ROOT, "assets", "manifest", "tags.json")
README = os.path.join(ROOT, "README.md")
TAGS_DOC = os.path.join(ROOT, "docs", "TAGS.md")

GROUP_LABELS = {
    "emotion": "情绪",
    "social": "社交",
    "action": "行为",
    "scene": "时令",
    "system": "系统",
}
GROUP_ORDER = ["emotion", "social", "action", "scene", "system"]
GROUP_NOTES = {
    "emotion": "由对话内容推断的情感状态，决定表情基调",
    "social": "对话意图层面的社交行为",
    "action": "正在进行的动作或话题领域",
    "scene": "时间与季节情境，仅作氛围加成（权重 ×0.35）",
    "system": "由 App 事件直接注入（余额档位 / 错误 / 点击 / 拖拽），优先级最高",
}
FALLBACK_CHAIN = {
    "apology": ["sad", "tired"],
    "comfort": ["calm", "love"],
    "refuse": ["angry", "tease"],
    "error": ["sad", "annoyed"],
    "sad": ["tired", "calm"],
    "tired": ["sleepy", "calm"],
    "lonely": ["sad", "calm"],
    "praise": ["shy", "joy"],
    "grateful": ["thanks", "joy"],
    "bored": ["dazed", "idle"],
}


def load():
    with io.open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)
    with io.open(TAGS_JSON, encoding="utf-8") as fh:
        tags = json.load(fh)
    return manifest, tags


def playable(clips):
    return [c for c in clips if c.get("anim")]


def top_tags(clip, limit=6):
    items = sorted(clip["tags"].items(), key=lambda kv: -kv[1])[:limit]
    return " · ".join(f"`{k}` {v:.2f}".replace("0.", ".") for k, v in items)


def tag_overview_table(manifest, tags) -> str:
    clips = playable(manifest["clips"])
    index = {}
    for clip in clips:
        for tag, score in clip["tags"].items():
            index.setdefault(tag, []).append((score, clip))

    lines = []
    for group in GROUP_ORDER:
        group_tags = [t for t in tags["tags"] if t["group"] == group]
        if not group_tags:
            continue
        lines.append(f"**{GROUP_LABELS[group]}**（{GROUP_NOTES[group]}）")
        lines.append("")
        lines.append("| 标签 | id | 可用动画 | 代表表情 |")
        lines.append("| --- | --- | --- | --- |")
        for tag in sorted(group_tags, key=lambda t: t["label"]):
            entries = index.get(tag["id"], [])
            entries.sort(key=lambda item: -item[0])
            names = "、".join(clip["name"] for _, clip in entries[:2])
            count = str(len(entries)) if entries else "—"
            if not entries:
                names = "*无专属素材，按回落链取相近表情*"
            lines.append(f"| **{tag['label']}** | `{tag['id']}` | {count} | {names} |")
        lines.append("")
    return "\n".join(lines).rstrip()


def tags_doc(manifest, tags) -> str:
    clips = manifest["clips"]
    playable_clips = playable(clips)
    webm_only = [c for c in clips if not c.get("anim")]
    keyword_total = sum(len(t["keywords"]) for t in tags["tags"])

    out = []
    out.append("# 语义标签与动画映射")
    out.append("")
    out.append("> 本文档由 `python tool/gen_docs.py` 依据 `assets/manifest/*.json` 生成，"
               "请勿手改表格；要改标签或素材标注，改 `tool/gen_manifest.py` 后重新生成。")
    out.append("")
    out.append(f"- 动画 **{len(clips)}** 段（全部可播放 {len(playable_clips)}）")
    out.append(f"- 语义标签 **{len(tags['tags'])}** 个，关键词 **{keyword_total}** 条")
    out.append(f"- 标签分组 **{len(GROUP_ORDER)}** 类：情绪 / 社交 / 行为 / 时令 / 系统")
    out.append("")
    out.append("## 1. 设计原则")
    out.append("")
    out.append("1. **标签是有限的、可解释的**：60 个标签覆盖情绪、社交意图、行为领域、时令与系统事件，"
               "每个标签都有中文名与一句说明，便于标注时对齐语义。")
    out.append("2. **素材与标签是多对多**：一段动画可携带 1~6 个标签及契合度（0~1），"
               "一个标签可被多段动画共享。契合度表示「这段动画有多像这个标签」，不是概率。")
    out.append("3. **权重而非布尔**：选片时用 `语义分 × 契合度` 求和，所以「有点开心」和「狂喜」"
               "会落到不同动画上，而不是都命中同一段。")
    out.append("4. **没有专属素材的标签不算错**：`apology`、`comfort`、`refuse` 等通过回落链"
               "借用相近情绪素材，避免为一个低频情绪硬造一段动画。")
    out.append("")
    out.append("## 2. 标签分组")
    out.append("")
    out.append("| 分组 | id | 说明 | 标签数 |")
    out.append("| --- | --- | --- | --- |")
    for group in GROUP_ORDER:
        count = len([t for t in tags["tags"] if t["group"] == group])
        out.append(f"| {GROUP_LABELS[group]} | `{group}` | {GROUP_NOTES[group]} | {count} |")
    out.append("")
    out.append("## 3. 标签全表")
    out.append("")
    out.append("`基础强度` 是词典命中时的起始分（0~1），会再乘来源权重（用户 0.55 / 回复 0.45）、"
               "程度修饰与重复衰减。")
    out.append("")
    out.append("| 标签 | id | 分组 | 基础强度 | 关键词 | 说明 |")
    out.append("| --- | --- | --- | --- | --- | --- |")
    for group in GROUP_ORDER:
        for tag in sorted([t for t in tags["tags"] if t["group"] == group], key=lambda t: t["label"]):
            keywords = "、".join(tag["keywords"][:6])
            if len(tag["keywords"]) > 6:
                keywords += "…"
            if not keywords:
                keywords = "*无（由结构或事件注入）*"
            out.append(
                f"| **{tag['label']}** | `{tag['id']}` | {GROUP_LABELS[group]} | "
                f"{tag['base']:.2f} | {keywords} | {tag['description']} |"
            )
    out.append("")
    out.append("## 4. 标签 → 动画")
    out.append("")
    out.append("按契合度降序。括号内为契合度，≥0.8 才允许被「系统事件」通道直接选中。")
    out.append("")
    for group in GROUP_ORDER:
        group_tags = sorted([t for t in tags["tags"] if t["group"] == group], key=lambda t: t["label"])
        out.append(f"### {GROUP_LABELS[group]}")
        out.append("")
        for tag in group_tags:
            entries = [(c["tags"][tag["id"]], c) for c in playable_clips if tag["id"] in c["tags"]]
            entries.sort(key=lambda item: -item[0])
            if entries:
                body = "、".join(f"{c['name']}（{s:.2f}）" for s, c in entries)
            else:
                chain = FALLBACK_CHAIN.get(tag["id"])
                body = ("*无专属素材*" if not chain
                        else "*无专属素材，回落：" + " → ".join(f"`{t}`" for t in chain) + "*")
            out.append(f"- **{tag['label']}** `{tag['id']}` — {body}")
        out.append("")
    out.append("## 5. 动画 → 标签（全表）")
    out.append("")
    out.append("| # | 动画 | id | 分组 | 停留 | 时长 | 标签（契合度） | 素材 |")
    out.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for index, clip in enumerate(clips, start=1):
        hold = "循环" if clip["hold"] == "loop" else "一次性"
        seconds = f"{clip['durationMs'] / 1000:.1f}s"
        source = "WebP+WebM" if clip.get("anim") and clip.get("webm") else (
            "仅 WebM" if clip.get("webm") else "WebP")
        out.append(
            f"| {index} | {clip['name']} | `{clip['id']}` | {clip['group']} | {hold} | "
            f"{seconds} | {top_tags(clip)} | {source} |"
        )
    out.append("")
    out.append("> 运行时素材是 640×360 的动画 WebP（真 alpha），由 `assets/webm` 里的母版"
               "经 `tool/gen_webp.py` 导出，尺寸与母版一致。")
    out.append("")
    out.append("## 6. 回落链")
    out.append("")
    out.append("当某个标签没有任何契合度 ≥0.8 的素材时，按此顺序寻找替代标签；"
               "全都没有则回到 `idle`。")
    out.append("")
    out.append("| 原标签 | 回落顺序 |")
    out.append("| --- | --- |")
    for tag, chain in FALLBACK_CHAIN.items():
        out.append(f"| `{tag}` | " + " → ".join(f"`{t}`" for t in chain) + " |")
    out.append("")
    out.append("## 7. 如何调整")
    out.append("")
    out.append("1. 改标签词典或基础强度：`tool/gen_manifest.py` 的 `TAGS`。")
    out.append("2. 改动画标注：`tool/gen_manifest.py` 的 `CLIPS`（分组、停留策略、标签与契合度）。")
    out.append("3. 改选片权重（氛围系数、覆盖率加成、防重复）：`lib/domain/semantic/animation_selector.dart`。")
    out.append("4. 重新生成：`python tool/gen_manifest.py && python tool/gen_docs.py`，再 `flutter test`。")
    out.append("")
    return "\n".join(out)


def inject_readme(table: str) -> str:
    with io.open(README, encoding="utf-8") as fh:
        text = fh.read()
    begin = "<!-- BEGIN:TAG_OVERVIEW -->"
    end = "<!-- END:TAG_OVERVIEW -->"
    if begin not in text or end not in text:
        raise SystemExit("README.md 缺少 TAG_OVERVIEW 标记，无法注入表格")
    head, rest = text.split(begin, 1)
    _, tail = rest.split(end, 1)
    return f"{head}{begin}\n{table}\n{end}{tail}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    manifest, tags = load()
    overview = tag_overview_table(manifest, tags)
    doc = tags_doc(manifest, tags)
    readme = inject_readme(overview)

    if args.check:
        ok = True
        if not os.path.exists(TAGS_DOC):
            print("缺少 docs/TAGS.md")
            ok = False
        else:
            with io.open(TAGS_DOC, encoding="utf-8") as fh:
                if fh.read() != doc:
                    print("docs/TAGS.md 与清单不同步，请重跑 python tool/gen_docs.py")
                    ok = False
        with io.open(README, encoding="utf-8") as fh:
            if fh.read() != readme:
                print("README.md 表格与清单不同步，请重跑 python tool/gen_docs.py")
                ok = False
        return 0 if ok else 1

    with io.open(TAGS_DOC, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(doc)
    with io.open(README, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(readme)
    print(f"已生成: {os.path.relpath(TAGS_DOC, ROOT)} 与 README 标签总览（{len(tags['tags'])} 个标签）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
