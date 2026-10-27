"""Fit the throws in a research log (the "research: throw flight" lines of 1.5.0): each thrown unit's positions
over its first seconds give its release speed and angle, against the aim NarrowHUD drew.

    python3 tools/fit_throws.py narrowhud.log

For each flight: a parabola p(t) = p0 + v0 t + g t^2 / 2 (g = 9.81 down, no drag) by least squares on the samples;
the flight run back to the height it was let go at (the aim's release point, logged with the flight), and the
speed there, its pitch above the horizontal, and the pitch of the aim NarrowHUD used (the camera's plus LIFT)
printed, with the fit's error. Then the mean over the throws of each kind: the numbers for THROW in
src/modules/12_throw.lua (LIFT = the fitted pitch minus the camera's pitch).
"""
import math
import re
import sys
from collections import defaultdict

LIFT = {'ball': math.radians(5.8), 'c4': math.radians(5), 'grenade': math.radians(8)}   # (as 12_throw.lua has them)


def fit(pts):
    """least squares for p0, v0 with gravity known: minimise |p(t) - (p0 + v0 t - g t^2/2 z)|"""
    n = len(pts)
    st = sum(t for t, *_ in pts)
    stt = sum(t * t for t, *_ in pts)
    det = n * stt - st * st
    if det == 0:
        return None
    out = []
    for i, g in ((1, 0), (2, 0), (3, 9.81)):
        sv = sum(p[i] + g * p[0] ** 2 / 2 for p in pts)
        svt = sum((p[i] + g * p[0] ** 2 / 2) * p[0] for p in pts)
        p0 = (sv * stt - svt * st) / det
        v0 = (n * svt - st * sv) / det
        out.append((p0, v0))
    err = 0
    for t, x, y, z in pts:
        px = out[0][0] + out[0][1] * t
        py = out[1][0] + out[1][1] * t
        pz = out[2][0] + out[2][1] * t - 9.81 * t * t / 2
        err += (px - x) ** 2 + (py - y) ** 2 + (pz - z) ** 2
    return out, math.sqrt(err / n)


class _Shift:
    """the match with the (aimed) / (quick) group taken out of the numbering: group(0) is it, the rest as before"""
    def __init__(self, m): self.m = m
    def group(self, i): return self.m.group(4) if i == 0 else (self.m.group(i) if i < 4 else self.m.group(i + 1))


