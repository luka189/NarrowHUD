"""NarrowHUD's icon textures: each art/icons/*.svg as the engine's texture resources, in a ladder of sizes, for
chef.bitmap (a texture drawn as a mask tinted by the colour given; Chef's UI material has no mipmaps, so a texture
drawn much smaller than it is looks stair-stepped: chef.texture_sizes picks the copy nearest the size drawn).

    python3 tools/make_textures.py            # writes build/textures/*.texture + *.gpu and src/textures_generated.lua

Each SVG is white (the icon) and black (holes) on transparent; the mask is its alpha times its whiteness. The
resource: 192 bytes of Stingray header, then a DDS header with the DX10 extension (RGBA8, one 2D texture, one mip
level), the pixels in .gpu_resources (tools/build.py packs them): the texture format Treasure Radar ships its icons
in (a BC3 chain with mip levels, as Stratagem Timers' icon sheet used before the October 2026 patch, showed as a
white square in the 1.5.4 and 1.5.8 tests).
"""
import io
import struct
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SIZES = [64, 128, 256]                          # the sizes shipped: squares, powers of two
PREFIX = 'mods/luka189/narrowhud/tex/'


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


def render(svg, size):
    """the icon fitted into a size x size square, centred, as a mask; and the icon's own width and height in it.
    Any fill but black is the icon (luka's stim is one dark colour, dogo314's grenade white); black is a hole."""
    import re
    import cairosvg
    text = Path(svg).read_text()
    def whiten(m):
        c = m.group(2).strip().lower()
        if c in ('none', '#000', '#000000', 'black') or c.startswith('url('):
            return m.group(0)
        return m.group(1) + '#ffffff' + m.group(3)
    text = re.sub(r'(fill:\s*)([^;"\']+)([;"\'])', whiten, text)
    text = re.sub(r'(fill=")([^"]+)(")', whiten, text)
    png = cairosvg.svg2png(bytestring=text.encode('utf-8'), output_width=size * 4)
    img = Image.open(io.BytesIO(png)).convert('RGBA')
    a = np.array(img).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3]
    sat = rgb.max(-1) - rgb.min(-1)
    white = np.clip(rgb.mean(-1) * (1 - sat), 0, 1)
    full = (al * white * 255).round().astype(np.uint8)
    # crop to the icon's own box, then fit the larger side to the square (a margin of 1/16 so mips don't bleed)
    ys, xs = np.nonzero(full)
    full = full[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h0, w0 = full.shape
    inner = size - 2 * (size // 16)
    scale = inner / max(w0, h0)
    w, h = max(1, round(w0 * scale)), max(1, round(h0 * scale))
    mask = np.array(Image.fromarray(full).resize((w, h), Image.LANCZOS))
    sq = np.zeros((size, size), np.uint8)
    top, left = (size - h) // 2, (size - w) // 2
    sq[top:top + h, left:left + w] = mask
    return sq, w, h


def texture_resource(width, height):
    """the texture resource: 192 bytes of Stingray header, then a DDS header with the DX10 extension: RGBA8
    (DXGI 28), one mip level (as Treasure Radar ships its icons)"""
    head = struct.pack('<III', 0, 0, 0xFFFFFFFF) + b'\0' * 180
    dds = b'DDS ' + struct.pack('<7I', 124, 0x100F, height, width, width * 4, 0, 1) + b'\0' * 44
    dds += struct.pack('<2I4s5I', 32, 4, b'DX10', 0, 0, 0, 0, 0)
    dds += struct.pack('<5I', 0x1000, 0, 0, 0, 0)
    dds += struct.pack('<5I', 28, 3, 0, 1, 0)
    out = head + dds
    assert len(out) == 340, len(out)
    return out


def texture(mask):
    """the mask (h, w) as a white picture with the mask for alpha: RGBA8, one level"""
    h, w = mask.shape
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = mask
    return texture_resource(w, h), rgba.tobytes()


# --- the game's own icon layout (docs/ICONS.md: HD2Runtime's research, HUDdle's atlases): the main part's first word
# the icon class 0xFCE7DA44, flags 0x21007 with the mip count, pitch 0, caps 0x401008, BC3 with the full mip chain
# in the gpu part. The 1.5.8 BC3 attempt had the header off in four places and showed as a white square.
ICON_CLASS = 0xFCE7DA44


def bc3_encode(rgba):
    """RGBA (h, w, 4), h and w multiples of 4 -> BC3 blocks."""
    h, w = rgba.shape[:2]
    blocks = rgba.reshape(h // 4, 4, w // 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 4).astype(np.int32)
    n = blocks.shape[0]
    a = blocks[..., 3]
    a0, a1 = a.max(1), a.min(1)
    same = a0 == a1
    span = np.maximum(a0 - a1, 1)
    t = np.clip(np.rint((a0[:, None] - a) * 7 / span[:, None]), 0, 7).astype(np.int64)
    amap = np.array([0, 2, 3, 4, 5, 6, 7, 1])
    aidx = amap[t]
    aidx[same] = 0
    abits = np.zeros(n, np.uint64)
    for i in range(16):
        abits |= aidx[:, i].astype(np.uint64) << np.uint64(3 * i)
    a1w = np.where(same, a0, a1)
    alpha_part = np.zeros((n, 8), np.uint8)
    alpha_part[:, 0] = a0
    alpha_part[:, 1] = a1w
    for i in range(6):
        alpha_part[:, 2 + i] = ((abits >> np.uint64(8 * i)) & np.uint64(0xFF)).astype(np.uint8)
    rgb = blocks[..., :3]
    lum = rgb @ np.array([299, 587, 114])
    hi = rgb[np.arange(n), lum.argmax(1)]
    lo = rgb[np.arange(n), lum.argmin(1)]

    def to565(c):
        return ((c[:, 0] * 31 + 127) // 255 << 11) | ((c[:, 1] * 63 + 127) // 255 << 5) | ((c[:, 2] * 31 + 127) // 255)

    def from565(v):
        r, g, b = (v >> 11) & 31, (v >> 5) & 63, v & 31
        return np.stack([(r * 255 + 15) // 31, (g * 255 + 31) // 63, (b * 255 + 15) // 31], 1)

    c0, c1 = to565(hi), to565(lo)
    swap = c0 < c1
    c0, c1 = np.where(swap, c1, c0), np.where(swap, c0, c1)
    eq = c0 == c1
    p0, p1 = from565(c0), from565(c1)
    pal = np.stack([p0, p1, (2 * p0 + p1) // 3, (p0 + 2 * p1) // 3], 1)
    d = ((rgb[:, :, None, :] - pal[:, None, :, :]) ** 2).sum(-1)
    cidx = d.argmin(-1)
    cidx[eq] = 0
    cbits = np.zeros(n, np.uint64)
    for i in range(16):
        cbits |= cidx[:, i].astype(np.uint64) << np.uint64(2 * i)
    color_part = np.zeros((n, 8), np.uint8)
    color_part[:, 0] = c0 & 0xFF
    color_part[:, 1] = c0 >> 8
    color_part[:, 2] = c1 & 0xFF
    color_part[:, 3] = c1 >> 8
    for i in range(4):
        color_part[:, 4 + i] = ((cbits >> np.uint64(8 * i)) & np.uint64(0xFF)).astype(np.uint8)
    return np.concatenate([alpha_part, color_part], 1).tobytes()


def texture_resource_game(width, height, mips, dxgi=77):
    head = struct.pack('<4I', ICON_CLASS, 0, 0xFFFFFFFF, 0).ljust(0xC0, b'\0')
    dds = b'DDS ' + struct.pack('<7I', 124, 0x21007, height, width, 0, 0, mips) + b'\0' * 44
    dds += struct.pack('<2I4s5I', 32, 4, b'DX10', 0, 0, 0, 0, 0)
    dds += struct.pack('<5I', 0x401008, 0, 0, 0, 0)
    dds += struct.pack('<5I', dxgi, 3, 0, 1, 0)
    out = head + dds
    assert len(out) == 340, len(out)
    return out


def texture_game(mask):
    """the mask as a BC3 texture with every mip level (each made from the full picture), the game's icon layout"""
    size = mask.shape[0]
    assert mask.shape == (size, size) and size & (size - 1) == 0
    img = Image.fromarray(mask)
    levels, gpu = 0, b''
    s = size
    while s >= 1:
        m = np.array(img.resize((s, s), Image.LANCZOS)) if s != size else mask
        if s < 4:                             # (a block is 4 x 4: the smallest levels padded)
            pad = np.zeros((4, 4), np.uint8); pad[:s, :s] = m; m = pad
        rgba = np.zeros((m.shape[0], m.shape[1], 4), np.uint8)
        rgba[..., :3] = 255
        rgba[..., 3] = m
        gpu += bc3_encode(rgba)
        levels += 1
        s //= 2
    return texture_resource_game(size, size, levels), gpu


def main():
    out = ROOT / 'build' / 'textures'
    out.mkdir(parents=True, exist_ok=True)
    lua = ['-- NarrowHUD icon textures, made by tools/make_textures.py from art/icons/*.svg: each icon in a ladder of sizes',
           "-- (size, the icon's height in it, the resource id, its width), smallest first, for chef.texture_sizes and chef.bitmap,",
           "-- and once in the game's icon layout. The stim and the reticle are luka189's; the grenade was traced by dogo314 (used with permission).", 'return {']
    for svg in sorted((ROOT / 'art' / 'icons').glob('*.svg')):
        name = svg.stem
        entries = []
        for width in sorted(SIZES):
            mask, w, h = render(svg, width)
            res = f'{PREFIX}{name}_{width}'
            tex, gpu = texture(mask)
            hid = '%016x' % resource_hash(res)
            (out / f'{hid}.texture').write_bytes(tex)
            (out / f'{hid}.gpu').write_bytes(gpu)
            Image.fromarray(mask).save(out / f'{name}_{width}.png')
            entries.append(f"{{ {width}, {h}, '{hid}', {w} }}")
        lua.append(f"  {name} = {{ {', '.join(entries)} }},   -- (square textures, the icon centred: {w} wide, {h} high in the largest)")
        # the same icon in the game's own icon layout (BC3, every mip level): one texture, no ladder
        mask, w, h = render(svg, 256)
        res = f'{PREFIX}{name}_game'
        tex, gpu = texture_game(mask)
        hid = '%016x' % resource_hash(res)
        (out / f'{hid}.texture').write_bytes(tex)
        (out / f'{hid}.gpu').write_bytes(gpu)
        lua.append(f"  {name}_game = {{ {{ 256, {h}, '{hid}', {w} }} }},   -- (the game's icon layout: BC3, 9 mip levels; the icon {w} wide, {h} high, centred)")
        print(name, 'done:', ', '.join(str(s) for s in sorted(SIZES)), '+ the game layout')
    lua.append('}')
    (ROOT / 'src' / 'textures_generated.lua').write_text('\n'.join(lua) + '\n')


if __name__ == '__main__':
    main()
