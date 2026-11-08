"""NarrowHUD's ground pictures (2.4.8): the blast zone, its outer ring and the landing pin, painted on the ground by
the game's projected-decal unit (12_decal). Our own pictures, drawn here: RGBA, the colour baked in (the decal's
material takes a picture, not a tint), anti-aliased by supersampling. Shipped by tools/make_textures.py in the game's
icon layout (BC3, every mip level).

    python3 tools/decal_art.py      # writes previews to build/decals/*.png (make_textures.py calls pictures())
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SIZE = 512
CREAM, RED, GREY, DARK = (236, 229, 206), (226, 74, 64), (150, 150, 150), (0, 0, 0)   # (GREY 2.6.1: a dud's pin)


def _radius(size, ss):
    n = size * ss
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2
    return np.hypot(x - c, y - c) / (n / 2), np.arctan2(y - c, x - c)


def _band(r, a, b, soft):
    """1 inside [a, b] of the radius (0 at the centre, 1 at the edge), soft edges `soft` wide"""
    return np.clip((r - a) / soft + 0.5, 0, 1) * np.clip((b - r) / soft + 0.5, 0, 1)


def _out(layers, size, ss):
    """layers: (rgb, alpha (n, n)) bottom first, composited over transparency, then shrunk by ss"""
    n = size * ss
    rgb = np.zeros((n, n, 3), np.float32)
    al = np.zeros((n, n), np.float32)
    for col, a in layers:
        c = np.array(col, np.float32) / 255
        rgb = rgb * (1 - a[..., None]) * al[..., None] + c * a[..., None]
        al = a + al * (1 - a)
        rgb = np.where(al[..., None] > 1e-6, rgb / np.maximum(al[..., None], 1e-6), 0)
    img = np.dstack([rgb * 255, al * 255]).clip(0, 255).astype(np.uint8)
    return np.array(Image.fromarray(img, 'RGBA').resize((size, size), Image.LANCZOS))


def zone(col, size=SIZE, ss=3):
    """the full-damage radius: a faint fill rising toward a bright rim, a dark edge outside it for contrast"""
    r, _ = _radius(size, ss)
    soft = 0.006
    fill = np.where(r < 0.955, 0.10 + 0.12 * np.clip(r / 0.955, 0, 1) ** 3, 0) * _band(r, -1, 0.955, soft)
    rim = _band(r, 0.925, 0.965, soft) * 0.95
    edge = _band(r, 0.965, 0.99, soft) * 0.45
    return _out([(col, fill), (DARK, edge), (col, rim)], size, ss)


def ring(col, size=SIZE, ss=3, dashes=36):
    """the outer radius (where the blast still hurts): a thin dashed ring, a fainter dark edge"""
    r, t = _radius(size, ss)
    soft = 0.006
    phase = (t / (2 * np.pi) * dashes) % 1
    dash = np.clip((0.62 - np.abs(phase - 0.31) * 2) / 0.04 + 0.5, 0, 1)   # (on 62 % of each step, soft ends)
    rim = _band(r, 0.95, 0.975, soft) * 0.75 * dash
    edge = _band(r, 0.975, 0.995, soft) * 0.30 * dash
    return _out([(DARK, edge), (col, rim)], size, ss)


def pin(col, size=256, ss=4):
    """the landing point: a ring, four short ticks pointing in, a dot, all with a dark edge"""
    r, t = _radius(size, ss)
    soft = 0.012
    ring_ = _band(r, 0.70, 0.82, soft)
    ang = (t / (np.pi / 2)) % 1
    ticks = _band(r, 0.42, 0.62, soft) * np.clip((0.06 - np.minimum(ang, 1 - ang)) / 0.02 + 0.5, 0, 1)
    dot = _band(r, -1, 0.14, soft)
    shape = np.maximum(np.maximum(ring_, ticks), dot)
    # the dark edge: the shape grown a little
    grown = np.maximum(np.maximum(_band(r, 0.64, 0.88, soft), _band(r, -1, 0.20, soft)),
                       _band(r, 0.36, 0.66, soft) * np.clip((0.10 - np.minimum(ang, 1 - ang)) / 0.02 + 0.5, 0, 1))
    return _out([(DARK, grown * 0.55), (col, shape * 0.97)], size, ss)


def pictures():
    """name -> RGBA array: the pictures the decals use"""
    return {
        'zone_cream': zone(CREAM), 'zone_red': zone(RED),
        'ring_cream': ring(CREAM), 'ring_red': ring(RED),
        'pin_cream': pin(CREAM), 'pin_red': pin(RED), 'pin_grey': pin(GREY),
    }


if __name__ == '__main__':
    out = ROOT / 'build' / 'decals'
    out.mkdir(parents=True, exist_ok=True)
    for name, img in pictures().items():
        Image.fromarray(img, 'RGBA').save(out / f'{name}.png')
        print(name, img.shape)
