"""NarrowHUD's ballistics table (the drop line, 1.4.0): each weapon type's projectile numbers.

    python3 tools/make_ballistics.py /path/to/HD2Runtime src/ballistics_generated.lua

The numbers (mass in g, speed in m/s, drag factor, gravity factor) are the Helldivers 2 wiki's, as HD2Runtime's
data/wiki_*_weapons.json carries them; the projectile's diameter (mm), which the wiki doesn't give, comes from
HD2Runtime's projectile catalogue (domains/projectile_stats.lua, the game's own rows, by the weapon's row in
domains/attack_outputs.lua) where that row agrees with the wiki, else a class default. HD2Runtime by SkyeShade
(https://github.com/SkyeShade/HD2Runtime) allows this with visible credit (its LICENSE, section 2).

The game knows a weapon type only by a 32-bit hash; which hash is which weapon is learnt from play (NAMES below:
the weapon the tester held when the type first appeared). An id marked guess = true was matched by its magazine
and rate of fire alone and still needs a tester's word.
"""
import json
import re
import sys
from pathlib import Path

# type id -> wiki name (as data/wiki_*_weapons.json spells it); sure: seen in a tester's hands and named
NAMES = {
    '314a1bf5': ('PLAS-45 Epoch', True),
    '7bfb2e06': ('AC-8 Autocannon', True),
    'b2bfd847': ('GR-8 Recoilless Rifle', True),
    '3d538455': ('MLS-4X Commando', True),
    '83d1036e': ('FAF-14 Spear', True),
    '26acc614': ('RS-422 Railgun', True),
    '521229d8': ('M-105 Stalwart', True),
    'c7dfd9eb': ('P-113 Verdict', True),
    '8fcdd35c': ('AR-11 Arbitrator', True),
    'c920c2d3': ('P-92 Warrant', True),
    '9c06f074': ('SG-20 Halt', True),
    '366d3622': ('LAS-99 Quasar Cannon', True),
    'd100e0c8': ('LAS-98 Laser Cannon', True),
    '4e87d68d': ('LAS-58 Talon', True),
    '3622f8dc': ('LAS-12 Sai', True),
    '960653cb': ('LAS-17 Double-Edge Sickle', True),
    '42a6b5ba': ('LAS-5 Scythe', True),
    '8c0aee6e': ('GL-21 Grenade Launcher', True),
    '17db8107': ('E/GL-21 Grenadier Battlement', True, 'GL-21 Grenade Launcher'),   # (the emplacement: the same 40 mm round; luka, 2026-10-30)
    '6b47e064': ('GL-28 Belt-Fed Grenade Launcher', True),
    '303d2220': ('SG-8P Punisher Plasma', True),
    '36fcbd00': ('GP-20 Ultimatum', True),
    'eb38d34e': ('CB-9 Exploding Crossbow', True),
    '362577f7': ('GP-31 Grenade Pistol', True),
    'e1f10066': ('GL-52 De-Escalator', True),
    '6ec2a850': ('EAT-17 Expendable Anti-Tank', True),
    '17b02218': ('GL-15 Evictor', True),
    '2df95dfe': ('S-11 Speargun', True),
    'c0ff5282': ('EAT-411 Leveller', True),
    '8a3c6fee': ('RL-77 Airburst Rocket Launcher', True),
    '15ae0889': ('R-36 Eruptor', True),
    'd724a2f9': ('EAT-700 Expendable Napalm', True),
    'a41ddfcd': ('PLAS-1 Scorcher', True),
    'ba161726': ('PLAS-101 Purifier', True),
    '82a8d3c2': ('JAR-5 Dominator', True),
    # matched from players' logs, not a tester's naming: the Breacher by its 20 rpm (the only weapon at that rate),
    # one round, a pistol's hand pose (1), as a secondary in two players' logs of 2026-10-28
    'f94a73b3': ('P-34 Breacher', True),
    '3244dc49': ('AR/GL-21 One-Two', True),   # (2026-10-28: luka's log, 650 rpm, the underbarrel grenade launcher)
    # the One-Two's underbarrel launcher (its own type, the weapon shown while selected): the GP-31's round
    '16425925': ('One-Two 40MM HE (underbarrel)', True, 'GP-31 Grenade Pistol'),
    # the Re-Educator by its 110 rpm, 6 rounds, secondary (swap key 2) and the one-handed pose 36, in testers' logs
    '1d3b01d7': ('P-35 Re-Educator', True),
}
# a diameter by projectile class when the catalogue has none that agrees (mm)
DEFAULT_DIAMETER = [
    (lambda m, v: m >= 2000, 80), (lambda m, v: m >= 300, 40), (lambda m, v: v <= 120 and m >= 40, 40),
    (lambda m, v: m >= 40, 15), (lambda m, v: True, 8),
]


