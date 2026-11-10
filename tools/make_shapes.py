#!/usr/bin/env python3
"""The structures' shapes from their meshes (2.5.18, luka's idea: "extract the models and fit boxes in peace").

Input: unit meshes exported by filediver (BSD; credited in the README) as .glb, with --model-include-lods so the
collision groups come along:
    filediver -T unit --model-format glb --model-include-lods -i "<hash or path>" -o shapes
Output: src/struct_parts_generated.lua — for each kind, the boxes the red mark tests, in metres from the unit's
root (hx, hy, hz, cx, cy, cz in the unit's frame: right, forward, up; the layout file's struct_parts block takes
fractions of the engine box instead) — and a picture per kind in research/shapes/ with the boxes drawn over the
mesh's three views, for the eye. The engine box matters only as a check (the mesh must sit in the engine's frame).

How: the LOD0 mesh goes into the game's frame (glTF is y-up: game x = x, game y = -z, game z = y), is voxelised
at 25 cm, and each horizontal slice is read as a map: the mesh is a shell, so the enclosed empty regions of a
slice are either the thing's inside (solid) or a tunnel. The tunnel of a bug hole is the enclosed region at the
bottom that, followed upward slice by slice, opens to the outside at the lip — that's the cavity ("the shot goes
in", a `hit` box), and the mouth above it gets 1.5 m more of the same footprint. Every other enclosed region and
the shell itself are solid (`stop` boxes: the line ends there, no red). The boxes: the solid and the cavity are
cut into z-bands wherever the band's footprint changes by more than BAND m, one box (the band's footprint) each.
Kinds with a collision group (material m_collision: rocks) use its smallest mesh as the solid, filled.

The frame check: the mesh's bounding box must match the engine's (the research log's "structure box" line) — the
tool prints both when given --engine 'kind=hx,hy,hz' and refuses a kind that doesn't fit within 0.3 m.

The rocks (3.0.4, luka: "lines stop on rocks, walls and trunks"): --inner. The same exports, by the folder:
    python3 tools/make_shapes.py --inner --pictures research/shapes/rocks <folders of .glb>
writes src/rock_parts_generated.lua, keyed by the unit's resource hash (murmur64 of its content path, as the
game names it): the mesh's box (half sizes and middle, the unit's frame) and up to INNER_MAX (INNER_MAX_BIG past
8 m) `stop` boxes inscribed in the solid — the collision hulls where the unit has them (a coarse hull round a finer
one dropped, disjoint pieces added up), else the LOD0 shell, closed at the bottom with a skirt (things standing
on the ground have no underside) — eroded INNER_MARGIN voxel(s), so a box is inside the surface and a line never
stops where the round would get through. Pitch size/100 clamped to 0.1–1 m, finer across a thin thing (a log).
Skipped: vistas (INNER_SIZE_MAX), pebbles (INNER_SIZE_MIN), and INNER_SKIP by name (barbwire, banners, spikes).
A run over 200 units takes 3 minutes; 12_rock.lua reads the file.

The review (3.0.13, luka: export whole folders, drop the small, eye the rest over): --review page.html writes one
HTML page instead of the Lua (tools/shape_review.py, tools/review_template.html): every kind a card with its side
and top view, the boxes over the mesh and a 1.8 m Helldiver; a height rule (boxes that reach under so many metres
above the root: the kind is left out), a click leaves a kind out, and kinds open underneath as modelled (a walkway
on stilts, an arch, a wall of roots) offer two fills. The page's list goes into tools/rock_skip.txt whole, and the
next --inner run writes the Lua by it. --cached takes every kind in the cache, with or without its export (the
exports are GBs, and a kind he has passed needs only its result). The kinds he has been through are in tools/rock_reviewed.txt (--reviewed adds
a round's folders); every other kind is "new" on the page, and the page opens on the new ones. --cache dir keeps each unit's result (a later run does only new files);
--census file.json (tools/shape_review.py --census, from the logs) puts each kind's count on a map on its card.
    python3 tools/make_shapes.py --inner --review review.html --census research/census.json --cache <dir> <folders>
A unit filediver has no name for is written as 0x<hash>.unit.glb: its hash is taken from the file name, and its
name from --names (research/unit_names.json, 2,585 units) where a newer name list has it.

Needs: pip install trimesh numpy scipy matplotlib pillow
"""
import argparse
import gc, glob, os, re, sys
import numpy as np

try:
    import trimesh
    from scipy import ndimage
except ImportError:
    sys.exit('needs trimesh, numpy and scipy: pip install trimesh numpy scipy matplotlib')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PITCH = 0.25
BAND = 0.6            # a new z-band when the footprint's edge moves more than this
MOUTH = 1.5           # the cavity's mouth: this much above the lip, the top band's footprint
MIN_BOX = 0.4         # boxes thinner than this on any side are dropped
MAX_BOXES = 12
# kinds read as solid whatever the slices say: a building's hollow inside is not a tunnel (the big Automaton
# factory opens at the roof; its vents are the layout file's business until they're placed by eye)
SOLID = {'colony_cyborg_spawner', 'cyborg_turret_small_autocannon'}
# guns that turn about their root (luka: "a box rotating around its centre"): their boxes are square across the
# body and centred on the root, the barrel left out — then the unit's yaw doesn't matter and nothing is re-read
TURRET = {'cyborg_tank_turret_cannon', 'cyborg_tank_turret_autocannons', 'cyborg_tank_turret_mortar', 'cyborg_turret_small_autocannon'}


def game_frame(v):
    return np.stack([v[:, 0], -v[:, 2], v[:, 1]], 1)


def load_groups(path):
    """The unit's LOD0 groups in the game frame: (name, material, Trimesh). filediver's node names carry _LODn only
    for named groups (unnamed ones are hashes, one per LOD), so the LODs are told apart by their bounding boxes:
    groups whose boxes match within 10 % are one thing at several LODs, and the one with the most vertices is
    LOD0 (the material splits of one LOD share its vertices, so all of them stay). The body is the cluster with the
    biggest box (the rubble a destroyed one leaves is smaller); the collision groups are kept by material."""
    sc = trimesh.load(path, force='scene', process=False)
    raw = []
    for node in sc.graph.nodes_geometry:
        T, g = sc.graph[node]
        geom = sc.geometry[g]
        if not isinstance(geom, trimesh.Trimesh):
            continue
        mat = geom.visual.material.name if getattr(geom.visual, 'material', None) is not None else ''
        if 'shadow' in mat or 'gib' in mat or 'damaged' in node or 'culling' in node:
            continue
        v = game_frame(trimesh.transform_points(geom.vertices, T))
        raw.append((node, mat, trimesh.Trimesh(v, geom.faces, process=False)))
    clusters = []
    for item in raw:
        lo, hi = item[2].bounds
        size = max(hi - lo)
        for c in clusters:
            clo, chi = c['lo'], c['hi']
            if np.abs(lo - clo).max() <= 0.1 * size + 0.05 and np.abs(hi - chi).max() <= 0.1 * size + 0.05:
                c['items'].append(item)
                break
        else:
            clusters.append(dict(lo=lo, hi=hi, items=[item]))
    out = []
    for c in clusters:
        coll = [i for i in c['items'] if 'collision' in i[1]]
        rest = [i for i in c['items'] if 'collision' not in i[1]]
        if rest:
            top = max(len(i[2].vertices) for i in rest)
            c['lod0'] = [i for i in rest if len(i[2].vertices) == top]
        else:
            c['lod0'] = []
        c['coll'] = coll
        c['vol'] = float(np.prod(c['hi'] - c['lo']))
    body = max((c for c in clusters if c['lod0']), key=lambda c: c['vol'], default=None)
    if body:
        out += body['lod0']
    for c in clusters:
        out += c['coll']
    return out


def voxelise(mesh, pitch=PITCH):
    vox = mesh.voxelized(pitch)
    return vox.matrix.copy(), vox.transform[:3, 3].copy()


def slice_regions(shell):
    """Per slice: labels of the empty cells; which labels touch the border (outside)."""
    nz = shell.shape[2]
    labels, outside = [], []
    for k in range(nz):
        empty = ~shell[:, :, k]
        lab, n = ndimage.label(empty)
        border = set(np.unique(np.concatenate([lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]]))) - {0}
        labels.append(lab)
        outside.append(border)
    return labels, outside


def classify(shell):
    """solid and cavity voxel masks from the shell, by the slice reading (see the module doc)."""
    nx, ny, nz = shell.shape
    labels, outside = slice_regions(shell)
    solid = shell.copy()
    cavity = np.zeros_like(shell)
    # the tunnel: start at the lowest slice with an enclosed region, follow it up by overlap
    tracked = None
    opened_at = None
    for k in range(nz):
        lab, out = labels[k], outside[k]
        enclosed = set(np.unique(lab)) - {0} - out
        if tracked is None:
            if enclosed and opened_at is None:
                # the largest enclosed region of the lowest such slice
                best = max(enclosed, key=lambda l: (lab == l).sum())
                tracked = lab == best
            for l in enclosed:
                if tracked is None or l != best:
                    solid[:, :, k] |= lab == l
            if tracked is not None:
                cavity[:, :, k] = tracked
            continue
        # follow: the region(s) of this slice overlapping the tracked one
        over = set(np.unique(lab[tracked])) - {0}
        if not over:
            tracked = None
            opened_at = None if opened_at is None else opened_at
            for l in enclosed:
                solid[:, :, k] |= lab == l
            continue
        if over & out:
            opened_at = k            # the tunnel opens to the outside: a cavity, its lip here
            for l in enclosed:
                solid[:, :, k] |= lab == l
            tracked = None
            continue
        if opened_at is not None:
            for l in enclosed:
                solid[:, :, k] |= lab == l
            continue
        nxt = np.zeros_like(tracked)
        for l in over:
            nxt |= lab == l
        for l in enclosed - over:
            solid[:, :, k] |= lab == l
        cavity[:, :, k] = nxt
        tracked = nxt
    if opened_at is None:
        # never opened: the tracked region was the inside of a solid (a trunk) — it's solid, not a cavity
        solid |= cavity
        cavity[:] = False
    else:
        # the tunnel's own wall is not the mound: shell voxels next to the cavity drop out of the solid
        wall = ndimage.binary_dilation(cavity, iterations=2) & shell
        solid &= ~wall
    return solid, cavity, opened_at


