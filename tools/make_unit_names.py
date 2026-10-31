#!/usr/bin/env python3
"""src/unit_names_generated.lua: unit resource ids (murmur64 of the path) -> the path, for the research log's unit
census (12_ground), from filediver's known-path lists (BSD; credited in the README).

    python3 tools/make_unit_names.py [path to filediver's hashes folder]

Only the paths a ground model could care about: the enemy factions' characters and structures (fac_bugs, fac_cyborgs,
fac_illuminate), the objectives' entities, and the environment folders' holes, nests, spawners and towers. Art-only
paths (materials, textures, animations, effects, lods, gibs ...) are left out: a unit's path is the plain one.
"""
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HASHES = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/fd/hashes'
KEEP = re.compile(r'^content/(fac_bugs|fac_cyborgs|fac_illuminate|fac_helldivers/vehicles|fac_helldivers/hellpod|objectives|env_bugs|env_cyborg|env_illuminate|env_super_earth|env_shared)/')
STRUCTURE_WORDS = re.compile(r'hole|nest|spawner|hive|tower|jammer|fabricator|spore|lair|bunker|ship|monolith|harvester|turret|cannon|mortar|detector|gunship|outpost|barrack|stratagem|nursery|egg|beacon|drill|silo|antenna|generator|objective|entities', re.I)
DROP = re.compile(r'audio|/sfx|material|texture|/anim|/vfx|particle|_lod|/ui/|wwise|shading|/fx|decal|gibs|ccras|_sss|_bci|_normal|albedo|emissive|_mesh|cloth|ragdoll|state_machine|physics|/props/|_prop$|wreck|corpse|_nac|strip|backside|destructible|intel|_dmg|debris|rubble', re.I)


def murmur64(name):
    data = name.encode('utf-8')
    mask, mix = (1 << 64) - 1, 0xC6A4A7935BD1E995
    value = len(data) * mix & mask
    end = len(data) // 8 * 8
    for (word,) in struct.iter_unpack('<Q', data[:end]):
        word = word * mix & mask
        word ^= word >> 47
        value = (value ^ (word * mix & mask)) * mix & mask
    if data[end:]:
        value = (value ^ int.from_bytes(data[end:], 'little')) * mix & mask
    value ^= value >> 47
    value = value * mix & mask
    return value ^ (value >> 47)


def main():
    paths = set()
    for fn in ('hashes.txt', 'cracked.txt'):
        with open(os.path.join(HASHES, fn), encoding='utf-8', errors='replace') as f:
            for line in f:
                p = line.strip()
                if not KEEP.match(p) or DROP.search(p):
                    continue
                top = p.split('/')[1]
                if top.startswith('env_') and not STRUCTURE_WORDS.search(p):
                    continue
                if top == 'objectives' and '/entities/' not in p:
                    continue
                paths.add(p)
    rows = sorted((('%016x' % murmur64(p)), p) for p in paths)
    out = ['-- Made by tools/make_unit_names.py from filediver\'s known paths (BSD): unit resource id -> path, for the',
           '-- research log\'s unit census. %d paths. Not every path is a unit: the census says which are.' % len(rows),
           'return {']
    for h, p in rows:
        out.append('  ["%s"] = "%s",' % (h, p))
    out.append('}')
    dest = os.path.join(HERE, '..', 'src', 'unit_names_generated.lua')
    with open(dest, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')
    print('%s: %d paths' % (dest, len(rows)))


if __name__ == '__main__':
    main()
