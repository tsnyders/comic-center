"""
Generate Android launcher icons from a source 1024x1024 image.
Resizes to all required mipmap densities (mdpi through xxxhdpi),
producing both ic_launcher.png (square with rounded corners) and
ic_launcher_round.png (circular mask).
"""

import sys
from pathlib import Path
from PIL import Image, ImageDraw

SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else None

ANDROID_RES = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "res"

SIZES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}


def make_round(img: Image.Image) -> Image.Image:
    """Apply a circular mask to the image."""
    size = img.size
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size[0], size[1]), fill=255)
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def make_rounded_square(img: Image.Image, radius_fraction: float = 0.22) -> Image.Image:
    """Apply rounded-corner mask (Android adaptive icon safe zone)."""
    size = img.size
    radius = int(size[0] * radius_fraction)
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def main():
    if not SOURCE or not SOURCE.exists():
        print(f"Usage: python {__file__} <source_1024x1024.png>")
        sys.exit(1)

    src = Image.open(SOURCE).convert("RGBA")
    print(f"Source: {SOURCE} ({src.size[0]}x{src.size[1]})")

    for folder, px in SIZES.items():
        out_dir = ANDROID_RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)

        resized = src.resize((px, px), Image.LANCZOS)

        # Square with rounded corners
        square = make_rounded_square(resized)
        square_path = out_dir / "ic_launcher.png"
        square.save(square_path, "PNG")
        print(f"  OK {square_path.relative_to(ANDROID_RES)}  ({px}x{px})")

        # Circular
        circle = make_round(resized)
        round_path = out_dir / "ic_launcher_round.png"
        circle.save(round_path, "PNG")
        print(f"  OK {round_path.relative_to(ANDROID_RES)}  ({px}x{px})")

    print("\nDone — all Android icons generated.")


if __name__ == "__main__":
    main()
