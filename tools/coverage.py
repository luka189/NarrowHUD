"""What NarrowHUD knows and doesn't, as a report, and what the logs we have would add.

    python3 tools/coverage.py [--runtime /path/to/HD2Runtime] [narrowhud.log ...]

Three parts:
  1. The wiki's weapons (HD2Runtime's data/wiki_*_weapons.json) against the types NarrowHUD has a name for
     (tools/make_ballistics.py NAMES): which weapons have a drop line, which could (their shot drops) but have no
     name yet, and which never will (no drop).
  2. The game's handheld weapon types (src/data_generated.lua) against the shipped seed (src/learned_seed.lua): how
     many show before their first shot, how many don't.
  3. What the given logs add: types learned for a hand pose that the seed lacks (proposed EXTRA entries for
     tools/make_seed.py), and unnamed types seen in hand with the signature the log gives them (rpm, rounds,
     magazines, pose) and the wiki weapons that signature fits (candidates for NAMES, as the Breacher was found).
Default log set: research/logs/*.log when it exists.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNTIME = Path('/home/claude/hd2runtime')


def wiki(runtime):
    out = {}
    for f in ('wiki_primary_weapons.json', 'wiki_support_weapons.json', 'wiki_player_weapons.json'):
        p = runtime / 'data' / f
        if not p.exists():
            continue
        d = json.loads(p.read_text())
        items = d if isinstance(d, list) else d.get('weapons', d)
        for it in (items if isinstance(items, list) else items.values()):
            name = it.get('name')
            if not name:
                continue
            ws = it.get('weaponStats', {})
            def val(k):
                v = ws.get(k)
                return v.get('value') if isinstance(v, dict) else v
            proj = None
            for a in it.get('attacks', []) or []:
                if a.get('kind') == 'Projectile' and a.get('projectile'):
                    pj = a['projectile']
                    proj = dict(m=(pj.get('massGrams') or {}).get('value'), v=(pj.get('initialVelocityMetersPerSecond') or {}).get('value'),
                                drag=(pj.get('dragFactor') or {}).get('value'), g=(pj.get('gravityFactor') or {}).get('value'))
                    break
            out[name] = dict(slot=it.get('slot') or f.split('_')[1], rpm=val('fireRateRpm'), capacity=val('capacity'),
                             mags=val('startingMagazines') or val('magazines'), proj=proj)
    return out


def drops(proj):
    """a rough drop over 100 m of level flight, metres (no drag: an upper bound on the range, a lower one on the drop)"""
    if not proj or not proj.get('v') or not proj.get('g'):
        return None
    t = 100 / proj['v']
    return 0.5 * 9.81 * proj['g'] * t * t


def names():
    s = (ROOT / 'tools' / 'make_ballistics.py').read_text()
    return dict(re.findall(r"'(\w{8})': \('([^']+)', (?:True|False)", s))


def data_types():
    s = (ROOT / 'src' / 'data_generated.lua').read_text()
    body = s.split('weapons =')[1].split('backpacks =')[0]
    return {tid: roles for tid, _, roles in re.findall(r'(\w{8}) (\S+) (\w*)', body)}


def seed():
    """type id -> the hand poses the shipped seed has for it (grip and poses sections)"""
    s = (ROOT / 'src' / 'learned_seed.lua').read_text()
    out = {}
    for sect in ('grip', 'poses'):
        m = re.search(r'\n  ' + sect + r' = \{(.*?)\n  \}', s, re.S)
        if not m:
            continue
        for line in m.group(1).splitlines():
            km = re.match(r'\s+(?:\["(\w{8})"\]|(\w{8}))\s*=\s*"?([\d,]+)"?', line)
            if km:
                out.setdefault(km.group(1) or km.group(2), set()).update(int(x) for x in km.group(3).split(',') if x)
    return out


def mine(paths):
    """per type: poses it was learned for / shown at, the signature seen, how many logs"""
    seen = {}
    for p in paths:
        text = Path(p).read_text(encoding='utf-8', errors='ignore')
        for tid, pose in re.findall(r'learned: type (\w{8}) goes with hand pose (\d+)', text):
            seen.setdefault(tid, {'poses': set(), 'logs': set(), 'sig': {}})['poses'].add(int(pose)); seen[tid]['logs'].add(p)
        # (a "hand pose N: type" line says the type was shown at that pose, which it stays through a sprint or a
        # climb: presence only, not a pose to seed)
        for pose, tid in re.findall(r'hand pose (\d+): (\w{8})', text):
            seen.setdefault(tid, {'poses': set(), 'logs': set(), 'sig': {}})['logs'].add(p)
        for tid, n, l in re.findall(r'type (\w{8}): learned for (\d+) hand poses \(([\d,]+)\)', text):
            seen.setdefault(tid, {'poses': set(), 'logs': set(), 'sig': {}})['suspect'] = f'{n} poses ({l}): a soldier\'s gun, or swaps learned wrong'
        for tid in re.findall(r'type (\w{8}): what was learned of its hand poses and key forgotten \(its objects aim by themselves\)', text):
            seen.setdefault(tid, {'poses': set(), 'logs': set(), 'sig': {}})['suspect'] = 'aims by itself: not a weapon of yours'
        for tid, fm, rpm in re.findall(r'fields (\w{8}): fire_mode=(\S+) options=\S+ rpm=(\S+)', text):
            if tid in seen and re.match(r'^[\d.]+$', rpm):
                seen[tid]['sig']['rpm'] = float(rpm)
        for tid, body in re.findall(r'research: all fields: weapon(?: in hand)? (\w{8}) \(object \d+\): (.*)', text):
            if tid not in seen:
                continue
            for key, label in (('rounds', 'rounds_remaining'), ('mags', 'magazines_remaining'), ('rpm', 'rpm'), ('slot0', 'slot0')):
                m = re.search(r'(?:=| )' + label + r'=([\d.]+)', body)
                if m:
                    v = float(m.group(1))
                    seen[tid]['sig'][key] = max(seen[tid]['sig'].get(key, 0), v)
        for tid in re.findall(r'weapon (\w{8}): no projectile numbers known', text):
            seen.setdefault(tid, {'poses': set(), 'logs': set(), 'sig': {}})['logs'].add(p)
    return seen


def candidates(sig, W):
    out = []
    for name, w in W.items():
        score = 0
        if sig.get('rpm') and w['rpm'] and abs(sig['rpm'] - w['rpm']) < 1:
            score += 2
        cap = sig.get('rounds') or sig.get('slot0')
        if cap and w['capacity'] and abs(cap - w['capacity']) <= 1:
            score += 1
        if score >= 2:
            out.append((score, name))
    return [n for _, n in sorted(out, reverse=True)]


def main():
    args = sys.argv[1:]
    runtime = RUNTIME
    if '--runtime' in args:
        i = args.index('--runtime'); runtime = Path(args[i + 1]); del args[i:i + 2]
    logs = args or sorted(str(p) for p in (ROOT / 'research' / 'logs').glob('*.log'))
    W, N, D, S = wiki(runtime), names(), data_types(), seed()
    named = set(N.values())
    print('1. The wiki\'s weapons against the named types (drop lines)')
    for slot in ('primary', 'secondary', 'support'):
        rows = [(n, w) for n, w in W.items() if w['slot'] == slot]
        has = [n for n, _ in rows if n in named]
        could = [n for n, w in rows if n not in named and (drops(w['proj']) or 0) >= 0.5]
        never = [n for n, w in rows if n not in named and (drops(w['proj']) or 0) < 0.5]
        print(f'   {slot}: {len(rows)} weapons: {len(has)} named (drop line), {len(could)} drop but unnamed, {len(never)} no drop or no projectile')
        if could:
            print('      drop but unnamed: ' + ', '.join(sorted(could)))
    print()
    handheld = {t for t, roles in D.items() if 'n' in roles}
    seeded = handheld & set(S)
    print(f'2. The seed: {len(seeded)} of {len(handheld)} handheld weapon types show before their first shot; {len(handheld - seeded)} learn from it')
    print()
    seen = mine(logs)
    print(f'3. {len(logs)} logs: {len(seen)} weapon types seen in hand')
    extra = {t: v for t, v in seen.items() if t in handheld and t not in S and v['poses']}
    if extra:
        print('   learned for a pose but not in the seed (proposed for make_seed.py EXTRA; check the pose is the firing one):')
        for t, v in sorted(extra.items(), key=lambda kv: -len(kv[1]['logs'])):
            print(f"     '{t}': poses {sorted(v['poses'])} in {len(v['logs'])} log(s), sig {v['sig']}" + (f"  SUSPECT: {v['suspect']}" if v.get('suspect') else ''))
    unnamed = {t: v for t, v in seen.items() if t not in N and t in handheld}
    if unnamed:
        print('   seen but unnamed (no drop line; the wiki weapons whose rpm and capacity fit):')
        for t, v in sorted(unnamed.items(), key=lambda kv: -len(kv[1]['logs'])):
            c = candidates(v['sig'], W)
            if v.get('suspect'):
                continue
            print(f"     {t}: sig {v['sig']} learned at {sorted(v['poses'])} in {len(v['logs'])} log(s)" + (f" -> {', '.join(c[:4])}" if c else ''))


if __name__ == '__main__':
    main()
