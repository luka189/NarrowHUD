#!/usr/bin/env python3
"""src/ground_seed.lua: the shipped height offsets of the map's unit kinds (12_ground), from research logs.

    python3 tools/make_ground_seed.py research/logs/ground/*.log

Each log's LAST "ground kinds" / "ground units" block gives, per kind, the mean and spread of (unit height - the
feet grid's height in the same cell) over n cells. From 2.0.14 the line reports only the session's own samples (the
seed's share left out), so a log from a seeded build adds to the seed without counting it twice; a 2.0.13 log would
count the seed again and is left out. These are turned back into the sums the mod keeps ("sum,sumsq,n")
and added up across logs. Only the logs from 2.0.11 on count (before it the position call lacked its node index and
answered garbage). Kinds with a spread over 1.5 m are left out (they'd never be trusted).
"""
import re
import sys
from collections import defaultdict

LINE = re.compile(r'([0-9a-f]{16}) x(\d+) in (\d+) cells(?:, z [-\d]+\.\.[-\d]+)? dz ([-+]\d+\.\d) \+-(\d+\.\d) over (\d+)')


def last_block(lines, marker):
    idx = [i for i, l in enumerate(lines) if marker in l]
    if not idx:
        return []
    # the block: every per-kind line of the last pass (the same timestamp prefix as the last marker line; the old
    # logs' "ground units" header line is followed by "ground units: <kind> x.." lines, the new logs' pass is all
    # "ground kinds: <kind> x.." lines)
    stamp = lines[idx[-1]][:20]
    return [l for l in lines if l.startswith(stamp) and ('ground units: ' in l or 'ground kinds: ' in l)]


def main():
    sums = defaultdict(lambda: [0.0, 0.0, 0])
    for path in sys.argv[1:]:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.read().splitlines()
        if not any('NarrowHUD 2.0.1' in l and not re.search(r'2\.0\.1[0]\b', l) for l in lines) and not any(re.search(r'NarrowHUD 2\.0\.(1[1-9]|[2-9]\d)\b', l) for l in lines):
            # (the version line is in narrowhud.log, not here: trust the caller's choice of logs)
            pass
        block = last_block(lines, 'cells have a unit') or last_block(lines, 'ground kinds') or last_block(lines, 'ground walk')
        n_kinds = 0
        for l in block:
            for m in LINE.finditer(l):
                k, n = m.group(1), int(m.group(6))
                mean, sd = float(m.group(4)), float(m.group(5))
                if n < 1 or sd > 1.5 or abs(mean) > 8:
                    continue
                s = sums[k]
                s[0] += mean * n
                s[1] += (sd * sd + mean * mean) * n
                s[2] += n
                n_kinds += 1
        print('%s: %d kinds' % (path, n_kinds))
    out = ['-- Made by tools/make_ground_seed.py from research/logs/ground: a unit kind\'s height offset against the ground,',
           '-- as "sum,sumsq,n" over the feet cells it stood in (12_ground learns the same in play). %d kinds.' % len(sums),
           'return {']
    for k in sorted(sums):
        s = sums[k]
        out.append('  ["%s"] = "%.2f,%.2f,%d",' % (k, s[0], s[1], s[2]))
    out.append('}')
    with open('src/ground_seed.lua', 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')
    print('src/ground_seed.lua: %d kinds' % len(sums))


if __name__ == '__main__':
    main()