def bands(mask, origin, pitch, band=BAND):
    """z-bands of a voxel mask, each an AABB in metres: [x0, x1, y0, y1, z0, z1]."""
    boxes = []
    cur = None
    for k in range(mask.shape[2]):
        sl = mask[:, :, k]
        if not sl.any():
            if cur: boxes.append(cur); cur = None
            continue
        xs, ys = np.where(sl)
        fp = [origin[0] + xs.min() * pitch, origin[0] + (xs.max() + 1) * pitch, origin[1] + ys.min() * pitch, origin[1] + (ys.max() + 1) * pitch]
        z0, z1 = origin[2] + k * pitch, origin[2] + (k + 1) * pitch
        if cur and max(abs(a - b) for a, b in zip(cur[:4], fp)) <= band:
            cur = [min(cur[0], fp[0]), max(cur[1], fp[1]), min(cur[2], fp[2]), max(cur[3], fp[3]), cur[4], z1]
        else:
            if cur: boxes.append(cur)
            cur = fp + [z0, z1]
    if cur: boxes.append(cur)
    boxes = [b for b in boxes if b[1] - b[0] >= MIN_BOX and b[3] - b[2] >= MIN_BOX and b[5] - b[4] >= MIN_BOX]
    while len(boxes) > MAX_BOXES:
        # merge the two neighbouring bands whose union grows the least
        best, besti = None, None
        for i in range(len(boxes) - 1):
            a, b = boxes[i], boxes[i + 1]
            u = [min(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), max(a[3], b[3]), a[4], b[5]]
            grow = (u[1] - u[0]) * (u[3] - u[2]) * (u[5] - u[4]) - (a[1] - a[0]) * (a[3] - a[2]) * (a[5] - a[4]) - (b[1] - b[0]) * (b[3] - b[2]) * (b[5] - b[4])
            if best is None or grow < best: best, besti = grow, i
        a, b = boxes[besti], boxes[besti + 1]
        boxes[besti:besti + 2] = [[min(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), max(a[3], b[3]), a[4], b[5]]]
    return boxes


def metres(box):
    """A box in metres from the root: hx, hy, hz, cx, cy, cz (the generated form, `abs`)."""
    return [round((box[1] - box[0]) / 2, 2), round((box[3] - box[2]) / 2, 2), round((box[5] - box[4]) / 2, 2),
            round((box[0] + box[1]) / 2, 2), round((box[2] + box[3]) / 2, 2), round((box[4] + box[5]) / 2, 2)]


def squared(boxes):
    """A turret's bands: square across the body, centred on the root; the barrel (forward) out. (2.5.22, luka's
    look at the cannon: the mesh's widest point is a fitting or a step, so the square takes 3/4 of the x extent —
    his "2 to -2" on a 2.75 body — and a band less than half the widest one's width is a sensor on top, not body:
    dropped.) The bands are then merged into one where they're the same width."""
    out = []
    widest = max((max(abs(b[0]), abs(b[1])) for b in boxes), default=0)
    for b in boxes:
        h = max(abs(b[0]), abs(b[1]))
        if h < 0.5 * widest:
            continue
        h = round(h * 0.75, 2)
        if out and abs(out[-1][1] - h) < 0.01 and abs(out[-1][5] - b[4]) < 0.3:
            out[-1][5] = b[5]
        else:
            out.append([-h, h, -h, h, b[4], b[5]])
    return out


# boxes luka set by eye, in metres from the root [x0, x1, y0, y1, z0, z1]: these replace the tool's for the kind
HAND = {
    'cyborg_tank_turret_cannon': [[-2, 2, -2, 2, 0, 1]],   # (2.5.22: "2 to -2 on both, the height is good", the sensor on top out)
}


def fractions(box, lo, hi):
    """A box in metres as the layout file's part: fx, fy, z0, z1, ox, oy (fractions of the kind's box)."""
    hx, hy, hz = (hi - lo) / 2
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    fx, fy = (box[1] - box[0]) / 2 / hx, (box[3] - box[2]) / 2 / hy
    z0, z1 = (box[4] - lo[2]) / (2 * hz), (box[5] - lo[2]) / (2 * hz)
    ox, oy = ((box[0] + box[1]) / 2 - cx) / hx, ((box[2] + box[3]) / 2 - cy) / hy
    return [round(min(fx, 1), 3), round(min(fy, 1), 3), round(max(z0, 0), 3), round(min(z1, 1), 3), round(ox, 3), round(oy, 3)]


def picture(path, groups, lo, hi, hit, stop, out):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.collections import PolyCollection
    from matplotlib.patches import Rectangle
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))
    views = [('top: x right, y up (forward)', 0, 1), ('front: x right, z up', 0, 2), ('side: y right (forward), z up', 1, 2)]
    for ax, (title, a, b) in zip(axes, views):
        for name, mat, m in groups:
            tri = m.vertices[m.faces][:, :, [a, b]]
            ax.add_collection(PolyCollection(tri, facecolors='gray', edgecolors='gray', linewidths=0.1, alpha=0.3))
        for boxes, col in ((stop, 'blue'), (hit, 'red')):
            for bx in boxes:
                x0, x1 = bx[2 * a], bx[2 * a + 1]
                y0, y1 = bx[2 * b], bx[2 * b + 1]
                ax.add_patch(Rectangle((x0, y0), x1 - x0, y1 - y0, fill=False, edgecolor=col, linewidth=1.4))
        ax.set_xlim(lo[a] - 1, hi[a] + 1); ax.set_ylim(lo[b] - 1, hi[b] + 1)
        ax.set_aspect('equal'); ax.grid(True, alpha=0.3); ax.set_title(title)
        ax.axhline(0, color='k', lw=0.5); ax.axvline(0, color='k', lw=0.5)
    fig.suptitle('%s — red: the shot goes in (hit); blue: solid (the line stops)' % os.path.basename(path))
    plt.tight_layout(); plt.savefig(out, dpi=80); plt.close(fig)


def do_kind(path, engine=None, kind=''):
    groups = load_groups(path)
    if not groups:
        return None, 'no LOD0 mesh'
    coll = [g for g in groups if 'collision' in g[1]]
    body = [g for g in groups if 'collision' not in g[1] and 'navigation' not in g[0]]
    allv = np.concatenate([g[2].vertices for g in body]) if body else np.concatenate([g[2].vertices for g in groups])
    lo, hi = allv.min(0), allv.max(0)
    note = 'mesh box %.1f x %.1f x %.1f m' % tuple(hi - lo)
    if engine is not None:
        half = np.array(engine[:3])
        d = np.abs((hi - lo) - 2 * half)
        note += '; the engine\'s %.1f x %.1f x %.1f' % tuple(2 * half)
        if len(engine) >= 6:
            # the engine box's middle, as the research line gives it (right, forward, up of the root): the parts are
            # fractions of *that* box, whatever the mesh's own bounds (the ship's box is 2 m taller than its mesh)
            mid = np.array(engine[3:6])
            lo, hi = mid - half, mid + half
            note += ', its middle %+.1f %+.1f %+.1f of the root' % tuple(mid)
        elif d.max() > 0.3:
            return None, note + ' — DOES NOT FIT the mesh; give the engine middle too (kind=hx,hy,hz,ox,oy,oz from the research line) or it stays skipped'
    if coll:
        # the smallest collision mesh (the physics hull), filled: all solid, no cavity
        cm = min(coll, key=lambda g: len(g[2].faces))[2]
        vox = cm.voxelized(PITCH)
        shell, origin = vox.matrix.copy(), vox.transform[:3, 3].copy()
        try:
            solid = vox.fill().matrix
        except Exception:
            solid = shell
        cavity = np.zeros_like(solid)
        note += '; collision hull %d faces' % len(cm.faces)
    else:
        mesh = trimesh.util.concatenate([g[2] for g in body])
        shell, origin = voxelise(mesh)
        solid, cavity, lip = classify(shell)
        if kind in SOLID:
            solid, cavity, lip = solid | cavity, np.zeros_like(cavity), None
            note += '; read as solid (SOLID)'
        if lip is not None:
            # the mouth: the top cavity band's footprint, MOUTH m up from the lip
            top = cavity[:, :, max(lip - 2, 0):lip].any(2)
            for k in range(lip, min(lip + int(MOUTH / PITCH), cavity.shape[2])):
                cavity[:, :, k] |= top
            note += '; a cavity, its lip %.1f m up' % (origin[2] + lip * PITCH - lo[2])
        else:
            note += '; solid'
    hit = bands(cavity, origin, PITCH)
    stop = bands(solid & ~cavity, origin, PITCH)
    if not hit and not coll:
        # a solid structure (a nest, the spewer): the thing itself is what the shot hits — its bands are the hit
        hit, stop = stop, []
    if kind in TURRET:
        hit = squared(hit)
        note += '; a turret: squared about the root'
    if kind in HAND:
        hit = [list(b) for b in HAND[kind]]
        note += '; set by eye (HAND)'
    return dict(lo=lo, hi=hi, hit=hit, stop=stop, groups=groups), note


