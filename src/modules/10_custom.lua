-- NarrowHUD, custom: the Custom layout: the layout file (docs/LAYOUT.md) and its elements.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, learned, learn, txt_width, txt, CREAM = N.cfg, N.learned, N.learn, N.txt_width, N.txt, N.CREAM
local WARN, RED, col, empty_rect, solid_bar, txt_modes = N.WARN, N.RED, N.col, N.empty_rect, N.solid_bar, N.txt_modes
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
local AFTER = { none = 1, bar = 1, charge = 1, count = 1, mags = 1, rpm = 1, stims = 1, grenades = 1, pack = 1,
  health = 1, stamina = 1, stim = 1, mode1 = 1, mode2 = 1, icon1 = 1, icon2 = 1, zoom = 1, zoomicon = 1 }
-- (1.5.53) pin: how a part sits against the one it's after — none: the old way (its x from that part's right edge
-- plus the gap, its y its own); right / left / above / below: its whole place from that part's box (the gap between
-- them, the align choosing the edge they line up on, x / y then small nudges). A part that isn't drawn (off, or
-- nothing to show: no backpack, a rifle with no charge meter) leaves its place to what's pinned to it.
-- side: left or right of the crosshair, for F9's Spread slider (auto: by the part's x from the centre anchor).
local PINS = { none = 1, right = 1, left = 1, above = 1, below = 1 }
-- (1.5.53) a bar's edge and shade: F9's ('auto'), or its own
local EDGES = { auto = 1, none = 1, outline = 1, brackets = 1 }
local SHADES = { auto = 1, on = 1, off = 1 }
local BAR_LOOK = { edge = { 'choice', 'auto', EDGES }, shade = { 'choice', 'auto', SHADES } }
local EDGE_OF = { none = 1, outline = 2, brackets = 3 }
local function look_of(e)
  local edge = e.edge == 'auto' and (cfg.edge or 1) or EDGE_OF[e.edge]
  local shade = e.shade == 'auto' and cfg.shade ~= false or e.shade == 'on'
  return edge, shade
end
local SIDES = { auto = 1, none = 1, left = 1, right = 1 }
local COMMON = { on = { 'boolean', true }, anchor = { 'choice', 'center', ANCHORS }, x = { 'number', 0, -100, 100 },
  y = { 'number', 0, -100, 100 }, align = { 'choice', 'bottom_left', ALIGNS }, size = { 'number', 1, 0.3, 4 },
  opacity = { 'number', 100, 0, 100 }, after = { 'choice', 'none', AFTER }, gap = { 'number', 8, -500, 500 },
  pin = { 'choice', 'none', PINS }, side = { 'choice', 'auto', SIDES }, hold = { 'boolean', false } }
