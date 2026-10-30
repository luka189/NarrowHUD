#!/usr/bin/env python3
"""Cut the middle of a screenshot out, for the Nexus images.

    python3 tools/crop_centre.py shot.png                 -> shot_crop.png, the middle 1400x800
    python3 tools/crop_centre.py shot.png --size 1600x900
    python3 tools/crop_centre.py shot.png --shift 0,120   -> the window 120 px lower (x,y; up and left negative)
    python3 tools/crop_centre.py *.png --out nexus/       -> every file into a folder, same names

Any screenshot size works (3440x1440, 2560x1440, ...): the window is centred on the screen's centre, which is
where the crosshair and the HUD sit. Needs Pillow (pip install pillow).
"""
import argparse
import glob
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit('needs Pillow for this Python (%s): %s -m pip install pillow' % (sys.executable, sys.executable))


def crop(path, size, shift, out_dir):
    try:
        im = Image.open(path)
    except Exception as e:
        print('%s skipped: %s' % (path, e))
        return
    w, h = im.size
    cw, ch = size
    if cw > w or ch > h:
        print('%s skipped: %dx%d, smaller than the %dx%d window' % (path, w, h, cw, ch))
        return
    x = (w - cw) // 2 + shift[0]
    y = (h - ch) // 2 + shift[1]
    x = max(0, min(x, w - cw))
    y = max(0, min(y, h - ch))
    out = im.crop((x, y, x + cw, y + ch))
    base, ext = os.path.splitext(os.path.basename(path))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        dest = os.path.join(out_dir, base + ext)
    else:
        dest = os.path.join(os.path.dirname(path), base + '_crop' + ext)
    if ext.lower() in ('.jpg', '.jpeg'):
        out.save(dest, quality=95)
    else:
        out.save(dest)
    print('%s -> %s (%dx%d at %d,%d of %dx%d)' % (path, dest, cw, ch, x, y, w, h))


def pair(s, sep):
    a, b = s.lower().split(sep)
    return int(a), int(b)


def main():
    p = argparse.ArgumentParser(description='cut the middle WxH out of screenshots')
    p.add_argument('files', nargs='+')
    p.add_argument('--size', default='1400x800', help='window, WxH (default 1400x800)')
    p.add_argument('--shift', default='0,0', help='move the window by x,y pixels (default 0,0)')
    p.add_argument('--out', default=None, help='folder for the crops (default: next to each file, _crop added)')
    a = p.parse_args()
    size = pair(a.size, 'x')
    shift = pair(a.shift, ',')
    files = []
    for f in a.files:   # PowerShell and cmd hand "*.png" over as written
        files += sorted(glob.glob(f)) if any(c in f for c in '*?[') else [f]
    if not files:
        sys.exit('no files match')
    for f in files:
        crop(f, size, shift, a.out)


if __name__ == '__main__':
    main()
