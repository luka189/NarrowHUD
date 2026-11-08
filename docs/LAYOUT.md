# The layout file (Layout: Custom layout)

With **F9 > NarrowHUD > Layout: Custom layout**, NarrowHUD draws each part of the HUD where a layout file says. The layout
editor writes this file; it can also be edited by hand.

- **Where:** `%APPDATA%\Arrowhead\Helldivers2\chef_data_luka189_2fnarrowhud__layout.lua`
- **First time:** if there's no file when Custom is chosen, NarrowHUD writes one with Under's look to start from.
- **Not the learned file:** `chef_data_luka189_2fnarrowhud__learned.lua` next to it is what NarrowHUD has learned about
  your weapons, rewritten as you play. (From 1.2.1, a layout pasted there by mistake is moved to the layout file.) Save
  with Ctrl+S: Notepad's "Save as" can make it `...layout.lua.txt`, which isn't read.
- **Read:** when Custom is chosen, at the start of each mission, and when you press the key set in F9 under "Read the
  layout file again" (no key until you pick one; it says so on screen, and says when the Layout isn't Custom).
- **Safe:** the file is a plain Lua table, read by Chef Shared Loader with nothing else available (it can't run
  code). A value that doesn't fit is left at its default and counted in narrowhud.log.
- **On top of it:** the F9 "Show ..." toggles, colours, opacity, "When nothing changes for a while" and Size still
  apply. F9's two offsets move the layout only when the file has `use_offsets = true` (off by default, so offsets set
  for another layout don't move a Custom one placed in the editor).

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

