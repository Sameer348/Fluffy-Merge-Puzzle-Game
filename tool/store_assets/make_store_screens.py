"""Assembles store screenshot sets from the rendered screens.

  flutter test tool/store_assets/screenshots_test.dart
  python3 tool/store_assets/make_store_screens.py

Writes:
  store/app_store/iphone_6_9/  1320 x 2868  (App Store 6.9" iPhone)
  store/app_store/ipad_13/     2064 x 2752  (App Store 13" iPad)
  store/google_play/phone/     1080 x 2160  (Play phone, max 2:1)
  store/google_play/tablet/    2064 x 2752  (Play 10" tablet)
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'build', 'store_screens')
OUT = os.path.join(ROOT, 'store')

# Store order: the first two or three are what most people see.
ORDER = [
    ('01_gameplay', '02_gameplay'),
    ('02_home', '01_home'),
    ('03_results', '05_results'),
    ('04_collection', '06_collection'),
    ('05_daily', '07_daily'),
    ('06_shop', '08_shop'),
]


def out_dir(*parts):
    d = os.path.join(OUT, *parts)
    os.makedirs(d, exist_ok=True)
    return d


ios_phone = out_dir('app_store', 'iphone_6_9')
ios_pad = out_dir('app_store', 'ipad_13')
play_phone = out_dir('google_play', 'phone')
play_tablet = out_dir('google_play', 'tablet')

for name, src in ORDER:
    phone = Image.open(os.path.join(SRC, 'iphone_6_9', src + '.png')).convert('RGB')
    pad = Image.open(os.path.join(SRC, 'ipad_13', src + '.png')).convert('RGB')
    assert phone.size == (1320, 2868), phone.size
    assert pad.size == (2064, 2752), pad.size
    phone.save(os.path.join(ios_phone, name + '.png'), optimize=True)
    pad.save(os.path.join(ios_pad, name + '.png'), optimize=True)
    pad.save(os.path.join(play_tablet, name + '.png'), optimize=True)
    # Play allows at most 2:1: trim equal strips top and bottom, then scale.
    w, h = phone.size
    trim = (h - w * 2) // 2
    phone.crop((0, trim, w, h - trim)).resize((1080, 2160), Image.LANCZOS).save(
        os.path.join(play_phone, name + '.png'), optimize=True
    )

print(f'{len(ORDER)} screenshots per device -> {OUT}')
