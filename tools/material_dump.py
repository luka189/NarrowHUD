"""The game's own material resources, read from the installed game: which shader a material uses, its texture
slots and its settings (the shader variables with their names' hashes and values), for drawing the game's icons in
their own colours (docs/ICONS.md). Read-only; nothing is changed or published.

    py tools/material_dump.py "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Helldivers 2\\data" out 6115051c9558c50e 3efff09cd12fb89a e2d6ed90906c1e8b

writes out\\<id>.material.txt per id (the parse), out\\<id>.material (the main part) and out\\<id>.material.gpu (the
GPU part: the shader programs; the text file lists every readable string in it, where variable names may be).
    py tools/material_dump.py "...\\Helldivers 2\\data" out --shader 5f8113d2 ba25de35

finds every shader library holding those material templates and writes out\\shader_<template>_<library>.txt with the
readable strings of its GPU part (the variable and texture names of the shader's constant buffers) and the .gpu part.
Needs tools/atlas_sprites.py beside it (the archive reading). Seen 2026-10-28: a GUI icon material is 160 bytes, no
settings, the shader template's id at 0x80 (the fire-mode icons 5f8113d2, Chef's yellow_logo ba25de35, the UI image
shader) and one diffuse_map slot pointing at the texture of the same name. The material layout is filediver's (BSD): a 136-byte
header (base material / shader template at 24, texture count at 64, setting count at 104), the texture slot hashes
(u32 each) and their textures (u64 each), the setting definitions (u32 type, count, name hash, offset, stride) and
their float data. A name hash is the top 32 bits of the name's murmur64: a list of likely names is tried.
"""
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import atlas_sprites as A  # noqa: E402

MATERIAL = 0xEAC0B497876ADEDF
SHADER_LIBRARY = A.murmur64('shader_library')
TYPES = {0: 'scalar', 1: 'vector2', 2: 'vector3', 3: 'vector4', 12: 'other'}
# names to try against the 32-bit hashes (the top half of murmur64)
CANDIDATES = '''
diffuse_map color colour tint c0 c1 c2 c3 c4 mask_color mask_colour icon_color icon_colour primary_color secondary_color
tertiary_color color_0 color_1 color_2 color_3 colour_0 colour_1 colour_2 layer_0 layer_1 layer_2 layer_3 red green blue
alpha opacity glow emissive tint_color tint_colour base_color base_colour main_color highlight shadow shadow_color
outline outline_color fill fill_color uv_scale uv_offset uv_rect rect scale offset gradient gradient_color r g b a
strength intensity brightness contrast saturation material_color layer_color_0 layer_color_1 layer_color_2 color_r
color_g color_b color_a mask_r mask_g mask_b mask_a channel_r channel_g channel_b channel_a channel_0 channel_1 channel_2
channel_3 col col0 col1 col2 col3 c0_color c1_color c2_color texture_atlas atlas_uv sprite_uv sdf_params sdf
edge_softness threshold blend blend_mode additive multiply
'''.split()


def thin(name):
    return A.murmur64(name) >> 32