An element left out, or a field left out, takes Under's look's value — so a file written for an older version
(1.5's, before pins, sides, edges and the split parts) still loads as it was; the new fields take their defaults.

### Every element

| Field | Values | Default |
|---|---|---|
| `on` | `true` / `false` | `true` |
| `anchor` | the screen point it's placed from: `center`, `top`, `bottom`, `left`, `right`, `top_left`, `top_right`, `bottom_left`, `bottom_right` | `center` |
| `x`, `y` | from the anchor, in % of the screen's **height** (so the HUD keeps its shape on any screen): + right / up, - left / down; -100 to 100 | 0 |
| `align` | which point of the element sits there: `bottom_left`, `bottom`, `bottom_right`, `left`, `center`, `right`, `top_left`, `top`, `top_right`; `arc` (1.5.74): a curved bar's own centre — the point its radius is measured from — so arcs around the crosshair stay concentric at every Size (a box edge can't: the box grows with the radius); for a straight part or a pinned one, as `center` | `bottom_left` |
| `size` | times the HUD's size (F9 Size); 0.3 to 4 | 1 |
| `opacity` | %, times F9's opacity; 0 to 100 | 100 |
| `after` | another part's name (`count`, `bar` ...): placed from that part's box (a **pin**, 1.5.53), so it moves along as that part grows ("100%") or is scaled, and **takes that part's place when it isn't drawn** (off, or nothing to show: no backpack, a rifle with no charge meter). Any part can be followed; a loop (a after b after a) is broken at the part that closes it, logged once. `none` to place it on its own | `none` |
| `pin` | which side of that part (with `after`): `right`, `left`, `above` or `below`, `gap` pixels between them; `align` says which edges line up (right / left: `bottom_*` bottoms level, `top_*` tops, `left` / `right` / `center` middles; above / below: `*_left` left edges, `*_right` right edges, `bottom` / `top` / `center` middles); `x` and `y` then nudge it from there (scaled with Size and the part's size, as the gap is, so the group keeps its shape at every Size). `none`: the old way (files from before 1.5.53): only `x` follows, from that part's right edge, `y` stays the part's own | `none` |
| `gap` | pixels between the two (at 1440p, Medium), with `after`; can be negative; -500 to 500 | 8 |
| `hold` | `true`: while the part has nothing to show for the moment (the weapon put away, a stratagem ball in hand, no gun seated), it keeps the place it had, so the parts pinned to it stay where they are. `false`: they take its place, as they do for a part that's Off or one this loadout never has (no backpack, no charge meter). Under's look has it on for the ammo bar, the count, health and stamina — the parts that only vanish for a moment (1.5.72, 1.5.75) | false |
| `color` | (2.6.8) the part's own colour at rest, `'RRGGBB'` (a `#` in front is fine): its text, bar, squares, ticks and icons. Low and Empty (orange, red) stay the palette's, so a low magazine still reads as one. Left out: the Colours tab's Text / Bars | none |
| `side` | which way F9's **Spread** and **Aim spread** sliders move the part (1.5.53): `left` or `right` (the two sides of the crosshair apart), `up` or `down` (2.2.9: the part vertically — the horizontal layout's free parts are `down`, so the whole stack moves down while you aim), `none`, or `auto` (left or right by the part's `x` from the `center` anchor; a part on another anchor is `none`). A pinned part goes with the part it's pinned to | `auto` |

Sizes are in pixels at 1440p for Medium; they scale with the screen's height and Size.

### The elements and their own fields

| Element | What it is | Own fields |
|---|---|---|
| `bar` | the ammo / heat bar, with its heat marks | `style` (see below); `fill` `auto` / `ticks` / `solid` (auto: a tick a round up to `ticks_max` rounds); `length` (260); `thickness` (14); `ticks_max` (30); `radius` (150); `edge`, `shade` (see below) |
| `charge` | the charge and lock-on meter (Railgun, Epoch, Spear ...; the Arc Thrower's charge) | `style` (see below); `length` (260); `thickness` (4); `radius` (150); `edge`, `shade` |
| `count` | rounds, or heat % | `digits` `auto` (F9 › Look › Count digits) / `fixed` (the number right-aligned in a box as wide as the full magazine, so it never slides as it falls) / `tight` (the number's own width) (2.2.0) |
| `mags` | spare magazines | `style` `number` (x7) / `squares`; `empty` `shown` / `hidden` (squares); `divider` `true` / `false` (a line before the number) |
| `mode1` | (1.5.54) the weapon mode alone: HEAT, UB, APHET ...; off unless a file turns it on, so the two can be pinned apart | — |
| `mode2` | the fire mode: AUTO, SEMI ... | — |
| `zoom` | the scope's zeroing as text (50 M / 100 M / 200 M), for a weapon whose scope is known; a part like any other (1.5.69: the fire mode never carries it in a layout; F9's zeroing-text toggle is for Under and Beside) | — |
| `icon1` | the game's own icon of the weapon mode (the ammo kind, the underbarrel); squares of twice the stim's width (1.5.66: the grouped `icons` part is gone) | `style` `line` / `stacked` |
| `icon2` | the fire mode's icon | `style` `line` / `stacked` |
| `zoomicon` | the zeroing icon (the game's low / medium / high); a part like any other | — |
| `rpm` | the rate of fire setting | — |
| `stims` | the stim icon and count | — |
| `grenades` | the grenade icon and count | — |
| `pack` | the backpack bar (also the warp pack's heat, the jump pack's recharge) | `style` (see below); `length` (135); `thickness` (7); `radius` (150); `edge`, `shade` |
| `health` | your health (1.1.0; shown when F9 › Health bar is on): cream, orange from half, red from a quarter, a hit's loss in red for a moment | `style` (see below); `length` (260); `thickness` (5); `radius` (150); `edge`, `shade` |
| `stamina` | your stamina (1.1.0; shown when F9 › Stamina bar is on): blue, orange when nearly out | `style` (see below); `length` (260); `thickness` (3); `radius` (150); `edge`, `shade` |
| `stim` | the stim timer (1.2.0; shown when F9 › Stim timer is on): green, shrinking over a stim's effect | `style` (see below); `length` (260); `thickness` (3); `radius` (150); `edge`, `shade` |

The elements are listed in the order they're drawn. A part placed on its own doesn't move when another grows: with
`digits` tight the count's width changes with its digits and its % sign, so the magazines follow it (`after = 'count'`)
in the horizontal look; with digits fixed (the default) the count's box is the full magazine's width and stays put.

### Bar styles (`bar`, `charge`, `pack`, `health`, `stamina`, `stim`)

| `style` | Shape | Fills |
|---|---|---|
| `horizontal` | a straight bar, side to side | from the left |
| `vertical` | a straight bar, up and down | from the bottom |
| `curved_left` | a `(`: a piece of a circle bulging left, for the left of the crosshair | from the bottom |
| `curved_right` | a `)`: a piece of a circle bulging right, for the right of the crosshair | from the bottom |
| `curved_up` | (2.6.10) a `∩`: a piece of a circle bulging up | from the left |
| `curved_down` | (2.6.10) a `∪`: a piece of a circle bulging down | from the left |

A bar's look (1.5.53), two fields apart: `edge` — `none`, `outline` (a line around the whole bar, the fill inside it)
or `brackets` (square brackets at the two ends, as the game draws its own health and stamina) — and `shade` — `on`
(the empty part faint behind the fill) or `off` (nothing there). Both default to `auto`: F9's own Look rows ("bar
edges", "shade behind the bars"), so one F9 choice styles every bar unless a bar says otherwise.

For the curved ones, `length` runs along the curve, `thickness` across it, and `radius` is the circle's (its middle
line's): a smaller radius curves more. The curve covers at most 360 degrees: a `length` of 2π × `radius` closes it
into a circle (2.6.10; 300 degrees before), its two ends meeting where the fill starts. The element's box
(what `align` and `anchor` place) is the box around the curve, so for a pair around the crosshair use
`align = 'right'` for the `(` and `align = 'left'` for the `)`, with `x` set to how far out each one sits.
Where Chef Shared Loader can't draw triangles, the curved ones are drawn `vertical` instead.


## `colors` (2.6.8): the palette from the file

The Colours tab's roles, set in the file instead; any given here wins over the tab's row, so one file carries the
whole look. The same `'RRGGBB'` strings; a role left out keeps the tab's.

```lua
return {
  _v = 1,
  colors = { text = 'ECE5CE', bars = 'ECE5CE', low = 'F0AA5A', empty = 'D25048', mode_a = '82CDF5', mode_b = '50DCAF',
             lines = 'ECE5CE', stamina = '82BEEB' },
  elements = { ... },
}
```

`lines` is drawn in the world, where each planet's light shifts a colour: pure colours (white, blue, red, green)
or the cream read as meant; anything else won't.

## `struct_parts` (for testing the red mark)

An optional block beside `elements`, for fitting the shapes the red landing mark tests against the enemies'
structures. Each structure kind has a box from the game (its whole mesh, mound and all — F9 Testing "Draw
structure boxes" draws it in dim red); a kind can instead get *parts*, smaller boxes of your own inside it (drawn
in full red), and the mark goes red only where the shot enters a part. Keyed by a piece of the kind's name, each a
list of parts, each a list of 4 to 9 numbers:

```lua
struct_parts = {
  bug_spawner_small_01 = { { 0.4, 0.3, 0.1, 0.6, 0.3, -0.2, 0, 0, 0 } },
}
```

`fx, fy` — the part's width and depth as fractions of the box's (0 to 1); `z0, z1` — the part's bottom and top as
fractions of the box's height, from the bottom up; `ox, oy` — the part's middle moved right and forward, as
fractions of the box's half width and half depth (0 when left out); `pitch, roll, yaw` — the part's own turn in
degrees about its middle (0 when left out). A part can instead be given in metres from the unit's root, as
`{ m = { hx, hy, hz, cx, cy, cz } }` — half sizes, then the middle right, forward and up of the root — which is
how the built-in shapes are written. The reload key reads the block again, so the red lines can be moved until
they sit in the opening. The built-in shapes (from the structures' own models: the holes' shafts, the nests' and
the spewer's trunk and cap, the guns' bodies) apply where the block has no entry for a kind.
