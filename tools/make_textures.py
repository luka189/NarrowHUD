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
    """the icon fitted into a size x size square, centred, as a mask; and the icon's own height within the square"""
    import cairosvg
    png = cairosvg.svg2png(url=str(svg), output_width=size * 4)
    img = Image.open(io.BytesIO(png)).convert('RGBA')
    w, h = img.size
    height = max(1, round(h * size / w))
    img = img.resize((size, height), Image.LANCZOS)
    a = np.array(img).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3]
    sat = rgb.max(-1) - rgb.min(-1)
    white = np.clip(rgb.mean(-1) * (1 - sat), 0, 1)
    mask = (al * white * 255).round().astype(np.uint8)
    sq = np.zeros((size, size), np.uint8)
    top = (size - height) // 2
    sq[top:top + height, :] = mask
    return sq, height


def texture_resource(width, height):
    """the texture resource: 192 bytes of Stingray header, then a DDS header with the DX10 extension: RGBA8
    (DXGI 28), one mip level (as Treasure Radar ships its icons; the BC3 chain with mip levels of 1.5.4 and 1.5.8
    showed as a white square)"""
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


def main():
    out = ROOT / 'build' / 'textures'
    out.mkdir(parents=True, exist_ok=True)
    lua = ['-- NarrowHUD icon textures, made by tools/make_textures.py from art/icons/*.svg: each icon in a ladder of sizes',
           "-- (size, the icon's height in it, the resource id), smallest first, for chef.texture_sizes and chef.bitmap.", 'return {']
    for svg in sorted((ROOT / 'art' / 'icons').glob('*.svg')):
        name = svg.stem
        entries = []
        for width in sorted(SIZES):
            mask, h = render(svg, width)
            res = f'{PREFIX}{name}_{width}'
            tex, gpu = texture(mask)
            hid = '%016x' % resource_hash(res)
            (out / f'{hid}.texture').write_bytes(tex)
            (out / f'{hid}.gpu').write_bytes(gpu)
            Image.fromarray(mask).save(out / f'{name}_{width}.png')
            entries.append(f"{{ {width}, {h}, '{hid}' }}")
        lua.append(f"  {name} = {{ {', '.join(entries)} }},   -- (square textures: the icon fills the width, {h} of {width} high in the largest)")
        print(name, 'done:', ', '.join(str(s) for s in sorted(SIZES)))
    lua.append('}')
    (ROOT / 'src' / 'textures_generated.lua').write_text('\n'.join(lua) + '\n')


if __name__ == '__main__':
    main()
