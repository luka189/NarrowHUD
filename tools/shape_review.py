"""The review page for the rocks' stop boxes (3.0.13, luka: "render all the remaining ones to where I can eye them over
real quick, and exclude any others that are unsuitable").

    python3 tools/make_shapes.py --inner --review review.html [--census census.json] [--cache dir] <glb folders>
    python3 tools/shape_review.py --census census.json <narrowhud_ground.log ...>     # units of each kind on a map

make_shapes.py does the boxes as always and hands each kind here: thumb() draws it (side and top, the mesh shaded,
the stop boxes over it, a 1.8 m Helldiver beside it), Review collects the numbers and writes one HTML file from
tools/review_template.html — every kind a card, the doubtful first, a click leaves one out, and the list of those
goes back into tools/rock_skip.txt. A page over PAGE_MAX of pictures gets them in <page>_thumbs_N.js files beside it,
to be published with the page.
"""
import base64, glob, io, json, os, re, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, SS = 440, 200, 2                 # the picture, and the supersampling it is drawn at
MESH_LO, MESH_HI = 92, 214             # the mesh's greys (readable on a light and on a dark page)
BOX = (38, 118, 255)                   # the stop boxes fitted inside the solid
COVER = (20, 160, 90)                  # the boxes laid over a thin sheet (they may stand a little outside it)
MAN = (232, 120, 30)                   # the Helldiver for scale
AUTO_NOT = ('cave',)                   # names that never start on the outline fill
AUTO_GAIN = 0.15                       # outline covered: this much more by the outline fill makes it the first choice
PAGE_MAX = 9e6                         # bytes of pictures a page holds itself; past it they go into files beside it
THUMB_FILE = 5e6                       # bytes a pictures file
MAX_FACES = 60000                      # a panel draws at most this many triangles (the biggest, by area)


def _shade(tris):
    """A grey per triangle from its normal (light from the upper left, a little toward the viewer)."""
    n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    ln = np.linalg.norm(n, axis=1)
    ln[ln == 0] = 1
    n = n / ln[:, None]
    light = np.array([-0.45, -0.35, 0.82])
    d = np.abs(n @ light)
    return (MESH_LO + (MESH_HI - MESH_LO) * d).astype(int)


def _panel(draw, over, tris, shade, boxes, a, b, depth, far_first, sc, ox, oy):
    """One view: world axes a (right) and b (up), the triangles painted far to near."""
    if len(tris):
        key = tris[:, :, depth].mean(axis=1)
        order = np.argsort(-key if far_first else key)
        px = ox + tris[:, :, a] * sc
        py = oy - tris[:, :, b] * sc
        for i in order:
            g = int(shade[i])
            draw.polygon([(px[i, 0], py[i, 0]), (px[i, 1], py[i, 1]), (px[i, 2], py[i, 2])], fill=(g, g, g + 6, 255))
    for bx in boxes:
        x0, x1 = ox + bx[2 * a] * sc, ox + bx[2 * a + 1] * sc
        y0, y1 = oy - bx[2 * b + 1] * sc, oy - bx[2 * b] * sc
        over.rectangle([x0, y0, x1, y1], fill=BOX + (40,), outline=BOX + (255,), width=SS + 1)


