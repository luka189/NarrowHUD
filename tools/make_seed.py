"""Make src/learned_seed.lua (NarrowHUD's shipped starting knowledge) from a learned file.

    python3 tools/make_seed.py chef_data_luka189_narrowhud_learned.lua [--drop id,id,...]

The learned file is in %APPDATA%\\Arrowhead\\Helldivers2. --drop leaves out types that aren't the player's own weapons
(SEAF troops' rifles, guard dog weapons ...): every entry of theirs, in every table. The 'drone' and 'rest' tables of
older versions are left out too.
"""
import sys
from pathlib import Path

import lupa.lua51 as lua51

ROOT = Path(__file__).resolve().parent.parent
HEADER = ("-- NarrowHUD's starting knowledge: what it learned in luka189's own play, shipped so weapons show before their\n"
          "-- first shot. Merged under what a player's game learns (theirs wins). Made with tools/make_seed.py.\n")


def to_py(x):
    if lua51.lua_type(x) == 'table':
        return {k: to_py(v) for k, v in x.items()}
    return x


def ser(v, ind=''):
    if isinstance(v, dict):
        out = ['{']
        for k in sorted(v, key=str):
            key = k if isinstance(k, str) and k[:1].isalpha() and k.isalnum() else '["%s"]' % k
            out.append('%s  %s = %s,' % (ind, key, ser(v[k], ind + '  ')))
        out.append(ind + '}')
        return '\n'.join(out)
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, float):
        return repr(round(v, 4))
    return str(v)


# weapons known from players' logs, not luka189's own play: kept in the seed on every run
EXTRA = { 'zoom': { '30294946': True, 'a4eff4fa': True },   # a scope with zeroing (the R-40 Sightliner, the AMW-20 Apex; luka's 2026-10-30 marks)
          'grip': {
    'c4235b66': 90,       # Liberator Legacy, hand pose 90 (a 2026-10-28 report)
    # single learns in testers' logs (tools/coverage.py, 2026-10-28): each learned at a shot with the fire button
    'ab38cade': 10, '4e64c4dc': 10, '61e573c5': 52,   # (86709cb9 dropped 1.5.39: a guard dog's gun, never in a hand)
    '9c06f074': 80,       # SG-20 Halt (three testers' logs: learned at 80 each time)
} }


def main():
    data = to_py(lua51.LuaRuntime().execute(open(sys.argv[1], encoding='utf-8').read()))
    drop = set(sys.argv[sys.argv.index('--drop') + 1].split(',')) if '--drop' in sys.argv else set()
    for kind in ('drone', 'rest', '_v'):
        data.pop(kind, None)
    for table in data.values():
        for k in list(table):
            if k in drop:
                del table[k]
    for kind, extra in EXTRA.items():
        data.setdefault(kind, {}).update({k: v for k, v in extra.items() if k not in data.get('poses', {})})
    (ROOT / 'src' / 'learned_seed.lua').write_text(HEADER + 'return ' + ser(data) + '\n', encoding='utf-8')
    n = len(set(data.get('grip', {})) | set(data.get('poses', {})))
    print('src/learned_seed.lua: %d weapons with a hand pose' % n)


if __name__ == '__main__':
    main()
