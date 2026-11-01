"""Builds NarrowHUD for Arsenal / HD2 Mod Manager (needs Chef Shared Loader 1.0.0 or newer):

    python3 tools/build.py [--out DIR]

writes build/narrowhud.lua (src/data_generated.lua put in front of src/narrowhud.lua as DATA) and
NarrowHUD-v<version>.zip: one patch archive holding it as the plain-text Lua resource mods/luka189/narrowhud, and
manifest.json. The archive layout and name hash are the ones Lua mods for the current game use (MurmurHash64A, seed 0;
a Lua resource is u32 length, u32 2, the text).
"""
import argparse
import json
from pathlib import Path
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parent.parent
NAME = 'mods/luka189/narrowhud'
GUID = '8e4b6f12-3a7d-4c95-b0e1-6d2f9a54c3b7'
LUA_TYPE, TEXTURE_TYPE = 0xA14E8DFA2CD117E2, 0xCD4238C6A0C69E32
ARCHIVE = '9ba626afa44a3aa3.patch_0'


def resource_hash(name):
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


def make_archive(resources):
    """A patch archive of (name hash, type hash, data, gpu data) resources: the main file and its .gpu_resources
    (the layout Stratagem Timers' icon sheet and Lua shipped in before the October 2026 patch)"""
    order = [LUA_TYPE, TEXTURE_TYPE]
    types = sorted({r[1] for r in resources}, key=lambda t: order.index(t) if t in order else 99)
    res = sorted(resources, key=lambda r: (types.index(r[1]), r[0]))
    count = len(res)
    offset = (72 + 32 * len(types) + 80 * count + 15) & ~15
    entries, body, gpu = bytearray(), bytearray(offset), bytearray()
    for index, (name, rtype, data, gdata) in enumerate(res):
        gpu_off = len(gpu) if gdata else 0
        entries += struct.pack('<7Q6I', name, rtype, offset, 0, gpu_off, 0, 0, len(data), 0, len(gdata), 16, 64, index)
        body += data
        body += b'\0' * (-len(body) % 16)
        offset = len(body)
        if gdata:
            gpu += gdata
            gpu += b'\0' * (-len(gpu) % 64)
    header = struct.pack('<III20sQQ24s', 0xF0000011, len(types), count, b'', offset, 0, b'')
    tlist = b''.join(struct.pack('<IIQIIII', 0, 0, t, sum(1 for r in res if r[1] == t), 0, 16, 64) for t in types)
    body[:72 + len(tlist) + len(entries)] = header + tlist + entries
    return bytes(body), bytes(gpu)


def textures():
    """the icon textures tools/make_textures.py wrote (build/textures/<id>.texture + .gpu): only those in the game's own
    icon layout (the *_game entries of src/textures_generated.lua). (2.1.8) The size ladder (a DDS layout of our own,
    one mip) is left out of the package: nothing draws it since the game layout came (1.5.18; the ways 2-4 and 8 are
    the tests'), and HUDdle's changelog blames the crash on quitting the game on textures that aren't laid out as the
    game's are (its 0.5.1 and 0.5.3) — luka sees that crash on a quit from a mission."""
    tex = (ROOT / 'src' / 'textures_generated.lua').read_text(encoding='utf-8')
    game = set(re.findall(r"_game = \{ \{ \d+, \d+, '([0-9a-f]{16})'", tex))
    out = []
    for path in sorted((ROOT / 'build' / 'textures').glob('*.texture')):
        if path.stem in game:
            out.append((int(path.stem, 16), TEXTURE_TYPE, path.read_bytes(), path.with_suffix('.gpu').read_bytes()))
    return out