def wiki_rows(root):
    rows = {}
    for f in ['wiki_primary_weapons.json', 'wiki_support_weapons.json', 'wiki_player_weapons.json']:
        d = json.load(open(root / 'data' / f))
        for w in d['weapons']:
            for a in w.get('attacks', []):
                p = a.get('projectile') or {}
                def val(x): return x.get('value') if isinstance(x, dict) else x
                if val(p.get('initialVelocityMetersPerSecond')) and w['name'] not in rows:
                    rows[w['name']] = dict(m=val(p['massGrams']), v=val(p['initialVelocityMetersPerSecond']),
                                           drag=val(p['dragFactor']), g=val(p['gravityFactor']))
    return rows


def catalogue(root):
    """weapon name -> the diameter of its row in the game's projectile table, when that row's speed and mass match"""
    a = (root / 'domains' / 'attack_outputs.lua').read_text()
    s = (root / 'domains' / 'projectile_stats.lua').read_text()
    rows = {}
    for p in re.split(r'(?=\["output/v1/projectile/)', a)[1:]:
        m = re.match(r'\["output/v1/projectile/[^"]+"\]=\{id="[^"]+",family="projectile",owner=\{kind="([^"]+)",name="([^"]+)"\}', p)
        cd = re.search(r'currentDefault=(\d+)', p)
        if not m or not cd:
            continue
        i = s.find('[%s]={["flight"]={' % cd.group(1))
        if i < 0:
            continue
        seg = s[i:s.find('}', i)]
        fl = {k: float(v) for k, v in re.findall(r'\["(\w+)"\]=([-\d.]+)', seg)}
        rows.setdefault(m.group(2), []).append(fl)
    return rows


# corrections measured in game by testers, applied over the wiki's numbers (the line drawn against the shots' landing)
TUNED = {
    'f94a73b3': { 'g': 1.2 },   # the Breacher drops about a fifth more than the wiki's numbers say at 50 m (luka, 2026-10-28)
}


def main():
    root, out = Path(sys.argv[1]), Path(sys.argv[2])
    wiki, cat = wiki_rows(root), catalogue(root)
    lines = ['-- NarrowHUD ballistics, made by tools/make_ballistics.py: the projectile of each known weapon type.',
             '-- m grams, v m/s, drag and g factors (the Helldivers 2 wiki), d the diameter in mm (HD2Runtime\'s catalogue,',
             '-- https://github.com/SkyeShade/HD2Runtime, SkyeShade). guess: the type matched by its magazine and rate of fire alone.',
             'return {']
    for tid, entry in sorted(NAMES.items(), key=lambda kv: kv[1][0]):
        name, sure = entry[0], entry[1]
        source = entry[2] if len(entry) > 2 else name      # (a third value: the wiki weapon whose round it fires)
        w = wiki.get(source)
        if not w:
            print('no wiki projectile for', name, file=sys.stderr)
            continue
        d = None
        for fl in cat.get(source, []):
            if abs(fl.get('velocity', -1) - w['v']) < 1 and abs(fl.get('mass', -1) - w['m']) < 0.5:
                d = fl.get('diameter')
        if d is None:
            d = next(dd for test, dd in DEFAULT_DIAMETER if test(w['m'], w['v']))
            print('diameter by class for %s: %s mm' % (name, d), file=sys.stderr)
        w = dict(w, **TUNED.get(tid, {}))
        lines.append("  ['%s'] = { name = '%s', m = %s, v = %s, drag = %s, g = %s, d = %s%s%s }," % (
            tid, name.replace("'", "\\'"), w['m'], w['v'], w['drag'], w['g'], d, '' if sure else ', guess = true', ', tuned = true' if tid in TUNED else ''))
    lines.append('}')
    out.write_text('\n'.join(lines) + '\n')
    print('wrote', out, len(lines) - 5, 'weapons')


if __name__ == '__main__':
    main()