def parse(main):
    out = []
    if len(main) < 136:
        return ['too short for a material header (%d bytes)' % len(main)]
    main_size, gpu_size = struct.unpack_from('<II', main, 12)
    base = struct.unpack_from('<Q', main, 24)[0]
    ntex = struct.unpack_from('<I', main, 64)[0]
    nset = struct.unpack_from('<I', main, 104)[0]
    out.append('header: main part %d, gpu part %d, base material / template %016x, %d textures, %d settings' % (main_size, gpu_size, base, ntex, nset))
    if len(main) >= 0x84:
        out.append('shader template (the word at 0x80): %08x' % struct.unpack_from('<I', main, 0x80)[0])
    names = {thin(n): n for n in CANDIDATES}
    off = 136
    keys = [struct.unpack_from('<I', main, off + 4 * i)[0] for i in range(ntex)]
    off += 4 * ntex
    vals = [struct.unpack_from('<Q', main, off + 8 * i)[0] for i in range(ntex)]
    off += 8 * ntex
    for k, v in zip(keys, vals):
        out.append('texture slot %08x (%s) = %016x' % (k, names.get(k, '?'), v))
    defs = []
    for i in range(nset):
        t, count, usage, doff, stride = struct.unpack_from('<IIIII', main, off + 20 * i)
        defs.append((t, count, usage, doff, stride))
    off += 20 * nset
    base_off = off
    for t, count, usage, doff, stride in defs:
        n = {0: 1, 1: 2, 2: 3, 3: 4}.get(t, count * stride // 4 if t == 12 else 0)
        try:
            data = struct.unpack_from('<%df' % n, main, base_off + doff)
        except struct.error:
            data = ()
        out.append('setting %08x (%s): %s = %s' % (usage, names.get(usage, '?'), TYPES.get(t, t), ', '.join('%g' % x for x in data)))
    return out


def strings(blob, least=3):
    return sorted(set(m.decode() for m in re.findall(rb'[\x20-\x7e]{%d,}' % least, blob)))


def shader(data, out, template):
    """every shader library whose GPU part holds the template's id: its readable strings (the variable names of its
    constant buffers and textures sit there in clear, as HD2Runtime found for the stratagem icon template)"""
    import time
    t0 = time.time()
    store = A.Store(data)
    needle = struct.pack('<I', template)
    hits, nlib = [], 0
    for name in store.names():
        for rname, rtype, moff, msize, goff, gsize in A.table(store, name, (SHADER_LIBRARY,)):
            nlib += 1
            gpu = store.read(name + '.gpu_resources', goff, gsize) if gsize else b''
            main_part = store.read(name, moff, msize)
            where = [i for blob in (gpu,) for i in [blob.find(needle)] if i >= 0]
            if where or main_part.find(needle) >= 0:
                hits.append((rname, name, gpu, main_part))
    print('%d shader libraries read in %.0f s; %d hold template %08x' % (nlib, time.time() - t0, len(hits), template))
    for rname, name, gpu, main_part in hits:
        at = [m.start() for m in re.finditer(re.escape(needle), gpu)]
        lines = ['shader library %016x in archive %s: template %08x at gpu offsets %s (main part %d bytes, gpu %d bytes, %d DXBC programs)'
                 % (rname, name, template, at, len(main_part), len(gpu), gpu.count(b'DXBC'))]
        lines.append('strings (2+ chars, NUL-ended) in the gpu part, in order:')
        lines += ['  %6d  %s' % (m.start(), m.group().decode()) for m in re.finditer(rb'[\x20-\x7e]{2,}(?=\0)', gpu)]
        lines.append('strings in the main part: ' + ', '.join(strings(main_part)))
        path = out / ('shader_%08x_%016x.txt' % (template, rname))
        path.write_text('\n'.join(lines))
        (out / ('shader_%08x_%016x.gpu' % (template, rname))).write_bytes(gpu)
        print('  written', path, '(%d strings)' % (len(lines) - 3))


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    data, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    if sys.argv[3] == '--shader':
        for t in sys.argv[4:]:
            shader(data, out, int(t, 16))
        return
    ids = [int(x, 16) for x in sys.argv[3:]]
    import time
    t0 = time.time()
    store = A.Store(data)
    found, nmat, narch = {}, 0, 0
    names = store.names()
    print('%d archives, %d bundle items; scanning every table' % (len(names), len(store.items or {})))
    for name in names:
        narch += 1
        for rname, rtype, moff, msize, goff, gsize in A.table(store, name, (MATERIAL,)):
            nmat += 1
            if rname in ids and rname not in found:
                found[rname] = (name, moff, msize, goff, gsize)
        if narch % 200 == 0:
            print('  %d archives, %d materials seen, %d of %d wanted found' % (narch, nmat, len(found), len(ids)), end='\r')
    print()
    print('%d archives read in %.0f s, %d material resources in all, %d unreadable archives' % (narch, time.time() - t0, nmat, len(A.unreadable)))
    for rid in ids:
        if rid not in found:
            print('%016x: no material resource of that id in the archives' % rid)
            continue
        name, moff, msize, goff, gsize = found[rid]
        mainp = store.read(name, moff, msize)
        gpu = store.read(name + '.gpu_resources', goff, gsize) if gsize else b''
        (out / ('%016x.material' % rid)).write_bytes(mainp)
        if gpu:
            (out / ('%016x.material.gpu' % rid)).write_bytes(gpu)
        lines = ['material %016x in archive %s (main %d bytes, gpu %d bytes)' % (rid, name, len(mainp), len(gpu))] + parse(mainp)
        lines.append('strings in the main part: ' + ', '.join(strings(mainp)))
        lines.append('strings in the gpu part: ' + ', '.join(strings(gpu, 4)))
        (out / ('%016x.material.txt' % rid)).write_text('\n'.join(lines))
        print('\n'.join(lines[:8]))
        print('  ...written to', out / ('%016x.material.txt' % rid))


if __name__ == '__main__':
    main()
