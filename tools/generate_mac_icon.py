#!/usr/bin/env python3
"""Build mac/src/AppIcon.icns from the single 1024 px master image.

The master (mac/images/icon/AppIcon-1024.png) is the only icon source; every
size in the .icns is downscaled from it. Run after editing the master:

    python3 tools/generate_mac_icon.py
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
MASTER = REPO / "mac/images/icon/AppIcon-1024.png"
OUTPUT = REPO / "mac/src/AppIcon.icns"

# (point size, scale) pairs macOS expects in an app icon.
SIZES = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
         (256, 1), (256, 2), (512, 1), (512, 2)]


def main():
    master = Image.open(MASTER).convert("RGBA")
    if master.size != (1024, 1024):
        raise SystemExit(f"{MASTER} must be 1024x1024, got {master.size}")
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for points, scale in SIZES:
            px = points * scale
            suffix = "@2x" if scale == 2 else ""
            img = master if px == 1024 else master.resize((px, px), Image.LANCZOS)
            img.save(iconset / f"icon_{points}x{points}{suffix}.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(OUTPUT)], check=True)
    print(f"Wrote {OUTPUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