# ------------------------------------------------------------------------------------------------ the rocks (3.1)
# (luka: "lines stop on rocks, walls and trunks", with the hitbox on the inner side of the rock's surface, so the
# line never stops where the game would let the round fly on) A rock's unit file carries its collision mesh
# (material m_collision; the navigation one left out) — the surface the game's physics tests a round against.
# The boxes here are *inscribed*: the collision meshes are voxelised and filled, intersected when there are
# several (a box inside all of them is inside whichever the game uses), the result eroded one voxel so every box
# face sits that much inside the surface, and up to INNER_MAX boxes are taken greedily, each the biggest that fits
# in what's left (grown from the deepest cell). A kind with no collision mesh (bug rocks, logs) takes its LOD0
# shell, filled, the same way. The pitch grows with the kind so a mountain stays tractable.
INNER_MAX = 8
INNER_MAX_BIG = 16                   # for a thing over 8 m across
INNER_SIZE_MAX = 300                 # metres: bigger is a backdrop (the magma vistas are 0.9–1.1 km; a sandy cliff is 155 m)
INNER_SIZE_MIN = 0.8                 # metres: smaller is a pebble
INNER_SKIP = ['barbwire', 'banner', 'head_spike', 'set_detail', 'rock_hole', 'poster_']   # by name: wire, cloth and spikes let a round through; a bug hole is a pit, its mesh all below the ground; a poster is a sheet on a wall
INNER_MIN = 0.2                                         # a box under this on any side is dropped
INNER_MARGIN = 1                                        # voxels shaved off the surface
# (3.0.13, luka: "drop anything small, the small logs don't stop the round at any different point than the ground")
# a kind whose stop boxes reach less than this above its root is left out. By height, not by its smallest side: a
# small log is 2.5 m long and 0.16 m of solid high. The number is luka's, from the review page: the `reach` line of
# tools/rock_skip.txt (none: no rule)
INNER_REACH_MIN = 0.0
# what the review page (tools/make_shapes.py --review) gives back, pasted whole: `reach 0.5` the height rule; a hash
# or a name a line, a kind left out by eye; `+hash` a kind kept although under the height rule; # comments
SKIP_FILE = os.path.join(ROOT, 'tools', 'rock_skip.txt')


def read_skip(path=None):
    """-> (the set of lines: hashes, names, +hashes, =hashes; the height rule in metres)"""
    path = path or SKIP_FILE
    out, reach = set(), INNER_REACH_MIN
    if os.path.exists(path):
        for line in open(path, encoding='utf-8'):
            line = line.split('#')[0].strip()
            m = re.match(r'reach\s+([\d.]+)$', line)
            if m:
                reach = float(m.group(1))
            elif line:
                out.add(line)
    return out, reach


REVIEWED_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rock_reviewed.txt')


def read_reviewed(path=None):
    """The hashes of the kinds luka has been through on the review page (tools/rock_reviewed.txt)."""
    path = path or REVIEWED_FILE
    out = set()
    if os.path.exists(path):
        for line in open(path, encoding='utf-8'):
            line = line.split('#')[0].strip()
            if line:
                out.add(line)
    return out


def murmur64(name):
    import struct
    data = name.encode('utf-8'); mask, mix = (1 << 64) - 1, 0xC6A4A7935BD1E995
    value = len(data) * mix & mask; end = len(data) // 8 * 8
    for (word,) in struct.iter_unpack('<Q', data[:end]):
        word = word * mix & mask; word ^= word >> 47; value = (value ^ (word * mix & mask)) * mix & mask
    if data[end:]: value = (value ^ int.from_bytes(data[end:], 'little')) * mix & mask
    value ^= value >> 47; value = value * mix & mask; return value ^ (value >> 47)


SKIRT_GAP = 1.5                      # metres: a bottomless gap wider than this, open at an end, is a way through


def _sides(shell, axis, pitch):
    """Per cell: is there shell on both sides along the axis, and how far apart the nearest two are (metres)."""
    n = shell.shape[axis]
    idx = np.arange(n).reshape([-1 if i == axis else 1 for i in range(3)])
    before = np.maximum.accumulate(np.where(shell, idx, -1), axis=axis)
    after = np.flip(np.minimum.accumulate(np.flip(np.where(shell, idx, n * 4), axis), axis=axis), axis)
    both = (before >= 0) & (after < n * 4)
    return both, np.where(both, (after - before) * pitch, np.inf)


# (3.0.15, luka: "walls and fortifications that are thin but big, left out because no box fits inside — I don't
# mind if the boxes stand outside the shape by a bit, I just don't want a bounding box") The covering boxes: what
# the inside boxes leave of the solid, piece by piece, gets boxes laid OVER it — turned about z to lie along a
# wall, as thick as the wall is — and a box that is too empty is split across its longest side until each is full
# enough, so none spans a gap. They may stand outside the solid by the sheet's own unevenness, never by more.
COVER_FILL_OK = 0.55     # a covering box at least this full of solid is taken as it is
COVER_FILL_MIN = 0.40    # one emptier than this at the end is dropped (a lattice, rails, a tangle: no wall)
COVER_THIN = 1.0         # metres: only a sheet gets one — a box whose thinnest side is over this is a rock's bulk,
                         # and a rock keeps to its inside boxes
COVER_OVER = 0.25        # metres: a plate box no thicker than twice this is taken at 40 % full (a wavy sheet)
COVER_MIN = 0.6          # metres: a leftover piece shorter than this every way gets no box
COVER_MAX = 16           # covering boxes looked for at most (the pick below decides how many are kept)
PLATE_CAP = 12           # plates and covering boxes kept a kind, beside its inside boxes; a kind over 8 m long:
PLATE_CAP_BIG = 24
OUTSIDE_MAX = 0.25       # a plate or covering box with more of its own outline than this outside the thing as it
                         # LOOKS (the LOD0 mesh: a collision hull can be fatter and taller than the rock drawn) is left out
INNER_MORE = 8           # inside boxes over the usual count, while they hold under
INNER_ENOUGH = 0.7       # this much of the solid


# (3.0.15, luka: "yes, build the flat face plates") The plates: a man-made wall is flat faces, and a flat face is
# found in the mesh itself — triangles that share a direction and a plane. Each big face is drawn in its own plane
# and rectangles are fitted INSIDE it (the inside-box rule, in two dimensions), then given PLATE_T of thickness
# behind the face. In the plane a plate never stands outside the wall; it stands outside only by its thickness,
# where the wall is thinner than that. Upright faces (walls) and level ones (decks, roofs); a face that leans more
# than PLATE_LEAN from upright is left to the covering boxes.
PLATE_T = 0.2            # metres of thickness behind the face
PLATE_AREA = 1.0         # square metres: a face smaller than this gets no plate
PLATE_RECT = 0.5         # square metres: nor a rectangle smaller than this (and none under PLATE_SIDE on a side)
PLATE_SIDE = 0.4
PLATE_PITCH = 0.1        # the face is drawn at this
PLATE_LEAN = 0.2         # |normal's z| up to this is an upright face; over 0.96 a level one
PLATE_MAX = 6            # rectangles a face
PLATE_CANDS = 150      # plates a kind may offer the pick (the biggest); 12 or 24 are taken
PLATE_FOOT = 0.5       # a level face looking down within this of the mesh's bottom ...
PLATE_FOOT_BODY = 2.0  # ... under a body this much taller is the thing's foot: no plate


def largest_rect(occ):
    """The largest all-true rectangle of a 2D boolean array: (area in cells, r0, r1, c0, c1), r1 / c1 exclusive."""
    rows, cols = occ.shape
    h = np.zeros(cols, int)
    best = (0, 0, 0, 0, 0)
    for r in range(rows):
        h = np.where(occ[r], h + 1, 0)
        stack = []
        for c in range(cols + 1):
            cur = h[c] if c < cols else 0
            start = c
            while stack and stack[-1][1] >= cur:
                st, ht = stack.pop()
                if ht * (c - st) > best[0]:
                    best = (ht * (c - st), r - ht + 1, r + 1, st, c)
                start = st
            stack.append((start, cur))
    return best


def _raster(tri2, lo, shape, pitch):
    """Triangles (n, 3, 2) drawn into a grid: the cells whose middle lies in a triangle, and those a corner or an
    edge's sample falls in (a sliver still counts)."""
    occ = np.zeros(shape, bool)
    for t in tri2:
        mn = np.floor((t.min(0) - lo) / pitch).astype(int)
        mx = np.floor((t.max(0) - lo) / pitch).astype(int) + 1
        mn = np.maximum(mn, 0); mx = np.minimum(mx, shape)
        if (mx <= mn).any():
            continue
        gu = lo[0] + (np.arange(mn[0], mx[0]) + 0.5) * pitch
        gv = lo[1] + (np.arange(mn[1], mx[1]) + 0.5) * pitch
        U, V = np.meshgrid(gu, gv, indexing='ij')
        d = (t[1, 1] - t[2, 1]) * (t[0, 0] - t[2, 0]) + (t[2, 0] - t[1, 0]) * (t[0, 1] - t[2, 1])
        if abs(d) < 1e-12:
            continue
        a = ((t[1, 1] - t[2, 1]) * (U - t[2, 0]) + (t[2, 0] - t[1, 0]) * (V - t[2, 1])) / d
        b = ((t[2, 1] - t[0, 1]) * (U - t[2, 0]) + (t[0, 0] - t[2, 0]) * (V - t[2, 1])) / d
        inside = (a >= -1e-6) & (b >= -1e-6) & (a + b <= 1 + 1e-6)
        occ[mn[0]:mx[0], mn[1]:mx[1]] |= inside
    return occ


_FACES = {}            # id(mesh) -> its flat faces' rectangles (the dear part of plates_of; a kind asks two or three times)


def plates_of(mesh, stop):
    """The mesh's big flat faces as plates: boxes turned about z, (cx, cy, cz, hx, hy, hz, yaw)."""
    if id(mesh) not in _FACES:
        _FACES.clear()                                      # (one mesh's at a time: ids are reused once a mesh is gone)
        _FACES[id(mesh)] = _faces_of(mesh)
    out = _FACES[id(mesh)]
    return _plate_boxes(mesh, out, stop)


