#!/usr/bin/env python3
"""从 WebM 母版导出运行时动画素材（动画 WebP，带真 alpha）。

为什么不是 GIF / 不是直接播 WebM：
  - 直接播 WebM：Flutter 三端没有「带透明通道的视频」管线。`video_player` 之类的
    纹理是不透明的，iOS 的 AVFoundation 更是完全不支持 VP9。宠物背后会出现黑块。
  - GIF：640×360 的 GIF 实测约 7 MB/段，114 段要 800 MB，而且只有 256 色。
  - 动画 WebP：同一套 `Image.asset` 代码路径（Flutter 原生支持多帧 WebP + alpha），
    640×360 只要约 1.3 MB/段，尺寸与母版完全一致，显示时是降采样，所以锐利。

WebM 母版的 alpha 是真的（VP9 ALPHA_MODE=1），但必须显式指定 `-c:v libvpx-vp9`
解码才会输出 yuva420p，否则拿到的是黑底不透明画面。

用法：
    python tool/gen_webp.py                     # 生成全部
    python tool/gen_webp.py --only 吃白饭 放烟花  # 只导几段
    python tool/gen_webp.py --check             # 只校验尺寸/存在性（CI 用，不需要 ffmpeg）
    python tool/gen_webp.py --dry-run           # 打印命令不执行

需要 ffmpeg（含 libvpx 与 libwebp）：用 --ffmpeg 指定路径，或放在 PATH 里。
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tool"))

from gen_manifest import CLIPS, parse_webp  # noqa: E402  （同目录脚本，复用标注表）

WEBM_DIR = os.path.join(ROOT, "assets", "webm")
OUT_DIR = os.path.join(ROOT, "assets", "animations")

# 默认参数：与母版同尺寸、保留真 alpha、体积控制在 ~1.0 MB/段
#
# 帧率选 12 而不是 15：母版是 24fps，24→12 是整数二分频，每帧间隔完全均匀；
# 24→15 会得到 1/2/1/2 帧的乱序采样，同码率下 SSIM 反而更低（实测 0.9465 vs
# 0.9469），体积还多 20%。所以 12fps 是「更小且更准」，不是妥协。
DEFAULT_WIDTH = 640
DEFAULT_FPS = 12
DEFAULT_QUALITY = 45
DEFAULT_SECONDS = 6


def find_ffmpeg(explicit: str | None) -> str:
    if explicit:
        if not os.path.exists(explicit):
            sys.exit(f"找不到 ffmpeg：{explicit}")
        return explicit
    env = os.environ.get("FFMPEG")
    if env and os.path.exists(env):
        return env
    found = shutil.which("ffmpeg")
    if found:
        return found
    sys.exit(
        "找不到 ffmpeg。请装好后加入 PATH，或用 --ffmpeg 指定，例如：\n"
        r"  python tool/gen_webp.py --ffmpeg C:\ffmpeg\bin\ffmpeg.exe"
    )


def build_command(ffmpeg: str, name: str, out: str, args) -> list[str]:
    return [
        ffmpeg,
        "-y",
        "-v",
        "error",
        # 必须显式指定解码器，否则 VP9 的 alpha 通道不会被解出来
        "-c:v",
        "libvpx-vp9",
        "-i",
        os.path.join(WEBM_DIR, f"{name}.webm"),
        "-t",
        str(args.seconds),
        "-vf",
        f"fps={args.fps},scale={args.width}:-1:flags=lanczos,format=rgba",
        "-c:v",
        "libwebp_anim",
        "-lossless",
        "0",
        "-q:v",
        str(args.quality),
        "-loop",
        "0",
        out,
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", help="ffmpeg 可执行文件路径")
    parser.add_argument("--width", type=int, default=DEFAULT_WIDTH)
    parser.add_argument("--fps", type=int, default=DEFAULT_FPS)
    parser.add_argument("--quality", type=int, default=DEFAULT_QUALITY)
    parser.add_argument("--seconds", type=float, default=DEFAULT_SECONDS)
    parser.add_argument("--only", nargs="*", help="只处理这些中文名（name 字段）")
    parser.add_argument("--check", action="store_true", help="只校验，不生成")
    parser.add_argument("--dry-run", action="store_true", help="只打印命令")
    args = parser.parse_args()

    targets = [(cid, name) for cid, name, *_ in CLIPS if cid]
    if args.only:
        wanted = set(args.only)
        targets = [(cid, name) for cid, name in targets if name in wanted]
        if not targets:
            sys.exit(f"没有匹配的素材：{sorted(wanted)}")

    if args.check:
        missing = []
        wrong_size = []
        for cid, _ in targets:
            path = os.path.join(OUT_DIR, f"{cid}.webp")
            if not os.path.exists(path):
                missing.append(cid)
                continue
            w, h, ms, frames = parse_webp(path)
            if w != args.width or h <= 0 or ms <= 0 or frames < 2:
                wrong_size.append(f"{cid}({w}x{h}, {frames}帧, {ms}ms)")
        if missing or wrong_size:
            for cid in missing:
                print(f"缺失: {cid}.webp")
            for item in wrong_size:
                print(f"尺寸/帧数异常: {item}")
            print(f"\n请运行 python tool/gen_webp.py --width {args.width}")
            return 1
        print(f"运行时素材一致（{len(targets)} 段，{args.width} 宽动画 WebP）")
        return 0

    os.makedirs(OUT_DIR, exist_ok=True)
    ffmpeg = "" if args.dry_run else find_ffmpeg(args.ffmpeg)

    done = 0
    total_bytes = 0
    for cid, name in targets:
        out = os.path.join(OUT_DIR, f"{cid}.webp")
        cmd = build_command(ffmpeg or "ffmpeg", name, out, args)
        if args.dry_run:
            print(" ".join(cmd))
            continue
        result = subprocess.run(cmd, capture_output=True)
        if result.returncode != 0:
            print(f"✗ {name}: {result.stderr.decode('utf-8', 'replace')[:300]}")
            return 1
        size = os.path.getsize(out)
        total_bytes += size
        done += 1
        print(f"[{done}/{len(targets)}] {name} → {cid}.webp  {size / 1048576:.2f} MB")

    print(
        f"\n完成 {done} 段，合计 {total_bytes / 1048576:.0f} MB"
        f"（{args.width}px / {args.fps}fps / q{args.quality} / {args.seconds}s）"
    )
    print("记得重跑 python tool/gen_manifest.py 与 tool/gen_docs.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
