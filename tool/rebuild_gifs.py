#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 assets/webm 批量重导出高分辨率透明 GIF。

需要本机安装 ffmpeg。只重导出「已有 GIF」的素材——只有 WebM、缺预览的
5 段素材导出后仍需在标注表里确认，脚本不会自动改清单。

用法:
    python tool/rebuild_gifs.py --dry-run      # 只打印命令，不执行
    python tool/rebuild_gifs.py --width 440    # 实际导出，覆盖 assets/animations/

导出后请重跑:  python tool/gen_manifest.py
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "manifest", "animations.json")

# palettegen/paletteuse 组合：reserve_transparent 保住 alpha，alpha_threshold 去边缘杂色
FILTER = (
    "fps={fps},scale={width}:-1:flags=lanczos,split[a][b];"
    "[a]palettegen=reserve_transparent=1:stats_mode=full[p];"
    "[b][p]paletteuse=alpha_threshold=128"
)


def build_commands(width: int, fps: int) -> list[list[str]]:
    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)

    commands = []
    for clip in manifest["clips"]:
        if not clip.get("gif") or not clip.get("webm"):
            continue
        source = os.path.join(ROOT, clip["webm"])
        target = os.path.join(ROOT, clip["gif"])
        if not os.path.exists(source):
            print(f"跳过（缺 WebM）: {clip['id']}", file=sys.stderr)
            continue
        commands.append(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-i",
                source,
                "-vf",
                FILTER.format(width=width, fps=fps),
                "-loop",
                "0",
                target,
            ]
        )
    return commands


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--width", type=int, default=440)
    parser.add_argument("--fps", type=int, default=20)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    commands = build_commands(args.width, args.fps)
    print(f"待处理 {len(commands)} 段素材（宽度 {args.width}px, {args.fps}fps）")

    if args.dry_run:
        for command in commands[:3]:
            print(" ".join(f'"{part}"' if " " in part else part for part in command))
        if len(commands) > 3:
            print(f"... 其余 {len(commands) - 3} 条同理")
        print("\n提示：实际执行时请确保 ffmpeg 在 PATH 中。体积约为原图的 4 倍。")
        return 0

    if shutil.which("ffmpeg") is None:
        print("未找到 ffmpeg，请先安装（https://ffmpeg.org/download.html）", file=sys.stderr)
        return 1

    for index, command in enumerate(commands, start=1):
        print(f"[{index}/{len(commands)}] {os.path.basename(command[-1])}")
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  失败: {result.stderr.strip()[:300]}", file=sys.stderr)

    print("\n完成。请重跑 python tool/gen_manifest.py 同步时长字段。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