def _faces_of(mesh):
    # (the faces are drawn at PLATE_PITCH up to 25 m of mesh, coarser past it: a 90 m ruin's thousands of faces at
    # 10 cm took minutes)
    pp = max(PLATE_PITCH, float(np.ptp(mesh.vertices, axis=0).max()) / 250)
    tris = mesh.vertices[mesh.faces]
    nrm = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    area = np.linalg.norm(nrm, axis=1) / 2
    ok = area > 1e-8
    tris, nrm, area = tris[ok], nrm[ok], area[ok]
    nrm = nrm / (2 * area[:, None])
    cen = tris.mean(1)
    out = []

    def face_plates(sel, n, u, v):
        # sel: the triangles of one direction; n its normal, u / v the plane's axes. Planes by their offset along n
        off = cen[sel] @ n
        if area[sel].sum() < PLATE_AREA:
            return
        bins = np.round(off / 0.1).astype(int)
        for b in np.unique(bins):
            m = np.abs(bins - b) <= 0                       # (one 10 cm slice of offsets)
            if area[sel][m].sum() < PLATE_AREA:
                continue
            m = np.abs(off - np.average(off[m], weights=area[sel][m])) <= 0.06
            d = float(np.average(off[m], weights=area[sel][m]))
            t = tris[sel][m]
            t2 = np.stack([t @ u, t @ v], axis=2)
            lo2 = t2.reshape(-1, 2).min(0) - pp
            shape = tuple(np.ceil((t2.reshape(-1, 2).max(0) + pp - lo2) / pp).astype(int))
            if shape[0] < 2 or shape[1] < 2 or shape[0] * shape[1] > 4e6:
                continue
            occ = _raster(t2, lo2, shape, pp)
            for _ in range(PLATE_MAX):
                a, r0, r1, c0, c1 = largest_rect(occ)
                w, h = (r1 - r0) * pp, (c1 - c0) * pp
                if a * pp ** 2 < PLATE_RECT or min(w, h) < PLATE_SIDE:
                    break
                occ[r0:r1, c0:c1] = False
                cu, cv = lo2[0] + (r0 + r1) / 2 * pp, lo2[1] + (c0 + c1) / 2 * pp
                c3 = u * cu + v * cv + n * (d - PLATE_T / 2)          # (behind the face)
                out.append((c3, u, v, n, w / 2, h / 2, a * pp ** 2))

    # upright faces, by the normal's bearing in 5 degree steps (a wall's two sides are two faces)
    up = np.abs(nrm[:, 2]) <= PLATE_LEAN
    if up.any():
        idx = np.where(up)[0]
        bearing = np.degrees(np.arctan2(nrm[idx, 1], nrm[idx, 0]))
        steps = np.round(bearing / 5).astype(int) % 72
        for st in np.unique(steps):
            sel = idx[steps == st]
            if area[sel].sum() < PLATE_AREA:
                continue
            n = np.average(nrm[sel], axis=0, weights=area[sel]); n[2] = 0
            ln = np.linalg.norm(n)
            if ln < 1e-6:
                continue
            n = n / ln
            face_plates(sel, n, np.array([-n[1], n[0], 0.0]), np.array([0.0, 0.0, 1.0]))
    # level faces (decks, roofs), in the unit's own x and y
    for sign in (1.0, -1.0):
        sel = np.where(nrm[:, 2] * sign >= 0.96)[0]
        if len(sel):
            face_plates(sel, np.array([0.0, 0.0, sign]), np.array([1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0]))
    return out


def _plate_boxes(mesh, out, stop):
    # as boxes turned about z; one mostly inside an inside box, or inside a bigger plate, is not needed
    boxes = []
    zlo, zhi = float(mesh.vertices[:, 2].min()), float(mesh.vertices[:, 2].max())
    for c3, u, v, n, hu, hv, a in sorted(out, key=lambda o: -o[6]):
        # the flat underside of a tall body (a cliff cut level at its foot) stops nothing the ground would not: a line
        # that reaches it has been through the body. It only flattered the top view's cover.
        if n[2] < -0.5 and c3[2] < zlo + PLATE_FOOT and zhi - c3[2] > PLATE_FOOT_BODY:
            continue
        if abs(n[2]) > 0.5:
            o = (c3[0], c3[1], c3[2], hu, hv, PLATE_T / 2, 0.0)
        else:
            o = (c3[0], c3[1], c3[2], hu, PLATE_T / 2, hv, float(np.arctan2(u[1], u[0])))
        k = obb_points(o, 5)
        held = np.zeros(len(k), bool)
        for b in stop:
            held |= (k[:, 0] >= b[0]) & (k[:, 0] <= b[1]) & (k[:, 1] >= b[2]) & (k[:, 1] <= b[3]) & (k[:, 2] >= b[4]) & (k[:, 2] <= b[5])
        for q in boxes:
            held |= in_obb(k, q, 0.05)
        if held.mean() < 0.7:
            boxes.append(o)
            if len(boxes) >= PLATE_CANDS:      # (the biggest first: a factory's 1,600 small faces each cost a pass over the grid)
                break
    return boxes


def obb_points(o, n):
    """n x n x 2 points through a turned box (its two big faces' grid), for asking what else holds it."""
    c, s_ = np.cos(o[6]), np.sin(o[6])
    g = np.linspace(-0.9, 0.9, n)
    pts = []
    for a in g:
        for b in g:
            for t in (-0.5, 0.5):
                if o[5] <= o[3] and o[5] <= o[4] and o[6] == 0.0 and o[5] == PLATE_T / 2:      # (a level plate)
                    x, y, z = a * o[3], b * o[4], t * o[5]
                else:
                    x, y, z = a * o[3], t * o[4], b * o[5]
                pts.append((o[0] + c * x - s_ * y, o[1] + s_ * x + c * y, o[2] + z))
    return np.array(pts)


def in_obb(pts, o, grow=0.0):
    c, s_ = np.cos(o[6]), np.sin(o[6])
    dx, dy = pts[:, 0] - o[0], pts[:, 1] - o[1]
    return (np.abs(dx * c + dy * s_) <= o[3] + grow) & (np.abs(-dx * s_ + dy * c) <= o[4] + grow) & (np.abs(pts[:, 2] - o[2]) <= o[5] + grow)


def cover_fit(pts, pitch):
    """A box turned about z round the points: (cx, cy, cz, hx, hy, hz, yaw), how full, its sizes, the points in its frame."""
    xy = pts[:, :2] - pts[:, :2].mean(0)
    yaw = 0.0
    if len(pts) >= 3:
        w, v = np.linalg.eigh(xy.T @ xy)
        if w[1] > 1.5 * max(w[0], 1e-9):           # (a long footprint: along it; a round one: as the unit lies)
            yaw = float(np.arctan2(v[1, 1], v[0, 1]))
    c, s_ = np.cos(yaw), np.sin(yaw)
    u = pts[:, 0] * c + pts[:, 1] * s_
    v_ = -pts[:, 0] * s_ + pts[:, 1] * c
    lo = np.array([u.min(), v_.min(), pts[:, 2].min()]) - pitch / 2
    hi = np.array([u.max(), v_.max(), pts[:, 2].max()]) + pitch / 2
    h, m = (hi - lo) / 2, (hi + lo) / 2
    fill = len(pts) * pitch ** 3 / max(1e-9, float(np.prod(hi - lo)))
    # a plate (a box no thicker than twice COVER_OVER on its thinnest side): how much of its face the solid
    # covers, seen through it — a wall with ribs and pipes is not full of solid, but nothing passes it
    ext = hi - lo
    k = int(np.argmin(ext))
    face = None
    if ext[k] <= 2 * COVER_OVER:
        uvz = (u, v_, pts[:, 2])
        a, b = [i for i in range(3) if i != k]
        cells = set(zip(np.floor((uvz[a] - lo[a]) / pitch).astype(int).tolist(), np.floor((uvz[b] - lo[b]) / pitch).astype(int).tolist()))
        face = len(cells) * pitch ** 2 / max(1e-9, float(ext[a] * ext[b]))
    return (m[0] * c - m[1] * s_, m[0] * s_ + m[1] * c, m[2], h[0], h[1], h[2], yaw), fill, ext, (u, v_, pts[:, 2]), face


def cover_piece(pts, pitch, budget):
    import heapq
    heap, done, n = [(0.0, 0, pts)], [], 0
    while heap:
        _, _, p = heapq.heappop(heap)
        o, fill, ext, uvz, face = cover_fit(p, pitch)
        if face is not None:
            fill = max(fill, face * 0.85)          # (a plate is judged by its face)
        if fill >= COVER_FILL_OK or len(done) + len(heap) + 1 >= budget or len(p) < 40:
            done.append((o, fill))
            continue
        # the cut that leaves the least box: each of the box's three sides tried at five places
        best = None
        for ax in range(3):
            if ext[ax] < 4 * pitch:
                continue
            key = uvz[ax]
            for qt in (0.2, 0.35, 0.5, 0.65, 0.8):
                cut = np.quantile(key, qt)
                m1 = key <= cut
                if m1.sum() < 10 or (~m1).sum() < 10:
                    continue
                v = float(np.prod(cover_fit(p[m1], pitch)[2])) + float(np.prod(cover_fit(p[~m1], pitch)[2]))
                if best is None or v < best[0]:
                    best = (v, m1)
        if best is None or best[0] > 0.97 * float(np.prod(ext)):       # (no cut helps: as it is)
            done.append((o, fill))
            continue
        a, b = p[best[1]], p[~best[1]]
        for q in (a, b):
            n += 1
            oq, fq, eq, _, faceq = cover_fit(q, pitch)
            if faceq is not None:
                fq = max(fq, faceq * 0.85)
            heapq.heappush(heap, (-(1 - fq) * float(np.prod(eq)), n, q))      # (the emptiest big one next)
    return [o for o, fill in done if fill >= COVER_FILL_MIN and 2 * max(o[3], o[4], o[5]) >= COVER_MIN
            and 2 * min(o[3], o[4], o[5]) <= COVER_THIN]


def cover_boxes(grid, glo, pitch, stop, plates=()):
    """grid: the solid (not eroded). -> the covering boxes for what the inside boxes `stop` and the plates leave of it."""
    idx = np.argwhere(grid)
    if not len(idx):
        return []
    pts = glo + (idx + 0.5) * pitch
    left = np.ones(len(pts), bool)
    for o in plates:
        left &= ~in_obb(pts, o, pitch)
    for b in stop:                                 # (what an inside box holds, and a cell round it, is done)
        left &= ~((pts[:, 0] >= b[0] - pitch) & (pts[:, 0] <= b[1] + pitch) & (pts[:, 1] >= b[2] - pitch) & (pts[:, 1] <= b[3] + pitch)
                  & (pts[:, 2] >= b[4] - pitch) & (pts[:, 2] <= b[5] + pitch))
    rest = np.zeros(grid.shape, bool)
    rest[tuple(idx[left].T)] = True
    lab, k = ndimage.label(rest, structure=np.ones((3, 3, 3)))
    budget = COVER_MAX
    out = []
    sizes = ndimage.sum(rest, lab, range(1, k + 1)) if k else []
    for i in np.argsort(-np.asarray(sizes)):
        if budget <= 0:
            break
        p = glo + (np.argwhere(lab == i + 1) + 0.5) * pitch
        if (p.max(0) - p.min(0)).max() < COVER_MIN:
            continue
        got = cover_piece(p, pitch, min(budget, 8))
        out += got
        budget -= len(got)
    return out


