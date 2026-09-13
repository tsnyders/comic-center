"""Build Android launcher icon resources for each look from assets/icon/yomi_icon_<look>.png.

Produces, per look:
  mipmap-{mdpi..xxxhdpi}/ic_launcher_<look>.png      legacy square icon
  mipmap-{mdpi..xxxhdpi}/ic_launcher_<look>_fg.png   adaptive foreground (108dp canvas)
  mipmap-anydpi-v26/ic_launcher_<look>.xml           adaptive icon (bg colour from colors.xml)
  drawable-{mdpi..xxxhdpi}/splash_<look>.png          launch-screen artwork (256dp canvas)
  drawable-{mdpi..xxxhdpi}/android12splash_<look>.png Android 12+ splash icon (same artwork)
  drawable/launch_background_<look>.xml               pre-12 launch window background

Run from the repo root:  python tool/make_look_icons.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
LOOKS = {
    'sumi': '#0B0B0A',
    'cinema': '#1C1917',
    'pastel': '#FBF6F3',
}
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
LEGACY_DP = 48
ADAPTIVE_DP = 108
# Artwork scale inside the 108dp adaptive canvas. The launcher mask shows the
# centre 72dp, so the source icon's own background colour must extend past it.
ART_SCALE = 0.80

SPLASH_DP = 256
SPLASH_ART = 176  # artwork size inside the 256dp splash canvas

LAUNCH_BG_XML = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/ic_launcher_{look}_bg"/>
    <item>
        <bitmap android:gravity="center" android:src="@drawable/splash_{look}"/>
    </item>
</layer-list>
'''

ADAPTIVE_XML = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_{look}_bg"/>
  <foreground android:drawable="@mipmap/ic_launcher_{look}_fg"/>
</adaptive-icon>
'''


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def main():
    for look, bg in LOOKS.items():
        src_path = ROOT / 'assets' / 'icon' / f'yomi_icon_{look}.png'
        src = Image.open(src_path).convert('RGBA')
        if src.size[0] != src.size[1]:
            side = min(src.size)
            left = (src.size[0] - side) // 2
            top = (src.size[1] - side) // 2
            src = src.crop((left, top, left + side, top + side))
        for density, scale in DENSITIES.items():
            d = RES / f'mipmap-{density}'
            d.mkdir(exist_ok=True)
            legacy = int(LEGACY_DP * scale)
            src.resize((legacy, legacy), Image.LANCZOS).save(
                d / f'ic_launcher_{look}.png', optimize=True)

            canvas_px = int(ADAPTIVE_DP * scale)
            art_px = int(canvas_px * ART_SCALE)
            fg = Image.new('RGBA', (canvas_px, canvas_px), hex_rgb(bg) + (255,))
            art = src.resize((art_px, art_px), Image.LANCZOS)
            off = (canvas_px - art_px) // 2
            fg.paste(art, (off, off), art)
            fg.save(d / f'ic_launcher_{look}_fg.png', optimize=True)
        (RES / 'mipmap-anydpi-v26' / f'ic_launcher_{look}.xml').write_text(
            ADAPTIVE_XML.format(look=look), encoding='utf-8')

        # Splash: the icon (its own background matches the window colour) on a
        # transparent 256dp canvas, so it reads as floating artwork.
        for density, scale in DENSITIES.items():
            d = RES / f'drawable-{density}'
            d.mkdir(exist_ok=True)
            canvas_px = int(SPLASH_DP * scale)
            art_px = int(SPLASH_ART * scale)
            img = Image.new('RGBA', (canvas_px, canvas_px), (0, 0, 0, 0))
            art = src.resize((art_px, art_px), Image.LANCZOS)
            off = (canvas_px - art_px) // 2
            img.paste(art, (off, off), art)
            img.save(d / f'splash_{look}.png', optimize=True)
            img.save(d / f'android12splash_{look}.png', optimize=True)
        (RES / 'drawable' / f'launch_background_{look}.xml').write_text(
            LAUNCH_BG_XML.format(look=look), encoding='utf-8')
        print('ok', look)


if __name__ == '__main__':
    main()
