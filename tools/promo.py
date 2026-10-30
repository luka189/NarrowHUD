#!/usr/bin/env python3
"""The Nexus images for 2.0 from luka189's screenshots (2026-10-30).

    python3 tools/promo.py <folder with the screenshots> [--out art/promo]

The folder holds the 1400x800 crops (crop_centre.py) and a "Whole screen" subfolder with the 3440x1440 originals
of the action shots. Writes main_tile.jpg (1920x1080), banner.jpg (1300x372), layouts.jpg, sizes.jpg, spread.jpg, heat.jpg,
drop.jpg and hero_*.jpg. Needs Pillow and the Inter fonts (/usr/share/fonts/opentype/inter).
"""
import argparse
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = '/usr/share/fonts/opentype/inter/'
BG = (1, 33, 48)          # the logo's blue
CREAM = (255, 255, 255)
DIM = (190, 205, 215)


def font(n, w='Bold'):
    return ImageFont.truetype(FONTS + 'Inter-%s.otf' % w, n)


def logo_mark(h):
    """the white mark of art/logo.png on transparent, h px tall"""
    im = Image.open(os.path.join(HERE, '..', 'art', 'logo.png')).convert('RGB')
    a = im.convert('L').point(lambda v: 255 if v > 120 else 0)
    bx = a.getbbox()
    a = a.crop(bx)
    k = h / a.height
    a = a.resize((max(1, int(a.width * k)), h), Image.LANCZOS)
    out = Image.new('RGBA', a.size, CREAM + (0,))
    out.putalpha(a)
    return out


def gradient(size, side, strength=0.82, span=0.55):
    """an RGBA black gradient over one side ('top', 'left', 'bottom', 'right') of an image, span = its share"""
    w, h = size
    g = Image.new('L', size, 0)
    px = g.load()
    n = int((h if side in ('top', 'bottom') else w) * span)
    for i in range(n):
        t = 1 - i / n
        v = int(255 * strength * t * t)
        if side == 'top':
            for x in range(w): px[x, i] = v
        elif side == 'bottom':
            for x in range(w): px[x, h - 1 - i] = v
        elif side == 'left':
            for y in range(h): px[i, y] = v
        else:
            for y in range(h): px[w - 1 - i, y] = v
    black = Image.new('RGBA', size, (0, 0, 0, 255))
    black.putalpha(g)
    return black


def shadow_text(d, xy, text, f, fill=CREAM, blur=0):
    x, y = xy
    d.text((x + 2, y + 2), text, font=f, fill=(0, 0, 0))
    d.text((x, y), text, font=f, fill=fill)