def filled_voxels(mesh, pitch, stats=None):
    """The mesh's voxels filled: the enclosed holes first; a shell the fill barely grows (a thing that stands on the
    ground has no bottom — a wall, a stump, a bug rock) gets a skirt from each column's lowest cell down to the
    grid's floor, which closes it.
    (3.0.13) The skirt only where the thing is closed sideways: shell on both sides along x and along y at that
    height — or along one of them with the two sides no more than SKIRT_GAP apart (a wall piece open at its ends).
    The skirt of 3.0.4 went under everything, so the way under an arch, a walkway on stilts or an overhang was
    filled in as rock, and a line would have stopped in the air there. That fill is still right for some kinds (a
    wall of roots, a debris cover: open as modelled, solid in the game), so it comes back too, as `whole`, for the
    review page to offer (tools/rock_skip.txt: =hash). -> the fill, its origin, the whole fill or None when it is
    the same; stats (a dict) takes how much of the whole fill is such air."""
    vox = mesh.voxelized(pitch)
    shell = vox.matrix.copy()
    solid = shell
    whole = None
    try:
        solid = vox.copy().fill(method='holes').matrix
    except Exception:
        pass
    if solid.sum() < 1.3 * shell.sum():
        cols = shell.any(axis=2)
        lowest = np.argmax(shell, axis=2)
        zi = np.arange(shell.shape[2])[None, None, :]
        below = cols[:, :, None] & (zi < lowest[:, :, None])
        bx, gx = _sides(shell, 0, pitch)
        by, gy = _sides(shell, 1, pitch)
        closed = (bx & by) | (bx & (gx <= SKIRT_GAP)) | (by & (gy <= SKIRT_GAP))
        alt = ndimage.binary_fill_holes(shell | (below & closed))
        old = ndimage.binary_fill_holes(shell | below)
        if stats is not None:
            stats['old'] = stats.get('old', 0) + int(old.sum())
            stats['air'] = stats.get('air', 0) + int((old & ~alt).sum())
        if old.sum() > max(solid.sum(), alt.sum()):
            whole = old | solid
        if alt.sum() > solid.sum():
            solid = alt
    return solid.copy(), vox.transform[:3, 3].copy(), (whole.copy() if whole is not None else None)


def on_grid(solid, origin, pitch, lo, shape):
    """The voxel set moved onto a common grid (origin lo, shape)."""
    out = np.zeros(shape, dtype=bool)
    off = np.round((origin - lo) / pitch).astype(int)
    sx, sy, sz = solid.shape
    x0, y0, z0 = (max(0, -o) for o in off)
    X0, Y0, Z0 = (max(0, o) for o in off)
    x1, y1, z1 = min(sx, shape[0] - X0 + x0), min(sy, shape[1] - Y0 + y0), min(sz, shape[2] - Z0 + z0)
    if x1 > x0 and y1 > y0 and z1 > z0:
        out[X0:X0 + x1 - x0, Y0:Y0 + y1 - y0, Z0:Z0 + z1 - z0] = solid[x0:x1, y0:y1, z0:z1]
    return out


def inner_boxes(grid, lo, pitch, max_boxes=INNER_MAX, thin=None):
    """Greedy: the biggest axis-aligned box of True cells grown from the deepest cell, taken out, again."""
    g = grid.copy()
    boxes = []
    least = INNER_MIN if thin is None else min(INNER_MIN, thin / 4)   # (a thin thing's boxes may be thin too)
    min_cells = max(2, int(round(least / pitch)))      # (two cells at the least)
    while len(boxes) < max_boxes and g.any():
        dist = ndimage.distance_transform_cdt(g, metric='chessboard')
        seed = np.unravel_index(np.argmax(dist), g.shape)
        r = int(dist[seed]) - 1
        b = [seed[0] - r, seed[0] + r, seed[1] - r, seed[1] + r, seed[2] - r, seed[2] + r]   # inclusive cell bounds
        # grow each face while the new slab is all True
        grew = True
        while grew:
            grew = False
            for face in range(6):
                nb = list(b)
                nb[face] += -1 if face % 2 == 0 else 1
                ax = face // 2
                if nb[face] < 0 or nb[face] >= g.shape[ax]:
                    continue
                sl = [slice(nb[0], nb[1] + 1), slice(nb[2], nb[3] + 1), slice(nb[4], nb[5] + 1)]
                sl[ax] = slice(nb[face], nb[face] + 1)
                if g[tuple(sl)].all():
                    b = nb
                    grew = True
        cells = [b[1] - b[0] + 1, b[3] - b[2] + 1, b[5] - b[4] + 1]
        g[b[0]:b[1] + 1, b[2]:b[3] + 1, b[4]:b[5] + 1] = False
        if min(cells) < min_cells:
            continue
        boxes.append([lo[0] + b[0] * pitch, lo[0] + (b[1] + 1) * pitch, lo[1] + b[2] * pitch, lo[1] + (b[3] + 1) * pitch,
                      lo[2] + b[4] * pitch, lo[2] + (b[5] + 1) * pitch])
    return boxes


COLL_COVER = 0.8       # a collision mesh is the solid when its outline stands behind this much of the thing as it looks ...
COLL_OUT = 0.25        # ... and no more than this much of its own outline outside it
OUTLINE_MORE = 1.25    # the outline fill is offered when it is this much bigger than the solid as modelled ...
OUTLINE_OVER = 1.15    # ... and than the whole fill, where that is offered
OUTLINE_AUTO = 0.5     # and it is the page's first choice when the solid as modelled is under this share of it
RESULT_V = 2           # a cached result older than this gets the outline fill added (do_inner's prev)