-- (1.5.72) hold: a part with nothing to show for the moment (the weapon put away, a stratagem ball in hand, no
-- weapon seated) keeps the place it had, so the parts pinned to it stay where they are; off, they take its place
-- (as a part that's Off, or one this loadout never has — no backpack, no charge meter — always does). On in Under's
-- look for the parts that only vanish for a moment — the ammo bar and the count (the weapon put away), health and
-- stamina — and off for the ones a weapon or loadout may not have (the charge meter, the magazines, the backpack,
-- the modes, the rate of fire), which give their place away (luka, 1.5.72 / 1.5.75)
local ELEMENTS = {
  { id = 'bar', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      fill = { 'choice', 'auto', { auto = 1, ticks = 1, solid = 1 } }, length = { 'number', 260, 10, 2000 },
      radius = { 'number', 150, 10, 2000 },
      thickness = { 'number', 14, 1, 200 }, ticks_max = { 'number', 30, 1, 200 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  { id = 'charge', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 4, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  { id = 'count', fields = {} },
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
  { id = 'stims', fields = {} },
  { id = 'grenades', fields = {} },
  { id = 'pack', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 120, 10, 2000 }, thickness = { 'number', 7, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  -- (1.1.0) your health and stamina: shown when F9's Health bar / Stamina bar say so (off by default)
  { id = 'health', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 5, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  { id = 'stamina', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 3, 1, 200 }, radius = { 'number', 150, 10, 2000 }, edge = BAR_LOOK.edge, shade = BAR_LOOK.shade } },
  -- (1.2.0) the stim timer: shown when F9's Stim timer is on, while a stim of yours works
  { id = 'stim', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
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
  zoomicon = { anchor = 'center', x = 0, y = 0, align = 'bottom_right', after = 'zoom', pin = 'below', gap = 2 },
  icon2 = { anchor = 'center', x = 0, y = 0, align = 'bottom_right', after = 'zoomicon', pin = 'left', gap = 4 },
  icon1 = { anchor = 'center', x = 0, y = 0, align = 'bottom_right', after = 'icon2', pin = 'left', gap = 4 },
  rpm = { anchor = 'center', x = 0, y = 0, align = 'bottom_left', after = 'count', pin = 'below', gap = 6 },
  stims = { anchor = 'center', x = -9, y = -9.6, align = 'top_left' },
  grenades = { anchor = 'center', x = 0, y = 0, align = 'top_left', after = 'stims', pin = 'right', gap = 8 },
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
  rpm = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'count', gap = 10, pin = 'above', side = 'auto', hold = false },
  icon2 = { on = true, anchor = 'center', x = 0, y = 0.8, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = -3, pin = 'right', side = 'auto', hold = false, style = 'line' },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'icon2', gap = -21, pin = 'below', side = 'auto', hold = false, style = 'line' },
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'icon1', gap = -24, pin = 'below', side = 'auto', hold = false },
  mode1 = { on = false, anchor = 'center', x = 9.8, y = 7.6, align = 'top_left', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false },
  mode2 = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode1', gap = 4, pin = 'below', side = 'auto', hold = false },
  zoom = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode2', gap = 4, pin = 'below', side = 'auto', hold = false },
  stims = { on = true, anchor = 'center', x = -1, y = -8.1, align = 'top_right', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'none', hold = false },
  grenades = { on = true, anchor = 'center', x = 1, y = -8.1, align = 'top_left', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'none', hold = false },
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
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'icon2', gap = -14, pin = 'below', side = 'auto', hold = false },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon2', gap = -14, pin = 'above', side = 'auto', hold = false, style = 'line' },
  icon2 = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'bar', gap = -6, pin = 'right', side = 'auto', hold = false, style = 'line' },
  rpm = { on = true, anchor = 'center', x = 0, y = -0.6, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = -15, pin = 'right', side = 'auto', hold = false },
  stims = { on = true, anchor = 'center', x = -1.35, y = -6.45, align = 'center', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'none', hold = false },
  grenades = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'stims', gap = 10, pin = 'right', side = 'none', hold = false },
  pack = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_right', length = 75, thickness = 5, radius = 92, edge = 'auto', shade = 'auto' },
  health = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'curved_left', length = 225, thickness = 7, radius = 120, edge = 'auto', shade = 'auto' },
  stamina = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_left', length = 200, thickness = 4, radius = 106.5, edge = 'auto', shade = 'auto' },
  stim = { on = true, anchor = 'center', x = 0, y = 0, align = 'arc', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = false, style = 'curved_left', length = 77, thickness = 5, radius = 94, edge = 'auto', shade = 'auto' } } }
