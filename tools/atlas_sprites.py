"""Where the game keeps its own HUD icons: the sprite records of its texture atlases, read from the installed game
(read-only; nothing is changed, nothing is published). For drawing the fire-mode and ammo icons from the game's own
atlas pages in a mission with chef.bitmap_uv, so NarrowHUD ships no art of the game's.

    py tools/atlas_sprites.py "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Helldivers 2\\data" out

writes, in out\\:
  sprites.json   the sprites whose name we know (NAMES below): page texture id, size, uv rectangle, archive
  pages.txt      the atlas pages those sprites are on: id, size, format, mips, archive
  all_sprites.tsv  every sprite record of every atlas (name hash, page, size, uv), for matching by hand
  <name>.png     each known sprite, cut from its page, to look at
  small\\<hash>.png  every unnamed square sprite of 32 to 160 px: browse these to find icons whose name we don't know
Standard library only (Python 3.8 or newer; with the lz4 package installed, `py -m pip install lz4`, the bundle
reading is many times faster). Reads every archive's resource table once. The game's data folder is either the old
layout (an archive per file, a 16-hex-digit name and no extension, the pixels in a .gpu_resources beside it) or the
slim one (bundles.nxa, a DSAA index of the archives' names and where their bytes sit in the DSAR bundle files, in
LZ4 chunks); both are read.

Layout (filediver's documentation of the formats, HD2Runtime's research, SkyeShade, sdk/tools/hd2_hud_icons.py,
hd2_archive.py and hd2_game_data.py; our own code): a DSAR bundle is a 32-byte head (u32 chunk count at 8) and 32-byte
chunk records (u64 uncompressed offset, u64 offset in the file, u32 uncompressed size, u32 size, u8 compression: 0
none, 3 LZ4 block); bundles.nxa is one whose contents are the DSAA index: at 12 u32 bundle count and u32 item count,
at 24 the items (u64 size, u32 name offset, u32 entry count, u64 entries offset), then u32 name offsets of the
bundles, strings NUL-ended; an item's 16-byte entries (u32 offset in the item at 0, u32 chunk offset in the bundle
at 8, u8 bundle index at 15) say which bundle chunk holds its bytes from that offset on. An archive
is u32 magic F0000011, u32 types, u32 files, 60 bytes, then 32 bytes per type, then 80 bytes per resource (u64 name,
u64 type, u64 main offset, u64 stream offset, u64 gpu offset, 2 u64, u32 main size, u32 stream size, u32 gpu size,
3 u32). A texture_atlas resource (type murmur64('texture_atlas')) is a u32 count then 40-byte records: u64 sprite
name, u64 page texture name, u32 width, u32 height, f32 u0, v0, du, dv. A page is a texture resource: 0xC0 bytes of
header, a DDS header with the DX10 extension, and the pixels, mip 0 first, in .gpu_resources.
"""
import json
import re
import struct
import sys
import zlib
from pathlib import Path

TEXTURE = 0xCD4238C6A0C69E32
TEXTURE_ATLAS = 0x9199BB50B6896F02
RECORD = struct.Struct('<QQII4f')
ROW = struct.Struct('<7Q6I')
# the icon names to look for: the HUD's weapon functions (fire modes, ammo kinds, options), its map and misc icons
# (paths from filediver's name list; whether a sprite is named by its texture path is what this run tells us)
NAMES = [
    'content/ui/mission/hud/weapon_function/' + n for n in '''
    airstrike ammo_aphet ammo_buckshot ammo_flak ammo_flechettes ammo_frag ammo_he ammo_heat ammo_slug ammo_stun bullet
    burst_fire firemode_all_barrels firemode_auto firemode_burst firemode_caltrops_narrow firemode_caltrops_wide
    firemode_deploy_c4 firemode_detonate_c4 firemode_no_underbarrel firemode_single firemode_smoke firemode_triple
    firemode_underbarrel firemode_underbarrel_flamer firemode_underbarrel_shotgun firemode_volley flashlight_auto
    flashlight_off flashlight_on guidance_off guidance_on heat laser_off laser_on prism_high prism_low prism_medium
    rof_high rof_low rof_medium velocity_high velocity_low velocity_medium zeroing_high zeroing_low zeroing_medium
    '''.split()
] + [
    'content/ui/mission/hud/map/' + n for n in '''
    waypoint arrow player_dot enemy_dot mapicon_backpack_ammo mapicon_backpack_generic mapicon_backpack_medical
    mapicon_backpack_shield mapicon_sample_low mapicon_sample_medium mapicon_sample_high mapicon_supportweapon
    mapicon_supportweapon_ap mapicon_supportweapon_at objective_area pulse
    '''.split()
] + [
    'content/ui/mission/hud/misc/' + n for n in 'objective_primary stratagem hud_marker_generic destroyer_marker item_bracket credits_icon'.split()
]
SMALL = (32, 160)   # unnamed square sprites of this size range get a picture
MAX_SMALL = 3000


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