def _hull(pts):
    """The convex hull of 2D points (monotone chain), counter-clockwise."""
    pts = sorted(set((round(float(x), 3), round(float(y), 3)) for x, y in pts))
    if len(pts) < 3:
        return pts
    def half(seq):
        h = []
        for p in seq:
            while len(h) >= 2 and (h[-1][0] - h[-2][0]) * (p[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (p[0] - h[-2][0]) <= 0:
                h.pop()
            h.append(p)
        return h
    lower, upper = half(pts), half(reversed(pts))
    return lower[:-1] + upper[:-1]


def obb_corners(o):
    """The 8 corners of a box turned about z: o = (cx, cy, cz, hx, hy, hz, yaw)."""
    cx, cy, cz, hx, hy, hz, yaw = o
    c, s_ = np.cos(yaw), np.sin(yaw)
    out = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                out.append((cx + c * sx * hx - s_ * sy * hy, cy + s_ * sx * hx + c * sy * hy, cz + sz * hz))
    return np.array(out)


def _obbs(over, obbs, a, b, sc, ox, oy):
    for o in obbs:
        k = obb_corners(o)
        poly = _hull([(ox + p[a] * sc, oy - p[b] * sc) for p in k])
        if len(poly) >= 3:
            over.polygon(poly, fill=COVER + (46,), outline=COVER + (255,))
            over.line(poly + [poly[0]], fill=COVER + (255,), width=SS + 1)


def thumb(groups, lo, hi, stop, obbs=()):
    """The kind's picture as WebP bytes: left the side view (its longer side across, z up, the ground line and a
    1.8 m Helldiver), right the top view (x right, y forward, the root a cross). One scale for both."""
    from PIL import Image, ImageDraw
    body = [g for g in groups if 'collision' not in g[1] and 'navigation' not in g[0]] or list(groups)
    tris = np.concatenate([g[2].vertices[g[2].faces] for g in body]) if body else np.zeros((0, 3, 3))
    if len(tris) > MAX_FACES:
        area = np.linalg.norm(np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0]), axis=1)
        tris = tris[np.argsort(-area)[:MAX_FACES]]
    shade = _shade(tris) if len(tris) else np.zeros(0, dtype=int)
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    for bx in stop:
        lo = np.minimum(lo, [bx[0], bx[2], bx[4]]); hi = np.maximum(hi, [bx[1], bx[3], bx[5]])
    a = 0 if (hi[0] - lo[0]) >= (hi[1] - lo[1]) else 1       # the side view's horizontal axis: the longer side
    d = 1 - a
    w, h = W * SS, H * SS
    pw, gap, pad = w * 0.5, 8 * SS, 10 * SS
    man_w = 1.1                                              # metres kept beside the mesh for the Helldiver
    z0, z1 = min(lo[2], 0.0), max(hi[2], 1.8)
    side_w, side_h = (hi[a] - lo[a]) + man_w, z1 - z0
    top_w, top_h = hi[0] - lo[0], hi[1] - lo[1]
    sc = min((pw - 2 * pad) / max(side_w, 1e-6), (h - 2 * pad) / max(side_h, 1e-6),
             (pw - 2 * pad - gap) / max(top_w, 1e-6), (h - 2 * pad) / max(top_h, 1e-6))
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    over = ImageDraw.Draw(layer)
    # the side view, centred in the left half, the ground at z = 0
    ox = pad + ((pw - 2 * pad) - side_w * sc) / 2 - lo[a] * sc + man_w * sc
    oy = h - pad - ((h - 2 * pad) - side_h * sc) / 2 + z0 * sc
    _panel(draw, over, tris, shade, stop, a, 2, d, True, sc, ox, oy)
    _obbs(over, obbs, a, 2, sc, ox, oy)
    gy = oy
    for x in range(int(pad), int(pw - pad), 12 * SS):
        over.line([x, gy, x + 6 * SS, gy], fill=(128, 134, 144, 255), width=SS)
    # the Helldiver, 1.8 m, left of the mesh
    mx = ox + (lo[a] - man_w * 0.55) * sc
    r = 0.13 * sc
    over.ellipse([mx - r, oy - 1.8 * sc, mx + r, oy - 1.8 * sc + 2 * r], fill=MAN + (255,))
    over.rounded_rectangle([mx - 0.2 * sc, oy - 1.5 * sc, mx + 0.2 * sc, oy], radius=max(1, 0.08 * sc), fill=MAN + (255,))
    # the top view, centred in the right half
    ox2 = pw + gap + ((pw - 2 * pad - gap) - top_w * sc) / 2 - lo[0] * sc
    oy2 = h - pad - ((h - 2 * pad) - top_h * sc) / 2 + lo[1] * sc
    _panel(draw, over, tris, shade, stop, 0, 1, 2, False, sc, ox2, oy2)
    _obbs(over, obbs, 0, 1, sc, ox2, oy2)
    c = 5 * SS
    over.line([ox2 - c, oy2, ox2 + c, oy2], fill=MAN + (255,), width=SS)
    over.line([ox2, oy2 - c, ox2, oy2 + c], fill=MAN + (255,), width=SS)
    img = Image.alpha_composite(img, layer).resize((W, H), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, 'WEBP', quality=72, method=4)
    return buf.getvalue()


