-- NarrowHUD, custom: the Custom layout: the layout file (docs/LAYOUT.md) and its elements.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, learned, learn, txt_width, txt, CREAM = N.cfg, N.learned, N.learn, N.txt_width, N.txt, N.CREAM
local WARN, RED, col, empty_rect, solid_bar, txt_modes = N.WARN, N.RED, N.col, N.empty_rect, N.solid_bar, N.txt_modes
local BARS, STAMINA_C = N.BARS, N.STAMINA                -- (2.6.6: the Bars and Stamina roles; CREAM is Text)
local MARK_COLORS, heat_tone, pack_state = N.MARK_COLORS, N.heat_tone, N.pack_state

------------------------------------------------------------------------------------------------ a custom layout
-- Each part of the HUD an element of its own, placed, sized and styled by the layout file
-- (chef_data_luka189_2fnarrowhud__layout.lua in %APPDATA%\Arrowhead\Helldivers2, made by the layout editor or by
-- hand). Layout "Custom layout" draws from it; the F9 toggles, colours, opacity, idle dimming, Size and the offsets apply
-- on top. Every element: on, anchor (a point of the screen), x / y (from there, % of the screen's height: right and
-- up), align (which point of the element sits there), size (x the HUD's), opacity (%), and its own style fields.
local LAYOUT_VERSION = 1
local ANCHORS = { center = { 0.5, 0.5 }, top = { 0.5, 1 }, bottom = { 0.5, 0 }, left = { 0, 0.5 }, right = { 1, 0.5 },
  top_left = { 0, 1 }, top_right = { 1, 1 }, bottom_left = { 0, 0 }, bottom_right = { 1, 0 } }
local ALIGNS = { bottom_left = { 0, 0 }, bottom = { 0.5, 0 }, bottom_right = { 1, 0 }, left = { 0, 0.5 },
  center = { 0.5, 0.5 }, right = { 1, 0.5 }, top_left = { 0, 1 }, top = { 0.5, 1 }, top_right = { 1, 1 },
  -- (1.5.74) arc: a curved bar's own centre (the point its radius is measured from) sits on the anchor, so arcs
  -- around the crosshair stay concentric at every Size (a box's edge can't: the box grows with the radius); for
  -- anything else, or a pinned part, as center
  arc = { 0.5, 0.5 } }
-- the elements in drawing order, each field: { kind, default, min / choices, max }
-- after: right after another part (drawn before it), gap pixels (at 1440p, Medium) from its right edge, its x then
-- not used: a count that grows ("100%") pushes the magazines along instead of running over them
-- (3.0.8: a hidden icon part keeps a size for the parts pinned to it; 3.0.10: its ink's — the usual icon's fractions
-- of the square: a mode or fire-mode icon about half of it, the zeroing's 0.53, the rate-of-fire bar 0.52 x 0.19)
local ICON_PARTS = { icon1 = { 0.5, 0.5 }, icon2 = { 0.48, 0.47 }, zoomicon = { 0.53, 0.53 }, rpmicon = { 0.52, 0.19 } }
local AFTER = { none = 1, bar = 1, charge = 1, count = 1, mags = 1, rpm = 1, stims = 1, grenades = 1, range = 1, pack = 1,
  health = 1, stamina = 1, stim = 1, mode1 = 1, mode2 = 1, icon1 = 1, icon2 = 1, zoom = 1, zoomicon = 1, rpmicon = 1 }
-- (1.5.53) pin: how a part sits against the one it's after — none: the old way (its x from that part's right edge
-- plus the gap, its y its own); right / left / above / below: its whole place from that part's box (the gap between
-- them, the align choosing the edge they line up on, x / y then small nudges). A part that isn't drawn (off, or
-- nothing to show: no backpack, a rifle with no charge meter) leaves its place to what's pinned to it.
-- side: left or right of the crosshair, for F9's Spread slider (auto: by the part's x from the centre anchor).
local PINS = { none = 1, right = 1, left = 1, above = 1, below = 1 }
-- (1.5.53) a bar's edge and shade: F9's ('auto'), or its own
local EDGES = { auto = 1, none = 1, outline = 1, brackets = 1 }
local SHADES = { auto = 1, on = 1, off = 1, hatch = 1 }   -- (2.3.9: hatch, the game's diagonal stripes)
local BAR_LOOK = { edge = { 'choice', 'auto', EDGES }, shade = { 'choice', 'auto', SHADES } }
local EDGE_OF = { none = 1, outline = 2, brackets = 3 }
local function look_of(e)
  local edge = e.edge == 'auto' and (cfg.edge or 1) or EDGE_OF[e.edge]
  local shade = e.shade == 'auto' and cfg.shade ~= false or e.shade == 'on' or e.shade == 'hatch'
  if shade and (e.shade == 'hatch' or (e.shade == 'auto' and cfg.hatch)) then shade = 'hatch' end
  return edge, shade
end
-- (2.2.9) side: up / down too — the Spread and the Aim spread move the part along its side, so a horizontal stack
-- (its parts on no side) can go down as a whole while you aim: luka's ask. "Apart from the crosshair": + is down
-- for down, up for up. The horizontal preset's free parts are 'down'
local SIDES = { auto = 1, none = 1, left = 1, right = 1, up = 1, down = 1 }
local COMMON = { on = { 'boolean', true }, anchor = { 'choice', 'center', ANCHORS }, x = { 'number', 0, -100, 100 },
  y = { 'number', 0, -100, 100 }, align = { 'choice', 'bottom_left', ALIGNS }, size = { 'number', 1, 0.3, 4 },
  opacity = { 'number', 100, 0, 100 }, after = { 'choice', 'none', AFTER }, gap = { 'number', 8, -500, 500 },
  pin = { 'choice', 'none', PINS }, side = { 'choice', 'auto', SIDES }, hold = { 'boolean', false },
  color = { 'color', nil } }   -- (2.6.8: the part's own colour at rest, 'RRGGBB'; none: the Colours tab's)
-- (1.5.72) hold: a part with nothing to show for the moment (the weapon put away, a stratagem ball in hand, no
-- weapon seated) keeps the place it had, so the parts pinned to it stay where they are; off, they take its place
-- (as a part that's Off, or one this loadout never has — no backpack, no charge meter — always does). On in Under's
-- look for the parts that only vanish for a moment — the ammo bar and the count (the weapon put away), health and
-- stamina — and off for the ones a weapon or loadout may not have (the charge meter, the magazines, the backpack,
-- the modes, the rate of fire), which give their place away (luka, 1.5.72 / 1.5.75)
local ELEMENTS = {
  { id = 'bar', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1, curved_up = 1, curved_down = 1 } },
      fill = { 'choice', 'auto', { auto = 1, ticks = 1, solid = 1 } }, length = { 'number', 260, 10, 2000 },
      radius = { 'number', 150, 10, 2000 },
      thickness = { 'number', 14, 1, 200 }, ticks_max = { 'number', 30, 1, 200 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  { id = 'charge', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1, curved_up = 1, curved_down = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 4, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  -- (2.1.13) digits: fixed — the number sits right-aligned in a box as wide as it gets (the full magazine, the full
  -- heat), so it never slides as it falls and what's pinned after it stays put (a player, 2026-11-01: "the 9 where
  -- the 0 of 10 was"); tight — the box is the number's own width, as before; auto (2.2.0) — as F9's Look row
  { id = 'count', fields = { digits = { 'choice', 'auto', { auto = 1, fixed = 1, tight = 1 } } } },
  { id = 'mags', fields = { style = { 'choice', 'number', { number = 1, squares = 1 } },
      empty = { 'choice', 'shown', { shown = 1, hidden = 1 } }, divider = { 'boolean', false } } },
  -- (1.5.54) the modes as two parts, to pin apart: the weapon mode (HEAT, UB, APHET ...) and the fire mode (AUTO ...,
  -- with the zeroing text). (1.5.66: the grouped "modes" part is gone — luka: pin these two instead; a file that
  -- still has it is read without it)
  { id = 'mode1', fields = {} },
  { id = 'mode2', fields = {} },
  -- (1.5.65) the scope's zeroing as parts of its own, text ("100 M") and icon. (1.5.69: parts like any other — the
  -- fire mode and its icon never carry the zeroing in a layout; off is off. Under and Beside keep it with the fire
  -- mode, by F9's zeroing-text toggle)
  { id = 'zoom', fields = {} },
  { id = 'zoomicon', fields = {} },
  -- (1.5.18) the game's own icons of the weapon's mode and fire mode (an F9 Show setting; docs/ICONS.md)
  -- (1.5.57 the two apart; 1.5.66 the grouped "icons" part gone, as the modes)
  { id = 'icon1', fields = { style = { 'choice', 'line', { line = 1, stacked = 1 } } } },
  { id = 'icon2', fields = { style = { 'choice', 'line', { line = 1, stacked = 1 } } } },
  { id = 'rpm', fields = {} },
  -- (3.0.6, luka) the rate-of-fire setting as the game's own icon (low / medium / high), beside or instead of the number
  { id = 'rpmicon', fields = {} },
  { id = 'stims', fields = {} },
  { id = 'grenades', fields = {} },
  -- (2.5.3, luka) the range: the metres to the landing chevron while a line is up, else to where the game's reticle
  -- points, for any weapon; "-" with nothing to measure (the sky: the reticle point 1 km out)
  { id = 'range', fields = {} },
  { id = 'pack', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1, curved_up = 1, curved_down = 1 } },
      length = { 'number', 120, 10, 2000 }, thickness = { 'number', 7, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  -- (1.1.0) your health and stamina: shown when F9's Health bar / Stamina bar say so (off by default)
  { id = 'health', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1, curved_up = 1, curved_down = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 5, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  { id = 'stamina', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1, curved_up = 1, curved_down = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 3, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  -- (1.2.0) the stim timer: shown when F9's Stim timer is on, while a stim of yours works
  { id = 'stim', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1, curved_up = 1, curved_down = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 3, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
}
-- the layout written the first time Custom is chosen and there's no file: Under's look, to start from
local DEFAULT_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { anchor = 'center', x = 0, y = -9, align = 'bottom', hold = true },
  charge = { anchor = 'center', x = 0, y = -7.75, align = 'bottom' },   -- (over the bar: 14 px and 4 px above -9 %)
  count = { anchor = 'center', x = 9.9, y = -8.5, align = 'left', hold = true },
  mags = { anchor = 'center', x = 0, y = 0, align = 'bottom_left', divider = true, after = 'count', pin = 'right', gap = 8 },
  zoom = { anchor = 'center', x = -9.7, y = -8.5, align = 'right' },
  mode2 = { anchor = 'center', x = 0, y = 0, align = 'bottom_right', after = 'zoom', pin = 'left', gap = 8 },
  mode1 = { anchor = 'center', x = 0, y = 0, align = 'bottom_right', after = 'mode2', pin = 'left', gap = 8 },
  zoomicon = { anchor = 'center', x = 0, y = 0, align = 'bottom_right', after = 'zoom', pin = 'below', gap = 16 },
  icon2 = { anchor = 'center', x = 0, y = 0, align = 'bottom_right', after = 'zoomicon', pin = 'left', gap = 32 },
  icon1 = { anchor = 'center', x = 0, y = 0, align = 'bottom_right', after = 'icon2', pin = 'left', gap = 32 },
  -- (3.0.7, luka) the rate-of-fire icon in the number's place, the number pinned right of it: the icon off (F9 or
  -- the layout), the number takes the icon's place
  rpmicon = { anchor = 'center', x = 0, y = 0, align = 'bottom_left', after = 'count', pin = 'below', gap = 20 },
  rpm = { anchor = 'center', x = 0, y = 0, align = 'left', after = 'rpmicon', pin = 'right', gap = 18 },
  stims = { anchor = 'center', x = -9, y = -9.6, align = 'top_left' },
  grenades = { anchor = 'center', x = 0, y = 0, align = 'top_left', after = 'stims', pin = 'right', gap = 8 },
  range = { anchor = 'center', x = 0, y = 0, align = 'top_left', after = 'grenades', pin = 'right', gap = 10 },
  pack = { anchor = 'center', x = -0.4, y = -10.6, align = 'left', length = 135 },
  -- (over the charge meter, as Under draws them)
  health = { anchor = 'center', x = 0, y = -7.33, align = 'bottom', hold = true },
  stamina = { anchor = 'center', x = 0, y = -6.78, align = 'bottom', hold = true },
  stim = { anchor = 'center', x = 0, y = -6.36, align = 'bottom' } } }

-- (2.0, luka's four layouts of 2026-10-30, made in the editor and passed here; their files in research/layouts)
-- F9's Layout row: 1 the horizontal stack, 2 the arcs, 3 the vertical pair, 4 the block, 5 a Custom file. The
-- old Under / Beside / Corner / Curved pair positions and the Preview ones are gone with them (the first three
-- were hand-drawn modules; Under's look lives on as DEFAULT_LAYOUT, what a Custom file leaves out).
-- The vertical pair: the ammo bar standing right of the crosshair, its middle at the crosshair's height, the
-- charge meter 8 px inside it and the backpack 8 px inside that; health standing on the left with the stamina
-- and the stim timer inside; the text at the bar's bottom right, the icons in a column from its top; stims and
-- grenades under the crosshair.
local VERTICAL_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { on = true, anchor = 'center', x = 7.6, y = 0, align = 'left', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'vertical', fill = 'auto', length = 190, radius = 150, thickness = 11, ticks_max = 30, edge = 'auto', shade = 'auto' },
  charge = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'left', side = 'auto', hold = false, style = 'vertical', length = 190, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  pack = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'bar', gap = 20, pin = 'left', side = 'auto', hold = false, style = 'vertical', length = 80, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' },
  count = { on = true, anchor = 'center', x = 0, y = -0.9, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 9, pin = 'right', side = 'auto', hold = true },
  mags = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'count', gap = 6, pin = 'right', side = 'auto', hold = false, style = 'number', empty = 'shown', divider = true },
  rpmicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'count', gap = 24, pin = 'above', side = 'auto', hold = false },
  rpm = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'rpmicon', gap = 18, pin = 'right', side = 'auto', hold = false },
  icon2 = { on = true, anchor = 'center', x = 0, y = 0.8, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = 11, pin = 'right', side = 'auto', hold = false, style = 'line' },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'icon2', gap = 7, pin = 'below', side = 'auto', hold = false, style = 'line' },
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'icon1', gap = 4, pin = 'below', side = 'auto', hold = false },
  mode1 = { on = false, anchor = 'center', x = 9.8, y = 7.6, align = 'top_left', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false },
  mode2 = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode1', gap = 4, pin = 'below', side = 'auto', hold = false },
  zoom = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode2', gap = 4, pin = 'below', side = 'auto', hold = false },
  stims = { on = true, anchor = 'center', x = -1, y = -8.1, align = 'top_right', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'none', hold = false },
  grenades = { on = true, anchor = 'center', x = 1, y = -8.1, align = 'top_left', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'none', hold = false },
  range = { on = true, anchor = 'center', x = 0, y = -11.6, align = 'center', size = 1, opacity = 100, after = 'none', gap = -67, pin = 'none', side = 'auto', hold = false },   -- (2.5.24, luka)
  health = { on = true, anchor = 'center', x = -7.6, y = 0, align = 'right', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'vertical', length = 190, thickness = 7, radius = 150, edge = 'auto', shade = 'auto' },
  stamina = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'health', gap = 8, pin = 'right', side = 'auto', hold = false, style = 'vertical', length = 190, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  stim = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'health', gap = 20, pin = 'right', side = 'auto', hold = false, style = 'vertical', length = 80, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' } } }