def do_inner(path, keep=False, prev=None):
    """keep: for the review page — a kind that is skipped still comes back, with its meshes and why (res['skipped']).
    prev: the kind's result from an earlier run, to which only the outline fill is added (its boxes stay)."""
    groups = load_groups(path)
    if not groups:
        return None, 'no LOD0 mesh'
    def skipped(why):
        return (dict(lo=lo, hi=hi, hit=[], stop=[], groups=groups, skipped=why) if keep else None), why
    coll = [g for g in groups if 'collision' in g[1] and 'navigation' not in g[0]]
    body = [g for g in groups if 'collision' not in g[1] and 'navigation' not in g[0]]
    allv = np.concatenate([g[2].vertices for g in (body or groups)])
    lo, hi = allv.min(0), allv.max(0)
    size = float(max(hi - lo))
    thin = float(min(hi - lo))
    if size > INNER_SIZE_MAX:
        return skipped('skipped: %.0f m across, a vista (the backdrop), not a thing a shot reaches' % size)
    if size < INNER_SIZE_MIN:
        return skipped('skipped: %.1f m across, too small to stop a line on' % size)
    base = os.path.basename(path)
    for word in INNER_SKIP:
        if word in base:
            return skipped('skipped: %s does not stop a round' % word)
    # (a mountain at 1 m, a rock at 10 cm; a thin thing — a log, a wall — fine enough for eight cells across it)
    pitch = max(0.04, min(min(1.0, max(0.1, size / 100)), thin / 8))
    note = 'mesh box %.1f x %.1f x %.1f m, pitch %.2f' % (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], pitch)
    srcs = [g[2] for g in coll] if coll else [trimesh.util.concatenate([g[2] for g in body])]
    note += '; %s' % ('%d collision mesh%s' % (len(coll), 'es' if len(coll) > 1 else '') if coll else 'no collision mesh: the LOD0 shell')
    # (3.0.15) a collision piece that is convex is a hull the game stops things on whole: its convex hull is the
    # solid, closed or not as exported (an open one was left a shell, and "open underneath" asked of it)
    hulls = 0
    if coll:
        for i, m in enumerate(srcs):
            try:
                h = m.convex_hull
                if h.area <= 1.15 * m.area and h.volume > 0:
                    srcs[i] = h
                    hulls += 1
            except Exception:
                pass
        if hulls:
            note += ' (%d convex: taken as hulls)' % hulls
    glo = lo - 2 * pitch
    shape = tuple(int(np.ceil((hi[i] - lo[i]) / pitch)) + 5 for i in range(3))
    # (a unit may carry several collision meshes: a coarse hull around a finer one — the hull is dropped, since
    # the finer is the surface — or disjoint pieces of a big rock, which add up)
    grids, wholes = [], []
    skirt = {}
    def fill_all():
        del grids[:], wholes[:]
        skirt.clear()
        for m in srcs:
            solid, origin, whole = filled_voxels(m, pitch, skirt)
            grids.append(on_grid(solid, origin, pitch, glo, shape))
            wholes.append(on_grid(whole if whole is not None else solid, origin, pitch, glo, shape))
    fill_all()

    # the thing as it looks, from the two sides and above (the LOD0 mesh's outline, its holes closed)
    look_v = None
    try:
        bm = trimesh.util.concatenate([g[2] for g in body]) if body else None
        if bm is not None:
            bv = bm.voxelized(pitch)
            lg = on_grid(bv.matrix.copy(), bv.transform[:3, 3].copy(), pitch, glo, shape)
            look_v = [ndimage.binary_fill_holes(lg.any(axis=ax)) for ax in range(3)]
    except Exception:
        look_v = None

    # (3.0.16, luka: "il_ruin_wall_broken_01, 02 and 03, il_corrupted_goo_03 and 04, il_ruin_pillar_big_01 ... the
    # existing methods should have done a better job there") A collision mesh is the solid only where it is the
    # thing: the Illuminate ruins carry one for a piece of the wall (a 4 m chunk of a 20 m wall, the foot of a 21 m
    # pillar), and il_ruin_roof_arch_02_broken a block that fills the arch. Seen from the two sides and above, the
    # collision must stand behind COLL_COVER of the thing as it looks and no more than COLL_OUT of it outside;
    # else the LOD0 shell is the solid, as for a kind with none.
    if coll and look_v is not None and body:
        cg = np.zeros(shape, dtype=bool)
        for g in grids:
            cg |= g
        both = sum(int((cg.any(axis=ax) & look_v[ax]).sum()) for ax in range(3))
        look_n = max(1, sum(int(look_v[ax].sum()) for ax in range(3)))
        coll_n = max(1, sum(int(cg.any(axis=ax).sum()) for ax in range(3)))
        if both < COLL_COVER * look_n or coll_n - both > COLL_OUT * coll_n:
            note += ': behind %.0f %% of the thing as it looks, %.0f %% of it outside — not its surface, the LOD0 shell instead' % (
                100 * both / look_n, 100 * (coll_n - both) / coll_n)
            coll = []
            srcs = [trimesh.util.concatenate([g[2] for g in body])]
            fill_all()

    def boxes_of(grids):
        # (3.0.16) which pieces are the solid. A piece is a coarse hull, and dropped, when it holds nine tenths of
        # all the others kept together — the whole thing wrapped once more. (The rule was "holds nine tenths of
        # ANY other piece": a real chunk with a small piece inside it went too — rock_pillar_05 lost 6 of its 12
        # pieces and ended at 2.6 m of 5.3.) The biggest first; the last one standing is never dropped
        order = sorted(range(len(grids)), key=lambda i: -int(grids[i].sum()))
        kept = set(i for i in order if grids[i].sum() > 0)
        for i in order:
            others = np.zeros(shape, dtype=bool)
            for j in kept:
                if j != i:
                    others |= grids[j]
            n_others = int(others.sum())
            if i in kept and n_others > 0 and (grids[i] & others).sum() >= 0.9 * n_others and grids[i].sum() > 1.05 * n_others:
                kept.discard(i)
        keep = [grids[i] for i in sorted(kept)]
        grid = np.zeros(shape, dtype=bool)
        for gi in keep:
            grid |= gi
        full = int(grid.sum())
        solid = grid
        if INNER_MARGIN > 0:
            grid = ndimage.binary_erosion(grid, iterations=INNER_MARGIN)
        # the inside boxes: the usual number, and up to INNER_MORE more while they hold under INNER_ENOUGH of the
        # solid (a tall pillar's narrow top came after the count was spent on its foot)
        base = INNER_MAX if size < 8 else INNER_MAX_BIG      # (a cliff or mountain: twice the boxes)
        stop_all = inner_boxes(grid, glo, pitch, max_boxes=base + INNER_MORE, thin=thin)
        n_solid = max(1, int(grid.sum()))
        stop, held_v = [], 0.0
        for k, b in enumerate(stop_all):
            if k >= base and held_v / (n_solid * pitch ** 3) >= INNER_ENOUGH:
                break
            stop.append(b)
            held_v += (b[1] - b[0]) * (b[3] - b[2]) * (b[5] - b[4])
        covered = sum((b[1] - b[0]) * (b[3] - b[2]) * (b[5] - b[4]) for b in stop)
        # the plates (from the pieces kept: a dropped hull's faces stood 0.4 m over rock_pillar_03) and the covering
        # boxes: candidates all, none over or under the mesh's own height
        cands = []
        for i in sorted(kept):
            cands += plates_of(srcs[i], stop)
        nplates_c = len(cands)
        cands += cover_boxes(solid, glo, pitch, stop, cands)
        z0, z1 = float(lo[2]) - 0.05, float(hi[2]) + 0.05
        clamped = []
        for k, o in enumerate(cands):
            top, bot = min(o[2] + o[5], z1), max(o[2] - o[5], z0)
            if top - bot >= 0.1:
                clamped.append((k < nplates_c, (o[0], o[1], (top + bot) / 2, o[3], o[4], (top - bot) / 2, o[6])))
        # (the inside boxes past the count are candidates too: one that fills in a pillar's narrow top is worth
        # more to a line than its volume says)
        extra = stop_all[len(stop):]
        for b in extra:
            clamped.append(('in', ((b[0] + b[1]) / 2, (b[2] + b[3]) / 2, (b[4] + b[5]) / 2, (b[1] - b[0]) / 2, (b[3] - b[2]) / 2, (b[5] - b[4]) / 2, 0.0)))
        # of those, the ones a line would meet: taken one at a time, each the one that adds the most of the solid's
        # outline (from the two sides and above) not yet behind a box, until one adds under half a percent or the
        # count is spent. (3.0.15 gave them what the inside boxes left of 16: a long wall's 16 small inside boxes
        # left nothing — cy_trench_wall_medium_3m_x4 had no plate at all)
        cells = glo + (np.indices(shape).reshape(3, -1).T + 0.5) * pitch
        boxg = np.zeros(len(cells), bool)
        for b in stop:
            boxg |= (cells[:, 0] >= b[0]) & (cells[:, 0] <= b[1]) & (cells[:, 1] >= b[2]) & (cells[:, 1] <= b[3]) & (cells[:, 2] >= b[4]) & (cells[:, 2] <= b[5])
        inner_g = boxg.reshape(shape).copy()
        sol_v = [solid.any(axis=ax) for ax in range(3)]
        sol_n = max(1, sum(int(v.sum()) for v in sol_v))
        have = [inner_g.any(axis=ax) for ax in range(3)]
        views = []
        for is_plate, o in clamped:
            g = in_obb(cells, o).reshape(shape)
            views.append([g.any(axis=ax) for ax in range(3)])
        over, nplates, left = [], 0, []
        for k in range(len(clamped)):                 # (one that stands too far outside the thing as it looks: not a candidate)
            if look_v is not None and clamped[k][0] != 'in':
                # (over the three views together no more than 15 %; and in any one view that is a fair share of the
                # box's outline — not a long wall seen end-on, where a sloped section always hangs out — a quarter)
                areas = [int(views[k][ax].sum()) for ax in range(3)]
                outs = [int((views[k][ax] & ~look_v[ax]).sum()) for ax in range(3)]
                tot = max(1, sum(areas))
                if sum(outs) > 0.15 * tot or any(areas[ax] >= 0.25 * tot and outs[ax] > OUTSIDE_MAX * areas[ax] for ax in range(3)):
                    continue
            left.append(k)
        cap = PLATE_CAP if size < 8 else PLATE_CAP_BIG
        while left and len(over) < cap:
            gains = [sum(int((views[k][ax] & sol_v[ax] & ~have[ax]).sum()) for ax in range(3)) for k in left]
            best = int(np.argmax(gains))
            if gains[best] < 0.005 * sol_n:
                break
            k = left.pop(best)
            if clamped[k][0] == 'in':
                stop.append(extra[k - (len(clamped) - len(extra))])
            else:
                over.append(clamped[k][1])
                nplates += 1 if clamped[k][0] else 0
            have = [have[ax] | views[k][ax] for ax in range(3)]
        plates = [None] * nplates
        # how much of the solid's cells lie in a box, the inside ones alone and with the others
        idx = np.argwhere(solid)
        pts = glo + (idx + 0.5) * pitch
        held = np.zeros(len(pts), bool)
        for b in stop:
            held |= (pts[:, 0] >= b[0]) & (pts[:, 0] <= b[1]) & (pts[:, 1] >= b[2]) & (pts[:, 1] <= b[3]) & (pts[:, 2] >= b[4]) & (pts[:, 2] <= b[5])
        inside = float(held.mean()) if len(pts) else 0.0
        for o in over:
            held |= in_obb(pts, o)
        shares = (inside, float(held.mean()) if len(pts) else 0.0)
        # what a line meets: the solid's silhouette from the unit's two sides and from above against the boxes'
        # — seen: how much of the solid's outline a box stands in front of; spill: how much of the boxes' outline
        # has no solid behind it (a line stopped in the open)
        for o in over:
            boxg |= in_obb(cells, o)
        boxg = boxg.reshape(shape)
        def sil(g):
            both, sol, out_, box = 0, 0, 0, 0             # (the three views added up by area: a wall's face counts as it is big)
            for ax in range(3):
                a, b2 = solid.any(axis=ax), g.any(axis=ax)
                seen_as = look_v[ax] if look_v is not None else a      # (spill: against the thing as it looks)
                # (3.0.16: "outline covered" too — against the solid it read 83 % on a wall whose collision mesh,
                # the solid then, was a fifth of the wall)
                both += (seen_as & b2).sum(); sol += seen_as.sum(); out_ += (b2 & ~seen_as).sum(); box += b2.sum()
            return (both / max(1, sol), out_ / max(1, box))
        shares = shares + sil(inner_g) + sil(boxg)
        return stop, covered, full * pitch ** 3, len(grids) - len(keep), over, shares, len(plates)

    def third_fill(res, note, air):
        # (3.0.16, luka: "these half destroyed buildings I would not mind if they got a large box in the middle that
        # ignores that it is collapsed inwards") The outline fill: what lies behind the thing's outline from both
        # sides and from above at once — a building with its windows, its fallen roof and its inside taken as one
        # block, a car with its cabin. Only for a shell (a collision mesh is the game's own word), and only where it
        # differs enough from the fills there are.
        if look_v is None or coll:
            return note
        outline = look_v[0][None, :, :] & look_v[1][:, None, :] & look_v[2][:, :, None]
        sol_g = np.zeros(shape, dtype=bool)
        for g in grids:
            sol_g |= g
        whole_g = np.zeros(shape, dtype=bool)
        for g in wholes:
            whole_g |= g
        out_n, sol_n, whole_n = int(outline.sum()), int(sol_g.sum()), int(whole_g.sum())
        best = whole_n if air > 0.03 else sol_n
        if out_n < OUTLINE_MORE * max(1, sol_n) or out_n < OUTLINE_OVER * max(1, best):
            return note
        hstop, hcov, hvol, _, hover, hshares, hplates = boxes_of([outline])
        if not hstop and not hover:
            return note
        res['stop_hull'], res['over_hull'] = hstop, hover
        res['info_hull'] = dict(cover=hcov / max(1e-9, hvol), vol=hvol, plates=hplates, seen_inside=hshares[2], seen=hshares[4], spill=hshares[5],
                                reach=max([b[5] for b in hstop] + [o[2] + o[5] for o in hover], default=0.0),
                                share=sol_n / max(1, out_n), auto=sol_n < OUTLINE_AUTO * out_n)
        return note + '; by its outline: %d boxes + %d (the solid as modelled is %.0f %% of it%s)' % (
            len(hstop), len(hover), 100 * sol_n / max(1, out_n), ', the first choice' if res['info_hull']['auto'] else '')

    if prev is not None:
        res = dict(prev[0])
        res['groups'] = groups
        res['v'] = RESULT_V
        return res, third_fill(res, prev[1], res.get('info', {}).get('air', 0))
    stop, covered, solid_vol, dropped, over, shares, nplates = boxes_of(grids)
    if dropped:
        note += ', %d hull%s dropped' % (dropped, 's' if dropped > 1 else '')
    note += '; %d boxes, %.0f %% of the solid' % (len(stop), 100 * covered / max(1e-9, solid_vol))
    if over:
        note += '; %d plates and %d covering boxes: %.0f %% of the solid in a box, up from %.0f' % (nplates, len(over) - nplates, 100 * shares[1], 100 * shares[0])
    # (for the review page) how much of the solid the boxes hold; how full the thing's convex hull is (an arch, a
    # cave or a ring is mostly air inside its hull); how far up from the root the boxes reach; how much of the
    # whole fill is open underneath
    hull_vol = 0.0
    try:
        from scipy.spatial import ConvexHull
        pts = np.concatenate([m.vertices for m in srcs])
        if len(pts) > 20000:
            pts = pts[np.random.default_rng(0).choice(len(pts), 20000, replace=False)]
        hull_vol = float(ConvexHull(pts).volume)
    except Exception:
        pass
    air = skirt.get('air', 0) / max(1, skirt.get('old', 0))
    info = dict(cover=covered / max(1e-9, solid_vol), solid=solid_vol, hull=hull_vol,
                fill=(solid_vol / hull_vol if hull_vol > 0 else 1.0),
                reach=max((b[5] for b in stop), default=0.0), source='collision' if coll else 'shell', pitch=pitch, air=air)
    res = dict(lo=lo, hi=hi, hit=[], stop=stop, groups=groups, info=info, over=over, v=RESULT_V)
    info['held'], info['held_over'] = shares[0], shares[1]
    info['seen_inside'], info['spill_inside'], info['seen'], info['spill'] = shares[2:6]
    info['plates'] = nplates
    # (the whole fill's boxes, where it differs: the kind may be solid in the game though open as modelled)
    if air > 0.03:
        wstop, wcov, wvol, _, wover, wshares, _ = boxes_of(wholes)
        res['stop_whole'], res['over_whole'] = wstop, wover
        res['info_whole'] = dict(cover=wcov / max(1e-9, wvol), reach=max((b[5] for b in wstop), default=0.0), vol=wvol,
                                 seen_inside=wshares[2], seen=wshares[4], spill=wshares[5])
        note += '; filled whole: %d boxes (%.0f %% of the fill is open underneath)' % (len(wstop), 100 * air)
    note = third_fill(res, note, air)
    return res, note