class Review:
    def __init__(self, census=None):
        self.kinds = []
        self.census = json.load(open(census)) if census else {}

    def add(self, h, r, why):
        lo, hi = np.asarray(r['lo'], float), np.asarray(r['hi'], float)
        info = r.get('info') or {}
        cp = r.get('cp') or ''
        self.kinds.append(dict(
            h=h, name=r['name'], folder=os.path.dirname(cp).replace('content/', '', 1),
            size=[round(float(x), 2) for x in (hi - lo)], low=round(float(lo[2]), 2), high=round(float(hi[2]), 2),
            boxes=len(r['stop']), cover=round(float(info.get('cover', 0)), 3), fill=round(float(info.get('fill', 1)), 3),
            reach=round(float(max([info.get('reach', 0)] + [o[2] + o[5] for o in (r.get('over') or ())])), 2), src=info.get('source', ''), air=round(float(info.get('air', 0)), 3),
            # (the research log's count of the kind's units listed, by name, where there is one: the ground
            # census counts its samples, several a unit)
            why=why, n=self.census.get(r['name'], self.census.get(h, 0)),
            plates=int(info.get('plates', 0)), over=len(r.get('over') or ()), seen0=round(float(info.get('seen_inside', 0)), 3),
            seen=round(float(info.get('seen', 0)), 3), spill=round(float(info.get('spill', 0)), 3),
            img='data:image/webp;base64,' + base64.b64encode(r['thumb']).decode() if r.get('thumb') else ''))
        def other(stop, over, w, thumb):
            d = dict(boxes=len(stop), cover=round(float(w.get('cover', 0)), 3),
                     reach=round(float(max([w.get('reach', 0)] + [o[2] + o[5] for o in over])), 2),
                     img='data:image/webp;base64,' + base64.b64encode(thumb).decode() if thumb else '')
            if 'seen' in w:              # (a result from before 3.0.16 has no outline numbers for its whole fill: the page shows the kind's own)
                d.update(over=len(over), plates=int(w.get('plates', 0)), seen0=round(float(w.get('seen_inside', 0)), 3),
                         seen=round(float(w.get('seen', 0)), 3), spill=round(float(w.get('spill', 0)), 3))
            return d
        if r.get('stop_whole'):                 # (the whole fill, where the kind is open underneath as modelled)
            self.kinds[-1]['whole'] = other(r['stop_whole'], r.get('over_whole') or [], r.get('info_whole') or {}, r.get('thumb_whole'))
        if r.get('stop_hull') or r.get('over_hull'):      # (the outline fill: a ruined building or a car as one block)
            u = r.get('info_hull') or {}
            self.kinds[-1]['hull'] = other(r.get('stop_hull') or [], r.get('over_hull') or [], u, r.get('thumb_hull'))
            # (the page's first choice for a new kind: mostly air as modelled, or the outline's boxes stand in front of
            # AUTO_GAIN more of the thing than the modelled solid's do — a ruin whose walls still enclose half its volume)
            auto = u.get('auto') or float(u.get('seen', 0)) - float(info.get('seen', 0)) >= AUTO_GAIN
            # (not a cave's piece: a tunnel or a cavern's roof filled by its outline is the cave filled in)
            self.kinds[-1]['hull']['auto'] = 1 if auto and not any(w in r['name'] for w in AUTO_NOT) else 0
            self.kinds[-1]['hull']['share'] = round(float(u.get('share', 0)), 2)

    def write(self, out, reach_min, skip, reviewed=()):
        """reviewed: the hashes luka has been through; with any, every other kind is marked new and the page opens on
        those (`round` changes when the set of new kinds does, which is what resets the page's filter once)."""
        page = open(os.path.join(HERE, 'review_template.html'), encoding='utf-8').read()
        fresh = 0
        for k in self.kinds:
            if reviewed and k['h'] not in reviewed:
                k['new'] = 1
                fresh += 1
        data = dict(kinds=sorted(self.kinds, key=lambda k: k['name']), reach=reach_min,
                    skip=sorted(skip), census=bool(self.census), round='%d+%d' % (len(self.kinds) - fresh, fresh) if fresh else '')
        # A page may be 16 MB where it is published, and a kind's pictures are about 17 KB: past PAGE_MAX the pictures
        # go into script files beside the page (<page>_thumbs_N.js, THUMB_FILE bytes each), which it loads after
        # its first drawing. The files of an earlier, longer run are removed.
        stem = os.path.splitext(out)[0]
        for old in glob.glob(glob.escape(stem) + '_thumbs_*.js'):
            os.remove(old)
        files = []
        if sum(len(k.get('img') or '') + sum(len((k.get(w) or {}).get('img') or '') for w in ('whole', 'hull')) for k in data['kinds']) > PAGE_MAX:
            part, size = {}, 0
            def flush():
                nonlocal part, size
                if part:
                    name = '%s_thumbs_%d.js' % (os.path.basename(stem), len(files))
                    with open(os.path.join(os.path.dirname(out), name), 'w', encoding='utf-8') as f:
                        f.write('window.THUMBS=Object.assign(window.THUMBS||{},' + json.dumps(part, separators=(',', ':')) + ');window.onThumbs&&window.onThumbs();')
                    files.append(name)
                part, size = {}, 0
            # (the new kinds first: theirs are the pictures looked at)
            for k in sorted(data['kinds'], key=lambda k: (not k.get('new'), k['name'])):
                for key, holder in ((k['h'], k), (k['h'] + 'w', k.get('whole')), (k['h'] + 'u', k.get('hull'))):
                    if holder and holder.get('img'):
                        part[key] = holder['img']; size += len(holder['img'])
                        holder['img'] = ''
                if size > THUMB_FILE:
                    flush()
            flush()
        data['thumbs'] = files
        page = page.replace('"__DATA__"', json.dumps(data, separators=(',', ':')).replace('</', '<\\/'))
        with open(out, 'w', encoding='utf-8') as f:
            f.write(page)
        return files


