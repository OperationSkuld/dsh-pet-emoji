#!/usr/bin/env python3
"""把 CHANGELOG 里当前版本的段落拼到发布说明开头，生成 Release 正文。

为什么需要：
  docs/release-notes-template.md 是「安装包 / 已知限制 / 许可」这类每次都不变的
  固定内容。如果直接拿它当 Release 正文，用户点进 Release 看不到这次改了什么。
  这个脚本从 CHANGELOG.md 里取出与 pubspec.yaml 版本对应的一段，拼在模板前面。

用法：
    python tool/gen_release_notes.py                     # 打到标准输出
    python tool/gen_release_notes.py --out dist/x.md     # 写到文件
    python tool/gen_release_notes.py --check             # 只校验版本段落存在
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG_PATH = os.path.join(ROOT, "CHANGELOG.md")
PUBSPEC_PATH = os.path.join(ROOT, "pubspec.yaml")
TEMPLATE_PATH = os.path.join(ROOT, "docs", "release-notes-template.md")

# pubspec 的 version 允许带 build 号（1.2.0+3），语义版本只取前半段
_VERSION_RE = re.compile(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)")


def read_text(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def current_version() -> str:
    for line in read_text(PUBSPEC_PATH).splitlines():
        matched = _VERSION_RE.match(line.strip())
        if matched:
            return matched.group(1)
    sys.exit(f"错误：{os.path.relpath(PUBSPEC_PATH, ROOT)} 里找不到 version")


def changelog_section(text: str, version: str) -> str:
    """取出 `## [1.2.0] - ...` 到下一个二级标题之间的内容。"""
    body: list[str] | None = None
    for line in text.splitlines():
        if body is None:
            if re.match(rf"^##\s*\[{re.escape(version)}\]", line):
                body = []
            continue
        if line.startswith("## "):
            break
        body.append(line)
    return "\n".join(body).strip("\n") if body else ""


def build(version: str) -> str:
    template = read_text(TEMPLATE_PATH)
    section = changelog_section(read_text(CHANGELOG_PATH), version)
    if not section:
        # 没有对应段落时退回纯模板，至少不会让发版流程挂掉
        return template
    return f"## v{version} 更新内容\n\n{section}\n\n---\n\n{template}"


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 Release 正文（版本变更 + 固定说明）")
    parser.add_argument("--version", help="默认取 pubspec.yaml 的版本")
    parser.add_argument("--out", help="输出路径，省略则打到标准输出")
    parser.add_argument("--check", action="store_true", help="只校验版本段落在 CHANGELOG 里存在")
    args = parser.parse_args()

    version = args.version or current_version()
    section = changelog_section(read_text(CHANGELOG_PATH), version)

    if args.check:
        if not section:
            print(f"错误：CHANGELOG.md 缺少 [{version}] 段落", file=sys.stderr)
            return 1
        print(f"发布说明可生成（v{version}，{len(section.splitlines())} 行变更）")
        return 0

    text = build(version)
    if args.out:
        out_path = args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out)
        os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
        with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        print(f"已写入 {args.out}")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