-- The horizontal stack: the bars under the crosshair (ammo, the charge meter above it; health with the stamina
-- above it, free), the count and magazines right of the bar, the icons left of it, stims and grenades and the
-- backpack under it.
local HORIZONTAL_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { on = true, anchor = 'center', x = 0, y = -12.2, align = 'bottom', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', style = 'horizontal', fill = 'auto', length = 260, radius = 150, thickness = 11, ticks_max = 30, edge = 'auto', shade = 'auto' },
  charge = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'above', side = 'auto', style = 'horizontal', length = 260, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  count = { on = true, anchor = 'center', x = 0, y = -0.6, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'right', side = 'auto' },
  mags = { on = true, anchor = 'center', x = 0, y = 0.3, align = 'bottom_left', size = 1, opacity = 100, after = 'count', gap = 8, pin = 'right', side = 'auto', style = 'number', empty = 'shown', divider = true },
  mode1 = { on = false, anchor = 'center', x = 0, y = 0, align = 'right', size = 1, opacity = 100, after = 'mode2', gap = 8, pin = 'left', side = 'auto' },
  mode2 = { on = false, anchor = 'center', x = 0, y = 0, align = 'right', size = 1, opacity = 100, after = 'zoom', gap = 8, pin = 'left', side = 'auto' },
  zoom = { on = false, anchor = 'center', x = -10.1, y = -10.62, align = 'right', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto' },
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0.8, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = -2, pin = 'right', side = 'auto' },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_right', size = 1, opacity = 100, after = 'icon2', gap = -14, pin = 'left', side = 'auto', style = 'line' },
  icon2 = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'bar', gap = 1, pin = 'left', side = 'auto', style = 'line' },
  rpm = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'count', gap = 2, pin = 'below', side = 'auto' },
  stims = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'below', side = 'auto' },
  grenades = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'stims', gap = 8, pin = 'right', side = 'auto' },
  pack = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_right', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 126, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' },
  health = { on = true, anchor = 'center', x = 0, y = -10, align = 'bottom', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', style = 'horizontal', length = 260, thickness = 7, radius = 150, edge = 'auto', shade = 'auto' },
  stamina = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom', size = 1, opacity = 100, after = 'health', gap = 8, pin = 'above', side = 'auto', style = 'horizontal', length = 260, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  stim = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'pack', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 126, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' } } }
-- The block: a short standing bar right of the crosshair with the charge meter inside it, the text column right
-- of it (the icons in a row above the count), stamina, health, the backpack and stim timer stacked under the bar.
local BLOCK_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { on = true, anchor = 'center', x = 10.7, y = -2.2, align = 'bottom_left', size = 1, opacity = 100, after = 'none', gap = 8, pin = 'none', side = 'auto', hold = true, style = 'vertical', fill = 'auto', length = 107, radius = 150, thickness = 11, ticks_max = 30, edge = 'auto', shade = 'auto' },
  charge = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'left', side = 'auto', style = 'vertical', length = 107, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  count = { on = true, anchor = 'center', x = 0, y = 0, align = 'left', size = 1, opacity = 100, after = 'bar', gap = 9, pin = 'right', side = 'auto', hold = true },
  mags = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'count', gap = 8, pin = 'right', side = 'auto', style = 'number', empty = 'shown', divider = false },
  mode1 = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'zoomicon', gap = 8, pin = 'right', side = 'auto' },
  mode2 = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode1', gap = 8, pin = 'right', side = 'auto' },
  zoom = { on = false, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'mode2', gap = 8, pin = 'right', side = 'auto' },
  icon2 = { on = true, anchor = 'center', x = -0.8, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'count', gap = -3, pin = 'above', side = 'auto', style = 'line' },
  icon1 = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon2', gap = -20, pin = 'right', side = 'auto', style = 'line' },
  zoomicon = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon1', gap = -20, pin = 'right', side = 'auto' },
  rpm = { on = true, anchor = 'center', x = 1, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'icon2', gap = -7, pin = 'above', side = 'auto' },
  stims = { on = true, anchor = 'center', x = 0.4, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'count', gap = 8, pin = 'below', side = 'auto' },
  grenades = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'stims', gap = 8, pin = 'right', side = 'auto' },
  stamina = { on = true, anchor = 'center', x = -0.83, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'bar', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 128, thickness = 4, radius = 150, edge = 'auto', shade = 'auto' },
  health = { on = true, anchor = 'center', x = 0, y = 0, align = 'bottom_left', size = 1, opacity = 100, after = 'stamina', gap = 8, pin = 'below', side = 'auto', hold = true, style = 'horizontal', length = 128, thickness = 7, radius = 150, edge = 'auto', shade = 'auto' },
  pack = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_left', size = 1, opacity = 100, after = 'health', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 60, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' },
  stim = { on = true, anchor = 'center', x = 0, y = 0, align = 'top_right', size = 1, opacity = 100, after = 'health', gap = 8, pin = 'below', side = 'auto', style = 'horizontal', length = 60, thickness = 5, radius = 150, edge = 'auto', shade = 'auto' } } }

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
        elseif ok and f[1] == 'choice' then ok = type(v) == 'string' and f[3][v] ~= nil end
        if v ~= nil and not ok then dropped = dropped + 1 end
        -- (a field not given: Under's look's, else the field's own default. Not after / pin / side when the element
        -- is in the file without them: a file from before pins had the magazines where its maker put them, which
        -- following the count would move. An element left out altogether takes all of Under's look (1.5.66: the
        -- split mode parts pinned as Under has them))
        local dv = (given == nil or (name ~= 'after' and name ~= 'pin' and name ~= 'side')) and DEFAULT_LAYOUT.elements[el.id] and DEFAULT_LAYOUT.elements[el.id][name] or nil
        if ok then e[name] = v elseif dv ~= nil then e[name] = dv elseif name == 'on' and el.off then e[name] = false else e[name] = f[2] end
      end
    end
    out[el.id] = e
  end
  return out, dropped