-- The arcs: every arc centred on the crosshair (align 'arc'); the bar, the charge meter 8 px inside it and the
-- backpack inside that on the right, health, stamina and the stim timer on the left; the text at the bar's
-- bottom right, the icons in a column at its middle.
local ARCS_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'curved_right', fill = 'auto', length = 225, radius = 120, thickness = 11, ticks_max = 30, edge = 'auto', shade = 'auto' },
  charge = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_right', length = 196, thickness = 4, radius = 104.5, edge = 'auto', shade = 'auto' },
  count = { on = true, anchor = 'center', x = 0, y = -0.6, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = -7, pin = 'right', side = 'auto', hold = false },
  mags = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'count', gap = 4, pin = 'below', side = 'auto', hold = false, style = 'number', empty = 'shown', divider = false },
  mode1 = { on = false, anchor = 'center', x = 0, y = 0.5, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = 14, pin = 'right', side = 'auto', hold = false },
  mode2 = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode1', gap = 4, pin = 'below', side = 'auto', hold = false },
  zoom = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode2', gap = 4, pin = 'below', side = 'auto', hold = false },
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'icon2', gap = 14, pin = 'below', side = 'auto', hold = false },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon2', gap = 14, pin = 'above', side = 'auto', hold = false, style = 'line' },
  icon2 = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'right', side = 'auto', hold = false, style = 'line' },
  rpmicon = { on = true, anchor = 'center', x = 0, y = -0.6, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = -1, pin = 'right', side = 'auto', hold = false },
  rpm = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'rpmicon', gap = 18, pin = 'right', side = 'auto', hold = false },
  stims = { on = true, anchor = 'center', x = -1.35, y = -6.45, align = 'center', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'none', hold = false },
  grenades = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'stims', gap = 10, pin = 'right', side = 'none', hold = false },
  range = { on = true, anchor = 'center', x = 0, y = -8.6, align = 'center', size = 1, opacity = 100, after = 'none', gap = 13, pin = 'none', side = 'auto', hold = false },   -- (2.5.24, luka)
  pack = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_right', length = 75, thickness = 5, radius = 92, edge = 'auto', shade = 'auto' },
  health = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'curved_left', length = 225, thickness = 7, radius = 120, edge = 'auto', shade = 'auto' },
  stamina = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_left', length = 200, thickness = 4, radius = 106.5, edge = 'auto', shade = 'auto' },
  stim = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_left', length = 77, thickness = 5, radius = 94, edge = 'auto', shade = 'auto' } } }
-- The horizontal stack: the bars under the crosshair (ammo, the charge meter above it; health with the stamina
-- above it, free), the count and magazines right of the bar, the icons left of it, stims and grenades and the
-- backpack under it.
local HORIZONTAL_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { on = true, anchor = 'center', x = 0, y = -12.2, align = 'bottom', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'down', style = 'horizontal', fill = 'auto', length = 260, radius = 150, thickness = 11, ticks_max = 30, edge = 'auto', shade = 'auto' },
  charge = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'above', side = 'auto', style = 'horizontal', length = 260, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  count = { on = true, anchor = 'center', x = 0, y = -0.6, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'right', side = 'auto' },
  mags = { on = true, anchor = 'center', x = 0, y = 0.3, align = 'bottom_left', size = 1, opacity = 100, after = 'count', gap = 8, pin = 'right', side = 'auto', style = 'number', empty = 'shown', divider = true },
  mode1 = { on = false, anchor = 'center', x = 0, y = 0, align = 'right', size = 1, opacity = 100, after = 'mode2', gap = 8, pin = 'left', side = 'auto' },
  mode2 = { on = false, anchor = 'center', x = 0, y = 0, align = 'right', size = 1, opacity = 100, after = 'zoom', gap = 8, pin = 'left', side = 'auto' },
  zoom = { on = false, anchor = 'center', x = -10.1, y = -10.62, align = 'right', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'down' },
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0.8, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 12, pin = 'right', side = 'auto' },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_right', size = 1, opacity = 100, after = 'icon2', gap = 14, pin = 'left', side = 'auto', style = 'line' },
  icon2 = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'bar', gap = 15, pin = 'left', side = 'auto', style = 'line' },
  rpmicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'count', gap = 16, pin = 'below', side = 'auto' },
  rpm = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'rpmicon', gap = 18, pin = 'right', side = 'auto' },
  stims = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'below', side = 'auto' },
  grenades = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'stims', gap = 8, pin = 'right', side = 'auto' },
  range = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom', size = 1, opacity = 100, after = 'stamina', gap = 10, pin = 'above', side = 'auto', hold = false },   -- (2.5.24, luka)
  pack = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_right', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 126, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' },
  health = { on = true, anchor = 'center', x = 0, y = -10, align = 'bottom', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'down', style = 'horizontal', length = 260, thickness = 7, radius = 150, edge = 'auto', shade = 'auto' },
  stamina = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom', size = 1, opacity = 100, after = 'health', gap = 8, pin = 'above', side = 'auto', style = 'horizontal', length = 260, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  stim = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'pack', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 126, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' } } }
-- The block: a short standing bar right of the crosshair with the charge meter inside it, the text column right
-- of it (the icons in a row above the count), stamina, health, the backpack and stim timer stacked under the bar.
local BLOCK_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { on = true, anchor = 'center', x = 10.7, y = -2.2, align = 'bottom_left', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'vertical', fill = 'auto', length = 107, radius = 150, thickness = 11, ticks_max = 30, edge = 'auto', shade = 'auto' },
  charge = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'left', side = 'auto', style = 'vertical', length = 107, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  count = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'bar', gap = 9, pin = 'right', side = 'auto', hold = true },
  mags = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'count', gap = 8, pin = 'right', side = 'auto', style = 'number', empty = 'shown', divider = false },
  mode1 = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'zoomicon', gap = 22, pin = 'right', side = 'auto' },
  mode2 = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode1', gap = 8, pin = 'right', side = 'auto' },
  zoom = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode2', gap = 8, pin = 'right', side = 'auto' },
  icon2 = { on = true, anchor = 'center', x = -0.8, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'count', gap = 11, pin = 'above', side = 'auto', style = 'line' },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon2', gap = 8, pin = 'right', side = 'auto', style = 'line' },
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon1', gap = 8, pin = 'right', side = 'auto' },
  rpmicon = { on = true, anchor = 'center', x = 1, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon2', gap = 21, pin = 'above', side = 'auto' },
  rpm = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'rpmicon', gap = 18, pin = 'right', side = 'auto' },
  stims = { on = true, anchor = 'center', x = 0.4, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'count', gap = 8, pin = 'below', side = 'auto' },
  grenades = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'stims', gap = 8, pin = 'right', side = 'auto' },
  range = { on = true, anchor = 'center', x = 0.2, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'pack', gap = 7, pin = 'below', side = 'auto', hold = false },   -- (2.5.24, luka)
  stamina = { on = true, anchor = 'center', x = -0.83, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 128, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  health = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'stamina', gap = 8, pin = 'below', side = 'auto', hold = true, style = 'horizontal', length = 128, thickness = 7, radius = 150, edge = 'auto', shade = 'auto' },
  pack = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'health', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 60, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' },
  stim = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_right', size = 1, opacity = 100, after = 'health', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 60, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' } } }