NAMES = {}             # hash -> content path, from --names (research/unit_names.json: luka's unit list and filediver's hashes.txt)


def hash_name(path):
    """The resource hash of a unit filediver has no name for: it writes the file as 0x<16 hex>.unit.glb (3.0.13)."""
    m = re.match(r'(?:0x)?([0-9a-fA-F]{16})\.', os.path.basename(path))
    return m.group(1).lower() if m else None


def unit_key(path):
    """(hash, name, content path or None) of an exported unit: the hash from its content path, or from a hash-named file."""
    cp = content_path(path)
    if cp and not hash_name(path):
        return '%016x' % murmur64(cp), os.path.basename(cp), cp
    h = hash_name(path)
    if h:
        cp = NAMES.get(h)                    # (--names: a newer name list knows units the exporting filediver did not)
        return h, os.path.basename(cp) if cp else h, cp
    return None, re.sub(r'\.unit\.glb$', '', os.path.basename(path)), None


def content_path(path):
    """content/.../name from a filediver export path (…/content/env_shared/assets/rocks/neutral/rock_01.unit.glb)."""
    p = path.replace('\\', '/')
    i = p.find('content/')
    if i < 0:
        return None
    p = p[i:]
    for suf in ('.unit.glb', '.glb'):
        if p.endswith(suf):
            p = p[:-len(suf)]
    return p


def fill_of(r, name, h, skip):
    """Which fill the review chose for the kind (tools/rock_skip.txt): 'hull' (~hash, by its outline), 'whole' (=hash,
    filled solid although open underneath) or '' (as modelled)."""
    if (r.get('stop_hull') or r.get('over_hull')) and (('~' + h) in skip or ('~' + name) in skip):
        return 'hull'
    if r.get('stop_whole') and (('=' + h) in skip or ('=' + name) in skip):
        return 'whole'
    return ''


def stop_of(r, name, h, skip):
    """The kind's inside boxes, of the fill the review chose."""
    f = fill_of(r, name, h, skip)
    return r.get('stop_hull') or [] if f == 'hull' else r['stop_whole'] if f == 'whole' else r['stop']


def over_of(r, name, h, skip):
    """The kind's plates and covering boxes, of the fill the review chose."""
    f = fill_of(r, name, h, skip)
    return (r.get('over_hull') if f == 'hull' else r.get('over_whole') if f == 'whole' else r.get('over')) or []


_STRUCT = None


def struct_kind(name, cp=None, h=None):
    """Whether the mod takes the kind for an enemy structure (12_struct's STRUCT_PAT and NOT_STRUCT, read from its
    source): the red mark tests those with shapes of their own, and a line asks the rocks first (12_throw) — a stop
    box on a bug hole's mound would end the throw before it reached the hole. A structure's marker unit is its mesh
    once more in the same place (bug_spawner_small_01_marker), so it counts too."""
    global _STRUCT
    if _STRUCT is None:
        src = open(os.path.join(ROOT, 'src', 'modules', '12_struct.lua'), encoding='utf-8').read()
        def strings(var):
            i = src.index('local %s = {' % var)
            body = re.sub(r'--[^\n]*', '', src[i:src.index('}', i)])      # (neither list nests a table)
            return re.findall(r"'([^']+)'", body)
        by_id = re.findall(r"\['([0-9a-f]{16})'\]", src[src.index('local STRUCT_BY_ID = {'):].split('\n', 1)[0])
        _STRUCT = (strings('STRUCT_PAT'), strings('NOT_STRUCT'), by_id)
        assert 'bug_spawner_small_01' in _STRUCT[0] and '_marker$' in _STRUCT[1] and 'f5f3207ca1b3a5d6' in by_id, _STRUCT
    pats, nots, by_id = _STRUCT
    if h in by_id:                               # (a structure by its hash: the Illuminate warp ship's hull)
        return True
    base = re.sub(r'_marker$', '', name)
    if not any(re.search(p, base) for p in pats):
        return False
    path = (cp or name).replace('content/', '', 1)
    return not any(re.search(p, path) or re.search(p, base) for p in nots if p != '_marker$')


STRUCT_WHY = 'an enemy structure: the red mark tests it with a shape of its own (12_struct), so it gets no stop boxes'


def left_out(r, name, h, skip, reach_min):
    """Why a kind is not written (None: it is). The review page shows the same verdicts."""
    if struct_kind(name, r.get('cp'), h):
        return STRUCT_WHY
    stop = stop_of(r, name, h, skip)
    over = over_of(r, name, h, skip)
    if not stop and over:
        stop = [(o[0] - o[3], o[0] + o[3], o[1] - o[4], o[1] + o[4], o[2] - o[5], o[2] + o[5]) for o in over]
    if not stop:
        return 'no box fits inside it'       # (too thin for one box: it stops nothing, so it isn't a kind to list)
    if name in skip or h in skip:
        return 'left out by eye (tools/rock_skip.txt)'
    reach = max(b[5] for b in stop)
    for o in over:                                         # (a plate or a covering box reaches up too)
        reach = max(reach, o[2] + o[5])
    reach = round(float(reach), 2)                         # (to the centimetre, as the review page shows it)
    if reach < reach_min and ('+' + h) not in skip and ('+' + name) not in skip:
        return 'its boxes reach %.2f m above its root, under %.2f' % (reach, reach_min)
    return None