end
local layout = { els = nil, said = nil, builtin = {} }
local cur = {}                                     -- the elements being drawn this frame
-- a built-in layout as read, once; F9's offsets move it
local BUILTIN = { vertical = VERTICAL_LAYOUT, arcs = ARCS_LAYOUT, horizontal = HORIZONTAL_LAYOUT, block = BLOCK_LAYOUT }
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
    log('layout file: can\'t be read (%s): Under\'s look until it\'s fixed (%s)', tostring(ok and err or t), why)
    return false
  end
  local dropped
  layout.els, dropped = read_layout(t)
  -- (F9's two offsets move a Custom layout only when its file says so: one set for another layout moved a Custom one
  -- placed in the editor without anyone noticing)
  layout.offsets = t.use_offsets == true
  if t.use_offsets ~= nil and type(t.use_offsets) ~= 'boolean' then dropped = dropped + 1 end
  local v = tonumber(t._v) or 0
  log('layout file: read (%s)%s%s', why, dropped > 0 and string.format(', %d values that didn\'t fit left at their defaults', dropped) or '',
    v > LAYOUT_VERSION and string.format(', from a newer NarrowHUD (version %d): read what fits', v) or '')
  return true, dropped
end

-- the weapon's fill (0 to 1), colour and alpha, as the built-in layouts have them
local function weapon_tone(d)
  local frac = 0
  if d.top and d.top > 0 then frac = math.max(0, math.min(1, d.value / d.top)) end
  local tone = CREAM
  if d.kind == 'ammo' then
    if d.value == 0 then tone = RED elseif frac <= 0.25 then tone = WARN end
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
local function curved(e) return arcs_ok and (e.style == 'curved_left' or e.style == 'curved_right') end
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
  local span = math.min(300, math.deg(len / R))
  local right = e.style == 'curved_right'
  local mid = right and 90 or 270
  local g = { r_in = R - th / 2, r_out = R + th / 2, span = span, len = len, th = th,
    bot = right and (mid + span / 2) or (mid - span / 2), dir = right and -1 or 1 }
  -- the box: every point of both edges, from one end to the other
  local x0, x1, y0, y1 = 1e9, -1e9, 1e9, -1e9
  local angs = {}
  for i = 0, 24 do angs[#angs + 1] = g.bot + g.dir * span * i / 24 end
  for q = 0, 360, 90 do   -- the farthest points, where the arc passes up, right, down or left
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
-- what's empty from f0 to f1: its shade (faint), its outline (the edge), both, or nothing
local function arc_empty(g, x, y, f0, f1, faint, lw, edge, shade)
  -- (an outline on a piece only a few pixels long, a narrow tick, would look filled anyway: faint instead)
  if edge ~= 2 or g.th <= 2 * lw + 1 or (f1 - f0) * g.len <= 4 * lw then
    if shade or edge == 2 then arc_piece(g, x, y, f0, f1, g.r_in, g.r_out, col(CREAM, faint), L_CUSTOM) end
    return
  end
  local c, cap = col(CREAM, 190), lw / math.max(1, g.len)
  arc_piece(g, x, y, f0, f1, g.r_in, g.r_in + lw, c, L_CUSTOM)
  arc_piece(g, x, y, f0, f1, g.r_out - lw, g.r_out, c, L_CUSTOM)
  arc_piece(g, x, y, f0, math.min(f1, f0 + cap), g.r_in, g.r_out, c, L_CUSTOM)
  arc_piece(g, x, y, math.max(f0, f1 - cap), f1, g.r_in, g.r_out, c, L_CUSTOM)
  if shade then arc_piece(g, x, y, f0 + cap, f1 - cap, g.r_in + lw, g.r_out - lw, col(CREAM, faint), L_CUSTOM) end
end
-- (1.5.53) square brackets at an arc's two ends: a radial stroke just past each end, a little beyond both edges,
-- with short feet in along the inner and outer edges
local function arc_brackets(g, x, y, lw)
  local c = col(CREAM, 210)
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
    if shade then arc_piece(g, x, y, f, 1, g.r_in, g.r_out, col(CREAM, faint), L_CUSTOM) end
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
local EL_DRAW = {}                                  -- (each element's draw function, by its id)
function EL_DRAW.bar(e, k, d, x, y, dry)
  if not d or d.kind == 'none' or not cfg.show_bar then return nil end
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h, g.cx, g.cy end
    local frac, tone, alpha = weapon_tone(d)
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
    else
      arc_solid(g, x, y, N.bar_eased(frac, d), col(N.pulsed('bar', tone), alpha), lw, 45, edge, shade)
      arc_glow(g, x, y, 'bar')
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
  else
    solid_bar(x, y, w, h, N.bar_eased(frac, d), col(N.pulsed('bar', tone), alpha), L_CUSTOM, lw, vert, edge, shade)
    N.glow('bar', x, y, w, h, L_CUSTOM)
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
function EL_DRAW.charge(e, k, d, x, y, dry)
  if not d or not d.charge_frac then return nil end
  local f = d.charge_frac
  local cc = d.locked and WARN or (f >= 0.95 and d.t0 and not d.t0.has.lock and not d.charge_safe and RED or (f >= (d.charge_mark or 2) and WARN or CREAM))
  if d.kind == 'none' then cc = f >= 1 and WARN or CREAM end
  local edge, shade = look_of(e)
  local lw = math.max(1, math.floor(k * 0.8 + 0.5))
  f = N.ease('charge', f, 80)
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h, g.cx, g.cy end
    arc_solid(g, x, y, f, col(cc, 230), lw, 40, edge, shade)
    if d.charge_mark then arc_mark(g, x, y, d.charge_mark, math.max(1, math.floor(2 * k)), col(WARN, 220)) end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  solid_bar(x, y, w, h, f, col(cc, 230), L_CUSTOM, lw, vert, edge, shade)
  if d.charge_mark then
    local mw = math.max(1, math.floor(2 * k))
    if vert then chef.rect(x - 1, y + math.floor(h * d.charge_mark), w + 2, mw, col(WARN, 220), L_CUSTOM + 2)
    else chef.rect(x + math.floor(w * d.charge_mark), y - 1, mw, h + 2, col(WARN, 220), L_CUSTOM + 2) end
  end
  return w, h
end
function EL_DRAW.count(e, k, d, x, y, dry)
  if not d or d.kind == 'none' or not cfg.show_count then return nil end
  local frac, tone = weapon_tone(d)
  local str = d.kind == 'heat' and string.format('%d%%', math.floor(frac * (d.pct_top or 100) + 0.5)) or tostring(d.value)
  local big = math.floor(28 * k + 0.5)
  if not dry then txt(x, y, str, big, col(N.pulsed('bar', tone), 245), L_CUSTOM) end
  return txt_width(str, big), big
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
          if i < d.reserve then chef.rect(sx, y, ps, ps, col(N.pulsed('mags', CREAM), 220), L_CUSTOM)
          elseif cfg.edge == 2 then empty_rect(sx, y, ps, ps, 55, L_CUSTOM, lw, 2, false)
          else chef.rect(sx, y, ps, ps, col({ 150, 150, 150 }, 120), L_CUSTOM) end
        end
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
      chef.rect(x, y, math.max(1, math.floor(2 * k)), big, col(CREAM, 150), L_CUSTOM)
      txt(x + dx, y, str, small, col(N.pulsed('mags', CREAM), 220), L_CUSTOM)
    end
    return dx + txt_width(str, small), big
  end
  if not dry then txt(x, y, str, small, col(N.pulsed('mags', CREAM), 220), L_CUSTOM) end
  return txt_width(str, small), small
end
-- (1.5.54) the modes apart: mode1 the weapon mode (HEAT, UB, the ammo kind), mode2 the fire mode and the zeroing text
local function mode_text(parts, k, x, y, dry)
  if #parts == 0 then return nil end
  local small = math.max(7, math.floor(16 * k + 0.5))
  local str = table.concat(parts, '  ')
  if not dry then txt_modes(x, y, str, small, 200, L_CUSTOM) end
  return txt_width(str, small), small
end
function EL_DRAW.mode1(e, k, d, x, y, dry)
  if not d then return nil end
  local parts = {}
  if d.kind == 'heat' and cfg.show_heat then parts[#parts + 1] = 'HEAT' end
  if d.underbarrel then if cfg.show_mode then parts[#parts + 1] = d.ub_label or 'UB' end
  elseif d.mode then parts[#parts + 1] = d.mode end
  return mode_text(parts, k, x, y, dry)
end
function EL_DRAW.mode2(e, k, d, x, y, dry)
  if not d then return nil end
  local parts = {}
  if d.fmode and not d.underbarrel then parts[#parts + 1] = d.fmode end
  return mode_text(parts, k, x, y, dry)
end
-- (1.5.65) the zeroing as text on its own (whenever the weapon's scope is known: the part being on is the choice)
function EL_DRAW.zoom(e, k, d, x, y, dry)
  if not d or not d.zoom_word then return nil end
  return mode_text({ d.zoom_word }, k, x, y, dry)
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
local function icon_list(e, k, list, x, y, dry)
  local tw = N.icon_px(k)
  local gap = math.floor(4 * k)
  local n = #list
  local w, h
  if e.style == 'stacked' then w, h = tw, n * tw + (n - 1) * gap else w, h = n * tw + (n - 1) * gap, tw end
  if dry then return w, h end
  local keys = {}
  for i = 1, n do
    local ex, ey
    if e.style == 'stacked' then ex, ey = x, y + h - i * tw - (i - 1) * gap else ex, ey = x + (i - 1) * (tw + gap), y end
    local ok, why = N.mode_icon(list[i], ex, ey, tw, L_CUSTOM, list[i].word)
    keys[#keys + 1] = list[i][6] .. (ok and '+' or ('-' .. tostring(why)))
  end
  N.mode_icons_said(cfg.mode_icons, keys)
  return w, h
end
local function without_zoom(list)
  local out = {}
  for _, it in ipairs(list) do if it.word ~= 'ZOOM' then out[#out + 1] = it end end
  return out
end
-- (1.5.65) the zeroing icon on its own
function EL_DRAW.zoomicon(e, k, d, x, y, dry)
  if not d or not (cfg.mode_icons and cfg.mode_icons > 1) or not N.mode_icons then return nil end
  local list = N.mode_icons()
  if not list then return nil end
  for _, it in ipairs(list) do if it.word == 'ZOOM' then return icon_list(e, k, { it }, x, y, dry) end end
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
    return icon_list(e, k, part, x, y, dry)
  end
end
EL_DRAW.icon1, EL_DRAW.icon2 = icons_part(false), icons_part(true)
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
        if i < lit then arc_piece(g, x, y, f0, f0 + segf, g.r_in, g.r_out, col(st.c, st.a), L_CUSTOM)
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
local STAMINA_C = { 130, 190, 235 }
local function vital_bar(e, k, f, c, trail, x, y, dry, key)
  f = math.max(0, math.min(1, f))
  if key and not dry then f = N.ease(key, f, 120) end
  local edge, shade = look_of(e)
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h, g.cx, g.cy end
    arc_solid(g, x, y, f, c, math.max(1, math.floor(k * 0.8 + 0.5)), 45, edge, shade)
    if trail and trail > f then arc_piece(g, x, y, f, math.min(1, trail), g.r_in, g.r_out, col(RED, 170), L_CUSTOM + 1) end
    if key then arc_glow(g, x, y, key) end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  solid_bar(x, y, w, h, f, c, L_CUSTOM, math.max(1, math.floor(k * 0.8 + 0.5)), vert, edge, shade)
  if trail and trail > f then
    local a, b = math.floor(len * f + 0.5), math.floor(len * math.min(1, trail) + 0.5)
    if b > a then
      if vert then chef.rect(x, y + a, w, b - a, col(RED, 170), L_CUSTOM + 1)
      else chef.rect(x + a, y, b - a, h, col(RED, 170), L_CUSTOM + 1) end
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
  local c = f <= 0.25 and RED or (f <= 0.5 and WARN or CREAM)
  if vit.show_h <= 0.01 then return vital_bar(e, k, f, col(c, 230), nil, x, y, true) end
  local a = N.alpha_k
  if not dry then N.alpha_k = a * vit.show_h * (vit.pulse_h or 1) end
  local w, h, acx, acy = vital_bar(e, k, f, col(c, 230), vit.trail and vit.trail / math.max(1, vit.max), x, y, dry, 'health')
  N.alpha_k = a
  return w, h, acx, acy   -- (1.5.76: the arc's centre too — dropped here, health and stamina lost their 'arc' align)
end
function EL_DRAW.stamina(e, k, d, x, y, dry, items, vit)
  if not vit or not vit.st or (cfg.stamina or 1) == 1 then return nil end
  if vit.show_s <= 0.01 then return vital_bar(e, k, vit.st, col(STAMINA_C, 220), nil, x, y, true) end
  local a = N.alpha_k
  if not dry then N.alpha_k = a * vit.show_s end
  local w, h, acx, acy = vital_bar(e, k, vit.st, col(N.pulsed('stamina', vit.st <= 0.2 and WARN or STAMINA_C), 220), nil, x, y, dry, 'stamina')
  N.alpha_k = a
  return w, h, acx, acy
end
-- the stim timer: green, shrinking from full as the stim's effect runs out
local STIM_C = { 120, 215, 140 }
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
local function resolve(els, w, h, sizes, last, offsets)
  local boxes, visiting = {}, {}
  local ox, oy = 0, 0
  if offsets then ox, oy = w * (cfg.off_x or 0) / 100, h * (cfg.off_y or 0) / 100 end
  -- (1.5.55: while aiming, the Aim spread eases in on top)
  -- (1.5.59: 120 ms at Quick and at Normal alike — luka found Normal's 190 too slow for this one)
  local spread = h * ((cfg.spread or 0) + N.ease('aimspread', N.aim_now and (cfg.aim_spread or 0) or 0, 120 / math.max(N.motion_scale(), 1))) / 100
  local function free_point(e)
    local an = ANCHORS[e.anchor]
    local px = w * an[1] + h * e.x / 100 + ox
    local sd = side_of(e)
    if sd == 'left' then px = px - spread elseif sd == 'right' then px = px + spread end
    return px, h * an[2] + h * e.y / 100 + oy
  end
  -- place(id): the part's box, cached. place(id, aw, ah): where the part would be if its size were aw x ah, not
  -- cached — how a part pinned to a hidden part takes its place (1.5.73): it's put where the hidden part would be
  -- with the follower's own size, so a 56 px icon pinned right of an empty icon with tops level sits where that
  -- icon would, not 56 px down in the count (the hidden slot has no height to line up with). A chain of hidden
  -- parts passes the size along.
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
    if target then
      visiting[id] = true
      local tb = place(target)
      if tb.hidden and not hidden then tb = place(target, ew, eh) end   -- (takes its place: see above)
      visiting[id] = nil
      local k = (h / 1440) * cfg.size * e.size
      local gap = tb.hidden and 0 or math.floor(e.gap * k + 0.5)
      -- (1.5.70: a pinned part's x / y nudges scale with Size and the part's size, as the gap does — luka's stims,
      -- a gap and a nudge cancelling at Medium, drifted at Small; a free part's x / y are a place, not scaled)
      local ns = (e.pin ~= 'none') and (cfg.size * e.size) or 1
      local nx, ny = math.floor(h * e.x / 100 * ns + 0.5), math.floor(h * e.y / 100 * ns + 0.5)
      if tb.hidden then x, y = tb.x, tb.y   -- (a hidden part with nothing to show at all, no last box: its point)
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
    if aw then return { x = x, y = y, w = ew, h = eh, hidden = false, taken = true } end
    boxes[id] = { x = x, y = y, w = ew, h = eh, hidden = hidden }
    return boxes[id]
  end
  for _, el in ipairs(ELEMENTS) do place(el.id) end
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
      if e.on and e.opacity > 0 then
        local c0 = el_clock and el_clock()
        local k = (h / 1440) * cfg.size * e.size
        local ew, eh, acx, acy = EL_DRAW[el.id](e, k, d, 0, 0, true, items, vitals)
        if ew then sizes[el.id] = { ew, eh, acx, acy } held[el.id] = sizes[el.id]
        elseif e.hold and held[el.id] and not f9_off(el.id) then sizes[el.id] = held[el.id] silent[el.id] = true end
        if c0 then clocks[el.id] = el_clock() - c0 end
      end
    end
  end
  local boxes = resolve(els, w, h, sizes, drawn, offsets)
  -- (tests: this pass's boxes, the other pass's kept as they were)
  layout.boxes = layout.boxes or {}
  for _, el in ipairs(ELEMENTS) do if (el.vitals == true) == (vitals ~= nil) then layout.boxes[el.id] = boxes[el.id] end end
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
      drawn[el.id] = { x = b.x, y = b.y, w = b.w, h = b.h }
      b.held = true
      was[el.id] = nil
    elseif sz then
      local e, b = els[el.id], boxes[el.id]
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
      -- (1.5.60: the part's Show rule, eased: held back, it keeps its place and isn't drawn (or is dimmed))
      local rule = N.el_alpha(el.id)
      N.alpha_k = base * e.opacity / 100 * fade * rule
      if rule > 0.01 then EL_DRAW[el.id](e, k, d, sx, sy, false, items, vitals) end
      drawn[el.id] = { x = b.x, y = b.y, w = b.w, h = b.h }
      if c0 then clocks[el.id] = (clocks[el.id] or 0) + el_clock() - c0 end
    elseif sizes[el.id] == false then
      was[el.id] = nil
    end
  end
  if el_clock then for id, t in pairs(clocks) do N.el_time[id] = (N.el_time[id] or 0) + t end end
  N.alpha_k = base
end


N.layout, N.load_layout, N.draw_custom = layout, load_layout, draw_custom
-- (2.0: every layout is a layout; the Under and Beside modules that drew the old positions by hand are gone)
N.draw = function(d, items) return draw_custom(d, items) end
N.draw_vitals = function(vit) return draw_custom(nil, nil, vit) end
