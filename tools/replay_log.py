"""Replay a narrowhud.log (with the research log on) through the test harness's fake game, and check what the
current build makes of it: the field values, hand poses and shots a player really had, instead of a hand-made
scenario.

    python3 tools/build.py && python3 tools/replay_log.py narrowhud.log [more logs ...] [-v] [--learned <the player's learned file>]
    python3 tools/build.py && python3 tools/replay_log.py --suite          # every log in research/logs, in parallel,
                                                                           # against research/logs/baseline.json

The suite (research/logs, private: testers' and reporters' logs with the research log on) is the regression set:
each fix that came from a log adds that log; --suite fails on any session with more misses than the baseline
records (a known, accepted miss is listed there with the reason). Run it before a release.

What's replayed, per session (each "NarrowHUD x.y.z:" start): the objects the research log lists ("all fields: <label>
<type> (object N): #i hash=name=value ..."), their changes ("... <type>: #i name old>new"), the hand pose lines, and
the fire button taken as held while any of those weapons reads is_firing (the log doesn't carry the button itself).
Fields are mapped from their hash to the role NarrowHUD reads (src/data_generated.lua); fields NarrowHUD doesn't
read are dropped.

Checks (each miss printed with its time):
  shown      a shot of yours (your Helldiver's stance field flicking, logged with the hand pose) has the HUD
             showing a weapon a second later
  not-yours  a type that fired as the weapon in hand was called someone else's (a false alarm unless you were host
             with SEAF soldiers around)
  count      the count shown agrees with the in-hand weapon's rounds (or slot) field when it changes
A session with no misses is one the current build handles as the player would expect.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tests'))
import run_tests as T                      # noqa: E402  (the harness: SRC, setup, type_name, role names)
import lupa.lua51 as lua51                 # noqa: E402

ROLES = {rid.rjust(8, '0'): (role, name) for role, rid, name in
         re.findall(r'(\w+) = \{ letter = "\w", id = "(\w+)", name = "([^"]+)" \}', T.DATA)}
ROLE_NAME = {role: name for _, (role, name) in ROLES.items()}
PLAYER_TID, AVATAR_TID = '803159b3', '5d9752f9'
START = re.compile(r'^(\d\d:\d\d:\d\d)\s+([\d.]+) s \| (.*)$')
OBJ_LINE = re.compile(r'^research: all fields: (weapon in hand|weapon|backpack|carried|your Helldiver|your player|object in your Helldiver\'s \S+) (\w{8}) \(object (\d+)\): (.*)$')
CHG_LINE = re.compile(r'^research: all fields: (weapon in hand|weapon|backpack|carried|your Helldiver|your player|object in your Helldiver\'s \S+) (\w{8}): (#.*)$')
POSE_LINE = re.compile(r'^hand pose (\d+|nil): (.*)$')


def value(s):
    s = s.strip()
    if s in ('true', 'false'):
        return s == 'true'
    try:
        return int(s)
    except ValueError:
        pass
    try:
        return float(s)
    except ValueError:
        return None                          # (a vector, a list, a string: nothing NarrowHUD reads as a role)


def parse(path):
    """-> sessions: [{ start, events: [(t, kind, data)] }]"""
    sessions = []
    cur = None
    for line in open(path, encoding='utf-8', errors='ignore'):
        m = START.match(line.rstrip('\n'))
        if not m:
            continue
        clock, t, msg = m.group(1), float(m.group(2)), m.group(3)
        if re.match(r'^NarrowHUD [\d.]+: ', msg):
            cur = {'start': clock, 'version': msg.split(':')[0], 'events': []}
            sessions.append(cur)
            continue
        if cur is None:
            continue
        mo = OBJ_LINE.match(msg)
        if mo:
            label, tid, goid, body = mo.groups()
            fields = {}
            for part in re.split(r', (?=#\d+ )', body):
                tok = part.split(' ', 1)
                if len(tok) < 2:
                    continue
                first = tok[1].split(' ', 1)[0]
                bits = first.split('=')
                h = bits[0].rjust(8, '0')
                if h in ROLES and len(bits) >= 2:
                    v = value(bits[-1])
                    if v is not None:
                        fields[ROLES[h][1]] = v
            cur['events'].append((t, 'object', (label, tid, int(goid), fields)))
            continue
        mc = CHG_LINE.match(msg)
        if mc:
            label, tid, body = mc.groups()
            changes = {}
            for part in re.split(r', (?=#\d+ )', body):
                tok = part.split(' ', 1)
                if len(tok) < 2:
                    continue
                first, _, after = tok[1].partition(' ')
                h = first.split('=')[0].rjust(8, '0')
                # (after: 'name old>new' or 'old>new')
                if '>' not in after:
                    continue
                oldnew = after.rsplit(' ', 1)[-1] if after.count(' ') and '>' in after.rsplit(' ', 1)[-1] else after
                new = oldnew.split('>', 1)[1]
                if h in ROLES:
                    v = value(new)
                    if v is not None:
                        changes[ROLES[h][1]] = v
            if changes:
                cur['events'].append((t, 'change', (label, tid, changes)))
            continue
        mp = POSE_LINE.match(msg)
        if mp:
            cur['events'].append((t, 'pose', (mp.group(1), mp.group(2))))
            continue
        ma = re.match(r'^research: field 95c46304 \(aim\) 0 > 4 at hand pose (\d+)', msg)
        if ma:
            cur['events'].append((t, 'shot', int(ma.group(1))))
            continue
        if msg.startswith('objects sorted:'):
            cur['events'].append((t, 'world', None))
        elif 'not yours' in msg or "isn't yours" in msg or 'never shown' in msg:
            cur['events'].append((t, 'verdict', msg))
    return sessions


HELD = ROLE_NAME['held'] if 'held' in ROLE_NAME else None


def replay(session, verbose=False, learned=None):
    r = lua51.LuaRuntime()
    T.setup(r, seeded=True)               # (the shipped seed, as a player has it)
    if learned:                            # (the player's own learned file, as NarrowHUD would read it)
        r.execute('saved = (function() ' + learned + ' end)()')
    r.execute('for k in pairs(OBJ) do if k > 2 then OBJ[k] = nil end end FIRE = false GRIP = 0')
    g = r.globals()
    objs = {}                              # log goid -> (mock goid, tid, label)
    by_type = {}                           # (label, tid) and tid -> log goid
    fired = []                             # (t, tid) is_firing false>true of a weapon
    misses = []
    pending = []                           # (check_at, kind, data)
    now = 0.0
    held_of = {}                           # mock goid -> is_firing
    shown_log = {}                         # tid -> True once the log itself showed it
    vals = {}                              # mock goid -> { role name: value } (to see a count go down)
    fire_until = -1.0                      # (a count drop of the weapon in hand: the button taken as pressed 0.3 s)
    COUNTS = [ROLE_NAME[k] for k in ('rounds', 'slot0', 'slot1') if k in ROLE_NAME]

    def mock_id(goid, tid):
        if tid == PLAYER_TID:
            return 1
        if tid == AVATAR_TID:
            return 2
        return goid + 10

    def set_fields(mid, fields):
        down = False
        for name, v in fields.items():
            lv = 'true' if v is True else ('false' if v is False else repr(v))
            r.execute(f'OBJ[{mid}].fields["{name}"] = {lv}')
            if name == HELD:
                held_of[mid] = v is True
            old = vals.setdefault(mid, {}).get(name)
            if name in COUNTS and isinstance(old, (int, float)) and isinstance(v, (int, float)) and v < old:
                down = True
            vals[mid][name] = v
        return down

    def advance(to):
        nonlocal now
        while pending and pending[0][0] <= to:
            at, kind, data = pending.pop(0)
            if at > now:
                r.execute(f'run({at - now:.3f})')
                now = at
            if kind == 'shown':
                t0, tid = data
                texts = r.eval('texts()')
                if not re.search(r'\d', texts):
                    misses.append((t0, 'shown', f'a shot {tid}, nothing shown a second later [{texts}]'))
        if to > now:
            r.execute(f'run({to - now:.3f})')
            now = to

    for t, kind, data in session['events']:
        advance(t)
        if kind == 'world':
            continue
        if kind == 'object':
            label, tid, goid, fields = data
            mid = mock_id(goid, tid)
            name = {PLAYER_TID: g.NAMES['player'], AVATAR_TID: g.NAMES['avatar']}.get(tid) or T.type_name(tid)
            if name is None:
                continue
            if mid > 2 or r.eval(f'OBJ[{mid}] == nil'):
                r.execute(f'OBJ[{mid}] = {{ name = "{name}", fields = {{}} }}')
            objs[goid] = (mid, tid, label)
            by_type[(label, tid)] = goid
            by_type[tid] = goid
            set_fields(mid, fields)
        elif kind == 'change':
            label, tid, changes = data
            goid = by_type.get((label, tid)) or by_type.get(tid)
            if goid is None:
                continue
            mid, _, _ = objs[goid]
            set_fields(mid, changes)
        elif kind == 'shot':
            # your Helldiver's stance field flicks 0 > 4 on each shot of yours (logged with the hand pose): the
            # fire button taken as pressed, and a weapon must be showing a second later
            fired.append((t, 'pose %d' % data))
            fire_until = t + 0.3
            pending.append((t + 1.0, 'shown', (t, 'at hand pose %d' % data)))
            pending.sort()
        elif kind == 'pose':
            pose, what = data
            r.execute(f'GRIP = {pose if pose != "nil" else "nil"}')
            if re.match(r'^\w{8}$', what):
                shown_log[what] = True
        elif kind == 'verdict':
            pass
        # the fire button: held while any weapon of yours reads is_firing, and just after a shot of the one in hand
        r.execute('FIRE = ' + ('true' if (any(held_of.values()) or now < fire_until) else 'false'))
    advance(now + 1.5)
    # the build's own verdicts in this replay
    logs = list(r.eval('logs').values())
    # a verdict against a type the log itself showed in your hand (a false alarm unless you were host with SEAF
    # soldiers' guns about)
    for l in logs:
        if ('not yours' in l or "isn't yours" in l) and any(tid in l for tid in shown_log):
            misses.append((None, 'not-yours', l))
    return {'fired': len(fired), 'misses': misses, 'logs': logs, 'events': len(session['events'])}


def suite():
    """every log in research/logs against the baseline; 1 on any session over its baseline"""
    import json
    from concurrent.futures import ProcessPoolExecutor
    folder = ROOT / 'research' / 'logs'
    base_path = folder / 'baseline.json'
    baseline = json.loads(base_path.read_text()) if base_path.exists() else {}
    paths = sorted(folder.glob('*.log'))
    bad, results = 0, {}
    with ProcessPoolExecutor() as pool:
        for path, out in zip(paths, pool.map(suite_one, paths)):
            results[path.name] = out
            for start, version, shots, misses in out:
                allowed = baseline.get(path.name, {}).get(start, {}).get('misses', 0)
                flag = '' if len(misses) <= allowed else '  <-- over the baseline'
                if flag:
                    bad += 1
                print(f'{path.name} {start} {version}: {shots} shots, {len(misses)} misses (baseline {allowed}){flag}')
                for t, kind, text in misses[:5]:
                    print(f"     {('%.1f s' % t) if t is not None else '      '} {kind}: {text[:150]}")
    print(f'{len(paths)} logs, {sum(len(v) for v in results.values())} sessions, {bad} over the baseline')
    return 1 if bad else 0


def suite_one(path):
    out = []
    for s in parse(path):
        if not any(k == 'object' for _, k, _ in s['events']):
            continue
        res = replay(s)
        out.append((s['start'], s['version'], res['fired'], res['misses']))
    return out


def main():
    if '--suite' in sys.argv:
        return suite()
    verbose = '-v' in sys.argv
    args = [a for a in sys.argv[1:] if a != '-v']
    learned = None
    if '--learned' in args:
        i = args.index('--learned')
        learned = Path(args[i + 1]).read_text(encoding='utf-8', errors='ignore')
        del args[i:i + 2]
    paths = args
    total_miss = 0
    for path in paths:
        sessions = parse(path)
        print(f'{path}: {len(sessions)} sessions')
        for s in sessions:
            if not any(k == 'object' for _, k, _ in s['events']):
                continue
            res = replay(s, verbose, learned)
            total_miss += len(res['misses'])
            print(f"  {s['start']} {s['version']}: {res['events']} events, {res['fired']} shots, {len(res['misses'])} misses")
            for t, kind, text in res['misses'][:8]:
                print(f"     {('%.1f s' % t) if t is not None else '      '} {kind}: {text[:160]}")
            if verbose:
                for l in res['logs']:
                    if 'learned' in l or 'not yours' in l or 'forgotten' in l:
                        print('       log:', l[:160])
    return 1 if total_miss else 0


if __name__ == '__main__':
    sys.exit(main())