def main():
    text = open(sys.argv[1], encoding='utf-8', errors='ignore').read()
    by_kind = defaultdict(list)
    for m in re.finditer(r'research: throw flight: (\w+) (\w+); aim (\w+)(?: \((\w+)\))? pitch ([-\d.]+) speed ([-\d.]+) at ([-\d.]+) s before(?: from ([-\d.,?]+))?; feet ([-\d.,?]+); (.*)', text):
        m = _Shift(m)
        kind, aim_kind, aim_pitch, aim_speed = m.group(2), m.group(3) + (' ' + m.group(0) if m.group(0) else ''), float(m.group(4)), float(m.group(5))
        release = [float(v) for v in m.group(7).split(',')] if m.group(7) and m.group(7) != '?' else None
        feet = [float(v) for v in m.group(8).split(',')] if m.group(8) != '?' else None
        pts = []
        for s in m.group(9).split():
            t, xyz = s.split(':')
            x, y, z = (float(v) for v in xyz.split(','))
            pts.append((t and float(t), x, y, z))
        # the flight proper: from the first sample moving faster than 8 m/s (before it, the thing sat in the hand)
        # until it slows (lands, bounces) or 1.2 s, whichever first
        flying = []
        for i in range(1, len(pts)):
            dt = pts[i][0] - pts[i - 1][0]
            if dt <= 0:
                continue
            sp = math.dist(pts[i][1:], pts[i - 1][1:]) / dt
            if not flying and sp > 8:
                flying.append(pts[i - 1])
            if flying:
                if sp < 6 or pts[i][0] - flying[0][0] > 1.2:
                    break
                flying.append(pts[i])
        pts = flying
        if len(pts) < 8:                             # (a throw into the ground: too short to fit)
            continue
        t_first = pts[0][0]
        pts = [(t - t_first, x, y, z) for t, x, y, z in pts]
        r = fit(pts)
        if not r:
            continue
        (x0, vx), (y0, vy), (z0, vz) = r[0]
        # the flight run back to the height it was let go at: the aim's release point when the aim was drawn, else
        # the feet + 2 m (an arm up; grenades 1.5)
        zr = release[2] if release else (feet[2] + (1.5 if kind == 'grenade' else 2.0) if feet else pts[0][3])
        a, b, c = -9.81 / 2, vz, z0 - zr
        d = b * b - 4 * a * c
        tr = 0 if d < 0 else min(((-b + math.sqrt(d)) / (2 * a), (-b - math.sqrt(d)) / (2 * a)), key=abs)   # (the root nearest the first sample, not a second earlier on the rising branch)
        vzr = vz - 9.81 * tr
        speed = math.sqrt(vx * vx + vy * vy + vzr * vzr)
        pitch = math.atan2(vzr, math.sqrt(vx * vx + vy * vy))
        cam_pitch = aim_pitch - LIFT.get(aim_kind.split()[0], 0)
        # What matters is where it lands: from the aim's release point R, which pitch (at the drawn speed) and which
        # speed (at the drawn pitch) take the line through the flight's farthest sample P. Those are the lift and
        # speed to draw with; the fit's own pitch depends on where the throw was really let go, which isn't known.
        eff_lift, eff_speed, gaps = None, None, ''
        if release and aim_kind.split()[0].lower() == kind.lower():
            P = max(pts, key=lambda q: q[0])
            hx, hy = P[1] - release[0], P[2] - release[1]
            D = math.hypot(hx, hy)
            hx, hy = hx / D, hy / D
            # the drawn line's height at a horizontal distance d from the release point
            def zline(d, theta, sp):
                return release[2] + d * math.tan(theta) - 9.81 * d * d / (2 * sp * sp * math.cos(theta) ** 2)
            # the flight against the line: how far below (-) or above it the thing really was, every 4 m or so
            gl = []
            for t, x, y, z in pts:
                d = (x - release[0]) * hx + (y - release[1]) * hy
                if not gl or d - gl[-1][0] >= 4:
                    gl.append((d, z - zline(d, aim_pitch, aim_speed)))
            gaps = '  flight against the line: ' + ' '.join('%.0fm %+.2f' % g for g in gl)
            # the flight's point at P's time, from the fit (smoother than the sample)
            px, py, pz = x0 + vx * P[0], y0 + vy * P[0], z0 + vz * P[0] - 9.81 * P[0] ** 2 / 2
            H = pz - release[2]
            # the pitch (at the drawn speed) and the speed (at the drawn pitch) whose line passes through that
            # point: the nearest to the drawn ones
            best = min((abs(zline(D, math.radians(d / 10), aim_speed) - release[2] - H) + abs(math.radians(d / 10) - aim_pitch) * 0.01, d / 10) for d in range(-600, 800))
            eff_lift = math.radians(best[1]) - cam_pitch
            best = min((abs(zline(D, aim_pitch, sp / 10) - release[2] - H), sp / 10) for sp in range(100, 400))
            eff_speed = best[1]
        print('%-8s aim %-14s fit: speed %5.1f m/s pitch %6.2f deg (camera %6.2f: lift %5.2f) rms %.2f m, %d pts, %.1f m up%s' % (
            kind, aim_kind, speed, math.degrees(pitch), math.degrees(cam_pitch), math.degrees(pitch - cam_pitch), r[1], len(pts), (pts[0][3] - feet[2]) if feet else 0,
            '  to pass through its end: lift %.1f deg at the drawn %.1f m/s, or %.1f m/s at the drawn lift' % (math.degrees(eff_lift), aim_speed, eff_speed) + gaps if eff_lift is not None
            else '  (no aim drawn for it, or another kind: the lift means nothing here)'))
        by_kind[kind].append((speed, pitch - cam_pitch, aim_speed, eff_lift is not None and r[1] < 0.5, eff_lift, eff_speed, 'aimed' in aim_kind))
    for kind, l in by_kind.items():
        n = len(l)
        good = [x for x in l if x[3]]
        for label, sel in (('all', good), ('aimed', [x for x in good if x[6]]), ('quick', [x for x in good if not x[6]])):
            if not sel:
                continue
            print('%s, %s: %d of %d throws with a line drawn and a clean fit: to land right, lift %.1f deg at the drawn speed, or %.1f m/s at the drawn lift (the fits\' own speed %.1f)' % (
                kind, label, len(sel), n, math.degrees(sum(x[4] for x in sel) / len(sel)), sum(x[5] for x in sel) / len(sel),
                sum(x[0] for x in sel) / len(sel)))


if __name__ == '__main__':
    main()