def wordmark(im, x, y, big=118, small=30, tagline=None, mark=96):
    """the logo mark, "NarrowHUD" and a tagline, drawn onto im at x, y (top-left)"""
    m = logo_mark(mark)
    im.alpha_composite(m, (x, y + (big - mark) // 2 + 8))
    d = ImageDraw.Draw(im)
    tx = x + m.width + 26
    shadow_text(d, (tx, y), 'NarrowHUD', font(big))
    if tagline:
        shadow_text(d, (tx + 4, y + big + 16), tagline, font(small, 'SemiBold'), DIM)
    return tx


def upscale_crop(src, cx, cy, cw, ch, size):
    """cw x ch of src around cx, cy (clamped), resized to size"""
    w, h = src.size
    x0 = max(0, min(cx - cw // 2, w - cw))
    y0 = max(0, min(cy - ch // 2, h - ch))
    return src.crop((x0, y0, x0 + cw, y0 + ch)).resize(size, Image.LANCZOS)


def tile(folder, out):
    """1920x1080: the arcs in the firefight, 1.5x so the HUD reads at thumbnail size; the wordmark top-left"""
    src = Image.open(os.path.join(folder, 'Whole screen', '20261030211251_1.jpg')).convert('RGB')
    W, H = 1920, 1080
    im = upscale_crop(src, 1720 + 20, 720 + 40, 1280, 720, (W, H)).convert('RGBA')
    im.alpha_composite(gradient((W, H), 'top', 0.66, 0.5))
    im.alpha_composite(gradient((W, H), 'left', 0.45, 0.45))
    wordmark(im, 72, 54, big=132, small=36, tagline='Ammo, heat and vitals, right at the crosshair.', mark=104)
    d = ImageDraw.Draw(im)
    f = font(30, 'SemiBold')
    line = '2.0  ·  four layouts  ·  a layout editor  ·  drop lines  ·  your colours'
    tw = d.textlength(line, font=f)
    shadow_text(d, (W - tw - 64, H - 70), line, f, DIM)
    im.convert('RGB').save(os.path.join(out, 'main_tile.jpg'), quality=94)


def banner(folder, out):
    """1300x372, the Nexus page header: a strip of the firefight at full resolution, the arcs on the right, the
    wordmark left. (Nexus writes the mod's name and counts over the lower-left: the wordmark sits in the upper half.)"""
    src = Image.open(os.path.join(folder, 'Whole screen', '20261030211251_1.jpg')).convert('RGB')
    W, H = 1300, 372
    x0, y0 = 716, 556             # the crosshair (1720, 720) lands at (1004, 164); the arcs span 740-1270
    im = src.crop((x0, y0, x0 + W, y0 + H)).convert('RGBA')
    im.alpha_composite(gradient((W, H), 'left', 0.96, 0.5))
    im.alpha_composite(gradient((W, H), 'top', 0.3, 0.4))
    wordmark(im, 40, 40, big=84, small=25, tagline='Ammo, heat and vitals at the crosshair.', mark=68)
    im.convert('RGB').save(os.path.join(out, 'banner.jpg'), quality=94)


def labelled(frames, cols, out_path, cell=(700, 400), label_h=52, gap=8, title=None):
    """a grid of (label, image) pairs, each image a 1400x800 crop scaled to cell; labels in a strip under each"""
    cw, ch = cell
    rows = (len(frames) + cols - 1) // cols
    th = 0 if title is None else 84
    W = cols * cw + (cols + 1) * gap
    H = th + rows * (ch + label_h) + (rows + 1) * gap
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im)
    if title:
        d.text((gap + 8, 22), title, font=font(40), fill=CREAM)
    for i, (label, src) in enumerate(frames):
        x = gap + (i % cols) * (cw + gap)
        y = th + gap + (i // cols) * (ch + label_h + gap)
        im.paste(src.resize((cw, ch), Image.LANCZOS), (x, y))
        d.text((x + 10, y + ch + 12), label, font=font(28, 'SemiBold'), fill=CREAM)
    im.save(out_path, quality=92)
    return im.size


def zoom(src, cx, cy, cw, ch):
    """a closer window of a 1400x800 crop, same aspect as the cell (7:4)"""
    return upscale_crop(src, cx, cy, cw, ch, (1400, 800))


def comparisons(folder, out):
    sh = lambda n: Image.open(os.path.join(folder, '20261030%s_1.jpg' % n)).convert('RGB')
    # the four layouts, the same spot: Horizontal, Arcs, Vertical pair, Block (closer, 1050x600 of each)
    layouts = [('1  Horizontal', zoom(sh('215225'), 740, 400, 1050, 600)),
               ('2  Arcs', zoom(sh('215259'), 700, 400, 1050, 600)),
               ('3  Vertical pair', zoom(sh('215241'), 700, 400, 1050, 600)),
               ('4  Block', zoom(sh('215033'), 740, 400, 1050, 600))]
    print('layouts.jpg', labelled(layouts, 2, os.path.join(out, 'layouts.jpg'), title='Four layouts. Or make your own in the editor.'))
    # sizes: the Block at Small, Medium, Large and Huge (the same spot)
    sizes = [('Small', zoom(sh('214957'), 910, 400, 700, 400)),
             ('Medium', zoom(sh('215008'), 910, 400, 700, 400)),
             ('Large', zoom(sh('215033'), 910, 400, 700, 400)),
             ('Huge', zoom(sh('215050'), 910, 400, 700, 400))]
    print('sizes.jpg', labelled(sizes, 4, os.path.join(out, 'sizes.jpg'), cell=(490, 280), title='Four sizes, the Block layout.'))
    # spread: the same layout pulled in or pushed apart (the Spread slider; it can change while you aim)
    spread = [('Arcs, pulled in', zoom(sh('215259'), 700, 400, 1050, 600)),
              ('Arcs, pushed apart', zoom(sh('215304'), 700, 400, 1050, 600)),
              ('Vertical pair, pulled in', zoom(sh('215333'), 700, 400, 1050, 600)),
              ('Vertical pair, pushed apart', zoom(sh('215331'), 700, 400, 1050, 600))]
    print('spread.jpg', labelled(spread, 2, os.path.join(out, 'spread.jpg'), title='Spread: pulled in or pushed apart. It can open while you aim.'))
    # heat and charge: the flamethrower at 80% and 93% (the orange is the warning)
    heat = [('Heat at 80%', zoom(sh('215726'), 700, 420, 1050, 600)),
            ('Heat at 93%: the arc turns', zoom(sh('215728'), 700, 420, 1050, 600))]
    print('heat.jpg', labelled(heat, 2, os.path.join(out, 'heat.jpg'), title='Heat, charge and lock-on, where you look.'))
    # the drop line: the grenade's arc from the crosshair (215621 / 215614)
    drop = [('Throwing: the grenade\'s arc', zoom(sh('215621'), 700, 400, 1050, 600)),
            ('Firing a launcher: the round\'s drop', zoom(sh('215614'), 700, 400, 1050, 600))]
    print('drop.jpg', labelled(drop, 2, os.path.join(out, 'drop.jpg'), title='Drop lines, measured from the game\'s throws.'))
    # heroes, as they are
    for name, n in [('hero_arcs', '211251'), ('hero_forest', '211830'), ('hero_block', '211940'), ('hero_shore', '215611')]:
        sh(n).save(os.path.join(out, name + '.jpg'), quality=92)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('folder')
    p.add_argument('--out', default=os.path.join(HERE, '..', 'art', 'promo'))
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    tile(a.folder, a.out)
    banner(a.folder, a.out)
    comparisons(a.folder, a.out)
    print('done ->', a.out)


if __name__ == '__main__':
    main()
