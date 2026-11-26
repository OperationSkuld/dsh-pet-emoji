#!/usr/bin/env python3
"""从一张 .ico 母版生成三端启动图标。

母版：`tool/brand/app_icon.ico`（7 档尺寸，最大 256×256，透明底）。
输出：
  - Windows  `windows/runner/resources/app_icon.ico`（原样复制，保留多尺寸）
  - Android  `android/app/src/main/res/mipmap-*/ic_launcher.png`
  - iOS      `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png`

iOS 的 App Store 规则不接受带 alpha 的图标，因此 iOS 侧统一压平到白底；
Android 保留透明（启动器会自行加背板）。Windows 保留 .ico 的完整尺寸表。

用法：
    python tool/gen_icons.py            # 生成
    python tool/gen_icons.py --check    # 只校验是否与母版一致（CI 用）
"""

from __future__ import annotations

import argparse
import io
import struct
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tool" / "brand" / "app_icon.ico"

WINDOWS_TARGET = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

ANDROID_TARGETS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# 文件名 -> 像素边长，与 AppIcon.appiconset/Contents.json 一一对应
IOS_TARGETS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

IOS_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"


def load_master() -> Image.Image:
    """取出 .ico 里最大的一档（256×256）作为母版。"""
    data = SOURCE.read_bytes()
    count = struct.unpack("<H", data[4:6])[0]
    best: tuple[int, bytes] = (0, b"")
    for index in range(count):
        offset = 6 + 16 * index
        width, _, _, _, _, _, size, start = struct.unpack(
            "<BBBBHHII", data[offset : offset + 16]
        )
        width = width or 256  # 0 表示 256
        if width >= best[0]:
            best = (width, data[start : start + size])
    if not best[1]:
        sys.exit(f"无法从 {SOURCE} 解析出图标数据")
    return Image.open(io.BytesIO(best[1])).convert("RGBA")


def resize(master: Image.Image, size: int) -> Image.Image:
    # 三次卷积：缩小时比默认双线性更干净；1024 由 256 放大，属于唯一的软上限
    return master.resize((size, size), Image.LANCZOS)


def flatten_white(image: Image.Image) -> Image.Image:
    """压平到白底，用于 iOS（App Store 不接受 alpha 通道）。"""
    canvas = Image.new("RGBA", image.size, (255, 255, 255, 255))
    canvas.alpha_composite(image)
    return canvas.convert("RGB")


def encode_png(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def build_outputs() -> list[tuple[Path, bytes]]:
    master = load_master()
    outputs: list[tuple[Path, bytes]] = []

    # Windows：整个 .ico 原样复制，保留 16/24/32/48/64/128/256 七档
    outputs.append((WINDOWS_TARGET, SOURCE.read_bytes()))

    for folder, size in ANDROID_TARGETS.items():
        path = ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
        png = encode_png(resize(master, size))
        outputs.append((path, png))

    for name, size in IOS_TARGETS.items():
        png = encode_png(flatten_white(resize(master, size)))
        outputs.append((IOS_DIR / name, png))

    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="只校验现有图标是否与母版一致，不写文件",
    )
    args = parser.parse_args()

    if not SOURCE.exists():
        sys.exit(f"母版缺失：{SOURCE}")

    outputs = build_outputs()
    stale: list[Path] = []

    for path, content in outputs:
        if args.check:
            if not path.exists() or path.read_bytes() != content:
                stale.append(path)
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    if args.check:
        if stale:
            print(f"图标与母版不一致（{len(stale)} 个），请运行 python tool/gen_icons.py：")
            for path in stale:
                print(f"  - {path.relative_to(ROOT)}")
            return 1
        print(f"图标一致（{len(outputs)} 个文件）")
        return 0

    print(f"已生成 {len(outputs)} 个图标文件")
    print(f"  Windows 1 · Android {len(ANDROID_TARGETS)} · iOS {len(IOS_TARGETS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
