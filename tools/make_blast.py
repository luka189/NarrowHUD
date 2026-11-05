"""NarrowHUD's blast radii (2.4.8): each explosive weapon's and grenade's full-damage (inner) and outer radius in
metres, for the blast zone painted where a drop or throw line lands (12_decal). From HD2Runtime's game-data
catalogues (https://github.com/SkyeShade/HD2Runtime, SkyeShade; credited in the README):
- support weapons: schemas/support_weapon_authoring_catalog.json, keyed by the weapon's unit resource, which
  src/weapon_units_generated.lua maps to our network type;
- primaries and sidearms: schemas/player_weapon_composition_catalog.json, by name, matched to src/ballistics_generated.lua;
- grenades: domains/explosion_catalogue.lua's throwable rows, matched to the grenade unit kinds (their resource paths
  in filediver's hash list, hashed the engine's way: 12_throw) by the table below, only where the pairing is plain.

    python3 tools/make_blast.py ../hd2runtime     # writes src/blast_generated.lua
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# the grenade unit kinds (12_throw: content/fac_helldivers/equipment/throwables/<name>/<name>) -> HD2Runtime's row
GRENADES = {
    '4ce9eab785a79b7b': 'throwable/g6_frag/detonation',                       # frag_grenade
    '6b11fc757618c57e': 'throwable/g12_high_explosive/detonation',            # he_grenade
    '7686544f539bb9b7': 'throwable/g16_impact/detonation',                    # impact_grenade
    '04653ab33f3ffb44': 'throwable/g10_incendiary/detonation',                # incendiary_grenade
    'eb725c39fc38b87c': 'throwable/g13_incendiary_impact/detonation',         # incendiary_impact_grenade
    'c5c05fcb5747c799': 'throwable/g123_thermite/detonation',                 # sticky_grenade (12_throw: the Thermite)
    '0080869506299773': 'throwable/g23_stun/detonation',                      # flashbang (12_throw: the Stun)
    'db922a7afc42894b': 'throwable/g31_arc/detonation',                       # arc_grenade
    '5de8fd02a05b4b0a': 'throwable/g3_smoke/detonation',                      # smoke_grenade
    '0416984f4922757b': 'throwable/g4_gas/detonation',                        # gas_grenade
    '46333fc9e3d4bd34': 'throwable/g48_giga_grenade/detonation',              # at_explosive_grenade (12_throw: the Giga)
    'ee4c107b941ab7f4': 'throwable/g40k_melta_mine/detonation',               # mine_shark (12_throw: the Melta Mine)
    'a20683199dfc19e8': 'throwable/tm1_lure_mine/detonation',                 # luring_mine
    '14368dc8784220b0': 'throwable/ted63_dynamite/detonation',                # dynamite
    '075b19b068fb1045': 'throwable/g7_pineapple/detonation',                  # cluster_frag_grenade
    '5c14f27759dd3be0': 'throwable/g8_immolation/detonation',                 # molotov_grenade (luka: the Immolation had no zone)
    'dab81b0d80b511c7': 'throwable/g89_smokescreen/detonation',               # impact_smoke_grenade
    '1b9ac59697006337': 'throwable/gsh39_shield/detonation',                  # energy_shield_grenade
}

SAME_AS_GL21 = { '17db8107': 'E/GL-21 Grenadier Battlement', '16425925': 'One-Two 40MM HE (underbarrel)' }


def lua_table(path):
    """a Lua file returning a table, read through lua (lupa)"""
    import lupa.lua51 as lua51
    rt = lua51.LuaRuntime()
    return rt.execute(Path(path).read_text(encoding='utf-8'))


def main(hd2rt):
    hd2rt = Path(hd2rt)
    units = dict((u, t) for t, u in re.findall(r"\['([0-9a-f]{8})'\] = '([0-9a-f]{16})'", (ROOT / 'src' / 'weapon_units_generated.lua').read_text()))
    ball = dict((n, t) for t, n in re.findall(r"\['([0-9a-f]{8})'\] = \{ name = '([^']+)'", (ROOT / 'src' / 'ballistics_generated.lua').read_text()))
    ball_ids = set(ball.values())
    out = {}
    # support weapons: the first attack with an explosion
    sup = json.load(open(hd2rt / 'schemas' / 'support_weapon_authoring_catalog.json'))
    for key, v in sup['candidates'].items():
        t = units.get(key.lower().replace('0x', ''))
        if not t or t not in ball_ids:
            continue
        for a in v.get('attacks') or []:
            rf = a.get('resolvedFields', {})
            if rf.get('explosion_outer_radius', 0) > 1:
                out[t] = (rf.get('explosion_inner_radius') or 0, rf['explosion_outer_radius'], next(n for n, i in ball.items() if i == t))
                break
    # primaries and sidearms, by name
    comp = json.load(open(hd2rt / 'schemas' / 'player_weapon_composition_catalog.json'))
    for name, w in comp['weapons'].items():
        t = ball.get(name)
        if not t or t in out:
            continue
        found = []
        def walk(o):
            if isinstance(o, dict):
                if isinstance(o.get('fields'), list):
                    vals = {f.get('id'): f.get('value') for f in o['fields'] if isinstance(f, dict)}
                    if vals.get('explosion.outer_radius'):
                        found.append((vals.get('explosion.inner_radius') or 0, vals['explosion.outer_radius']))
                for x in o.values(): walk(x)
            elif isinstance(o, list):
                for x in o: walk(x)
        walk(w)
        if found and found[0][1] > 1:        # (an outer radius of 1 m or less isn't a blast to paint: the Breacher's 1 / 1)
            out[t] = (found[0][0], found[0][1], name)
    # grenades
    # the C4 charge (12_throw's C4_CHARGE), keyed in the support catalogue by its own unit
    c4 = sup['candidates'].get('0x9B75217D8312DD67', {})
    for a in c4.get('attacks') or []:
        rf = a.get('resolvedFields', {})
        if rf.get('explosion_outer_radius'):
            gren_c4 = (rf.get('explosion_inner_radius') or 0, rf['explosion_outer_radius'], 'B-1 C4 charge (its backpack\'s)')
            break
    else:
        gren_c4 = None
    ex = lua_table(hd2rt / 'domains' / 'explosion_catalogue.lua')
    exps = ex['explosions']
    gren = {}
    for kind, row in GRENADES.items():
        e = exps[row]
        vals = e['values']
        gren[kind] = (vals[1], vals[2], e['label'])
    if gren_c4:
        gren['9b75217d8312dd67'] = gren_c4
    # (2.4.12, luka) the GL-21's 40 mm round, fired by the Grenadier Battlement and the One-Two's underbarrel too: the
    # catalogues don't list those two, so they take the GL-21's radii
    for t, n in SAME_AS_GL21.items():
        if '8c0aee6e' in out and t not in out:
            out[t] = (out['8c0aee6e'][0], out['8c0aee6e'][1], n + " (the GL-21's round)")
    lines = ['-- NarrowHUD blast radii, made by tools/make_blast.py from HD2Runtime\'s game-data catalogues',
             '-- (https://github.com/SkyeShade/HD2Runtime, SkyeShade): { inner, outer } in metres, the full-damage radius and',
             '-- the outer one. Weapons by network type, grenades by the thrown unit\'s kind.',
             'return {', '  weapons = {']
    for t in sorted(out, key=lambda k: out[k][2]):
        i, o, n = out[t]
        lines.append(f"    ['{t}'] = {{ {round(i, 2)}, {round(o, 2)} }},   -- {n}")
    lines += ['  },', '  grenades = {']
    for k in sorted(gren, key=lambda k: gren[k][2]):
        i, o, n = gren[k]
        lines.append(f"    ['{k}'] = {{ {round(i, 2)}, {round(o, 2)} }},   -- {n}")
    lines += ['  },', '}']
    (ROOT / 'src' / 'blast_generated.lua').write_text('\n'.join(lines) + '\n')
    print(len(out), 'weapons,', len(gren), 'grenades')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else ROOT.parent / 'hd2runtime')
