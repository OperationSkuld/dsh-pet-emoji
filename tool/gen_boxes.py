#!/usr/bin/env python3
"""量出每段动画在画面里「真正有内容」的矩形，写到 tool/boxes.json。

为什么需要：
  运行时素材是 640×360 的统一画布，但角色本身只占其中一块——站姿类大约
  230×280，带特效的动作才会用到大半画面。如果按整张画布排版，气泡和底部
  按钮就会离角色很远，看起来像「留白太大」。

  这份数据让界能把气泡、操作条贴着角色的真实边缘摆，默认位置也能做到
  真正的「右下角留 20」而不是「画布右下角留 20」。

做法：
  逐帧取 alpha 通道、按阈值二值化后求包围盒，再把整段动画的包围盒合并，
  外扩 PAD 像素给抗锯齿留余量。输出为画面像素坐标 [x, y, w, h]。

用法：
    python tool/gen_boxes.py            # 重新测量并写入 tool/boxes.json
    python tool/gen_boxes.py --check    # 只校验 boxes.json 是否覆盖全部素材
"""

from __future__ import annotations

import argparse
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM_DIR = os.path.join(ROOT, "assets", "animations")
OUT_PATH = os.path.join(ROOT, "tool", "boxes.json")

# alpha 低于此值视为透明：既要滤掉有损压缩的微弱噪点，又不能切掉柔边
ALPHA_MIN = 8
# 包围盒外扩，给抗锯齿与缩放留余量
PAD = 2

# 二值化查找表（point 走 C 实现，比逐像素判断快两个数量级）
_LUT = [255 if i > ALPHA_MIN else 0 for i in range(256)]


def measure(path: str) -> tuple[int, int, int, int, int, int] | None:
    """返回 (x, y, w, h, frameW, frameH)；整段全透明时返回 None。"""
    box: tuple[int, int, int, int] | None = None
    with Image.open(path) as im:
        size = im.size
        for index in range(getattr(im, "n_frames", 1)):
            im.seek(index)
            alpha = im.convert("RGBA").getchannel("A").point(_LUT)
            found = alpha.getbbox()
            if found is None:
                continue
            box = found if box is None else (
                min(box[0], found[0]),
                min(box[1], found[1]),
                max(box[2], found[2]),
                max(box[3], found[3]),
            )
    if box is None:
        return None
    x0 = max(0, box[0] - PAD)
    y0 = max(0, box[1] - PAD)
    x1 = min(size[0], box[2] + PAD)
    y1 = min(size[1], box[3] + PAD)
    return x0, y0, x1 - x0, y1 - y0, size[0], size[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="只校验覆盖面")
    args = parser.parse_args()

    names = sorted(f[:-5] for f in os.listdir(ANIM_DIR) if f.endswith(".webp"))
    if not names:
        sys.exit(f"{ANIM_DIR} 里没有 WebP 素材")

    if args.check:
        if not os.path.exists(OUT_PATH):
            print("缺少 tool/boxes.json，请运行 python tool/gen_boxes.py")
            return 1
        with open(OUT_PATH, encoding="utf-8") as file:
            saved = json.load(file)["boxes"]
        missing = [n for n in names if n not in saved]
        if missing:
            print(f"boxes.json 未覆盖 {len(missing)} 段素材：{missing[:5]} …")
            return 1
        print(f"内容框数据齐全（{len(names)} 段）")
        return 0

    boxes: dict[str, list[int]] = {}
    frames: dict[str, list[int]] = {}
    for name in names:
        result = measure(os.path.join(ANIM_DIR, f"{name}.webp"))
        if result is None:
            print(f"⚠ {name} 整段全透明，按整幅画面处理")
            continue
        x, y, w, h, fw, fh = result
        boxes[name] = [x, y, w, h]
        frames[name] = [fw, fh]

    payload = {
        "generator": "tool/gen_boxes.py",
        "note": "每段动画的内容包围盒 [x, y, w, h]，单位是画面像素；外扩 2px 抗锯齿余量",
        "frames": frames,
        "boxes": boxes,
    }
    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as file:
        json.dump(payload, file, ensure_ascii=False, indent=1, sort_keys=True)
        file.write("\n")

    widths = [b[2] for b in boxes.values()]
    heights = [b[3] for b in boxes.values()]
    print(f"已写入 {os.path.relpath(OUT_PATH, ROOT)}：{len(boxes)} 段")
    print(f"  内容宽度 {min(widths)}~{max(widths)}，内容高度 {min(heights)}~{max(heights)}")
    print("记得重跑 python tool/gen_manifest.py 与 tool/gen_docs.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
