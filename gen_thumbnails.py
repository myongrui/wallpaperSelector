#!/usr/bin/env python3
import colorsys
import hashlib
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def dominant_saturation(img: Image.Image) -> float:
    small = img.resize((50, 50), Image.LANCZOS).convert("RGB")
    saturations = []
    for r, g, b in small.getdata():
        _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if v > 0.1:  # ignore near-black pixels
            saturations.append(s)
    return sum(saturations) / len(saturations) if saturations else 0.0


def main():
    if len(sys.argv) < 3:
        print("Usage: gen_thumbnails.py <wallpaper_dir> <cache_dir>", file=sys.stderr)
        sys.exit(1)

    wallpaper_dir = Path(sys.argv[1])
    cache_dir = Path(sys.argv[2])
    cache_dir.mkdir(parents=True, exist_ok=True)

    thumb_w, thumb_h, radius = 240, 135, 10
    exts = {".jpg", ".jpeg", ".png", ".webp", ".gif"}

    images = sorted(
        p for p in wallpaper_dir.iterdir() if p.is_file() and p.suffix.lower() in exts
    )

    for img_path in images:
        h = hashlib.md5(str(img_path).encode()).hexdigest()
        thumb_path = cache_dir / (h + ".png")
        sat_path = cache_dir / (h + ".sat")

        try:
            if not thumb_path.exists() or not sat_path.exists():
                img = Image.open(img_path).convert("RGB")

                if not thumb_path.exists():
                    scale = max(thumb_w / img.width, thumb_h / img.height)
                    sw = max(int(img.width * scale), thumb_w)
                    sh = max(int(img.height * scale), thumb_h)
                    resized = img.resize((sw, sh), Image.LANCZOS)
                    left = (sw - thumb_w) // 2
                    top = (sh - thumb_h) // 2
                    cropped = resized.crop((left, top, left + thumb_w, top + thumb_h)).convert("RGBA")
                    mask = Image.new("L", (thumb_w, thumb_h), 0)
                    ImageDraw.Draw(mask).rounded_rectangle(
                        [0, 0, thumb_w - 1, thumb_h - 1], radius=radius, fill=255
                    )
                    cropped.putalpha(mask)
                    cropped.save(str(thumb_path))

                if not sat_path.exists():
                    sat_path.write_text(str(dominant_saturation(img)))

            sat = float(sat_path.read_text())
            print(f"{img_path}\t{thumb_path}\t{sat}", flush=True)
        except Exception as e:
            print(f"SKIP {img_path.name}: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
