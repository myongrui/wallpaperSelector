#!/usr/bin/env python3
import hashlib
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    if len(sys.argv) < 3:
        print("Usage: gen_thumbnails.py <wallpaper_dir> <cache_dir>", file=sys.stderr)
        sys.exit(1)

    wallpaper_dir = Path(sys.argv[1])
    cache_dir = Path(sys.argv[2])
    cache_dir.mkdir(parents=True, exist_ok=True)

    thumb_w, thumb_h, radius = 240, 135, 4
    exts = {".jpg", ".jpeg", ".png", ".webp", ".gif"}

    images = sorted(
        p for p in wallpaper_dir.iterdir() if p.is_file() and p.suffix.lower() in exts
    )

    for img_path in images:
        thumb_name = hashlib.md5(str(img_path).encode()).hexdigest() + ".png"
        thumb_path = cache_dir / thumb_name

        if not thumb_path.exists():
            try:
                img = Image.open(img_path).convert("RGB")
                scale = max(thumb_w / img.width, thumb_h / img.height)
                sw = max(int(img.width * scale), thumb_w)
                sh = max(int(img.height * scale), thumb_h)
                img = img.resize((sw, sh), Image.LANCZOS)
                left = (sw - thumb_w) // 2
                top = (sh - thumb_h) // 2
                img = img.crop((left, top, left + thumb_w, top + thumb_h))
                img = img.convert("RGBA")
                mask = Image.new("L", (thumb_w, thumb_h), 0)
                ImageDraw.Draw(mask).rounded_rectangle(
                    [0, 0, thumb_w - 1, thumb_h - 1], radius=radius, fill=255
                )
                img.putalpha(mask)
                img.save(str(thumb_path))
            except Exception as e:
                print(f"SKIP {img_path.name}: {e}", file=sys.stderr)
                continue

        print(f"{img_path}\t{thumb_path}", flush=True)


if __name__ == "__main__":
    main()
