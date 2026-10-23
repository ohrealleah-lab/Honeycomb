#!/usr/bin/env python3
"""Build every Honeycomb app icon from the single 1024 px master image.

The master (mac/images/icon/AppIcon-1024.png) is the only icon source. From it:
  - mac/src/AppIcon.icns                                 (rounded white tile, all sizes)
  - ios/Honeycomb/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
                                                         (full white square, no alpha; iOS masks it)
  - windows/src/SoliBee.Desktop/Assets/AppIcon.ico       (rounded white tile, 16-256 px)
  - windows/src/SoliBee.Desktop/Assets/AppIcon.png       (bee on transparent, 512 px)
Run after editing the master:

    python3 tools/generate_app_icons.py
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

REPO = Path(__file__).resolve().parent.parent
MASTER = REPO / "mac/images/icon/AppIcon-1024.png"
MAC_ICNS = REPO / "mac/src/AppIcon.icns"
IOS_PNG = REPO / "ios/Honeycomb/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
WIN_ICO = REPO / "windows/src/SoliBee.Desktop/Assets/AppIcon.ico"
WIN_PNG = REPO / "windows/src/SoliBee.Desktop/Assets/AppIcon.png"

# (point size, scale) pairs macOS expects in an app icon.
MAC_SIZES = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
             (256, 1), (256, 2), (512, 1), (512, 2)]
WIN_ICO_SIZES = [16, 32, 48, 64, 128, 256]
WIN_CORNER_RADIUS = 0.2  # fraction of the icon's width

# The Mac tile's rim and shadow sit in the outer edge of the master; the art is
# well inside this inset, so the art is only looked for within it.
ART_INSET = 0.06


def ink_mask(master):
    """Darkness of the black-on-white art as an alpha mask, tile rim excluded."""
    # Flatten onto white first so the tile's transparent corners don't read as ink.
    flat = Image.alpha_composite(Image.new("RGBA", master.size, (255, 255, 255, 255)), master)
    ink = ImageChops.invert(flat.convert("L"))
    inset = round(master.width * ART_INSET)
    inner = (inset, inset, master.width - inset, master.height - inset)
    # The rim curves inward at the corners, so keep only the solid art's bounding box.
    solid = ink.crop(inner).point(lambda v: 255 if v > 128 else 0).getbbox()
    pad = 8
    box = (inner[0] + solid[0] - pad, inner[1] + solid[1] - pad,
           inner[0] + solid[2] + pad, inner[1] + solid[3] + pad)
    mask = Image.new("L", master.size, 0)
    mask.paste(ink.crop(box), box[:2])
    return mask


def build_mac(master):
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for points, scale in MAC_SIZES:
            px = points * scale
            suffix = "@2x" if scale == 2 else ""
            img = master if px == 1024 else master.resize((px, px), Image.LANCZOS)
            img.save(iconset / f"icon_{points}x{points}{suffix}.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(MAC_ICNS)], check=True)


def main():
    master = Image.open(MASTER).convert("RGBA")
    if master.size != (1024, 1024):
        raise SystemExit(f"{MASTER} must be 1024x1024, got {master.size}")
    build_mac(master)

    mask = ink_mask(master)
    white = Image.new("RGB", master.size, (255, 255, 255))
    on_white = Image.composite(Image.new("RGB", master.size, (0, 0, 0)), white, mask)
    on_white.save(IOS_PNG)

    # Windows gets a clean rounded white tile (no Mac shadow), drawn 4x and
    # downsampled for smooth corners.
    big = master.width * 4
    corners = Image.new("L", (big, big), 0)
    ImageDraw.Draw(corners).rounded_rectangle((0, 0, big - 1, big - 1),
                                              radius=round(big * WIN_CORNER_RADIUS), fill=255)
    tile = on_white.convert("RGBA")
    tile.putalpha(corners.resize(master.size, Image.LANCZOS))
    tile.save(WIN_ICO, sizes=[(s, s) for s in WIN_ICO_SIZES])

    transparent = Image.new("RGBA", master.size, (0, 0, 0, 0))
    transparent.putalpha(mask)
    transparent.resize((512, 512), Image.LANCZOS).save(WIN_PNG)

    for path in (MAC_ICNS, IOS_PNG, WIN_ICO, WIN_PNG):
        print(f"Wrote {path.relative_to(REPO)}")


if __name__ == "__main__":
    main()