-- (2.6.12, luka's "Cake") five rings on one centre right of the crosshair, a 30-degree slice open at the top, 6 px
-- apart: the backpack and the stim timer sharing the innermost (150 degrees each, right and left), then stamina,
-- health, the ammo bar and the charge meter; the count and the magazines in the middle, the icons and the rate of
-- fire right of the rings, stims and grenades either side of the crosshair, the range under it.
local CAKE_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { on = true, anchor = 'center', x = 16.3, y = -13.1, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'curved_down', fill = 'auto', length = 466.5, radius = 81, thickness = 11, ticks_max = 30, edge = 'auto', shade = 'auto' },
  charge = { on = true, anchor = 'center', x = 16.3, y = -13.1, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_down', length = 544.3, thickness = 4, radius = 94.5, edge = 'auto', shade = 'auto' },
  count = { on = true, anchor = 'center', x = 16.3, y = -12.6, align = 'center', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, digits = 'tight' },
  mags = { on = true, anchor = 'center', x = 0, y = 0, align = 'top', size = 1, opacity = 100, after = 'count', gap = 3, pin = 'below', side = 'auto', hold = false, style = 'number', empty = 'shown', divider = false },
  mode1 = { on = false, anchor = 'center', x = 0, y = 0.5, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = 14, pin = 'right', side = 'auto', hold = false },
  mode2 = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode1', gap = 4, pin = 'below', side = 'auto', hold = false },
  zoom = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode2', gap = 4, pin = 'below', side = 'auto', hold = false },
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'icon2', gap = 14, pin = 'below', side = 'auto', hold = false },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon2', gap = 14, pin = 'above', side = 'auto', hold = false, style = 'line' },
  icon2 = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'bar', gap = 20, pin = 'right', side = 'auto', hold = false, style = 'line' },
  rpmicon = { on = true, anchor = 'center', x = 0, y = -0.6, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = 17, pin = 'right', side = 'auto', hold = false },
  rpm = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'rpmicon', gap = 18, pin = 'right', side = 'auto', hold = false },
  stims = { on = true, anchor = 'center', x = -1, y = -8.1, align = 'top_right', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'none', hold = false },
  grenades = { on = true, anchor = 'center', x = 1, y = -8.1, align = 'top_left', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'none', hold = false },
  range = { on = true, anchor = 'center', x = 0, y = -11.6, align = 'center', size = 1, opacity = 100, after = 'none', gap = -67, pin = 'none', side = 'auto', hold = false },
  pack = { on = true, anchor = 'center', x = 16.3, y = -13.1, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_right', length = 115.2, thickness = 5, radius = 44, edge = 'auto', shade = 'auto' },
  health = { on = true, anchor = 'center', x = 16.3, y = -13.1, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'curved_down', length = 380.1, thickness = 7, radius = 66, edge = 'auto', shade = 'auto' },
  stamina = { on = true, anchor = 'center', x = 16.3, y = -13.1, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_down', length = 313.9, thickness = 4, radius = 54.5, edge = 'auto', shade = 'auto' },
  stim = { on = true, anchor = 'center', x = 16.3, y = -13.1, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_left', length = 115.2, thickness = 5, radius = 44, edge = 'auto', shade = 'auto' } } }

-- a layout table as read: every known field checked (type, range, choice), what doesn't fit dropped and counted,
-- Under's look's values (or the field's default) for the rest
local function read_layout(t)
  local out, dropped = {}, 0
  local src = type(t) == 'table' and type(t.elements) == 'table' and t.elements or {}
  for _, el in ipairs(ELEMENTS) do
    local e, given = {}, src[el.id]
    if given ~= nil and type(given) ~= 'table' then dropped, given = dropped + 1, nil end
    for _, set in ipairs({ COMMON, el.fields }) do
      for name, f in pairs(set) do
        local v = given and given[name]
        local ok = v ~= nil
        if ok and f[1] == 'boolean' then ok = type(v) == 'boolean'
        elseif ok and f[1] == 'number' then ok = type(v) == 'number' and v == v and v >= f[3] and v <= f[4]
        elseif ok and f[1] == 'choice' then ok = type(v) == 'string' and f[3][v] ~= nil
        elseif ok and f[1] == 'color' then ok = type(v) == 'string' and N.hex_rgb(v) ~= nil end
        if v ~= nil and not ok then dropped = dropped + 1 end
        -- (a field not given: Under's look's, else the field's own default. Not after / pin / side when the element
        -- is in the file without them: a file from before pins had the magazines where its maker put them, which
        -- following the count would move. An element left out altogether takes all of Under's look (1.5.66: the
        -- split mode parts pinned as Under has them))
        local dv = (given == nil or (name ~= 'after' and name ~= 'pin' and name ~= 'side')) and DEFAULT_LAYOUT.elements[el.id] and DEFAULT_LAYOUT.elements[el.id][name] or nil
        if ok then e[name] = v elseif dv ~= nil then e[name] = dv elseif name == 'on' and el.off then e[name] = false else e[name] = f[2] end
      end
    end
    if e.color then e.rgb = { N.hex_rgb(e.color) } end   -- (2.6.8: parsed once)
    out[el.id] = e
  end
  return out, dropped
end
-- (2.6.8) the file's `colors = { text = 'RRGGBB', bars = ..., low, empty, mode_a, mode_b, lines, stamina }`: the
-- roles over the Colours tab's rows; what doesn't fit is dropped and counted
local COLOR_ROLES = { text = 1, bars = 1, low = 1, empty = 1, mode_a = 1, mode_b = 1, lines = 1, stamina = 1 }
local function read_colors(t)
  local out, dropped = {}, 0
  local src = type(t) == 'table' and t.colors or nil
  if src ~= nil and type(src) ~= 'table' then return out, 1 end
  for role, v in pairs(src or {}) do
    if COLOR_ROLES[role] and type(v) == 'string' and N.hex_rgb(v) then out[role] = v else dropped = dropped + 1 end
  end
  return out, dropped
end
local layout = { els = nil, said = nil, builtin = {} }
local cur = {}                                     -- the elements being drawn this frame
-- a built-in layout as read, once; F9's offsets move it
local BUILTIN = { vertical = VERTICAL_LAYOUT, arcs = ARCS_LAYOUT, horizontal = HORIZONTAL_LAYOUT, block = BLOCK_LAYOUT, cake = CAKE_LAYOUT }
local function builtin_layout(name)
  local l = layout.builtin[name]
  if not l then l = { els = read_layout(BUILTIN[name] or HORIZONTAL_LAYOUT) } layout.builtin[name] = l end
  return l
end
local function load_layout(why)
  -- (chef.load_table's second value says why there's no table: called on its own, an 'and' would drop it)
  local ok, t, err = false, nil, 'no chef.load_table'
  if chef.load_table then ok, t, err = pcall(chef.load_table, 'layout') end
  -- (no file yet: the horizontal, the first layout, written for the editor or a text editor to start from (2.0;
  -- Under's look before). One that's there but can't be read, a typo in a hand edit, is never written over:
  -- Under's look until it's fixed)
  local none = ok and type(t) ~= 'table' and (string.find(tostring(err), 'none saved') or
    string.find(tostring(err), 'no such file') or string.find(tostring(err), 'missing'))
  if none and chef.save_table then
    t = HORIZONTAL_LAYOUT
    pcall(chef.save_table, 'layout', t)
    log('layout file: none yet, one with the horizontal written (%s)', why)
  end
  if not ok or type(t) ~= 'table' then
    layout.els, layout.offsets = read_layout(DEFAULT_LAYOUT), false
    N.layout_colors = nil if N.apply_palette then N.apply_palette() end
    log('layout file: can\'t be read (%s): Under\'s look until it\'s fixed (%s)', tostring(ok and err or t), why)
    return false
  end
  local dropped
  layout.els, dropped = read_layout(t)
  local colors, cdropped = read_colors(t)
  N.layout_colors = next(colors) and colors or nil
  if N.apply_palette then N.apply_palette() end
  dropped = dropped + cdropped
  -- (F9's two offsets move a Custom layout only when its file says so: one set for another layout moved a Custom one
  -- placed in the editor without anyone noticing)
  layout.offsets = t.use_offsets == true
  if t.use_offsets ~= nil and type(t.use_offsets) ~= 'boolean' then dropped = dropped + 1 end
  if N.struct_parts_set then N.struct_parts_set(t.struct_parts) end   -- (2.5.15: the structures' parts, if the file has them)
  local v = tonumber(t._v) or 0
  log('layout file: read (%s)%s%s', why, dropped > 0 and string.format(', %d values that didn\'t fit left at their defaults', dropped) or '',
    v > LAYOUT_VERSION and string.format(', from a newer NarrowHUD (version %d): read what fits', v) or '')
  return true, dropped
end

-- the weapon's fill (0 to 1), colour and alpha, as the built-in layouts have them
local function weapon_tone(d)
  local frac = 0
  if d.top and d.top > 0 then frac = math.max(0, math.min(1, d.value / d.top)) end
  local tone = BARS                                           -- (2.6.6: the bar's rest colour; the count takes Text at rest)
  if d.kind == 'ammo' then
    if d.value == 0 then tone = RED elseif frac <= (cfg.low_ammo or 0.25) then tone = WARN end   -- (2.4.5: F9 Low ammo at)
  else
    if d.overheated then tone = RED
    elseif d.heat_marks then tone = heat_tone(d, frac)
    elseif frac >= 0.75 and not learned.charge2[d.tid] then tone = WARN end
  end
  return frac, tone, d.reloading and 120 or 235
end

-- Each element: measure (w, h for its box at scale k) and draw (at x, y, its box's bottom left). nil: nothing to show.
local L_CUSTOM = 905                             -- (+ N.L0, set at each draw_custom)
-- Curved bars: 'curved_left' a "(", 'curved_right' a ")", drawn as triangles (chef.triangle, as the 1.0.5 icons
-- were). length runs along the arc, thickness across it, radius is its middle line's; they fill from the bottom up.
-- Without chef.triangle, or when Chef draws triangles as rows of rects: vertical instead.
local arcs_ok = chef.triangle ~= nil
-- (2.6.10, luka) and 'curved_up' a "⌒" bulging up, 'curved_down' a "⌣" bulging down, both filling from the left; a
-- curve may cover the full 360 degrees now (a length of 2 pi times the radius closes the circle)
local ARC_MID = { curved_right = 90, curved_left = 270, curved_up = 0, curved_down = 180 }
local function curved(e) return arcs_ok and ARC_MID[e.style] ~= nil end
-- the arc's shape at scale k: { cx, cy (from the box's bottom left), r_in, r_out, bot (the bottom end's angle: 0 up,
-- clockwise, degrees), span (degrees), dir (+1: the fill goes clockwise), len }, and the box w, h
-- (worked out once per layout and size: the box takes a few dozen sin / cos)
local geo_cache = setmetatable({}, { __mode = 'k' })
local function arc_geom(e, k)
  local hit = geo_cache[e]
  if hit and hit.k == k then return hit.g, hit.w, hit.h end
  local th = math.max(1, math.floor(e.thickness * k + 0.5))
  local R = math.max(th, e.radius * k)
  local len = e.length * k
  local span = math.min(360, math.deg(len / R))
  local mid = ARC_MID[e.style] or 270
  -- (the fill runs from `bot` in direction `dir`: up from the bottom for the left and right curves, left to right
  -- for the up and down ones — clockwise for right and down, the other way for left and up)
  local cw = e.style == 'curved_right' or e.style == 'curved_down'
  local g = { r_in = R - th / 2, r_out = R + th / 2, span = span, len = len, th = th,
    bot = cw and (mid + span / 2) or (mid - span / 2), dir = cw and -1 or 1 }
  -- the box: every point of both edges, from one end to the other
  local x0, x1, y0, y1 = 1e9, -1e9, 1e9, -1e9
  local angs = {}
  for i = 0, 24 do angs[#angs + 1] = g.bot + g.dir * span * i / 24 end
  for q = -360, 360, 90 do   -- the farthest points, where the arc passes up, right, down or left (the up curve's angles run negative)
    if (q - g.bot) * g.dir >= 0 and (q - g.bot) * g.dir <= span then angs[#angs + 1] = q end
  end
  for _, deg in ipairs(angs) do
    local a = math.rad(deg)
    for _, r in ipairs({ g.r_in, g.r_out }) do
      local px, py = r * math.sin(a), r * math.cos(a)
      x0, x1, y0, y1 = math.min(x0, px), math.max(x1, px), math.min(y0, py), math.max(y1, py)
    end
  end
  g.cx, g.cy = -x0, -y0
  -- how many degrees one straight piece may cover: its middle no more than half a pixel inside the true curve
  -- (r (1 - cos(step / 2)) <= 0.5). Each piece is two triangles, and each triangle costs: 9 degrees at a 160 px
  -- radius, a third of a fixed 3 degrees.
  g.step = math.max(3, math.min(20, math.deg(2 * math.acos(math.max(-1, 1 - 0.5 / g.r_out)))))
  local w, h = math.ceil(x1 - x0), math.ceil(y1 - y0)
  geo_cache[e] = { k = k, g = g, w = w, h = h }
  return g, w, h
end
-- a piece of it from f0 to f1 (0: the bottom end, 1: the top), between radii r0 and r1
local function arc_piece(g, x, y, f0, f1, r0, r1, c, layer)
  if f1 <= f0 or r1 <= r0 then return end
  if not arcs_ok then return end
  local cx, cy = x + g.cx, y + g.cy
  local a0, a1 = g.bot + g.dir * g.span * f0, g.bot + g.dir * g.span * f1
  local n = math.max(1, math.ceil(math.abs(a1 - a0) / g.step - 0.01))
  local pa = math.rad(a0)
  local ix, iy, ox, oy = cx + r0 * math.sin(pa), cy + r0 * math.cos(pa), cx + r1 * math.sin(pa), cy + r1 * math.cos(pa)
  for i = 1, n do
    local a = math.rad(a0 + (a1 - a0) * i / n)
    local jx, jy, px, py = cx + r0 * math.sin(a), cy + r0 * math.cos(a), cx + r1 * math.sin(a), cy + r1 * math.cos(a)
    if chef.triangle(ix, iy, ox, oy, px, py, c, layer) == false then
      arcs_ok = false
      log('curved bars: Chef draws triangles as rows of rects here: vertical bars instead')
      return
    end
    chef.triangle(ix, iy, px, py, jx, jy, c, layer)
    ix, iy, ox, oy = jx, jy, px, py
  end
end
-- (2.3.10) the hatched shade on an arc, between f0 and f1 and radii r0, r1: the dark ground, then stripes slanted
-- across it ("////" along the arc, one every 1.4 thicknesses at the middle radius, half of it drawn, fixed to the arc
-- so ticks read as one pattern). Each stripe is a slanted piece in (along, across) space, clipped there and mapped onto
-- the arc corner by corner (a stripe is narrow: straight edges between the corners follow the curve closely enough)
local function arc_hatch(g, x, y, f0, f1, r0, r1, faint)
  if f1 <= f0 or r1 <= r0 or not arcs_ok then return end
  if not chef.triangle then arc_piece(g, x, y, f0, f1, r0, r1, col(BARS, faint), L_CUSTOM) return end
  arc_piece(g, x, y, f0, f1, r0, r1, col({ 0, 0, 0 }, 70), L_CUSTOM)
  local len = math.max(1, g.len)
  local P = math.max(6, math.floor(10 * (N.hatch_k or 1) + 0.5)) / len   -- (2.3.11: the straight bars' spacing; in fractions of the arc)
  local S, d = P / 2, (r1 - r0) / len                          -- (the slant: 45 degrees at the middle radius)
  local c = col(N.hatch_tint or BARS, 95)
  local cx, cy = x + g.cx, y + g.cy
  local clip = N.hatch_clip
  for kk = math.floor((f0 - d) / P) - 1, math.ceil(f1 / P) + 1 do
    local u = kk * P
    local poly = { { u, r0 }, { u + S, r0 }, { u + S + d, r1 }, { u + d, r1 } }
    poly = clip(poly, 1, f0, true)
    if #poly > 0 then poly = clip(poly, 1, f1, false) end
    for i = 1, #poly do
      local a = math.rad(g.bot + g.dir * g.span * poly[i][1])
      local r = poly[i][2]
      poly[i] = { cx + r * math.sin(a), cy + r * math.cos(a) }
    end
    for i = 2, #poly - 1 do
      chef.triangle(poly[1][1], poly[1][2], poly[i][1], poly[i][2], poly[i + 1][1], poly[i + 1][2], c, L_CUSTOM)
    end
  end
end
-- what's empty from f0 to f1: its shade (faint), its outline (the edge), both, or nothing
local function arc_empty(g, x, y, f0, f1, faint, lw, edge, shade)
  -- (an outline on a piece only a few pixels long, a narrow tick, would look filled anyway: faint instead)
  if edge ~= 2 or g.th <= 2 * lw + 1 or (f1 - f0) * g.len <= 4 * lw then
    if shade == 'hatch' then arc_hatch(g, x, y, f0, f1, g.r_in, g.r_out, faint)
    elseif shade or edge == 2 then arc_piece(g, x, y, f0, f1, g.r_in, g.r_out, col(BARS, faint), L_CUSTOM) end
    return
  end
  local c, cap = col(BARS, 190), lw / math.max(1, g.len)
  arc_piece(g, x, y, f0, f1, g.r_in, g.r_in + lw, c, L_CUSTOM)
  arc_piece(g, x, y, f0, f1, g.r_out - lw, g.r_out, c, L_CUSTOM)
  arc_piece(g, x, y, f0, math.min(f1, f0 + cap), g.r_in, g.r_out, c, L_CUSTOM)
  arc_piece(g, x, y, math.max(f0, f1 - cap), f1, g.r_in, g.r_out, c, L_CUSTOM)
  if shade == 'hatch' then arc_hatch(g, x, y, f0 + cap, f1 - cap, g.r_in + lw, g.r_out - lw, faint)
  elseif shade then arc_piece(g, x, y, f0 + cap, f1 - cap, g.r_in + lw, g.r_out - lw, col(BARS, faint), L_CUSTOM) end
end
-- (1.5.53) square brackets at an arc's two ends: a radial stroke just past each end, a little beyond both edges,
-- with short feet in along the inner and outer edges
local function arc_brackets(g, x, y, lw)
  local c = col(BARS, 210)
  local len = math.max(1, g.len)
  local cap = lw / len                      -- (lw along the arc, as a fraction of it)
  local s = math.max(4 * lw, math.min(math.floor(g.th * 0.5 + 0.5), 10 * lw)) / len
  for _, f in ipairs({ 0, 1 }) do
    -- the stroke 2 lw thick, a gap of lw from the end, 2 lw past both edges; the feet lw thick along the edges
    local a0, a1 = f == 0 and -3 * cap or 1 + cap, f == 0 and -cap or 1 + 3 * cap
    arc_piece(g, x, y, a0, a1, g.r_in - 2 * lw, g.r_out + 2 * lw, c, L_CUSTOM + 2)
    local b0, b1 = f == 0 and -cap or 1 - s, f == 0 and -cap + s or 1 + cap
    arc_piece(g, x, y, b0, b1, g.r_in - 2 * lw, g.r_in - lw, c, L_CUSTOM + 2)
    arc_piece(g, x, y, b0, b1, g.r_out + lw, g.r_out + 2 * lw, c, L_CUSTOM + 2)
  end
end
-- a solid curved bar f full: on its shade (or nothing), inside one outline around the whole, or between brackets
local function arc_solid(g, x, y, f, c, lw, faint, edge, shade)
  f = math.max(0, math.min(1, f))
  if edge == 2 and g.th > 2 * lw + 1 then
    arc_empty(g, x, y, 0, 1, faint, lw, edge, shade)
    local cap = lw / math.max(1, g.len)
    arc_piece(g, x, y, cap, cap + (1 - 2 * cap) * f, g.r_in + lw, g.r_out - lw, c, L_CUSTOM + 1)
  else
    if edge == 3 then arc_brackets(g, x, y, lw) end
    arc_piece(g, x, y, 0, f, g.r_in, g.r_out, c, L_CUSTOM + 1)   -- (the faint part only where it's empty)
    if shade == 'hatch' then arc_hatch(g, x, y, f, 1, g.r_in, g.r_out, faint)
    elseif shade then arc_piece(g, x, y, f, 1, g.r_in, g.r_out, col(BARS, faint), L_CUSTOM) end
  end
end
-- (1.5.58) a pulse's wash over the whole arc
local function arc_glow(g, x, y, key)
  local b = N.glow_k(key)
  if b > 0 then arc_piece(g, x, y, 0, 1, g.r_in, g.r_out, col(N.glow_col(key), N.GLOW_A * b), L_CUSTOM + 3) end
end
-- marks across it (heat marks, the charge mark, the warp pack's): at f, mw pixels wide
local function arc_mark(g, x, y, f, mw, c)
  local hw = mw / 2 / math.max(1, g.len)
  arc_piece(g, x, y, f - hw, f + hw, g.r_in - 2, g.r_out + 2, c, L_CUSTOM + 2)
end
-- (2.3.4, a test) the shells in the air (08_motion): each the piece of the bar its round had — the tick, or on a solid
-- bar a round's share of it (at least a few pixels) — thrown square to the bar, away from the crosshair (a vertical
-- bar right of it to the right; a horizontal one below it down; an arc outwards), eased out, falling a little,
-- shrinking and fading. span(i, top) gives the piece's start and end along the bar in pixels (an arc: in fractions)
-- (2.3.6: the shell is the bar's own colour — orange when ammo is low, as the ticks are; luka)
local function shell_alpha(p) return math.floor(240 * (1 - p * p) + 0.5) end   -- (p through the part shown: gone at its end)
local function bar_shells(k, x, y, w, h, vert, th, span, tone)
  local list = N.shells_live and N.shells_live()
  if not list or #list == 0 then return end
  local sw, sh = chef.screen()
  local dir
  if vert then dir = (x + w / 2 >= (sw or 0) / 2) and 1 or -1 else dir = (y + h / 2 >= (sh or 0) / 2) and 1 or -1 end
  local far = math.max(4 * th, 26 * k)
  for _, s in ipairs(list) do
    local a, z = span(s.i, s.top)
    if a then
      local p, u = s.p, s.u or s.p                                -- (u: through the whole flight, for the path)
      local off = far * (1 - (1 - u) ^ 3)
      local along, across = (z - a) * (1 - 0.4 * u), th * (1 - 0.3 * u)
      local mid = (a + z) / 2
      local fall = vert and 12 * k * u * u or 0                   -- (a vertical bar's shell drops as it flies)
      local c = col(tone, shell_alpha(p))
      if vert then
        local px = dir > 0 and (x + w + off - th + (th - across) / 2) or (x - off + (th - across) / 2)
        chef.rect(math.floor(px + 0.5), math.floor(y + mid - along / 2 - fall + 0.5), math.max(1, math.floor(across + 0.5)), math.max(1, math.floor(along + 0.5)), c, L_CUSTOM + 3)
      else
        local py = dir > 0 and (y + off + (th - across) / 2) or (y - off + (th - across) / 2)
        chef.rect(math.floor(x + mid - along / 2 + 0.5), math.floor(py + 0.5), math.max(1, math.floor(along + 0.5)), math.max(1, math.floor(across + 0.5)), c, L_CUSTOM + 3)
      end
    end
  end
end
local function arc_shells(g, x, y, span, tone)
  local list = N.shells_live and N.shells_live()
  if not list or #list == 0 then return end
  local far = math.max(4 * g.th, 26)
  for _, s in ipairs(list) do
    local f0, f1 = span(s.i, s.top)
    if f0 then
      local p, u = s.p, s.u or s.p
      local off = far * (1 - (1 - u) ^ 3)
      local mid, half = (f0 + f1) / 2, (f1 - f0) / 2 * (1 - 0.4 * u)
      local th = g.th * (1 - 0.3 * u)
      local r0 = g.r_in + (g.th - th) / 2 + off
      arc_piece(g, x, y, mid - half, mid + half, r0, r0 + th, col(tone, shell_alpha(p)), L_CUSTOM + 3)
    end
  end
end
local EL_DRAW = {}                                  -- (each element's draw function, by its id)
function EL_DRAW.bar(e, k, d, x, y, dry)
  if not d or d.kind == 'none' or not cfg.show_bar then return nil end
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h, g.cx, g.cy end
    local frac, tone, alpha = weapon_tone(d)
    N.hatch_tint = tone                                -- (2.3.10: an arc's stripes in its colour too)
    local lw = math.max(1, math.floor(k * 0.8 + 0.5))
    local edge, shade = look_of(e)
    local ticks = d.kind == 'ammo' and d.top and d.top >= 1 and
      (e.fill == 'ticks' or (e.fill == 'auto' and d.top <= e.ticks_max))
    if ticks then
      local n = math.max(d.top, math.min(d.value, d.top + 3))
      local gapf = math.max(1, math.min(g.len / n * 0.45, 4 * k)) / math.max(1, g.len)
      local segf = (1 + gapf) / n - gapf
      tone = N.pulsed('bar', tone)
      for i = 0, n - 1 do
        local f0 = i * (segf + gapf)
        if N.tick_lit(i, d.value) then arc_piece(g, x, y, f0, f0 + segf, g.r_in, g.r_out, col(tone, alpha), L_CUSTOM)
        else arc_empty(g, x, y, f0, f0 + segf, 55, lw, edge, shade) end
      end
      if edge == 3 then arc_brackets(g, x, y, lw) end
      arc_glow(g, x, y, 'bar')
      arc_shells(g, x, y, function(i) if i >= n then return nil end local f0 = i * (segf + gapf) return f0, f0 + segf end, tone)
    else
      arc_solid(g, x, y, N.bar_eased(frac, d), col(N.pulsed('bar', tone), alpha), lw, 45, edge, shade)
      arc_glow(g, x, y, 'bar')
      if d.kind == 'ammo' then
        arc_shells(g, x, y, function(i, top)
          if not top or top < 1 or i >= top then return nil end
          local seg = math.max(1 / top, 4 * lw / math.max(1, g.len))
          local f = (i + 0.5) / top
          return math.max(0, f - seg / 2), math.min(1, f + seg / 2)
        end, tone)
      end
      if d.kind == 'heat' and not learned.charge2[d.tid] then
        for _, m in ipairs(d.heat_marks or { { 0.75, 3 } }) do
          arc_mark(g, x, y, m[1], math.max(2, math.floor(2 * k)), col(MARK_COLORS[m[2]], 220))
        end
      end
    end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  local frac, tone, alpha = weapon_tone(d)
  N.hatch_tint = tone                                -- (2.3.9: the hatched shade's stripes in the bar's colour)
  N.hatch_ox, N.hatch_oy = x, y                      -- (2.3.11: the pattern fixed to the bar)
  local lw = math.max(1, math.floor(k * 0.8 + 0.5))
  local edge, shade = look_of(e)
  local ticks = d.kind == 'ammo' and d.top and d.top >= 1 and
    (e.fill == 'ticks' or (e.fill == 'auto' and d.top <= e.ticks_max))
  if ticks then
    local n = math.max(d.top, math.min(d.value, d.top + 3))
    local gap = math.max(1, math.min(len / n * 0.45, 4 * k))
    local step = (len + gap) / n
    for i = 0, n - 1 do
      local a, z = math.floor(i * step + 0.5), math.floor(i * step + step - gap + 0.5)
      local tx, ty, tw, tt = x + a, y, math.max(1, z - a), th
      if vert then tx, ty, tw, tt = x, y + a, th, math.max(1, z - a) end
      if N.tick_lit(i, d.value) then chef.rect(tx, ty, tw, tt, col(N.pulsed('bar', tone), alpha), L_CUSTOM)
      else empty_rect(tx, ty, tw, tt, 55, L_CUSTOM, lw, edge, shade) end
    end
    if edge == 3 then N.brackets(x, y, w, h, lw, vert, L_CUSTOM) end
    N.glow('bar', x, y, w, h, L_CUSTOM)
    bar_shells(k, x, y, w, h, vert, th, function(i)
      if i >= n then return nil end
      return math.floor(i * step + 0.5), math.floor(i * step + step - gap + 0.5)
    end, tone)
  else
    solid_bar(x, y, w, h, N.bar_eased(frac, d), col(N.pulsed('bar', tone), alpha), L_CUSTOM, lw, vert, edge, shade)
    N.glow('bar', x, y, w, h, L_CUSTOM)
    if d.kind == 'ammo' then
      bar_shells(k, x, y, w, h, vert, th, function(i, top)
        if not top or top < 1 or i >= top then return nil end
        local seg = math.max(len / top, 4 * lw)
        local m = (i + 0.5) * len / top
        return math.max(0, m - seg / 2), math.min(len, m + seg / 2)
      end, tone)
    end
    if d.kind == 'heat' and not learned.charge2[d.tid] then
      for _, m in ipairs(d.heat_marks or { { 0.75, 3 } }) do
        local mw = math.max(2, math.floor(2 * k))
        if vert then chef.rect(x - 2, y + math.floor(h * m[1]), w + 4, mw, col(MARK_COLORS[m[2]], 220), L_CUSTOM + 2)
        else chef.rect(x + math.floor(w * m[1]), y - 2, mw, h + 4, col(MARK_COLORS[m[2]], 220), L_CUSTOM + 2) end
      end
    end
  end
  return w, h
end
-- (2.4.4) the charge mark as the charge crosses it: brighter, near white, and a pixel or two wider for a few frames
-- (08_motion's 'chmark' pulse); past it the bar is red (luka: it was orange there, red only at 95 %). (2.4.5) The
-- mark itself red, from the start (luka: it was orange)
local function chmark_look(k)
  local b = N.pulse_k('chmark')
  local mw = math.max(1, math.floor(2 * k))
  if b <= 0 then return col(RED, 220), mw, 0 end
  local extra = math.floor(2 * k * b + 0.5)
  return col(N.pulsed('chmark', RED), 220 + math.floor(35 * b)), mw + extra, math.floor(extra / 2)
end
function EL_DRAW.charge(e, k, d, x, y, dry)
  if not d or not d.charge_frac then N.ease_reset('charge') return nil end   -- (2.4.4: a new charge starts from empty)
  local f = d.charge_frac
  local over = d.charge_mark and f >= d.charge_mark
  local cc = d.locked and WARN or (((over or f >= 0.95) and d.t0 and not d.t0.has.lock and not d.charge_safe) and RED or BARS)
  if d.kind == 'none' then cc = f >= 1 and WARN or BARS end
  local edge, shade = look_of(e)
  local lw = math.max(1, math.floor(k * 0.8 + 0.5))
  f = N.ease('charge', f, 80)
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h, g.cx, g.cy end
    arc_solid(g, x, y, f, col(cc, 230), lw, 40, edge, shade)
    if d.charge_mark then local mc, mw = chmark_look(k) arc_mark(g, x, y, d.charge_mark, mw, mc) end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  solid_bar(x, y, w, h, f, col(cc, 230), L_CUSTOM, lw, vert, edge, shade)
  if d.charge_mark then
    local mc, mw, back = chmark_look(k)
    if vert then chef.rect(x - 1 - back, y + math.floor(h * d.charge_mark) - back, w + 2 + 2 * back, mw, mc, L_CUSTOM + 2)
    else chef.rect(x + math.floor(w * d.charge_mark) - back, y - 1 - back, mw, h + 2 + 2 * back, mc, L_CUSTOM + 2) end
  end
  return w, h
end
function EL_DRAW.count(e, k, d, x, y, dry)
  if not d or d.kind == 'none' or not cfg.show_count then return nil end
  local frac, tone = weapon_tone(d)
  local str = d.kind == 'heat' and string.format('%d%%', math.floor(frac * (d.pct_top or 100) + 0.5)) or tostring(d.value)
  local big = math.floor(28 * k + 0.5)
  local w = txt_width(str, big)
  local box = w
  local tight = e.digits == 'tight' or (e.digits ~= 'fixed' and cfg.count_tight)
  if not tight then
    local most = d.kind == 'heat' and (string.rep('0', #tostring(math.floor(d.pct_top or 100))) .. '%')
      or string.rep('0', #tostring(math.floor(math.max(d.top or 0, d.value or 0))))
    box = math.max(w, txt_width(most, big))
  end
  if not dry then txt(x + box - w, y, str, big, col(N.pulsed('bar', tone == BARS and CREAM or tone), 245), L_CUSTOM) end   -- (2.6.6: Text at rest)
  return box, big
end
function EL_DRAW.mags(e, k, d, x, y, dry)
  if not d or not d.reserve then return nil end
  if e.style == 'squares' then
    local o = d.o or {}
    local id = not d.underbarrel and d.t0 and d.t0.id
    if dry then
      -- (the most this weapon has carried, as beside the crosshair)
      if d.reserve > (o.res_top or 0) then o.res_top = d.reserve end
      if id and d.reserve > (learned.resmax[id] or 0) then learn('resmax', id, d.reserve) end
    end
    local top = math.max(d.reserve, o.res_top or 0, id and learned.resmax[id] or 0)
    if e.empty == 'hidden' or cfg.mags_hide then top = d.reserve end
    local ps, pg = math.max(2, math.floor(6 * k + 0.5)), math.max(1, math.floor(3 * k + 0.5))
    if top <= 12 then
      if top == 0 then return nil end
      if not dry then
        local lw = math.max(1, math.floor(k * 0.8 + 0.5))
        for i = 0, top - 1 do
          local sx = x + i * (ps + pg)
          if N.sweep_lit('mags', i, d.reserve) then chef.rect(sx, y, ps, ps, col(N.pulsed('mags', BARS), 220), L_CUSTOM)   -- (2.4.4: a resupply lights them in order)
          elseif cfg.edge == 2 then empty_rect(sx, y, ps, ps, 55, L_CUSTOM, lw, 2, false)
          else chef.rect(sx, y, ps, ps, col({ 150, 150, 150 }, 120), L_CUSTOM) end
        end
        N.glow('mags', x, y, top * ps + (top - 1) * pg, ps, L_CUSTOM)   -- (2.4.4: and the wash over them, as a bar's)
      end
      return top * ps + (top - 1) * pg, ps
    end
  end
  local small = math.max(7, math.floor(16 * k + 0.5))
  local str = 'x' .. tostring(d.reserve)
  if e.divider then
    -- (a thin line before it, as tall as the count: "31 | x7")
    local big = math.floor(28 * k + 0.5)
    local dx = math.floor(7 * k)
    if not dry then
      chef.rect(x, y, math.max(1, math.floor(2 * k)), big, col(BARS, 150), L_CUSTOM)
      txt(x + dx, y, str, small, col(N.pulsed('mags', CREAM), 220), L_CUSTOM)
    end
    return dx + txt_width(str, small), big
  end
  if not dry then txt(x, y, str, small, col(N.pulsed('mags', CREAM), 220), L_CUSTOM) end
  return txt_width(str, small), small
end
-- (1.5.54) the modes apart: mode1 the weapon mode (HEAT, UB, the ammo kind), mode2 the fire mode and the zeroing text
-- (2.4.4) a mode word that changes cross-fades (luka's pick): the old one out as the new one comes in over 100 ms
-- (Motion's scale), on the same weapon; a new weapon, or the part back after a moment away, shows at once
local word_fades = {}
local function mode_text(parts, k, x, y, dry, key, d, tone)   -- (3.0.7: tone, the zeroing's step, over the words' own)
  if #parts == 0 then return nil end
  local small = math.max(7, math.floor(16 * k + 0.5))
  local str = table.concat(parts, '  ')
  if not dry then
    local now = N.now or chef.time()
    local goid = d and (d.goid or d.goid0)
    local f = key and word_fades[key]
    if key and (not f or f.goid ~= goid or now - f.at > 0.25) then
      f = { cur = str, goid = goid } word_fades[key] = f
    elseif f and f.cur ~= str then
      f.old, f.cur, f.t0 = f.cur, str, now
    end
    local secs = 0.1 * N.motion_scale()
    local p = (f and f.old and secs > 0) and (now - f.t0) / secs or 1
    if f then f.at = now end
    if p >= 1 then
      if f then f.old = nil end
      txt_modes(x, y, str, small, 200, L_CUSTOM, nil, tone)
    else
      txt_modes(x, y, f.old, small, math.floor(200 * (1 - p) + 0.5), L_CUSTOM, nil, tone)
      txt_modes(x, y, str, small, math.floor(200 * p + 0.5), L_CUSTOM, nil, tone)
    end
  end
  return txt_width(str, small), small
end
function EL_DRAW.mode1(e, k, d, x, y, dry)
  if not d then return nil end
  local parts = {}
  if d.kind == 'heat' and cfg.show_heat then parts[#parts + 1] = 'HEAT' end
  if d.underbarrel then if cfg.show_mode then parts[#parts + 1] = d.ub_label or 'UB' end
  elseif d.mode then parts[#parts + 1] = d.mode end
  return mode_text(parts, k, x, y, dry, 'mode1', d)
end
function EL_DRAW.mode2(e, k, d, x, y, dry)
  if not d then return nil end
  local parts = {}
  if d.fmode and not d.underbarrel then parts[#parts + 1] = d.fmode end
  return mode_text(parts, k, x, y, dry, 'mode2', d)
end
-- (1.5.65) the zeroing as text on its own (whenever the weapon's scope is known: the part being on is the choice)
function EL_DRAW.zoom(e, k, d, x, y, dry)
  if not d or not d.zoom_word then return nil end
  return mode_text({ d.zoom_word }, k, x, y, dry, 'zoom', d, d.zoom + 1)   -- (3.0.7: the step's tone, as its icon)
end
function EL_DRAW.rpm(e, k, d, x, y, dry)
  if not d or not d.setting then return nil end
  local tiny = math.max(6, math.floor(12 * k + 0.5))
  if not dry then txt(x, y, d.setting, tiny, col(CREAM, 190), L_CUSTOM) end
  return txt_width(d.setting, tiny), tiny
end
local icon_el_said = false
local function icon_el(rows, n, k, x, y, dry)
  local cell = math.max(1, math.floor(1.6 * N.icon_scale(k) + 0.5))
  local small = math.max(7, math.floor(16 * k + 0.5))
  local S = N.stim_px(k)                                      -- (1.5.77: smooth with Size; the sprite fallback keeps whole cells)
  local name = rows == N.STIM and 'stim' or 'grenade'
  -- (1.5.18) the icon's texture when it draws (its own width), the pixel sprite otherwise
  local g = TEXTURES[name .. '_game'] and TEXTURES[name .. '_game'][1]
  local tex_on = g and (cfg.icon_tex or 7) > 1 and chef.bitmap_uv
  if not tex_on and cfg.research and not icon_el_said then
    icon_el_said = true
    log('research: the %s icon drawn as the pixel sprite in this layout: %s', name, not g and 'no texture table' or (not chef.bitmap_uv and 'no uv call' or ('way ' .. tostring(cfg.icon_tex))))
  end
  local iw = tex_on and math.max(1, math.floor(S * g[4] / g[1] + 0.5)) or #rows[1] * cell
  local str = tostring(n)
  local w = iw + math.floor(4 * k) + txt_width(str, small)
  if dry then return w, S end
  local c = N.pulsed(rows == N.STIM and 'stims' or 'grenades', n == 0 and RED or CREAM)
  local p = rows == N.STIM and n == 0 and N.warn_stims or 1
  local drawn = tex_on and N.icon_texture(name, x, y, S, c, p, L_CUSTOM)
  if not drawn then
    iw = #rows[1] * cell
    chef.sprite(x, y + math.floor((S - #rows * cell) / 2), rows, cell,
      { ['#'] = col(c, 220 * p), ['+'] = col({ 40, 40, 40 }, 210 * p), o = col({ 0, 0, 0 }, 110 * p) }, L_CUSTOM)
  end
  txt(x + iw + math.floor(4 * k), y + math.floor((S - small) / 2), str, small, col(c, 220 * p), L_CUSTOM)
  return w, S
end
-- (1.5.18) the game's own icons of the weapon's mode and fire mode: squares of twice the stim's width (the sprites
-- have a lot of padding), in a line or stacked (the fire mode first, under or right of it the ammo kind)
-- (2.4.5, luka: the icons as the words) an icon that changes in its place cross-fades over the same 100 ms, the
-- old one out as the new one comes in; a new weapon, or the part back after a moment away, at once. (Whether the
-- game's icon material takes the colour's alpha isn't proven: the tint is, 1.5.20; if not, both show for 100 ms)
local icon_fades = {}
-- (3.0.10, luka: "the bounding boxes for these icons are 2x the size of the icons they show": alignment by ink) the
-- part's box is the icons' drawn pixels (each sprite's `ink` fractions, 07_weapon's atlas), not the padded square
-- the sprite is drawn in: pins and gaps go by what's seen, and parts at one edge line up by it. The square is
-- still drawn, offset so its ink lands in the box. F9 Look "Icons by their ink" off: the squares, as before
local function ink_box(it, tw)
  local ink = cfg.ink_align ~= false and it.ink
  if not ink then return tw, tw, 0, 0 end
  local iw, ih = math.max(1, math.floor(tw * (ink[3] - ink[1]) + 0.5)), math.max(1, math.floor(tw * (ink[4] - ink[2]) + 0.5))
  -- the sprite's square from the ink box: its left is ink.l of tw left of the box, its bottom (1 - ink.b) of tw below
  return iw, ih, -math.floor(tw * ink[1] + 0.5), -math.floor(tw * (1 - ink[4]) + 0.5)
end
local function icon_list(e, k, list, x, y, dry, key, d)
  local tw = N.icon_px(k)
  local gap = math.floor(4 * k)
  local n = #list
  local w, h = 0, 0
  local iws, ihs = {}, {}
  for i = 1, n do
    iws[i], ihs[i] = ink_box(list[i], tw)
    if e.style == 'stacked' then w, h = math.max(w, iws[i]), h + ihs[i] + (i > 1 and gap or 0)
    else w, h = w + iws[i] + (i > 1 and gap or 0), math.max(h, ihs[i]) end
  end
  if dry then return w, h end
  local keys = {}
  local now = N.now or chef.time()
  local goid = d and (d.goid or d.goid0)
  local secs = 0.1 * N.motion_scale()
  local fades = key and icon_fades[key]
  if key and (not fades or fades.goid ~= goid or now - fades.at > 0.25) then fades = { goid = goid, slots = {} } icon_fades[key] = fades end
  if fades then fades.at = now end
  local run = 0   -- (the icons' boxes laid along the line or the stack, middles level across it)
  for i = 1, n do
    local it = list[i]
    local iw, ih, ox, oy = iws[i], ihs[i], select(3, ink_box(it, tw))
    local ex, ey
    if e.style == 'stacked' then
      ex, ey = x + math.floor((w - iw) / 2), y + h - run - ih
      run = run + ih + gap
    else
      ex, ey = x + run, y + math.floor((h - ih) / 2)
      run = run + iw + gap
    end
    -- (the sprite's square, so its ink fills the box; a cross-fade's old sprite in the same square — its own ink
    -- may differ a little, a frame or two)
    ex, ey = ex + ox, ey + oy
    local sl = fades and fades.slots[i]
    if fades then
      if not sl then sl = { cur = it } fades.slots[i] = sl
      elseif sl.cur.word ~= it.word or sl.cur[1] ~= it[1] or sl.cur[2] ~= it[2] or sl.cur[3] ~= it[3] or sl.cur.tex ~= it.tex then
        sl.old, sl.cur, sl.t0 = sl.cur, it, now                  -- (a sprite of the same atlas: its uv tells)
      else sl.cur = it end
    end
    local p = (sl and sl.old and secs > 0) and (now - sl.t0) / secs or 1
    local ok, why
    if p >= 1 then
      if sl then sl.old = nil end
      ok, why = N.mode_icon(it, ex, ey, tw, L_CUSTOM, it.word)
    else
      N.mode_icon(sl.old, ex, ey, tw, L_CUSTOM, sl.old.word, 1 - p)
      ok, why = N.mode_icon(it, ex, ey, tw, L_CUSTOM, it.word, p)
    end
    keys[#keys + 1] = it[6] .. (ok and '+' or ('-' .. tostring(why)))
  end
  if fades then for i = n + 1, #fades.slots do fades.slots[i] = nil end end
  N.mode_icons_said(cfg.mode_icons, keys, key)
  return w, h
end
local function without_zoom(list)
  local out = {}
  for _, it in ipairs(list) do if it.word ~= 'ZOOM' then out[#out + 1] = it end end
  return out
end
-- (1.5.65) the zeroing icon on its own
-- (3.0.6) the rate-of-fire icon, a square as the mode icons, the game's rof_low / _medium / _high
function EL_DRAW.rpmicon(e, k, d, x, y, dry)
  local it = N.rof_icon and N.rof_icon(d)
  if not it then return nil end
  return icon_list(e, k, { it }, x, y, dry, 'rpmicon', d)
end
function EL_DRAW.zoomicon(e, k, d, x, y, dry)
  if not d or not (cfg.mode_icons and cfg.mode_icons > 1) or not N.mode_icons then return nil end
  local list = N.mode_icons()
  if not list then return nil end
  for _, it in ipairs(list) do if it.word == 'ZOOM' then return icon_list(e, k, { it }, x, y, dry, 'zoomicon', d) end end
  return nil
end
-- (1.5.57) the icons apart, as the modes: icon1 the weapon mode's (the ammo kind, the underbarrel), icon2 the fire
-- mode's and the zeroing; off unless a file turns them on
local function icons_part(fire)
  return function(e, k, d, x, y, dry)
    if not d or not (cfg.mode_icons and cfg.mode_icons > 1) or not N.mode_icons then return nil end
    local list = N.mode_icons()
    if not list then return nil end
    local part = {}
    for _, it in ipairs(without_zoom(list)) do if N.FIRE_WORD(it.word or '') == fire then part[#part + 1] = it end end
    if #part == 0 then return nil end
    return icon_list(e, k, part, x, y, dry, fire and 'icon2' or 'icon1', d)
  end
end
EL_DRAW.icon1, EL_DRAW.icon2 = icons_part(false), icons_part(true)
-- (2.5.3) the range as a part: the chevron's distance this frame (12_decal sets N.range_m), else the reticle point's
-- from your Helldiver (12_drop's reticle_point, any weapon); over RANGE_MOST or none: "-" (the sky puts the game's
-- point about 1 km from the camera, so 997–1003 m from you: 900 keeps it out whichever way it rounds)
local RANGE_MOST = 900
local range_at = { frame = nil, str = '-' }
local function range_str()
  if range_at.frame == N.frame then return range_at.str end
  range_at.frame = N.frame
  local d = (N.range_frame and N.range_frame >= N.frame - 1) and N.range_m or nil   -- (the chevron's, a frame old)
  if not d and N.reticle_point and chef.camera then
    local cam = chef.camera()
    local rp = cam and N.reticle_point(cam, true)
    local u = rp and N.my_unit and N.my_unit()
    if u and chef.unit_position then
      local px, py = chef.unit_position(u)
      if px then d = math.sqrt((rp.x - px) ^ 2 + (rp.y - py) ^ 2) end
    end
  end
  range_at.str = (d and d <= RANGE_MOST) and string.format('%d m', math.floor(d + 0.5)) or '-'
  return range_at.str
end
function EL_DRAW.range(e, k, d, x, y, dry)
  if not cfg.show_range then return nil end
  -- (2.5.5) "Not by the chevron": hidden while the chevron carries the number itself
  -- (2.5.24, luka: the rule for all: the field is never shown while the chevron carries the number — "Distance by
  -- the chevron" off, the field carries it with a drop-arc weapon)
  if cfg.mark_range ~= false and N.range_frame and N.range_frame >= N.frame - 1 and N.range_m then return nil end
  local small = math.max(7, math.floor(16 * k + 0.5))
  local str = range_str()
  if not dry then txt(x, y, str, small, col(CREAM, 220), L_CUSTOM) end
  return txt_width(str, small), small
end
function EL_DRAW.stims(e, k, d, x, y, dry, items)
  if not items or not cfg.show_stims then return nil end
  return icon_el(N.STIM, items.s, k, x, y, dry)
end
function EL_DRAW.grenades(e, k, d, x, y, dry, items)
  if not items or not cfg.show_grenades then return nil end
  return icon_el(N.GRENADE, items.g, k, x, y, dry)
end
function EL_DRAW.pack(e, k, d, x, y, dry, items)
  if not items or not cfg.pack then return nil end
  local st = pack_state(items, d)
  if not st then return nil end
  if not dry then N.edge_pulse('pack', st.f <= 0) st.c = N.pulsed('pack', st.c) end
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h, g.cx, g.cy end
    local lw = math.max(1, math.floor(k * 0.8 + 0.5))
    local edge, shade = look_of(e)
    if st.segs and st.segs >= 2 and g.len >= st.segs * 3 then
      -- (1.5.48) a pack counted in uses: a tick a use along the arc, as the ammo bar's magazine ticks
      local n, lit = st.segs, st.n or 0
      local gapf = math.max(1, math.min(g.len / n * 0.45, 4 * k)) / math.max(1, g.len)
      local segf = (1 + gapf) / n - gapf
      for i = 0, n - 1 do
        local f0 = i * (segf + gapf)
        if N.sweep_lit('pack', i, lit) then arc_piece(g, x, y, f0, f0 + segf, g.r_in, g.r_out, col(st.c, st.a), L_CUSTOM)
        else arc_empty(g, x, y, f0, f0 + segf, 55, lw, edge, shade) end
      end
      if edge == 3 then arc_brackets(g, x, y, lw) end
    else
      arc_solid(g, x, y, N.ease('pack', st.f, 120), col(st.c, st.a), lw, 45, edge, shade)
    end
    arc_glow(g, x, y, 'pack')
    for _, m in ipairs(st.marks) do arc_mark(g, x, y, m[1], math.max(1, math.floor(2 * k)), col(m[2], 220)) end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  local edge, shade = look_of(e)
  if not N.pack_ticks(st, x, y, w, h, vert, L_CUSTOM, k, edge, shade) then
    solid_bar(x, y, w, h, N.ease('pack', st.f, 120), col(st.c, st.a), L_CUSTOM, math.max(1, math.floor(k * 0.8 + 0.5)), vert, edge, shade)
  end
  N.glow('pack', x, y, w, h, L_CUSTOM)
  for _, m in ipairs(st.marks) do
    local mw = math.max(1, math.floor(2 * k))
    if vert then chef.rect(x - 1, y + math.floor(h * m[1]), w + 2, mw, col(m[2], 220), L_CUSTOM + 2)
    else chef.rect(x + math.floor(w * m[1]), y - 1, mw, h + 2, col(m[2], 220), L_CUSTOM + 2) end
  end
  return w, h
end

-- Health and stamina (vit: 13_main's reading): a bar of the part that's left, and for health, what a hit just took
-- in red, shrinking to it ("trail"). Health cream, orange from half, red from a quarter; stamina blue, orange when
-- nearly out. Faint where it's empty, as the other bars.
local function vital_bar(e, k, f, c, trail, x, y, dry, key, tint)
  f = math.max(0, math.min(1, f))
  local tc = col(RED, 170)
  if key and not dry then f = N.ease(key, f, 120) end
  local edge, shade = look_of(e)
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h, g.cx, g.cy end
    N.hatch_tint = tint
    arc_solid(g, x, y, f, c, math.max(1, math.floor(k * 0.8 + 0.5)), 45, edge, shade)
    -- (2.3.8: trail a number, one piece from the fill up; or a list of { lo, hi } pieces, the chunks)
    if type(trail) == 'table' then
      for _, c in ipairs(trail) do
        local lo, hi = math.max(f, c[1]), math.min(1, c[2])
        if hi > lo then arc_piece(g, x, y, lo, hi, g.r_in, g.r_out, tc, L_CUSTOM + 1) end
      end
    elseif trail and trail > f then arc_piece(g, x, y, f, math.min(1, trail), g.r_in, g.r_out, tc, L_CUSTOM + 1) end
    if key then arc_glow(g, x, y, key) end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  N.hatch_tint, N.hatch_ox, N.hatch_oy = tint, x, y
  solid_bar(x, y, w, h, f, c, L_CUSTOM, math.max(1, math.floor(k * 0.8 + 0.5)), vert, edge, shade)
  local pieces = type(trail) == 'table' and trail or ((trail and trail > f) and { { f, trail } } or nil)
  for _, c in ipairs(pieces or {}) do
    local a, b = math.floor(len * math.max(f, c[1]) + 0.5), math.floor(len * math.min(1, c[2]) + 0.5)
    if b > a then
      if vert then chef.rect(x, y + a, w, b - a, tc, L_CUSTOM + 1)
      else chef.rect(x + a, y, b - a, h, tc, L_CUSTOM + 1) end
    end
  end
  if key then N.glow(key, x, y, w, h, L_CUSTOM) end
  return w, h
end
-- (1.5.60: a bar its rule holds back (show_h / show_s at 0) keeps its place: measured, not drawn; one switched Off
-- (cfg.health 1) is nil, as before)
function EL_DRAW.health(e, k, d, x, y, dry, items, vit)
  if not vit or not vit.hp or (cfg.health or 1) == 1 then return nil end
  local f = vit.hp / math.max(1, vit.max)
  local c = f <= 0.25 and RED or (f <= 0.5 and WARN or BARS)
  if vit.show_h <= 0.01 then return vital_bar(e, k, f, col(c, 230), nil, x, y, true) end
  local a = N.alpha_k
  if not dry then N.alpha_k = a * vit.show_h * (vit.pulse_h or 1) end
  -- (2.3.7) no trail on a red bar: red on red read as one bar, a pale one as healing (luka); there it's the health alone
  local trail, mode, mx = nil, cfg.trail or 3, math.max(1, vit.max)
  if c ~= RED and mode == 2 and vit.trail then trail = vit.trail / mx
  elseif c ~= RED and mode == 3 and vit.chunks and #vit.chunks > 0 then
    trail = {}
    for i, ch in ipairs(vit.chunks) do trail[i] = { ch.lo / mx, (ch.top or ch.hi) / mx } end
  end
  local w, h, acx, acy = vital_bar(e, k, f, col(c, 230), trail, x, y, dry, 'health', c)
  N.alpha_k = a
  return w, h, acx, acy   -- (1.5.76: the arc's centre too — dropped here, health and stamina lost their 'arc' align)
end
function EL_DRAW.stamina(e, k, d, x, y, dry, items, vit)
  if not vit or not vit.st or (cfg.stamina or 1) == 1 then return nil end
  if vit.show_s <= 0.01 then return vital_bar(e, k, vit.st, col(STAMINA_C, 220), nil, x, y, true) end
  local a = N.alpha_k
  if not dry then N.alpha_k = a * vit.show_s end
  local w, h, acx, acy = vital_bar(e, k, vit.st, col(N.pulsed('stamina', vit.st <= 0.2 and WARN or STAMINA_C), 220), nil, x, y, dry, 'stamina',
    vit.st <= 0.2 and WARN or STAMINA_C)
  N.alpha_k = a
  return w, h, acx, acy
end
-- the stim timer: green, shrinking from full as the stim's effect runs out
local STIM_C = { 120, 215, 140 }
N.ink_tables_add(STIM_C)                           -- (2.6.8: a stim part's own colour takes its green too)
function EL_DRAW.stim(e, k, d, x, y, dry, items, vit)
  if not vit or not vit.stim then return nil end
  return vital_bar(e, k, vit.stim, col(STIM_C, 225), nil, x, y, dry, 'stim')
end
N.vital_bar, N.STAMINA_C, N.EL_DRAW = vital_bar, STAMINA_C, EL_DRAW

-- (research log: each element's time, for the timing line)
N.el_time = {}
local el_clock = cfg.research and os and os.clock or nil
-- (1.5.53) The layout engine. Every part's box is measured first (its draw function dry), then placed: a free part
-- at its anchor plus x / y (plus F9's offsets and, by its side, the Spread), a pinned part from the box of the part
-- it's after. The other pass's parts (vitals against the rest) count with their boxes from their last frame. A
-- part that isn't drawn is a slot of no size where it would be, so what's pinned to it takes its place (no gap).
-- A loop of pins (a after b after a) is broken at the part that closes it, which is placed free; logged once.
local function side_of(e)
  if e.side ~= 'auto' then return e.side end
  if e.anchor ~= 'center' then return 'none' end
  if e.x < -0.05 then return 'left' elseif e.x > 0.05 then return 'right' end
  -- (1.5.76: an arc centred on the crosshair is on the side it bulges to)
  if e.align == 'arc' then
    if e.style == 'curved_right' then return 'right' elseif e.style == 'curved_left' then return 'left' end
  end
  local al = ALIGNS[e.align]
  if al[1] == 1 then return 'left' elseif al[1] == 0 then return 'right' end
  return 'none'
end
N.side_of = side_of
-- (2.4.13, the frame time) the boxes kept while nothing that places them has changed: the layout, the screen, the
-- parts' measured sizes, the other pass's boxes, the Spread, the aim spread and the offsets. luka's 2.4.11 log had
-- the HUD's parts at ~0.4 ms a frame with few engine calls; the harness profile put a third of the frame's Lua in
-- place() and draw_custom(), run twice a frame (a pass each for the parts and the vitals) over every part
local rcache = {}
local function same_size(a, b)
  if a == b then return true end
  if not a or not b then return false end
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end
local function same_box(a, b)
  if a == b then return true end
  if not a or not b then return false end
  return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h and a.ax == b.ax and a.ay == b.ay
end
local function resolve(els, w, h, sizes, last, offsets, pass)
  local ox, oy = 0, 0
  if offsets then ox, oy = w * (cfg.off_x or 0) / 100, h * (cfg.off_y or 0) / 100 end
  local spread = h * (cfg.spread or 0) / 100
  local aim = h * N.tween('aimspread', N.aim_now and (cfg.aim_spread or 0) or 0, 120 / math.max(N.motion_scale(), 1), 0, 0.4) / 100
  local rc = rcache[pass or 1]
  if rc and rc.els == els and rc.w == w and rc.h == h and rc.ox == ox and rc.oy == oy and rc.spread == spread and rc.aim == aim
     and rc.size == cfg.size then
    local same = true
    for _, el in ipairs(ELEMENTS) do
      local id = el.id
      if not same_size(rc.sizes[id], sizes[id]) or not same_box(rc.last[id], last[id]) then same = false break end
    end
    if same then return rc.boxes end
  end
  local boxes, visiting = {}, {}
  -- (1.5.55: while aiming, the Aim spread eases in on top)
  -- (1.5.59: 120 ms at Quick and at Normal alike — luka found Normal's 190 too slow for this one)
  -- (2.4.2) The Aim spread is kept out of the boxes: a box is the part's place at rest (the F9 Spread in it), and
  -- the aim part is an offset on top (ax, ay by the part's side; a pinned part takes its target's), added after the
  -- part's slide. Before, the eased spread moved the box itself every frame, and the slide (150 ms to a box that
  -- moved) never got going until the box stood still — so the parts sat for 120 ms, then slid 150 ms ease-out, and
  -- each started on its own frame (the frame its box's rounding stopped changing): luka's "the two sides are a frame
  -- or two out of sync". Now every part moves by one value, the same frame: a tween with luka's speed profile,
  -- 15 / 70 / 15 (08_motion), advanced once a frame
  local function aim_of(e)
    local sd = side_of(e)
    if sd == 'left' then return -aim, 0 elseif sd == 'right' then return aim, 0
    elseif sd == 'down' then return 0, -aim elseif sd == 'up' then return 0, aim end
    return 0, 0
  end
  local function free_point(e)
    local an = ANCHORS[e.anchor]
    local px = w * an[1] + h * e.x / 100 + ox
    local sd = side_of(e)
    local py = h * an[2] + h * e.y / 100 + oy
    if sd == 'left' then px = px - spread elseif sd == 'right' then px = px + spread
    elseif sd == 'down' then py = py - spread elseif sd == 'up' then py = py + spread end   -- (bottom-left origin)
    return px, py
  end
  -- place(id): the part's box, cached. place(id, aw, ah): where the part would be if its size were aw x ah, not
  -- cached — how a part pinned to a hidden part takes its place (1.5.73): it's put where the hidden part would be
  -- with the follower's own size, so a 56 px icon pinned right of an empty icon with tops level sits where that
  -- icon would, not 56 px down in the count (the hidden slot has no height to line up with). A chain of hidden
  -- parts passes the size along.
  -- (3.0.8, luka: the rate-of-fire icon under the count with a gap of -21 for the sprite's padding; the icon off,
  -- the number pinned right of it landed inside the count) a hidden icon part has a size all the same — a square
  -- of the icon's width — so a part pinned to it is put inside that square by its own align (middles level: the
  -- number at the icon's middle), not at the icon's slot with its own 12 px height, 21 px up into the count
  local function nominal(id)
    if not ICON_PARTS[id] then return nil end
    local e = els[id]
    local tw = N.icon_px and N.icon_px((h / 1440) * cfg.size * e.size) or 0
    if tw <= 0 then return nil end
    if cfg.ink_align == false then return tw, tw end
    local f = ICON_PARTS[id]
    return math.max(1, math.floor(tw * f[1] + 0.5)), math.max(1, math.floor(tw * f[2] + 0.5))
  end
  local function place(id, aw, ah)
    if not aw and boxes[id] then return boxes[id] end
    local e = els[id]
    local sz = sizes[id]
    local ew, eh, hidden = 0, 0, true
    if aw then ew, eh, hidden = aw, ah, false
    elseif sz then ew, eh, hidden = sz[1], sz[2], false
    elseif sz == nil and last[id] then ew, eh, hidden = last[id].w, last[id].h, false end
    local al = ALIGNS[e.align]
    local target = e.after ~= 'none' and e.after ~= id and els[e.after] and e.after or nil
    if target and visiting[target] then
      if not layout.loop_said then
        layout.loop_said = true
        log('layout: a loop of pins (%s after %s, and back): %s placed where its own x / y say', id, target, id)
      end
      target = nil
    end
    local x, y
    local ax, ay = aim_of(e)
    if target then
      visiting[id] = true
      local tb = place(target)
      ax, ay = tb.ax or 0, tb.ay or 0                            -- (with its target)
      if e.pin == 'none' then local _, oay = aim_of(e) ay = oay end   -- (y its own: a free point)
      if tb.hidden and not hidden then   -- (takes its place: see above; an icon part's square when it has one)
        local nw, nh = nominal(target)
        if nw then tb = place(target, nw, nh) tb.nominal = true else tb = place(target, ew, eh) end
      end
      visiting[id] = nil
      local k = (h / 1440) * cfg.size * e.size
      local gap = tb.hidden and 0 or math.floor(e.gap * k + 0.5)
      -- (1.5.70: a pinned part's x / y nudges scale with Size and the part's size, as the gap does — luka's stims,
      -- a gap and a nudge cancelling at Medium, drifted at Small; a free part's x / y are a place, not scaled)
      local ns = (e.pin ~= 'none') and (cfg.size * e.size) or 1
      local nx, ny = math.floor(h * e.x / 100 * ns + 0.5), math.floor(h * e.y / 100 * ns + 0.5)
      if tb.hidden then x, y = tb.x, tb.y   -- (a hidden part with nothing to show at all, no last box: its point)
      elseif tb.taken and tb.nominal then   -- (inside the hidden icon's square, by this part's align)
        x, y = math.floor(tb.x + (tb.w - ew) * al[1] + 0.5), math.floor(tb.y + (tb.h - eh) * al[2] + 0.5)
      elseif tb.taken then x, y = tb.x, tb.y   -- (the hidden part's place, with this part's size)
      elseif e.pin == 'none' then
        local _, py = free_point(e)
        x, y = tb.x + tb.w + gap, math.floor(py - eh * al[2] + 0.5)
      elseif e.pin == 'right' then x, y = tb.x + tb.w + gap + nx, math.floor(tb.y + (tb.h - eh) * al[2] + 0.5) + ny
      elseif e.pin == 'left' then x, y = tb.x - gap - ew + nx, math.floor(tb.y + (tb.h - eh) * al[2] + 0.5) + ny
      elseif e.pin == 'above' then x, y = math.floor(tb.x + (tb.w - ew) * al[1] + 0.5) + nx, tb.y + tb.h + gap + ny
      else x, y = math.floor(tb.x + (tb.w - ew) * al[1] + 0.5) + nx, tb.y - gap - eh + ny end
    else
      local px, py = free_point(e)
      if e.align == 'arc' and sz and sz[3] and not aw then x, y = math.floor(px - sz[3] + 0.5), math.floor(py - sz[4] + 0.5)
      else x, y = math.floor(px - ew * al[1] + 0.5), math.floor(py - eh * al[2] + 0.5) end
    end
    if not hidden then
      x = math.max(0, math.min(x, w - ew))
      y = math.max(0, math.min(y, h - eh))
    end
    if aw then return { x = x, y = y, w = ew, h = eh, hidden = false, taken = true, ax = ax, ay = ay } end
    boxes[id] = { x = x, y = y, w = ew, h = eh, hidden = hidden, ax = ax, ay = ay }
    return boxes[id]
  end
  for _, el in ipairs(ELEMENTS) do place(el.id) end
  local lc = {}
  for id, b in pairs(last) do lc[id] = { x = b.x, y = b.y, w = b.w, h = b.h, ax = b.ax, ay = b.ay } end
  rcache[pass or 1] = { els = els, w = w, h = h, ox = ox, oy = oy, spread = spread, aim = aim, size = cfg.size, sizes = sizes, last = lc, boxes = boxes }
  return boxes
end
N.resolve_layout = resolve
-- (vitals: the health and stamina parts only, drawn on their own each frame; else every other part)
-- (a part switched Off in F9 is off for good, not for a moment: no holding its place)
local function f9_off(id)
  local part = N.EL_PART and N.EL_PART[id]
  if part and cfg.vis and cfg.vis[part] == 1 then return true end
  return false
end
local function draw_custom(d, items, vitals)
  N.ink_pop()                                      -- (2.6.8: a push a failed draw left on, undone before anything draws)
  L_CUSTOM = N.L0 + 905
  local w, h = chef.screen()
  if not w then return end
  local els, offsets = nil, nil
  if cfg.builtin then
    els, offsets = builtin_layout(cfg.builtin).els, true
  else
    if not layout.els then load_layout('Custom chosen') end
    els, offsets = layout.els, layout.offsets
  end
  cur = els
  local base = N.alpha_k
  -- (each part's box, for the parts pinned to it: this pass's from this frame, the other pass's from its last frame)
  local drawn = layout.drawn or {}
  layout.drawn = drawn
  -- (1.5.72: the last size each part had, for the ones that hold their place while they have nothing to show;
  -- forgotten with the layout)
  if layout.held_els ~= els then layout.held, layout.held_els = {}, els end
  local held, silent = layout.held, {}
  local sizes, clocks = {}, {}
  for _, el in ipairs(ELEMENTS) do
    if (el.vitals == true) == (vitals ~= nil) then
      drawn[el.id] = nil
      local e = els[el.id]
      sizes[el.id] = false
      if e.on and e.opacity > 0 and not f9_off(el.id) then   -- (3.0.8: a part Off in F9 has no size, so its followers take its place)
        local c0 = el_clock and el_clock()
        local k = (h / 1440) * cfg.size * e.size
        local ew, eh, acx, acy = EL_DRAW[el.id](e, k, d, 0, 0, true, items, vitals)
        if ew then sizes[el.id] = { ew, eh, acx, acy } held[el.id] = sizes[el.id]
        elseif e.hold and held[el.id] and not f9_off(el.id) then sizes[el.id] = held[el.id] silent[el.id] = true end
        if c0 then clocks[el.id] = el_clock() - c0 end
      end
    end
  end
  local pass = vitals and 2 or 1
  local boxes = resolve(els, w, h, sizes, drawn, offsets, pass)
  -- (tests: this pass's boxes, the other pass's kept as they were — M.debug_boxes reads them; 2.4.13: no copy a
  -- frame, that was a sixth of this function's time)
  layout.pass_boxes = layout.pass_boxes or {}
  layout.pass_boxes[pass] = boxes
  -- (1.5.55) a part whose place changed slides there (150 ms; a move over a quarter of the screen snaps); one that
  -- wasn't drawn last frame fades in (120 ms) where it is, no slide
  local was = layout.was or {}
  layout.was = was
  local now = N.now or chef.time()
  for _, el in ipairs(ELEMENTS) do
    local sz = sizes[el.id]
    if sz and silent[el.id] then
      -- (holding its place: the slot stays for the parts pinned to it, nothing drawn; it fades in when it's back)
      local b = boxes[el.id]
      drawn[el.id] = { x = b.x, y = b.y, w = b.w, h = b.h, ax = b.ax, ay = b.ay }
      b.held = true
      was[el.id] = nil
    elseif sz then
      local e, b = els[el.id], boxes[el.id]
      b.held = nil
      local c0 = el_clock and el_clock()
      local k = (h / 1440) * cfg.size * e.size
      local key = 'el:' .. el.id
      local fade = 1
      if not was[el.id] then
        N.slide_reset(key)
        was[el.id] = now
      end
      local age = now - was[el.id]
      if age < 0.12 * N.motion_scale() then fade = age / (0.12 * N.motion_scale()) end
      local sx, sy = N.slide(key, b.x, b.y, 150, h * 0.25)
      sx, sy = sx + math.floor((b.ax or 0) + 0.5), sy + math.floor((b.ay or 0) + 0.5)   -- (2.4.2: the aim spread on top)
      -- (1.5.60: the part's Show rule, eased: held back, it keeps its place and isn't drawn (or is dimmed))
      local rule = N.el_alpha(el.id)
      N.alpha_k = base * e.opacity / 100 * fade * rule
      -- (2.3.9: each part sets its own colour, or the stripes are cream; 2.3.11: its size, and its corner to fix the
      -- pattern to, or the box's own)
      N.hatch_tint, N.hatch_ox, N.hatch_oy, N.hatch_k = nil, nil, nil, k
      if rule > 0.01 then
        if e.rgb then N.ink_push(e.rgb) end            -- (2.6.8: the part's own colour at rest)
        EL_DRAW[el.id](e, k, d, sx, sy, false, items, vitals)
        if e.rgb then N.ink_pop() end
      end
      drawn[el.id] = { x = b.x, y = b.y, w = b.w, h = b.h, ax = b.ax, ay = b.ay }
      if c0 then clocks[el.id] = (clocks[el.id] or 0) + el_clock() - c0 end
    elseif sizes[el.id] == false then
      was[el.id] = nil
    end
  end
  if el_clock then for id, t in pairs(clocks) do N.el_time[id] = (N.el_time[id] or 0) + t end end
  N.alpha_k = base
end


N.layout, N.load_layout, N.draw_custom, N.ELEMENTS = layout, load_layout, draw_custom, ELEMENTS
-- (2.0: every layout is a layout; the Under and Beside modules that drew the old positions by hand are gone)
N.draw = function(d, items) return draw_custom(d, items) end
N.draw_vitals = function(vit) return draw_custom(nil, nil, vit) end
