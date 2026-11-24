"""Captioned App Store screenshots: headline + subline over the game's sky,
with the real screen below in a rounded frame.

  python3 tool/store_assets/make_marketing_screens.py

Input:  store/app_store/{iphone_6_9,ipad_13}/  (raw screens)
Output: store/app_store/{iphone_6_9,ipad_13}_captioned/  (same sizes:
        1320 x 2868 and 2064 x 2752, no alpha, ready to upload)
Needs Pillow; uses the bundled Fredoka / Nunito fonts.
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, 'assets', 'fonts')

CAPTIONS = {
    '01_gameplay': ('Drop, merge & grow!', 'Two alike make one fluffier puff'),
    '02_home': ('Meet Fluffy!', 'A cozy puzzle full of plush friends'),
    '03_results': ('Chain combos', 'Big merges, big scores'),
    '04_collection': ('Collect all 12 puffs', 'From Tiny Puff to Rainbow Puff'),
    '05_daily': ('New goals every day', 'Daily challenges and a 7-day streak'),
    '06_shop': ('Power-ups & cute skins', 'Sweep, Pop, Grow, Shake and more'),
}

SKY = [(143, 200, 255), (203, 229, 255), (255, 226, 238)]  # AppColors sky
TITLE = (110, 58, 167)  # purple, like the logo
SUB = (94, 72, 84)


def gradient(w, h):
    img = Image.new('RGB', (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        a, b, u = (SKY[0], SKY[1], t / 0.55) if t < 0.55 else (SKY[1], SKY[2], (t - 0.55) / 0.45)
        c = tuple(round(a[i] + (b[i] - a[i]) * u) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def fit_font(draw, text, path, size, max_w):
    while True:
        f = ImageFont.truetype(path, size)
        if draw.textlength(text, font=f) <= max_w or size < 20:
            return f
        size -= 4


def compose(raw, title, sub, *, caption_h, shot_h, radius):
    w, h = raw.size
    canvas = gradient(w, h)
    draw = ImageDraw.Draw(canvas)
    pad = w * 0.07

    # Headline (white outline like the in-game popups) and subline.
    tf = fit_font(draw, title, os.path.join(FONTS, 'Fredoka-SemiBold.ttf'), int(w * (0.11 if h > w * 1.6 else 0.075)), w - 2 * pad)
    sf = fit_font(draw, sub, os.path.join(FONTS, 'Nunito-Bold.ttf'), int(w * (0.05 if h > w * 1.6 else 0.034)), w - 2 * pad)
    # Center the two lines in the caption band.
    ty = caption_h * 0.5 - sf.size * 0.75
    draw.text((w / 2, ty), title, font=tf, fill=TITLE, anchor='mm',
              stroke_width=max(4, int(tf.size * 0.09)), stroke_fill=(255, 255, 255))
    draw.text((w / 2, ty + tf.size * 0.95), sub, font=sf, fill=SUB, anchor='mm')

    # The screen, scaled into a rounded white frame with a soft shadow.
    sw = round(w * shot_h / h)
    shot = raw.resize((sw, shot_h), Image.LANCZOS)
    x0, y0 = (w - sw) // 2, caption_h
    border = max(10, w // 110)

    shadow = Image.new('L', (w, h), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x0 - border, y0 - border + 24, x0 + sw + border, y0 + shot_h + border + 24),
        radius + border, fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.paste((96, 70, 150), (0, 0), shadow)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((x0 - border, y0 - border, x0 + sw + border, y0 + shot_h + border),
                           radius + border, fill=(255, 255, 255))
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, shot_h - 1), radius, fill=255)
    canvas.paste(shot, (x0, y0), mask)
    return canvas


DEVICES = {
    # folder: (expected size, caption band height, screen height, corner radius)
    'iphone_6_9': ((1320, 2868), 640, 2140, 90),
    'ipad_13': ((2064, 2752), 560, 2090, 60),
}

for device, (size, caption_h, shot_h, radius) in DEVICES.items():
    src = os.path.join(ROOT, 'store', 'app_store', device)
    out = os.path.join(ROOT, 'store', 'app_store', device + '_captioned')
    os.makedirs(out, exist_ok=True)
    for name, (title, sub) in CAPTIONS.items():
        raw = Image.open(os.path.join(src, name + '.png')).convert('RGB')
        assert raw.size == size, (device, name, raw.size)
        img = compose(raw, title, sub, caption_h=caption_h, shot_h=shot_h, radius=radius)
        assert img.size == size and img.mode == 'RGB'
        img.save(os.path.join(out, name + '.png'), optimize=True)
    print(f'{device}: {len(CAPTIONS)} captioned screenshots -> {out}')
