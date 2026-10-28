"""List a Helldivers 2 patch archive's resources: types, entries (sizes, offsets, flags), and for textures the
Stingray + DDS headers. python3 -I parse_patch.py <patch_0> [--dump]"""
import struct
import sys
from pathlib import Path

TYPES = {0xA14E8DFA2CD117E2: 'lua', 0xCD4238C6A0C69E32: 'texture', 0xEAC0B497876ADEDF: 'material',
         0xE0A48D0BE9A7453F: 'unit', 0x9199BB50B6896F02: 'strings'}
DXGI = {28: 'R8G8B8A8_UNORM', 29: 'R8G8B8A8_UNORM_SRGB', 71: 'BC1_UNORM', 72: 'BC1_SRGB', 74: 'BC2', 77: 'BC3_UNORM', 78: 'BC3_SRGB',
        80: 'BC4', 83: 'BC5', 95: 'BC6H', 98: 'BC7_UNORM', 99: 'BC7_SRGB', 61: 'R8_UNORM', 87: 'B8G8R8A8_UNORM'}


def main(path, dump=False):
    p = Path(path)
    d = p.read_bytes()
    gpu = p.with_name(p.name + '.gpu_resources')
    gpu = gpu.read_bytes() if gpu.exists() else b''
    stream = p.with_name(p.name + '.stream')
    stream = stream.read_bytes() if stream.exists() else b''
    magic, ntypes, nfiles = struct.unpack_from('<III', d, 0)
    hdr = struct.unpack_from('<III20sQQ24s', d, 0)
    print(f'{p}: magic {magic:#x} types {ntypes} files {nfiles} main {len(d)} gpu {len(gpu)} stream {len(stream)} header q1={hdr[4]:#x} q2={hdr[5]:#x} tail={hdr[6].hex()}')
    off = 72
    for i in range(ntypes):
        a, b, t, n, c, al1, al2 = struct.unpack_from('<IIQIIII', d, off)
        print(f'  type {TYPES.get(t, "%016x" % t)}: {n} entries (fields {a} {b} {c} align {al1} {al2})')
        off += 32
    for i in range(nfiles):
        name, rtype, doff, soff, goff, buf, gbuf, dsize, ssize, gsize, al1, al2, idx = struct.unpack_from('<7Q6I', d, off)
        off += 80
        tn = TYPES.get(rtype, '%016x' % rtype)
        line = f'  [{idx}] {tn} {name:016x}: main @{doff:#x} {dsize} B, stream @{soff:#x} {ssize} B, gpu @{goff:#x} {gsize} B, buf {buf:#x}/{gbuf:#x}, align {al1}/{al2}'
        if tn == 'texture':
            body = d[doff:doff + dsize]
            sh = body[:192]
            dds = body[192:192 + 148]
            if dds[:4] == b'DDS ':
                (size, flags, h, w, pitch, depth, mips) = struct.unpack_from('<7I', dds, 4)
                caps = struct.unpack_from('<5I', dds, 108)
                fmt = struct.unpack_from('<5I', dds, 128)   # dxgi, dim, misc, arraysize, misc2
                pf = struct.unpack_from('<2I4s5I', dds, 76)
                line += f'\n       DDS {w}x{h} mips {mips} flags {flags:#x} pitch {pitch} caps {[hex(c) for c in caps]} pf {pf[1]:#x} {pf[2]} dxgi {fmt[0]} {DXGI.get(fmt[0], "?")} dim {fmt[1]} misc {fmt[2]:#x} arr {fmt[3]} misc2 {fmt[4]}'
                line += f'\n       stingray header: ' + ' '.join(f'{v:08x}' for v in struct.unpack_from('<48I', sh, 0))
            else:
                line += '\n       no DDS magic; head ' + body[:32].hex()
        print(line)
        if dump and tn == 'lua':
            Path(f'/tmp/claude-0/-home-claude/c2ff0839-0d4a-581e-b262-7b5f65cd16db/scratchpad/{name:016x}.lua').write_bytes(d[doff + 8:doff + dsize])


if __name__ == '__main__':
    main(sys.argv[1], '--dump' in sys.argv)