def write_rocks(results, out):
    """results: hash -> the kind's dict (name, lo, hi, stop)."""
    lines = ['-- generated by tools/make_shapes.py --inner from filediver unit exports: the rocks\', walls\' and logs\' inscribed',
             '-- boxes, metres from the unit\'s root (hx, hy, hz, cx, cy, cz), inside the collision mesh by a voxel; `box` is the',
             '-- LOD0 mesh\'s half sizes and middle, for the scale against the engine\'s box. Keyed by the unit\'s resource hash.',
             'return {']
    skip, reach_min = read_skip()
    n = 0
    for h, r in sorted(results.items(), key=lambda kv: (kv[1].get('cp') or kv[1]['name'], kv[0])):
        if left_out(r, r['name'], h, skip, reach_min):
            continue
        n += 1
        lo, hi = r['lo'], r['hi']
        half = (hi - lo) / 2; mid = (hi + lo) / 2
        parts = []
        for b in stop_of(r, r['name'], h, skip):
            parts.append('{ %.2f, %.2f, %.2f, %.2f, %.2f, %.2f }' % ((b[1] - b[0]) / 2, (b[3] - b[2]) / 2, (b[5] - b[4]) / 2,
                                                                     (b[0] + b[1]) / 2, (b[2] + b[3]) / 2, (b[4] + b[5]) / 2))
        # (3.0.15) the plates and covering boxes after them: a 7th number, the box's turn about z, where it has one
        for o in over_of(r, r['name'], h, skip):
            if abs(o[6]) > 1e-4:
                parts.append('{ %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.4f }' % (o[3], o[4], o[5], o[0], o[1], o[2], o[6]))
            else:
                parts.append('{ %.2f, %.2f, %.2f, %.2f, %.2f, %.2f }' % (o[3], o[4], o[5], o[0], o[1], o[2]))
        lines.append("  ['%s'] = { name = '%s', box = { %.2f, %.2f, %.2f, %.2f, %.2f, %.2f }, stop = { %s } }," % (
            h, r['name'], half[0], half[1], half[2], mid[0], mid[1], mid[2], ', '.join(parts)))
    lines.append('}')
    with open(out, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    return n


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('glbs', nargs='*', help='.glb files or folders from filediver')
    ap.add_argument('--engine', action='append', default=[], help="'kind=hx,hy,hz' (half sizes) or 'kind=hx,hy,hz,ox,oy,oz' (and the middle's offset from the root: right, forward, up) from the research log's structure box line, to check the frame or to place the parts in the engine's box")
    ap.add_argument('--out', default=os.path.join(ROOT, 'src', 'struct_parts_generated.lua'))
    ap.add_argument('--pictures', default=os.path.join(ROOT, 'research', 'shapes'))
    ap.add_argument('--inner', action='store_true', help='the rocks: inscribed stop boxes from the collision meshes, keyed by resource hash (src/rock_parts_generated.lua)')
    ap.add_argument('--review', help='with --inner: write a review page here (one HTML file: every kind drawn with its boxes, to leave kinds out by eye) and no Lua')
    ap.add_argument('--census', help='with --review: a JSON file { hash: units on a map } (tools/shape_review.py --census makes it from ground logs)')
    ap.add_argument('--names', default=os.path.join(ROOT, 'research', 'unit_names.json'), help='a JSON file { hash: content path } that names the units exported by hash')
    ap.add_argument('--reviewed', action='store_true', help='with --inner: add the given folders\' kinds to tools/rock_reviewed.txt (luka has been through them) and stop')
    ap.add_argument('--cached', action='store_true', help='with --cache: every kind in the cache counts, also one whose export is not among the folders any more')
    ap.add_argument('--results', help='with --inner: a .json.gz of every kind\'s boxes (no pictures). Kinds in it and not among the folders or the cache count too; it is written anew with all of them (research/rock_results.json.gz: the data can be made again from it alone)')
    ap.add_argument('--cache', help='with --inner: a folder that keeps each kind\'s result, so a second run only does the new files')
    args = ap.parse_args()
    if args.names and os.path.exists(args.names):
        import json
        NAMES.update(json.load(open(args.names)))
    files = []
    for g in args.glbs:
        files += sorted(glob.glob(os.path.join(g, '**', '*.glb'), recursive=True)) if os.path.isdir(g) else [g]
    engine = {}
    for e in args.engine:
        k, v = e.split('=')
        engine[k] = [float(x) for x in v.split(',')]
    os.makedirs(args.pictures, exist_ok=True)
    if args.inner:
        out = args.out if args.out != os.path.join(ROOT, 'src', 'struct_parts_generated.lua') else os.path.join(ROOT, 'src', 'rock_parts_generated.lua')
        review = None
        if args.review:
            import shape_review
            review = shape_review.Review(args.census)
        if args.reviewed:
            have = read_reviewed()
            add = {}
            for f in files:
                h, kind, cp = unit_key(f)
                if h and h not in have:
                    add[h] = kind
            with open(REVIEWED_FILE, 'a', encoding='utf-8') as fh:
                for h, kind in sorted(add.items(), key=lambda kv: kv[1]):
                    fh.write('%s   # %s\n' % (h, kind))
            print('added', len(add), 'kinds to', REVIEWED_FILE)
            return
        results = {}
        been = read_reviewed()
        for f in files:
            h, kind, cp = unit_key(f)
            cached = args.cache and os.path.join(args.cache, (h or kind) + '.pkl')
            res = note = prev = None
            if cached and os.path.exists(cached) and os.path.getmtime(cached) >= os.path.getmtime(f):
                import pickle
                res, note = pickle.load(open(cached, 'rb'))
                # (a result from before the outline fill gets it added, its own boxes kept — but not a kind luka has
                # been through already: its picture is the one he passed)
                if review and res and res.get('v', 1) < RESULT_V and not res.get('skipped') and h not in been and \
                        (res.get('info') or {}).get('source') == 'shell':
                    prev, res = (res, note), None
            if res is None:
                try:
                    res, note = do_inner(f, keep=bool(review), prev=prev)
                except Exception as e:
                    res, note = (prev[0], prev[1] + '; the outline fill failed: %s' % e) if prev else (None, 'failed: %s' % e)
                    if prev:
                        res = dict(res); res['v'] = RESULT_V
                if res and h:
                    res['name'], res['cp'] = kind, cp
                    if review and 'groups' in res:
                        if not prev:
                            res['thumb'] = shape_review.thumb(res['groups'], res['lo'], res['hi'], res['stop'], res.get('over') or ())
                            if res.get('stop_whole'):
                                res['thumb_whole'] = shape_review.thumb(res['groups'], res['lo'], res['hi'], res['stop_whole'], res.get('over_whole') or ())
                        if res.get('stop_hull') or res.get('over_hull'):
                            res['thumb_hull'] = shape_review.thumb(res['groups'], res['lo'], res['hi'], res.get('stop_hull') or [], res.get('over_hull') or ())
                    elif not res.get('skipped'):
                        picture(f, res['groups'], res['lo'], res['hi'], [], res['stop'], os.path.join(args.pictures, kind + '.png'))
                    res.pop('groups', None)    # (the meshes: two hundred of them would not fit in memory)
                if cached and res and h:
                    import pickle
                    os.makedirs(args.cache, exist_ok=True)
                    pickle.dump((res, note), open(cached, 'wb'))
            print('%-36s %s' % (kind, note), flush=True)
            if not res or not h:
                continue
            if h in results:                   # (the same unit exported twice: one is enough)
                continue
            results[h] = res
            gc.collect()
        if args.cached and args.cache:           # (the kinds whose exports were deleted to make room: their results are all that is needed)
            import pickle
            for c in sorted(glob.glob(os.path.join(args.cache, '*.pkl'))):
                h = os.path.basename(c)[:-4]
                if h not in results and re.fullmatch(r'[0-9a-f]{16}', h):
                    res, note = pickle.load(open(c, 'rb'))
                    if res:
                        results[h] = res
        if args.results:                         # (the results without the pictures: what the data needs, kept in the repo)
            import json, gzip
            keep = ('name', 'cp', 'lo', 'hi', 'stop', 'over', 'stop_whole', 'over_whole', 'stop_hull', 'over_hull', 'skipped', 'v', 'info', 'info_whole', 'info_hull')
            def plain(v):
                if isinstance(v, dict):
                    return {k: plain(x) for k, x in v.items()}
                if isinstance(v, (list, tuple, np.ndarray)):
                    return [plain(x) for x in v]
                if isinstance(v, (np.floating, float)):
                    return float(v)                  # (in full: the data's numbers are rounded from these, and must come out the same)
                if isinstance(v, (np.integer, np.bool_)):
                    return int(v)
                return v
            if os.path.exists(args.results):
                for h, r in json.load(gzip.open(args.results, 'rt', encoding='utf-8')).items():
                    if h not in results:
                        r['lo'], r['hi'] = np.array(r['lo']), np.array(r['hi'])
                        results[h] = r
            with gzip.open(args.results, 'wt', encoding='utf-8') as fh:
                json.dump({h: {k: plain(r[k]) for k in keep if r.get(k) is not None} for h, r in sorted(results.items())}, fh, separators=(',', ':'))
            print('results:', args.results, len(results), 'kinds')
        if review:
            skip, reach_min = read_skip()
            for h, r in results.items():
                if struct_kind(r['name'], r.get('cp'), h) and not r.get('skipped'):      # (shown, with its picture, among the never candidates)
                    r = dict(r, stop=[], over=[], stop_whole=None, over_whole=None, stop_hull=None, over_hull=None, skipped='skipped: ' + STRUCT_WHY)
                review.add(h, r, r.get('skipped') or (None if (r['stop'] or r.get('stop_whole')) else 'no box fits inside it'))
            beside = review.write(args.review, reach_min, skip, read_reviewed())
            print('wrote', args.review, len(results), 'kinds' + (', its pictures in %d files beside it (publish them with it)' % len(beside) if beside else ''))
            return
        n = write_rocks({h: r for h, r in results.items() if not r.get('skipped')}, out)
        print('wrote', out, n, 'kinds of', len(results))
        return
    lines = ['-- generated by tools/make_shapes.py from filediver unit meshes (BSD): the structures\' parts in metres from',
             '-- the unit\'s root (right, forward, up), each { hx, hy, hz, cx, cy, cz } — abs: the shot goes in (red); stop_abs:',
             '-- solid (the line ends, no red; unused yet). See the pictures in research/shapes/. Edit the tool, not this file.', 'return {']
    for f in files:
        kind = re.sub(r'\.unit\.glb$', '', os.path.basename(f))
        res, note = do_kind(f, engine.get(kind), kind)
        print('%-28s %s' % (kind, note))
        if not res:
            continue
        picture(f, res['groups'], res['lo'], res['hi'], res['hit'], res['stop'], os.path.join(args.pictures, kind + '.png'))
        def lua(boxes):
            return ', '.join('{ %s }' % ', '.join('%g' % x for x in metres(b)) for b in boxes)
        lines.append("  ['%s'] = { -- %s" % (kind, note))
        lines.append('    abs = { %s },' % lua(res['hit']))
        lines.append('    stop_abs = { %s },' % lua(res['stop']))
        lines.append('  },')
    lines.append('}')
    with open(args.out, 'w') as fh:
        fh.write('\n'.join(lines) + '\n')
    print('wrote', args.out)


if __name__ == '__main__':
    main()
