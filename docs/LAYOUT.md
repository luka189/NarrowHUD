# The layout file (Position: Custom)

With **F9 > NarrowHUD > Position: Custom**, NarrowHUD draws each part of the HUD where a layout file says. The layout
editor writes this file; it can also be edited by hand.

- **Where:** `%APPDATA%\Arrowhead\Helldivers2\chef_data_luka189_2fnarrowhud__layout.lua`
- **First time:** if there's no file when Custom is chosen, NarrowHUD writes one with Under's look to start from.
- **Read:** when Custom is chosen, at the start of each mission, and when you press the key set in F9 under "Read the
  layout file again".
- **Safe:** the file is a plain Lua table, read by Chef Shared Loader with nothing else available (it can't run
  code). A value that doesn't fit is left at its default and counted in narrowhud.log.
- **On top of it:** the F9 "Show ..." toggles, colours, opacity, "When nothing changes for a while" and Size still
  apply. F9's two offsets move the layout only when the file has `use_offsets = true` (off by default, so offsets set
  for another Position don't move a layout placed in the editor).

## Format

```lua
return {
  _v = 1,
  use_offsets = false,   -- true: F9's Offset sliders move every part too
  elements = {
    bar   = { anchor = 'center', x = 0, y = -9, align = 'bottom', style = 'horizontal', length = 260, thickness = 14 },
    count = { anchor = 'center', x = 9.9, y = -8.5, align = 'left' },
    -- ...
  },
}
```

An element left out, or a field left out, takes Under's look's value.

### Every element

| Field | Values | Default |
|---|---|---|
| `on` | `true` / `false` | `true` |
| `anchor` | the screen point it's placed from: `center`, `top`, `bottom`, `left`, `right`, `top_left`, `top_right`, `bottom_left`, `bottom_right` | `center` |
| `x`, `y` | from the anchor, in % of the screen's **height** (so the HUD keeps its shape on any screen): + right / up, - left / down; -100 to 100 | 0 |
| `align` | which point of the element sits there: `bottom_left`, `bottom`, `bottom_right`, `left`, `center`, `right`, `top_left`, `top`, `top_right` | `bottom_left` |
| `size` | times the HUD's size (F9 Size); 0.3 to 4 | 1 |
| `opacity` | %, times F9's opacity; 0 to 100 | 100 |
| `after` | another part's name (`count`, `bar` ...): placed right after that part, `gap` pixels from its right edge, so it moves along as that part grows ("100%"). `x` is then not used. Only a part listed before it in the table below can be followed; `none` to place it on its own | `none` (Under's look, as written the first time, has `count` for `mags`) |
| `gap` | pixels between the two (at 1440p, Medium), with `after`; can be negative; -500 to 500 | 8 |

Sizes are in pixels at 1440p for Medium; they scale with the screen's height and Size.

### The elements and their own fields

| Element | What it is | Own fields |
|---|---|---|
| `bar` | the ammo / heat bar, with its heat marks | `style` (see below); `fill` `auto` / `ticks` / `solid` (auto: a tick a round up to `ticks_max` rounds); `length` (260); `thickness` (14); `ticks_max` (30); `radius` (150) |
| `charge` | the charge and lock-on meter (Railgun, Epoch, Spear ...; the Arc Thrower's charge) | `style` (see below); `length` (260); `thickness` (4); `radius` (150) |
| `count` | rounds, or heat % | — |
| `mags` | spare magazines | `style` `number` (x7) / `squares`; `empty` `shown` / `hidden` (squares); `divider` `true` / `false` (a line before the number) |
| `modes` | HEAT, UB, the weapon mode and the fire mode | `style` `line` / `stacked` |
| `rpm` | the rate of fire setting | — |
| `stims` | the stim icon and count | — |
| `grenades` | the grenade icon and count | — |
| `pack` | the backpack bar (also the warp pack's heat, the jump pack's recharge) | `style` (see below); `length` (135); `thickness` (7); `radius` (150) |

The elements are listed in the order they're drawn. A part placed on its own doesn't move when another grows: the
count's width changes with its digits and its % sign, so the magazines follow it (`after = 'count'`) in Under's look.

### Bar styles (`bar`, `charge`, `pack`)

| `style` | Shape | Fills |
|---|---|---|
| `horizontal` | a straight bar, side to side | from the left |
| `vertical` | a straight bar, up and down | from the bottom |
| `curved_left` | a `(`: a piece of a circle bulging left, for the left of the crosshair | from the bottom |
| `curved_right` | a `)`: a piece of a circle bulging right, for the right of the crosshair | from the bottom |

For the curved ones, `length` runs along the curve, `thickness` across it, and `radius` is the circle's (its middle
line's): a smaller radius curves more. The curve covers at most 300 degrees, however long it is. The element's box
(what `align` and `anchor` place) is the box around the curve, so for a pair around the crosshair use
`align = 'right'` for the `(` and `align = 'left'` for the `)`, with `x` set to how far out each one sits.
Where Chef Shared Loader can't draw triangles, the curved ones are drawn `vertical` instead.

