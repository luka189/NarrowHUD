#!/usr/bin/env python3
"""src/weapon_units_generated.lua: each weapon network type -> the unit resource its entity uses (the model watched
at the hand, 05_hand), from filediver's embedded entity table (BSD-3-Clause; nothing of the game's files needed).

    python3 tools/make_weapon_units.py /home/claude/fd [src/weapon_units_generated.lua]

filediver's datalibrary/generated_entities.dl_bin holds, under the DL type "EntitySettingsHashmap", one record per
entity: its resource path hash (MurmurHash64A of the entity path, which is the unit's path too, but for a few
renamed units), the offset and count of its components, and its game object type (the 32-bit network type id, the
same hash NarrowHUD keys its types by). The weapon types in src/data_generated.lua are looked up there; the path's
name comes from filediver's hashes.txt where it is known.
"""
import gzip
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def dl_sum(text):
    r = 5381
    for ch in text:
        r = (r * 33 + ord(ch)) & 0xffffffff
    return (r - 5381) & 0xffffffff


def m64(b):
    M, MASK = 0xc6a4a7935bd1e995, (1 << 64) - 1
    h = (len(b) * M) & MASK
    i = 0
    while len(b) - i >= 8:
        k = int.from_bytes(b[i:i + 8], 'little')
        i += 8
        k = (k * M) & MASK
        k ^= k >> 47
        k = (k * M) & MASK
        h ^= k
        h = (h * M) & MASK
    r = b[i:]
    if r:
        for j in range(len(r) - 1, -1, -1):
            h ^= r[j] << (8 * j)
        h = (h * M) & MASK
    h ^= h >> 47
    h = (h * M) & MASK
    h ^= h >> 47
    return h


def entity_table(fd):
    p = fd / 'datalibrary' / 'generated_entities.dl_bin'
    data = p.read_bytes() if p.exists() else gzip.decompress((fd / 'datalibrary' / 'generated_entities.dl_bin.gz').read_bytes())
    marker = struct.pack('<I', dl_sum('EntitySettingsHashmap'))
    at = data.find(marker)
    if at < 0:
        sys.exit('EntitySettingsHashmap not found in generated_entities.dl_bin')
    # DLInstanceHeader: id u32, magic 4, version u32, type u32, size u32, is64 u8, pad 7
    _, magic, version, typ, size, is64 = struct.unpack_from('<I4sIIIB', data, at)
    body = data[at + 28: at + 28 + size]
    # EntitySettings: resource u64, components offset u64, count u64, game object id u32, pad u32 (32 bytes)
    out = {}
    n = len(body) // 32
    for i in range(n):
        res, off, cnt, goid, _ = struct.unpack_from('<QQQII', body, i * 32)
        if res == 0 or cnt > 200:
            continue
        out.setdefault('%08x' % goid, []).append(('%016x' % res, cnt))
    return out


def main():
    fd = Path(sys.argv[1] if len(sys.argv) > 1 else '/home/claude/fd')
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / 'src' / 'weapon_units_generated.lua'
    table = entity_table(fd)
    names = {}
    for line in (fd / 'hashes' / 'hashes.txt').read_text(errors='ignore').splitlines():
        s = line.strip()
        if s and '/' in s:
            names['%016x' % m64(s.encode())] = s
    src = (ROOT / 'src' / 'data_generated.lua').read_text()
    weapons = src.split('weapons = "')[1].split('"')[0].replace('\\n', '\n').split('\n')
    ids = [l.split()[0] for l in weapons if l.strip()]
    lines, found, named, missing = [], 0, 0, []
    for tid in sorted(ids):
        ents = table.get(tid)
        if not ents:
            missing.append(tid)
            continue
        # (one entity a type as a rule; several: the one with the most components is the real thing)
        res, _ = max(ents, key=lambda e: e[1])
        found += 1
        name = names.get(res)
        if name:
            named += 1
        lines.append("  ['%s'] = '%s',%s" % (tid, res, name and (' -- ' + name.rsplit('/', 1)[-1]) or ' -- (path not in hashes.txt)'))
    out = ['-- NarrowHUD: each weapon network type -> its unit resource (MurmurHash64A of the unit path), made by',
           '-- tools/make_weapon_units.py from filediver\'s entity table (BSD-3-Clause). %d of %d weapon types; %d paths named.' % (found, len(ids), named),
           'return {'] + lines + ['}', '']
    dst.write_text('\n'.join(out))
    print('%s: %d of %d weapon types have an entity, %d paths named; missing: %s' % (dst, found, len(ids), named, ' '.join(missing[:20]) + (' ...' if len(missing) > 20 else '')))


if __name__ == '__main__':
    main()