def census(logs, out):
    """{ hash or name: the most units of that kind any one of the logs' maps had } from the ground logs' census lines
    and the research logs' "rocks:" lines."""
    most = {}
    for path in logs:
        seen = {}
        for line in open(path, errors='replace'):
            # (the research log's own list of the rocks it has listed, by name: "research: rocks: 1275 listed of 40
            # kinds: log_large_01 x18; ...")
            if 'research: rocks:' in line:
                for m in re.finditer(r'([A-Za-z0-9_]+) x(\d+)', line.split('kinds:', 1)[-1]):
                    seen[m.group(1)] = max(seen.get(m.group(1), 0), int(m.group(2)))
            if 'census: ground kinds:' not in line:
                continue
            for m in re.finditer(r'([0-9a-f]{16}) x(\d+) in \d+ cells', line):
                seen[m.group(1)] = max(seen.get(m.group(1), 0), int(m.group(2)))
        for k, v in seen.items():
            most[k] = max(most.get(k, 0), v)
    json.dump(most, open(out, 'w'), indent=0, sort_keys=True)
    print('wrote', out, len(most), 'kinds from', len(logs), 'logs')


if __name__ == '__main__':
    if len(sys.argv) > 3 and sys.argv[1] == '--census':
        census(sys.argv[3:], sys.argv[2])
    else:
        print(__doc__)
