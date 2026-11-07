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

Needs: pip install trimesh numpy scipy matplotlib
"""
import argparse, glob, os, re, sys
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


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('glbs', nargs='+', help='.glb files or folders from filediver')
    ap.add_argument('--engine', action='append', default=[], help="'kind=hx,hy,hz' (half sizes) or 'kind=hx,hy,hz,ox,oy,oz' (and the middle's offset from the root: right, forward, up) from the research log's structure box line, to check the frame or to place the parts in the engine's box")
    ap.add_argument('--out', default=os.path.join(ROOT, 'src', 'struct_parts_generated.lua'))
    ap.add_argument('--pictures', default=os.path.join(ROOT, 'research', 'shapes'))
    args = ap.parse_args()
    files = []
    for g in args.glbs:
        files += sorted(glob.glob(os.path.join(g, '**', '*.glb'), recursive=True)) if os.path.isdir(g) else [g]
    engine = {}
    for e in args.engine:
        k, v = e.split('=')
        engine[k] = [float(x) for x in v.split(',')]
    os.makedirs(args.pictures, exist_ok=True)
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
