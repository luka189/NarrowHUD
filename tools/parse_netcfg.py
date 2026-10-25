"""Reads the game's network config (generated.network_config.main, taken out of the game files with filediver:
`filediver.exe -T network_config -o extracted`) and lists its game object types and their fields.

    python3 tools/parse_netcfg.py generated.network_config.main types.json

The types are one after the other, each:
    u32 type id (thin hash), u32 ?, u32 ?, u32 0, u32 0, u32 n, n x u32 field type index, u32 n, n x u32 field id, u32 ?
(learnt on the 2026-10-22 build: 1,884 types from 0x52b42 to 0xb6da2, no gaps). Ids are thin hashes:
murmur64(name) >> 32.
"""
import json
import struct
import sys


def records(d):
    def rec_at(p):
        if p + 28 > len(d):
            return None
        tid, a, b, z1, z2, m = struct.unpack_from('<6I', d, p)
        if z1 or z2 or m == 0 or m > 600:
            return None
        q = p + 24
        if q + 8 * m + 8 > len(d):
            return None
        idx = struct.unpack_from('<%dI' % m, d, q)
        if max(idx) > 4000 or struct.unpack_from('<I', d, q + 4 * m)[0] != m:
            return None
        fields = struct.unpack_from('<%dI' % m, d, q + 4 * m + 4)
        k = struct.unpack_from('<I', d, q + 8 * m + 4)[0]
        return dict(at=p, id=tid, a=a, b=b, types=list(idx), fields=list(fields), k=k, end=q + 8 * m + 8)

    out, p = [], 0
    while p < len(d) - 28:
        r = rec_at(p)
        if r and (rec_at(r['end']) or r['end'] >= len(d) - 8 or (out and r['at'] == out[-1]['end'])):
            out.append(r)
            p = r['end']
        else:
            p += 2
    return out


def main():
    d = open(sys.argv[1], 'rb').read()
    recs = records(d)
    print(f'{len(recs)} types, {hex(recs[0]["at"])} to {hex(recs[-1]["end"])}', file=sys.stderr)
    json.dump([{k: v for k, v in r.items() if k != 'end'} for r in recs], open(sys.argv[2], 'w'))


if __name__ == '__main__':
    main()