try:
    import lz4.block as _lz4
except ImportError:
    _lz4 = None


def lz4_block(src, size):
    """an LZ4 block decoded (the pure-Python way when the lz4 package isn't there)"""
    if _lz4:
        return _lz4.decompress(src, uncompressed_size=size)
    dst = bytearray()
    s, n = 0, len(src)
    while s < n:
        token = src[s]; s += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[s]; s += 1; lit += b
                if b != 255:
                    break
        dst += src[s:s + lit]; s += lit
        if s >= n:
            break
        off = src[s] | src[s + 1] << 8; s += 2
        match = (token & 15) + 4
        if match == 19:
            while True:
                b = src[s]; s += 1; match += b
                if b != 255:
                    break
        d = len(dst)
        if off >= match:
            dst += dst[d - off:d - off + match]
        else:
            pat = dst[d - off:d]
            dst += (pat * (match // off + 1))[:match]
    return bytes(dst[:size])


def dsar_chunks(path):
    with open(path, 'rb') as f:
        head = f.read(32)
        if head[:4] != b'DSAR':
            raise ValueError(f'{path} is not a DSAR bundle')
        count = struct.unpack_from('<I', head, 8)[0]
        raw = f.read(32 * count)
    return [struct.unpack_from('<QQIIB', raw, 32 * i) for i in range(count)]


_chunks = {}   # the last few decoded chunks (an archive's head and table sit in the same one)


def dsar_chunk(path, c):
    uoff, coff, usize, csize, comp = c
    key = (str(path), coff)
    if key in _chunks:
        return _chunks[key]
    with open(path, 'rb') as f:
        f.seek(coff)
        data = f.read(csize)
    if comp == 3:
        data = lz4_block(data, usize)
    elif comp != 0:
        raise ValueError(f'chunk compression {comp} in {path}')
    if len(_chunks) >= 8:
        del _chunks[next(iter(_chunks))]
    _chunks[key] = data
    return data


class Store:
    """the archives of a data folder, loose files or bundled, read by name and byte range"""

    def __init__(self, folder):
        self.folder = folder
        self.items = None
        nxa = folder / 'bundles.nxa'
        if nxa.exists():
            self._open_bundles(nxa)

    def _open_bundles(self, nxa):
        index = b''.join(dsar_chunk(nxa, c) for c in dsar_chunks(nxa))
        if index[:4] != b'DSAA':
            raise ValueError('bundles.nxa has no DSAA index')
        nb, ni = struct.unpack_from('<II', index, 12)
        def cstr(o): return index[o:index.index(b'\0', o)].decode()
        self.bundles = []
        for i in range(nb):
            o = struct.unpack_from('<I', index, 24 + 24 * ni + 4 * i)[0]
            path = self.folder / cstr(o)
            self.bundles.append((path, dsar_chunks(path)))
        self.items = {}
        for i in range(ni):
            size, name_off, count, eoff = struct.unpack_from('<QIIQ', index, 24 + 24 * i)
            entries = [(struct.unpack_from('<I', index, eoff + 16 * k)[0], struct.unpack_from('<I', index, eoff + 16 * k + 8)[0], index[eoff + 16 * k + 15]) for k in range(count)]
            self.items[cstr(name_off)] = (size, entries)
        self.chunk_index = [{c[0]: k for k, c in enumerate(chunks)} for _, chunks in self.bundles]   # by uncompressed offset

    @staticmethod
    def is_archive(name):
        """a 16-hex-digit name, bare or with .patch_N (a patch archive is a whole archive too)"""
        base, _, ext = name.partition('.')
        return len(base) == 16 and all(c in '0123456789abcdef' for c in base) and (not ext or re.fullmatch(r'patch_\d+', ext))

    def names(self):
        """the archive names: the loose files of the folder and, in the slim layout, the bundled ones"""
        loose = {p.name for p in self.folder.iterdir() if p.is_file() and self.is_archive(p.name)}
        bundled = {n for n in self.items if self.is_archive(n)} if self.items else set()
        return sorted(loose | bundled)

    def read(self, name, start, length):
        """bytes [start, start+length) of the archive (or of its .gpu_resources etc. by that name)"""
        path = self.folder / name
        if path.is_file():
            try:
                with open(path, 'rb') as f:
                    f.seek(start)
                    return f.read(length)
            except OSError:
                return b''
        if not self.items or name not in self.items:
            return b''
        size, entries = self.items[name]
        length = min(length, size - start)
        out = bytearray()
        for i, (aoff, boff, bidx) in enumerate(entries):
            end = entries[i + 1][0] if i + 1 < len(entries) else size
            if end <= start or aoff >= start + length:
                continue
            path, chunks = self.bundles[bidx]
            ci = self.chunk_index[bidx].get(boff)
            if ci is None:
                return b''
            pos = aoff
            while pos < end and pos < start + length and ci < len(chunks):
                c = chunks[ci]; ci += 1
                seg_start, seg_end = pos, pos + c[2]
                lo, hi = max(seg_start, start), min(seg_end, start + length)
                if lo < hi:
                    data = dsar_chunk(path, c)
                    out += data[lo - seg_start:hi - seg_start]
                pos = seg_end
        return bytes(out)


unreadable = []   # archive names whose head couldn't be read or isn't an archive's


def table(store, name, types=(TEXTURE, TEXTURE_ATLAS)):
    """(name, type, main offset, main size, gpu offset, gpu size) of each resource of the given types in an archive"""
    out = []
    head = store.read(name, 0, 72)
    if len(head) < 72 or struct.unpack_from('<I', head)[0] != 0xF0000011:
        unreadable.append(name)
        return out
    ntypes, nfiles = struct.unpack_from('<II', head, 4)
    rows = store.read(name, 72 + 32 * ntypes, 80 * nfiles)
    for i in range(len(rows) // 80):
        r = ROW.unpack_from(rows, 80 * i)
        if r[1] in types:
            out.append((r[0], r[1], r[2], r[7], r[4], r[9]))
    return out


def page_layout(main):
    dds = main[0xC0:]
    if dds[:4] != b'DDS ' or len(dds) < 148:
        return None
    height, width = struct.unpack_from('<II', dds, 12)
    mips = struct.unpack_from('<I', dds, 28)[0]
    fmt = struct.unpack_from('<I', dds, 128)[0]
    return dict(width=width, height=height, mips=mips, dxgi=fmt)


# --- just enough BC1 / BC3 / 8-bit RGBA decoding to look at one sprite's rectangle
def _565(c):
    return ((c >> 11) & 31) * 255 // 31, ((c >> 5) & 63) * 255 // 63, (c & 31) * 255 // 31


def _colours(block, at, bc1):
    """the 16 colours of a colour block and, for BC1 in its 3-colour mode, which texels are punched through"""
    c0, c1, bits = struct.unpack_from('<HHI', block, at)
    p0, p1 = _565(c0), _565(c1)
    three = bc1 and c0 <= c1
    if three:
        pal = [p0, p1, tuple((a + b) // 2 for a, b in zip(p0, p1)), (0, 0, 0)]
    else:
        pal = [p0, p1, tuple((2 * a + b) // 3 for a, b in zip(p0, p1)), tuple((a + 2 * b) // 3 for a, b in zip(p0, p1))]
    idx = [(bits >> (2 * i)) & 3 for i in range(16)]
    return [pal[i] for i in idx], [three and i == 3 for i in idx]


def _alphas(block, at):
    a0, a1 = block[at], block[at + 1]
    bits = int.from_bytes(block[at + 2:at + 8], 'little')
    if a0 > a1:
        pal = [a0, a1] + [((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)]
    else:
        pal = [a0, a1] + [((5 - i) * a0 + i * a1) // 5 for i in range(1, 5)] + [0, 255]
    return [pal[(bits >> (3 * i)) & 7] for i in range(16)]


def cut(gpu, page, x, y, w, h):
    """the RGBA pixels of a rectangle of the page's top mip, or None for a format we don't decode"""
    fmt, W = page['dxgi'], page['width']
    out = bytearray(w * h * 4)
    if fmt in (28, 29, 87, 91):
        bgra = fmt in (87, 91)
        for j in range(h):
            row = gpu[((y + j) * W + x) * 4:((y + j) * W + x + w) * 4]
            if bgra:
                row = bytes(b for px in struct.iter_unpack('<BBBB', row) for b in (px[2], px[1], px[0], px[3]))
            out[j * w * 4:j * w * 4 + len(row)] = row
        return bytes(out)
    bc1 = fmt in (71, 72)
    if not bc1 and fmt not in (77, 78):
        return None
    bs = 8 if bc1 else 16
    bw = W // 4
    for by in range(y // 4, (y + h + 3) // 4):
        for bx in range(x // 4, (x + w + 3) // 4):
            at = (by * bw + bx) * bs
            block = gpu[at:at + bs]
            if len(block) < bs:
                continue
            cols, punched = _colours(block, bs - 8, bc1)
            alphas = None if bc1 else _alphas(block, 0)
            for i in range(16):
                px, py = bx * 4 + i % 4 - x, by * 4 + i // 4 - y
                if 0 <= px < w and 0 <= py < h:
                    r, g, b = cols[i]
                    a = alphas[i] if alphas else (0 if punched[i] else 255)
                    out[(py * w + px) * 4:(py * w + px) * 4 + 4] = bytes((r, g, b, a))
    return bytes(out)


def png(path, w, h, rgba):
    raw = b''.join(b'\0' + rgba[j * w * 4:(j + 1) * w * 4] for j in range(h))
    def chunk(t, b): return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xFFFFFFFF)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def scan(store):
    """every sprite record (by name hash) and every texture's layout, from all archives of the store"""
    sprites, pages = {}, {}
    files = store.names()
    print(f'{len(files)} archives in {store.folder}' + (f', {len(store.items)} items in the bundles' if store.items else ', no bundles'))
    for i, p in enumerate(files):
        for name, rtype, moff, msize, goff, gsize in table(store, p):
            if rtype == TEXTURE_ATLAS and msize >= 4:
                main = store.read(p, moff, msize)
                count = struct.unpack_from('<I', main)[0]
                for k in range(min(count, (len(main) - 4) // RECORD.size)):
                    sname, page, w, h, u0, v0, du, dv = RECORD.unpack_from(main, 4 + RECORD.size * k)
                    sprites.setdefault(sname, dict(sprite='%016x' % sname, page='%016x' % page, width=w, height=h, u0=u0, v0=v0, du=du, dv=dv, archive=p))
            elif rtype == TEXTURE and msize >= 0xC0 + 148:
                lay = page_layout(store.read(p, moff, 0xC0 + 148))
                if lay:
                    pages.setdefault('%016x' % name, dict(lay, archive=p, gpu_offset=goff, gpu_size=gsize))
        if i % 50 == 0:
            print(f'  {i} archives read, {len(sprites)} sprites found', end='\r')
    print()
    return sprites, pages


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    data, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    (out / 'small').mkdir(exist_ok=True)
    wanted = {murmur64(n): n for n in NAMES}
    store = Store(data)
    if not _lz4 and store.items is not None:
        print('(no lz4 package: reading the bundles the slow way; `py -m pip install lz4` makes it quick)')
    sprites, pages = scan(store)
    known = {wanted[h]: s for h, s in sprites.items() if h in wanted}
    (out / 'sprites.json').write_text(json.dumps(known, indent=2, sort_keys=True))
    with open(out / 'all_sprites.tsv', 'w') as f:
        f.write('sprite\tpage\twidth\theight\tu0\tv0\tdu\tdv\tarchive\n')
        for s in sorted(sprites.values(), key=lambda s: (s['page'], s['sprite'])):
            f.write('\t'.join(str(s[k]) for k in ('sprite', 'page', 'width', 'height', 'u0', 'v0', 'du', 'dv', 'archive')) + '\n')
    used = {s['page'] for s in known.values()}
    with open(out / 'pages.txt', 'w') as f:
        for pid in sorted(used):
            pg = pages.get(pid)
            f.write(f"{pid}: {pg['width']}x{pg['height']} dxgi {pg['dxgi']} mips {pg['mips']} in {pg['archive']}\n" if pg else f'{pid}: page texture not found in the archives\n')
    print(f'{len(sprites)} sprite records in all; {len(known)} of {len(NAMES)} names found, on {len(used)} page(s)')
    if unreadable:
        print(f'{len(unreadable)} archive(s) could not be read (no archive header), e.g. {", ".join(unreadable[:5])}')
    missing = [n for n in NAMES if n not in known]
    if missing:
        print('names not found as sprites:', ', '.join(n.rsplit('/', 1)[1] for n in missing))
    # the pictures: the known sprites, and the small square unnamed ones to browse
    cache = {}
    def pixels(pid):
        if pid not in cache:
            pg = pages.get(pid)
            cache[pid] = (pg, store.read(pg['archive'] + '.gpu_resources', pg['gpu_offset'], pg['gpu_size'])) if pg else (None, None)
        return cache[pid]
    def picture(s, path):
        pg, gpu = pixels(s['page'])
        if not pg or not gpu:
            return False
        x, y = round(s['u0'] * pg['width']), round(s['v0'] * pg['height'])
        w, h = round(s['du'] * pg['width']), round(s['dv'] * pg['height'])
        if w <= 0 or h <= 0:
            return False
        rgba = cut(gpu, pg, x, y, w, h)
        if rgba:
            png(path, w, h, rgba)
        return bool(rgba)
    for name, s in known.items():
        picture(s, out / (name.rsplit('/', 1)[1] + '.png'))
    n = 0
    for h, s in sprites.items():
        if h in wanted or s['width'] != s['height'] or not (SMALL[0] <= s['width'] <= SMALL[1]):
            continue
        if n >= MAX_SMALL:
            break
        n += picture(s, out / 'small' / (s['sprite'] + '.png'))
    print(f'pictures written to {out}: {len(known)} named, {n} small unnamed in small\\')


if __name__ == '__main__':
    main()
