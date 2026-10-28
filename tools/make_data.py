"""NarrowHUD's game data: which network game object types are weapons (and backpacks), which of the weapon fields
each one declares, and a stand-in name for every type and field the mod reads.

    python3 tools/make_data.py types.json cracked.txt[,more.txt] src/data_generated.lua [--build 26088801]

types.json: tools/parse_netcfg.py's list of the game's types (from the network config, taken out of the game files
with filediver: `filediver.exe -T network_config -o extracted`). cracked.txt: tools/crack_thin's "0xid name" lines.
To know which ids need names: python3 tools/make_data.py types.json - --ids-only > ids.txt
then: cc -O3 -fopenmp -o crack_thin tools/crack_thin.c && ./crack_thin - < ids.txt > cracked.txt

The engine knows a type or field only by a 32-bit hash of its name (murmur64(name) >> 32), so any string with that
hash works as its name: the stand-in names are such strings. Reading only fields a type declares keeps every
engine call one the game accepts.
"""
import json
import sys

# the fields NarrowHUD reads, by role: letter (in the per-type role string), field id
ROLES = {
    'rounds': ('r', 0xd7a5d63e), 'magazines': ('m', 0xec64918b), 'slot0': ('a', 0x04ec5b95),
    'slot1': ('b', 0xe525fa9c), 'selected': ('s', 0xa74ef0d5), 'chamber': ('c', 0x4a893e74),
    'spare': ('p', 0x9a34c336), 'heat': ('h', 0xa5023836), 'overheated': ('o', 0xf6275c53),
    'charging': ('g', 0x88b7cf6d), 'reload_stage': ('l', 0xcd889dbc), 'fire_mode': ('f', 0x49c250a6),
    'carry': ('k', 0x788b9753), 'underbarrel': ('u', 0x67526982), 'remaining': ('e', 0x69889752),
    'rpm': ('q', 0x4cbcc2a2), 'options': ('x', 0x31f86165), 'held': ('y', 0x3132608f),
    'lock': ('z', 0x9b738dca), 'locked': ('w', 0x1ddc206a), 'guide': ('v', 0xf8d23bd2),
    'pos': ('t', 0x8bbeb160), 'owner': ('n', 0x3ccffa7f),
    # (1.5.18) a support weapon's link to its pickup on the ground: a goid while it lies there, none in a hand
    'floor': ('j', 0xc3a3f66c),
}
WEAPON = {ROLES['rounds'][1], ROLES['slot0'][1], ROLES['heat'][1]}
BACKPACK = {ROLES['remaining'][1]}
PLAYER, AVATAR = 0x803159b3, 0x5d9752f9
PLAYER_FIELDS = {'avatar': 0x0f27c68e}
AVATAR_FIELDS = {'grenades': 0xd92082f9, 'stims': 0x5f8eb478}


# weapons fed straight from a backpack (the ammo is the pack's): no ammo field of their own, but a fire mode and the
# carry field
FED = {ROLES['fire_mode'][1], ROLES['carry'][1]}


def chosen(types):
    weapons = [t for t in types if WEAPON & set(t['fields']) or FED <= set(t['fields'])]
    packs = [t for t in types if BACKPACK & set(t['fields']) and not WEAPON & set(t['fields'])]
    return weapons, packs


def others_of(types):
    # everything else you can carry (the carry field) and isn't a weapon or an ammo backpack: jump, hover and warp packs
    # and the like; only for the research log
    weapons, packs = chosen(types)
    ids = {t['id'] for t in weapons + packs}
    return [t for t in types if ROLES['carry'][1] in t['fields'] and t['id'] not in ids]


def needed_ids(types):
    weapons, packs = chosen(types)
    weapons = weapons + others_of(types)
    ids = {t['id'] for t in weapons + packs} | {PLAYER, AVATAR}
    ids |= {f for _, f in ROLES.values()} | set(PLAYER_FIELDS.values()) | set(AVATAR_FIELDS.values())
    ids |= {f for t in weapons + packs for f in t['fields']}        # every field, for the research log
    ids |= {f for t in types if t['id'] == AVATAR for f, ty in zip(t['fields'], t['types']) if ty == 108}
    return sorted(ids)


def main():
    types = json.load(open(sys.argv[1]))
    if '--ids-only' in sys.argv:
        print('\n'.join('%08x' % i for i in needed_ids(types)))
        return
    names = {}
    for path in sys.argv[2].split(','):
        for line in open(path):
            parts = line.split()
            if len(parts) == 2 and parts[1] != '(none)':
                names[int(parts[0], 16)] = parts[1]
    missing = [i for i in needed_ids(types) if i not in names]
    if missing:
        raise SystemExit(f'{len(missing)} ids have no stand-in name yet (see --ids-only)')
    build = sys.argv[sys.argv.index('--build') + 1] if '--build' in sys.argv else '?'
    weapons, packs = chosen(types)
    by_id = {f: letter for letter, f in ROLES.values()}

    def row(t):
        roles = ''.join(sorted(by_id[f] for f in t['fields'] if f in by_id))
        return '%08x %s %s' % (t['id'], names[t['id']], roles)
    out = ['-- NarrowHUD game data, made by tools/make_data.py from the game\'s network config (game build %s).' % build,
           '-- Types: "id stand-in-name roles" (roles: the letters of the weapon fields the type declares).',
           'return {',
           '  build = %s,' % json.dumps(build),
           '  roles = {']
    for role, (letter, f) in sorted(ROLES.items()):
        out.append('    %s = { letter = %s, id = "%08x", name = %s },' % (role, json.dumps(letter), f, json.dumps(names[f])))
    out.append('  },')
    out.append('  player = { id = "%08x", name = %s, avatar = %s },' % (PLAYER, json.dumps(names[PLAYER]),
                                                                     json.dumps(names[PLAYER_FIELDS['avatar']])))
    # the avatar's fields that hold another object's id (type 108, as the player's avatar field): its backpack and
    # weapons, by the research log
    av = next(t for t in types if t['id'] == AVATAR)
    refs = [f for f, ty in zip(av['fields'], av['types']) if ty == 108]
    out.append('  avatar = { id = "%08x", name = %s, grenades = %s, stims = %s, refs = %s },' % (
        AVATAR, json.dumps(names[AVATAR]), json.dumps(names[AVATAR_FIELDS['grenades']]),
        json.dumps(names[AVATAR_FIELDS['stims']]), json.dumps(' '.join('%08x:%s' % (f, names[f]) for f in refs))))
    out.append('  weapons = %s,' % json.dumps('\n'.join(row(t) for t in weapons)))
    out.append('  backpacks = %s,' % json.dumps('\n'.join(row(t) for t in packs)))
    others = others_of(types)
    out.append('  others = %s,' % json.dumps('\n'.join('%08x %s' % (t['id'], names[t['id']]) for t in others)))
    # for the research log: every field of every weapon, backpack and other carried type ("type field field ..."), and
    # their names
    out.append('  fields = %s,' % json.dumps('\n'.join('%08x ' % t['id'] + ' '.join('%08x' % f for f in t['fields'])
                                                      for t in weapons + packs + others)))
    allf = sorted({f for t in weapons + packs + others for f in t['fields']})
    out.append('  fieldnames = %s,' % json.dumps('\n'.join('%08x %s' % (f, names[f]) for f in allf)))
    out.append('}')
    open(sys.argv[3], 'w').write('\n'.join(out) + '\n')
    print(f'{len(weapons)} weapon types, {len(packs)} backpack types', file=sys.stderr)


if __name__ == '__main__':
    main()
