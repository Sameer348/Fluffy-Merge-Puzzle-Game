"""Resizes the rendered icon masters (build/icon_src) into every platform size.

  flutter test tool/icons/render_icons_test.dart
  python3 tool/icons/make_icons.py

Needs Pillow. Writes:
  * iOS AppIcon set (opaque RGB: App Store rejects alpha in app icons)
  * Android legacy mipmaps + adaptive icon layers (foreground/background/
    monochrome) for Android 8+, themed icons on 13+
  * store/google_play/icon_512.png and store/app_store/app_icon_1024.png
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'build', 'icon_src')


def load(name):
    return Image.open(os.path.join(SRC, name + '.png')).convert('RGBA')


def save(img, path, size, rgb=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if rgb:
        out = out.convert('RGB')
    out.save(path, optimize=True)


full = load('icon_full')
fg = load('adaptive_foreground')
bg = load('adaptive_background')
mono = load('adaptive_monochrome')

# --- iOS ---------------------------------------------------------------
ios = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
with open(os.path.join(ios, 'Contents.json')) as f:
    contents = json.load(f)
for img in contents['images']:
    pts = float(img['size'].split('x')[0])
    scale = int(img['scale'].rstrip('x'))
    save(full, os.path.join(ios, img['filename']), round(pts * scale), rgb=True)

# --- Android -------------------------------------------------------------
res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for d, k in densities.items():
    save(full, os.path.join(res, f'mipmap-{d}', 'ic_launcher.png'), round(48 * k))
    # Adaptive layers are 108 dp.
    for name, img in (('fg', fg), ('bg', bg), ('mono', mono)):
        save(img, os.path.join(res, f'mipmap-{d}', f'ic_launcher_{name}.png'), round(108 * k))

# --- Store listings --------------------------------------------------------
save(full, os.path.join(ROOT, 'store', 'google_play', 'icon_512.png'), 512)
save(full, os.path.join(ROOT, 'store', 'app_store', 'app_icon_1024.png'), 1024, rgb=True)
print('icons written')