def source():
    main = (ROOT / 'src' / 'narrowhud.lua').read_text(encoding='utf-8')
    data = (ROOT / 'src' / 'data_generated.lua').read_text(encoding='utf-8')
    lines = main.split('\n')
    if lines[0] != f'-- HD2-Addon: {NAME}':
        raise SystemExit('src/narrowhud.lua must start with its header line')
    # the header lines (-- HD2-...) stay first: Chef reads them from the first 400 characters
    n = 1
    while lines[n].startswith('-- HD2-'):
        n += 1
    head, rest = '\n'.join(lines[:n]), '\n'.join(lines[n:])
    seed = (ROOT / 'src' / 'learned_seed.lua').read_text(encoding='utf-8')
    ball = (ROOT / 'src' / 'ballistics_generated.lua').read_text(encoding='utf-8')
    tex = (ROOT / 'src' / 'textures_generated.lua').read_text(encoding='utf-8')
    unames = (ROOT / 'src' / 'unit_names_generated.lua').read_text(encoding='utf-8')
    gseed = (ROOT / 'src' / 'ground_seed.lua').read_text(encoding='utf-8')
    # the modules (src/modules/NN_name.lua, in order), each in a function of its own (each gets Lua's 200 locals),
    # sharing through N; the head (src/narrowhud.lua) first, return M last
    rest = rest.replace('-- the modules (src/modules, in order) go here, then: return M\n', '')
    mods = sorted((ROOT / 'src' / 'modules').glob('[0-9][0-9]_*.lua'))
    body = ''.join(f';(function() -- {m.stem}\n{m.read_text(encoding="utf-8")}end)()\n' for m in mods)
    return (f'{head}\nlocal DATA = (function()\n{data}\nend)()\nlocal SEED = (function()\n{seed}\nend)()\n'
            f'local BALLISTICS = (function()\n{ball}\nend)()\nlocal TEXTURES = (function()\n{tex}\nend)()\n'
            f'local UNIT_NAMES = (function()\n{unames}\nend)()\n'
            f'SEED.ground = (function()\n{gseed}\nend)()\n'
            f'{rest}local N = {{}}\n{body}return M\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default=str(ROOT / 'build'))
    parser.add_argument('--research', choices=['R0', 'R1'], help='a research build for the disconnect reports: '
                        'R0 reads nothing and draws nothing, R1 reads everything and draws nothing (13_main)')
    parser.add_argument('--no-ref-reads', action='store_true', help='the interim public build for the disconnect '
                        'reports: floor never read, underbarrel only while selected (01_core N.REF_READS); same version')
    args = parser.parse_args()
    src = source()
    version = re.search(r"local M = \{ version = '([^']+)' \}", src).group(1)
    if args.research:
        src = src.replace("local M = { version = '%s' }" % version,
                          "local M = { version = '%s-%s', research_build = '%s' }" % (version, args.research, args.research), 1)
        version = '%s-%s' % (version, args.research)
    if args.no_ref_reads:
        head = "local M = { version = '%s'" % version
        assert head in src, 'no M line to patch'
        src = src.replace(head, head + ", ref_reads = false", 1)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    suffix = ('-' + args.research) if args.research else ('-noref' if args.no_ref_reads else '')
    (out / ('narrowhud%s.lua' % suffix)).write_text(src, encoding='utf-8')
    lua = src.encode('utf-8')
    manifest = {'Version': 1, 'Guid': GUID, 'Name': f'NarrowHUD {version}',
                'Description': 'NEW: layout editor at https://luka189.github.io/NarrowHUD/editor/ . '
                               'Ammo and heat by the crosshair, plus stims, grenades and your backpack. '
                               'Needs Chef Shared Loader 1.2.3 or newer. Settings: F9 menu, NarrowHUD.',
                'IconPath': 'thumbnail.png'}
    main_file, gpu_file = make_archive([(resource_hash(NAME), LUA_TYPE, struct.pack('<II', len(lua), 2) + lua, b'')] + textures())
    files = {f'core/{ARCHIVE}': main_file,
             f'core/{ARCHIVE}.stream': b'', f'core/{ARCHIVE}.gpu_resources': gpu_file,
             'manifest.json': (json.dumps(manifest, indent=2) + '\n').encode(),
             'Source/narrowhud.lua': lua,
             'thumbnail.png': (ROOT / 'art' / 'thumbnail.png').read_bytes(),
             'LICENSE.txt': (ROOT / 'LICENSE').read_bytes()}
    manifest['Options'] = [{'Name': 'NarrowHUD', 'Description': 'The mod. Keep this ticked.', 'Include': ['core']}]
    files['manifest.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    z = out / (f'NarrowHUD-v{version}-noref.zip' if args.no_ref_reads else f'NarrowHUD-v{version}.zip')
    with zipfile.ZipFile(z, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        for path, content in sorted(files.items()):
            info = zipfile.ZipInfo(path, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            zf.writestr(info, content)
    print(f'Built {z}')
    if args.research or args.no_ref_reads:
        return
    # the layout editor as a whole page for GitHub Pages (editor/editor.html is the page's content, as published as an
    # artifact; this adds the document around it)
    page = (ROOT / 'editor' / 'editor.html').read_text(encoding='utf-8')
    head = ('<!doctype html>\n<!-- Made by tools/build.py from editor/editor.html: edit that one. -->\n'
            '<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            '<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}'
            'body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>\n</head>\n<body>\n')
    (ROOT / 'editor' / 'index.html').write_text(
        head + page + '\n</body>\n</html>\n',
        encoding='utf-8')
    print('Built editor/index.html')


if __name__ == '__main__':
    main()
