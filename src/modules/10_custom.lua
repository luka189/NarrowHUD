-- NarrowHUD, custom: the Custom layout: the layout file (docs/LAYOUT.md) and its elements.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, learned, learn, txt_width, txt, CREAM = N.cfg, N.learned, N.learn, N.txt_width, N.txt, N.CREAM
local WARN, RED, col, empty_rect, solid_bar, txt_modes = N.WARN, N.RED, N.col, N.empty_rect, N.solid_bar, N.txt_modes
local MARK_COLORS, heat_tone, pack_state = N.MARK_COLORS, N.heat_tone, N.pack_state

------------------------------------------------------------------------------------------------ a custom layout
-- Each part of the HUD an element of its own, placed, sized and styled by the layout file
-- (chef_data_luka189_2fnarrowhud__layout.lua in %APPDATA%\Arrowhead\Helldivers2, made by the layout editor or by
-- hand). Position "Custom" draws from it; the F9 toggles, colours, opacity, idle dimming, Size and the offsets apply
-- on top. Every element: on, anchor (a point of the screen), x / y (from there, % of the screen's height: right and
-- up), align (which point of the element sits there), size (x the HUD's), opacity (%), and its own style fields.
local LAYOUT_VERSION = 1
local ANCHORS = { center = { 0.5, 0.5 }, top = { 0.5, 1 }, bottom = { 0.5, 0 }, left = { 0, 0.5 }, right = { 1, 0.5 },
  top_left = { 0, 1 }, top_right = { 1, 1 }, bottom_left = { 0, 0 }, bottom_right = { 1, 0 } }
local ALIGNS = { bottom_left = { 0, 0 }, bottom = { 0.5, 0 }, bottom_right = { 1, 0 }, left = { 0, 0.5 },
  center = { 0.5, 0.5 }, right = { 1, 0.5 }, top_left = { 0, 1 }, top = { 0.5, 1 }, top_right = { 1, 1 } }
-- the elements in drawing order, each field: { kind, default, min / choices, max }
-- after: right after another part (drawn before it), gap pixels (at 1440p, Medium) from its right edge, its x then
-- not used: a count that grows ("100%") pushes the magazines along instead of running over them
local AFTER = { none = 1, bar = 1, charge = 1, count = 1, mags = 1, modes = 1, rpm = 1, stims = 1, grenades = 1, pack = 1,
  health = 1, stamina = 1, stim = 1, icons = 1 }
local COMMON = { on = { 'boolean', true }, anchor = { 'choice', 'center', ANCHORS }, x = { 'number', 0, -100, 100 },
  y = { 'number', 0, -100, 100 }, align = { 'choice', 'bottom_left', ALIGNS }, size = { 'number', 1, 0.3, 4 },
  opacity = { 'number', 100, 0, 100 }, after = { 'choice', 'none', AFTER }, gap = { 'number', 8, -500, 500 } }
local ELEMENTS = {
  { id = 'bar', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      fill = { 'choice', 'auto', { auto = 1, ticks = 1, solid = 1 } }, length = { 'number', 260, 10, 2000 },
      radius = { 'number', 150, 10, 2000 },
      thickness = { 'number', 14, 1, 200 }, ticks_max = { 'number', 30, 1, 200 } } },
  { id = 'charge', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 4, 1, 200 }, radius = { 'number', 150, 10, 2000 } } },
  { id = 'count', fields = {} },
  { id = 'mags', fields = { style = { 'choice', 'number', { number = 1, squares = 1 } },
      empty = { 'choice', 'shown', { shown = 1, hidden = 1 } }, divider = { 'boolean', false } } },
  { id = 'modes', fields = { style = { 'choice', 'line', { line = 1, stacked = 1 } } } },
  -- (1.5.18) the game's own icons of the weapon's mode and fire mode (an F9 Show setting; docs/ICONS.md)
  { id = 'icons', fields = { style = { 'choice', 'line', { line = 1, stacked = 1 } } } },
  { id = 'rpm', fields = {} },
  { id = 'stims', fields = {} },
  { id = 'grenades', fields = {} },
  { id = 'pack', fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 120, 10, 2000 }, thickness = { 'number', 7, 1, 200 }, radius = { 'number', 150, 10, 2000 } } },
  -- (1.1.0) your health and stamina: shown when F9's Health bar / Stamina bar say so (off by default)
  { id = 'health', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 5, 1, 200 }, radius = { 'number', 150, 10, 2000 } } },
  { id = 'stamina', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 3, 1, 200 }, radius = { 'number', 150, 10, 2000 } } },
  -- (1.2.0) the stim timer: shown when F9's Stim timer is on, while a stim of yours works
  { id = 'stim', vitals = true, fields = { style = { 'choice', 'horizontal', { horizontal = 1, vertical = 1, curved_left = 1, curved_right = 1 } },
      length = { 'number', 260, 10, 2000 }, thickness = { 'number', 3, 1, 200 }, radius = { 'number', 150, 10, 2000 } } },
}
-- the layout written the first time Custom is chosen and there's no file: Under's look, to start from
local DEFAULT_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { anchor = 'center', x = 0, y = -9, align = 'bottom' },
  charge = { anchor = 'center', x = 0, y = -7.75, align = 'bottom' },   -- (over the bar: 14 px and 4 px above -9 %)
  count = { anchor = 'center', x = 9.9, y = -8.5, align = 'left' },
  mags = { anchor = 'center', x = 13.3, y = -9.47, align = 'bottom_left', divider = true, after = 'count', gap = 8 },
  modes = { anchor = 'center', x = -9.7, y = -8.5, align = 'right' },
  icons = { anchor = 'center', x = -9.4, y = -9.6, align = 'top_right' },
  rpm = { anchor = 'center', x = 9.9, y = -9.9, align = 'top_left' },
  stims = { anchor = 'center', x = -9, y = -9.6, align = 'top_left' },
  grenades = { anchor = 'center', x = -4.6, y = -9.6, align = 'top_left' },
  pack = { anchor = 'center', x = -0.4, y = -10.6, align = 'left', length = 135 },
  -- (over the charge meter, as Under draws them)
  health = { anchor = 'center', x = 0, y = -7.33, align = 'bottom' },
  stamina = { anchor = 'center', x = 0, y = -6.78, align = 'bottom' },
  stim = { anchor = 'center', x = 0, y = -6.36, align = 'bottom' } } }

-- (1.5.13, luka's 1.5.22 version) Position: Curved pair, a built-in layout: every arc centred on the crosshair: the
-- ammo bar as a ) on the right with the charge meter outside it and the backpack inside, health as a ( on the left
-- with stamina outside and the stim timer inside; the text in a column right of the arcs, the icons beside it,
-- stims and grenades under the crosshair. 8 px between a bar and its meter on both sides. The same layout is the
-- editor's Curved pair preset (editor/editor.html: PRESETS).
local CURVED_LAYOUT = { _v = LAYOUT_VERSION, elements = {
  bar = { anchor = 'center', x = 6, y = 0, align = 'left', style = 'curved_right', fill = 'auto', length = 300, radius = 160, thickness = 10 },
  charge = { anchor = 'center', x = 6.78, y = 0, align = 'left', style = 'curved_right', length = 330, radius = 176, thickness = 4 },
  count = { anchor = 'center', x = 9.7, y = -8.4, align = 'top_left' },
  mags = { anchor = 'center', x = 9.7, y = -10.6, align = 'top_left', style = 'number', empty = 'shown', divider = false, after = 'none' },
  modes = { anchor = 'center', x = 10.6, y = 8, align = 'bottom_left', style = 'stacked' },
  icons = { anchor = 'center', x = 15.8, y = 8, align = 'bottom_left', style = 'stacked' },
  rpm = { anchor = 'center', x = 10.6, y = 11.4, align = 'bottom_left' },
  stims = { anchor = 'center', x = -4.7, y = -9.2, align = 'top_right' },
  grenades = { anchor = 'center', x = -8.7, y = -9.2, align = 'top_right' },
  pack = { anchor = 'center', x = -6, y = 0, align = 'right', style = 'curved_left', length = 240, radius = 160, thickness = 8 },
  health = { anchor = 'center', x = 0, y = -12, align = 'top', style = 'horizontal', length = 220, thickness = 5 },
  stamina = { anchor = 'center', x = 0, y = -12.7, align = 'top', style = 'horizontal', length = 220, thickness = 3 },
  stim = { anchor = 'center', x = 0, y = -13.2, align = 'top', style = 'horizontal', length = 220, thickness = 3 } } }
-- (1.5.24) the Preview positions: luka's four layouts of 2026-10-28, aligned by the arcs' geometry and the bars'
-- edges (8 px between a bar and its meter, the set's thicknesses: bar 11, charge 4, backpack and stim timer 5,
-- health 7, stamina 4). Preview 3, the curved pair: every arc centred on the crosshair, the backpack arc inside
-- the bar and the stim timer inside the health arc. Kept apart from the Positions people have set up until the
-- offsets and the pinning of parts to each other are redone for presets.
local PREVIEW_CURVED = { _v = LAYOUT_VERSION, elements = {
  bar = { anchor = 'center', x = 6.35, y = 0, align = 'left', style = 'curved_right', fill = 'auto', length = 300, radius = 160, thickness = 11 },
  charge = { anchor = 'center', x = 7.15, y = 0, align = 'left', style = 'curved_right', length = 330, radius = 176, thickness = 4 },
  pack = { anchor = 'center', x = 9.24, y = 0, align = 'left', style = 'curved_right', length = 100, radius = 144, thickness = 5 },
  count = { anchor = 'center', x = 11.3, y = -7.3, align = 'top_left' },
  mags = { anchor = 'center', x = 11.3, y = -9.5, align = 'top_left', style = 'number', empty = 'shown', divider = false, after = 'none' },
  modes = { anchor = 'center', x = 11.3, y = 7.3, align = 'bottom_left', style = 'stacked' },
  rpm = { anchor = 'center', x = 11.3, y = 10.1, align = 'bottom_left' },
  icons = { anchor = 'center', x = 13.7, y = 0, align = 'center', style = 'stacked' },
  stims = { anchor = 'center', x = -1.8, y = -8.6, align = 'center' },
  grenades = { anchor = 'center', x = 1.8, y = -8.6, align = 'center' },
  health = { anchor = 'center', x = -6.43, y = 0, align = 'right', style = 'curved_left', length = 300, radius = 160, thickness = 7 },
  stamina = { anchor = 'center', x = -7.07, y = 0, align = 'right', style = 'curved_left', length = 326, radius = 174, thickness = 4 },
  stim = { anchor = 'center', x = -9.24, y = 0, align = 'right', style = 'curved_left', length = 100, radius = 144, thickness = 5 } } }
-- Preview 4, the vertical pair, luka's layout: the ammo bar standing right of the crosshair with the charge
-- meter outside it and the backpack inside, health standing on the left with stamina outside and the stim timer
-- inside, the text in a column right of the bars, stims and grenades under the crosshair. The spacing: the bar's
-- edges mirrored exactly (the health bar thinner), 8 px between a bar and its meter on both sides.
local PREVIEW_VERTICAL = { _v = LAYOUT_VERSION, elements = {
  bar = { anchor = 'center', x = 7.6, y = -6.5, align = 'bottom_left', style = 'vertical', fill = 'auto', length = 190, thickness = 11 },
  charge = { anchor = 'center', x = 9.2, y = -6.5, align = 'bottom_right', style = 'vertical', length = 190, thickness = 4 },
  pack = { anchor = 'center', x = 6.6, y = 2.8, align = 'top_left', style = 'vertical', length = 80, thickness = 5 },
  count = { anchor = 'center', x = 9.8, y = -7.6, align = 'bottom_left' },
  mags = { anchor = 'center', x = 14.33, y = -6.69, align = 'center', style = 'number', empty = 'shown', divider = true, after = 'count', gap = 6 },
  rpm = { anchor = 'center', x = 9.8, y = -4.9, align = 'bottom_left' },
  modes = { anchor = 'center', x = 9.8, y = 7.6, align = 'top_left', style = 'stacked' },
  icons = { anchor = 'center', x = 9.4, y = 4.5, align = 'top_left', style = 'stacked' },
  stims = { anchor = 'center', x = -1.0, y = -8.1, align = 'top_right' },
  grenades = { anchor = 'center', x = 1.0, y = -8.1, align = 'top_left' },
  health = { anchor = 'center', x = -7.6, y = -6.5, align = 'bottom_right', style = 'vertical', length = 190, thickness = 7 },
  stamina = { anchor = 'center', x = -8.64, y = -6.5, align = 'bottom_right', style = 'vertical', length = 190, thickness = 4 },
  stim = { anchor = 'center', x = -6.6, y = 2.8, align = 'top_right', style = 'vertical', length = 80, thickness = 5 } } }

-- Preview 2, the compact block, luka's layout: one block right of the crosshair with the
-- short standing ammo bar as its spine (the charge meter 8 px left of it), the text in a column right of it (the
-- icons and modes in a line on top, the rate of fire, the count with the magazines, stims and grenades), and
-- under the bar three rows the block's width: stamina, health, then the backpack and stim timer side by side.
local PREVIEW_COMPACT = { _v = LAYOUT_VERSION, elements = {
  bar = { anchor = 'center', x = 10.7, y = -2.2, align = 'bottom_left', style = 'vertical', fill = 'auto', length = 107, thickness = 11 },
  charge = { anchor = 'center', x = 10.14, y = -2.2, align = 'bottom_right', style = 'vertical', length = 107, thickness = 4 },
  icons = { anchor = 'center', x = 12.1, y = 5.5, align = 'top_left', style = 'line' },
  modes = { anchor = 'center', x = 15, y = 5.5, align = 'top_left', style = 'line', after = 'icons', gap = 8 },
  rpm = { anchor = 'center', x = 12.1, y = 3.73, align = 'top_left' },
  count = { anchor = 'center', x = 12.1, y = 0.4, align = 'bottom_left' },
  mags = { anchor = 'center', x = 12.9, y = 1.5, align = 'top_left', style = 'number', empty = 'shown', divider = false, after = 'count', gap = 8 },
  stims = { anchor = 'center', x = 12.1, y = -0.15, align = 'top_left' },
  grenades = { anchor = 'center', x = 15, y = -0.15, align = 'top_left' },
  stamina = { anchor = 'center', x = 9.86, y = -3.03, align = 'bottom_left', style = 'horizontal', length = 128, thickness = 4 },
  health = { anchor = 'center', x = 9.86, y = -4.08, align = 'bottom_left', style = 'horizontal', length = 128, thickness = 7 },
  pack = { anchor = 'center', x = 9.86, y = -4.98, align = 'bottom_left', style = 'horizontal', length = 60, thickness = 5 },
  stim = { anchor = 'center', x = 18.75, y = -4.98, align = 'bottom_right', style = 'horizontal', length = 60, thickness = 5 } } }

-- Preview 1, the horizontal stack, luka's layout: the bars under the crosshair 8 px apart (ammo, charge, health,
-- stamina), the backpack and stim timer in two rows under the right half, stims and grenades under the left, the
-- count and rate of fire right of the bars, modes and icons mirrored on the left.
local PREVIEW_HORIZONTAL = { _v = LAYOUT_VERSION, elements = {
  bar = { anchor = 'center', x = 0, y = -11, align = 'bottom', style = 'horizontal', fill = 'auto', length = 260, thickness = 11 },
  charge = { anchor = 'center', x = 0, y = -9.68, align = 'bottom', style = 'horizontal', length = 260, thickness = 4 },
  health = { anchor = 'center', x = 0, y = -8.85, align = 'bottom', style = 'horizontal', length = 260, thickness = 7 },
  stamina = { anchor = 'center', x = 0, y = -7.8, align = 'bottom', style = 'horizontal', length = 260, thickness = 4 },
  pack = { anchor = 'center', x = 0.28, y = -11.9, align = 'bottom_left', style = 'horizontal', length = 126, thickness = 5 },
  stim = { anchor = 'center', x = 0.28, y = -12.8, align = 'bottom_left', style = 'horizontal', length = 126, thickness = 5 },
  count = { anchor = 'center', x = 10.1, y = -10.62, align = 'left' },
  mags = { anchor = 'center', x = 13.3, y = -11.27, align = 'bottom_left', style = 'number', empty = 'shown', divider = true, after = 'count', gap = 8 },
  rpm = { anchor = 'center', x = 10.1, y = -11.7, align = 'top_left' },
  modes = { anchor = 'center', x = -10.1, y = -10.62, align = 'right', style = 'line' },
  icons = { anchor = 'center', x = -10.1, y = -11.7, align = 'top_right', style = 'line' },
  stims = { anchor = 'center', x = -9, y = -11.56, align = 'top_left' },
  grenades = { anchor = 'center', x = -5.6, y = -11.56, align = 'top_left' } } }

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
        -- (a field not given: Under's look's, else the field's own default. Not after: a file from before it had
        -- the magazines where its maker put them, which following the count would move)
        local dv = name ~= 'after' and DEFAULT_LAYOUT.elements[el.id] and DEFAULT_LAYOUT.elements[el.id][name] or nil
        if ok then e[name] = v elseif dv ~= nil then e[name] = dv else e[name] = f[2] end
      end
    end
    out[el.id] = e
  end
  return out, dropped
end
local layout = { els = nil, said = nil, builtin = {} }
-- a built-in layout (Position: Curved pair) as read, once; F9's offsets move it, as they move Under and Beside
local BUILTIN = { curved = CURVED_LAYOUT, preview1 = PREVIEW_HORIZONTAL, preview2 = PREVIEW_COMPACT, preview3 = PREVIEW_CURVED, preview4 = PREVIEW_VERTICAL }
local function builtin_layout(name)
  local l = layout.builtin[name]
  if not l then l = { els = read_layout(BUILTIN[name] or CURVED_LAYOUT) } layout.builtin[name] = l end
  return l
end
local function load_layout(why)
  -- (chef.load_table's second value says why there's no table: called on its own, an 'and' would drop it)
  local ok, t, err = false, nil, 'no chef.load_table'
  if chef.load_table then ok, t, err = pcall(chef.load_table, 'layout') end
  -- (no file yet: Under's look written, for the editor or a text editor to start from. One that's there but can't
  -- be read, a typo in a hand edit, is never written over: Under's look until it's fixed)
  local none = ok and type(t) ~= 'table' and (string.find(tostring(err), 'none saved') or
    string.find(tostring(err), 'no such file') or string.find(tostring(err), 'missing'))
  if none and chef.save_table then
    t = DEFAULT_LAYOUT
    pcall(chef.save_table, 'layout', t)
    log('layout file: none yet, one with Under\'s look written (%s)', why)
  end
  if not ok or type(t) ~= 'table' then
    layout.els, layout.offsets = read_layout(DEFAULT_LAYOUT), false
    log('layout file: can\'t be read (%s): Under\'s look until it\'s fixed (%s)', tostring(ok and err or t), why)
    return false
  end
  local dropped
  layout.els, dropped = read_layout(t)
  -- (F9's two offsets move a Custom layout only when its file says so: one set for another Position moved a layout
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
local L_CUSTOM = 905
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
-- what's empty from f0 to f1: faint, or (outlines) its outline
local function arc_empty(g, x, y, f0, f1, faint, lw)
  -- (an outline on a piece only a few pixels long, a narrow tick, would look filled anyway: faint instead)
  if not cfg.outline or g.th <= 2 * lw + 1 or (f1 - f0) * g.len <= 4 * lw then
    arc_piece(g, x, y, f0, f1, g.r_in, g.r_out, col(CREAM, faint), L_CUSTOM)
    return
  end
  local c, cap = col(CREAM, 190), lw / math.max(1, g.len)
  arc_piece(g, x, y, f0, f1, g.r_in, g.r_in + lw, c, L_CUSTOM)
  arc_piece(g, x, y, f0, f1, g.r_out - lw, g.r_out, c, L_CUSTOM)
  arc_piece(g, x, y, f0, math.min(f1, f0 + cap), g.r_in, g.r_out, c, L_CUSTOM)
  arc_piece(g, x, y, math.max(f0, f1 - cap), f1, g.r_in, g.r_out, c, L_CUSTOM)
end
-- a solid curved bar f full: the background (faint all along, or one outline around the whole), the fill inside
local function arc_solid(g, x, y, f, c, lw, faint)
  f = math.max(0, math.min(1, f))
  if cfg.outline and g.th > 2 * lw + 1 then
    arc_empty(g, x, y, 0, 1, faint, lw)
    local cap = lw / math.max(1, g.len)
    arc_piece(g, x, y, cap, cap + (1 - 2 * cap) * f, g.r_in + lw, g.r_out - lw, c, L_CUSTOM + 1)
  else
    arc_piece(g, x, y, 0, f, g.r_in, g.r_out, c, L_CUSTOM + 1)   -- (the faint part only where it's empty)
    arc_piece(g, x, y, f, 1, g.r_in, g.r_out, col(CREAM, faint), L_CUSTOM)
  end
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
    if dry then return w, h end
    local frac, tone, alpha = weapon_tone(d)
    local lw = math.max(1, math.floor(k * 0.8 + 0.5))
    local ticks = d.kind == 'ammo' and d.top and d.top >= 1 and
      (e.fill == 'ticks' or (e.fill == 'auto' and d.top <= e.ticks_max))
    if ticks then
      local n = math.max(d.top, math.min(d.value, d.top + 3))
      local gapf = math.max(1, math.min(g.len / n * 0.45, 4 * k)) / math.max(1, g.len)
      local segf = (1 + gapf) / n - gapf
      for i = 0, n - 1 do
        local f0 = i * (segf + gapf)
        if i < d.value then arc_piece(g, x, y, f0, f0 + segf, g.r_in, g.r_out, col(tone, alpha), L_CUSTOM)
        else arc_empty(g, x, y, f0, f0 + segf, 55, lw) end
      end
    else
      arc_solid(g, x, y, frac, col(tone, alpha), lw, 45)
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
      if i < d.value then chef.rect(tx, ty, tw, tt, col(tone, alpha), L_CUSTOM)
      else empty_rect(tx, ty, tw, tt, 55, L_CUSTOM, lw) end
    end
  else
    solid_bar(x, y, w, h, frac, col(tone, alpha), L_CUSTOM, lw, vert)
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
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h end
    f = math.max(0, math.min(1, f))
    arc_piece(g, x, y, 0, f, g.r_in, g.r_out, col(cc, 230), L_CUSTOM + 1)
    arc_piece(g, x, y, f, 1, g.r_in, g.r_out, col(CREAM, 40), L_CUSTOM)
    if d.charge_mark then arc_mark(g, x, y, d.charge_mark, math.max(1, math.floor(2 * k)), col(WARN, 220)) end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  chef.rect(x, y, w, h, col(CREAM, 40), L_CUSTOM)
  if vert then chef.rect(x, y, w, math.floor(h * math.min(1, f) + 0.5), col(cc, 230), L_CUSTOM + 1)
  else chef.rect(x, y, math.floor(w * math.min(1, f) + 0.5), h, col(cc, 230), L_CUSTOM + 1) end
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
  if not dry then txt(x, y, str, big, col(tone, 245), L_CUSTOM) end
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
          if i < d.reserve then chef.rect(sx, y, ps, ps, col(CREAM, 220), L_CUSTOM)
          elseif cfg.outline then empty_rect(sx, y, ps, ps, 55, L_CUSTOM, lw)
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
      txt(x + dx, y, str, small, col(CREAM, 220), L_CUSTOM)
    end
    return dx + txt_width(str, small), big
  end
  if not dry then txt(x, y, str, small, col(CREAM, 220), L_CUSTOM) end
  return txt_width(str, small), small
end
function EL_DRAW.modes(e, k, d, x, y, dry)
  if not d then return nil end
  local parts = {}
  if d.kind == 'heat' and cfg.show_heat then parts[#parts + 1] = 'HEAT' end
  if d.underbarrel then if cfg.show_mode then parts[#parts + 1] = d.ub_label or 'UB' end
  elseif d.mode then parts[#parts + 1] = d.mode end
  if d.fmode and not d.underbarrel then parts[#parts + 1] = d.fmode end
  if #parts == 0 then return nil end
  local small = math.max(7, math.floor(16 * k + 0.5))
  local gap = math.floor(4 * k)
  if e.style == 'stacked' then
    local w = 0
    for _, p in ipairs(parts) do w = math.max(w, txt_width(p, small)) end
    local h = #parts * small + (#parts - 1) * gap
    if not dry then
      for i, p in ipairs(parts) do txt_modes(x, y + (#parts - i) * (small + gap), p, small, 200, L_CUSTOM) end
    end
    return w, h
  end
  local str = table.concat(parts, '  ')
  if not dry then txt_modes(x, y, str, small, 200, L_CUSTOM) end
  return txt_width(str, small), small
end
function EL_DRAW.rpm(e, k, d, x, y, dry)
  if not d or not d.setting then return nil end
  local tiny = math.max(6, math.floor(12 * k + 0.5))
  if not dry then txt(x, y, d.setting, tiny, col(CREAM, 190), L_CUSTOM) end
  return txt_width(d.setting, tiny), tiny
end
local icon_el_said = false
local function icon_el(rows, n, k, x, y, dry)
  local cell = math.max(1, math.floor(1.6 * k + 0.5))
  local small = math.max(7, math.floor(16 * k + 0.5))
  local S = #N.GRENADE * cell
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
  local c = n == 0 and RED or CREAM
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
function EL_DRAW.icons(e, k, d, x, y, dry)
  if not d or not (cfg.mode_icons and cfg.mode_icons > 1) or not N.mode_icons then return nil end
  local list = N.mode_icons()
  if not list then return nil end
  local cell = math.max(1, math.floor(1.6 * k + 0.5))
  local tw = 2 * #N.STIM[1] * cell
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
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h end
    arc_solid(g, x, y, st.f, col(st.c, st.a), math.max(1, math.floor(k * 0.8 + 0.5)), 45)
    for _, m in ipairs(st.marks) do arc_mark(g, x, y, m[1], math.max(1, math.floor(2 * k)), col(m[2], 220)) end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  solid_bar(x, y, w, h, st.f, col(st.c, st.a), L_CUSTOM, math.max(1, math.floor(k * 0.8 + 0.5)), vert)
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
local function vital_bar(e, k, f, c, trail, x, y, dry)
  f = math.max(0, math.min(1, f))
  if curved(e) then
    local g, w, h = arc_geom(e, k)
    if dry then return w, h end
    arc_solid(g, x, y, f, c, math.max(1, math.floor(k * 0.8 + 0.5)), 45)
    if trail and trail > f then arc_piece(g, x, y, f, math.min(1, trail), g.r_in, g.r_out, col(RED, 170), L_CUSTOM + 1) end
    return w, h
  end
  local vert = e.style ~= 'horizontal'
  local len, th = math.floor(e.length * k + 0.5), math.max(1, math.floor(e.thickness * k + 0.5))
  local w, h = vert and th or len, vert and len or th
  if dry then return w, h end
  solid_bar(x, y, w, h, f, c, L_CUSTOM, math.max(1, math.floor(k * 0.8 + 0.5)), vert)
  if trail and trail > f then
    local a, b = math.floor(len * f + 0.5), math.floor(len * math.min(1, trail) + 0.5)
    if b > a then
      if vert then chef.rect(x, y + a, w, b - a, col(RED, 170), L_CUSTOM + 1)
      else chef.rect(x + a, y, b - a, h, col(RED, 170), L_CUSTOM + 1) end
    end
  end
  return w, h
end
function EL_DRAW.health(e, k, d, x, y, dry, items, vit)
  if not vit or not vit.hp or vit.show_h <= 0 then return nil end
  local f = vit.hp / math.max(1, vit.max)
  local c = f <= 0.25 and RED or (f <= 0.5 and WARN or CREAM)
  local a = N.alpha_k
  if not dry then N.alpha_k = a * vit.show_h * (vit.pulse_h or 1) end
  local w, h = vital_bar(e, k, f, col(c, 230), vit.trail and vit.trail / math.max(1, vit.max), x, y, dry)
  N.alpha_k = a
  return w, h
end
function EL_DRAW.stamina(e, k, d, x, y, dry, items, vit)
  if not vit or not vit.st or vit.show_s <= 0 then return nil end
  local a = N.alpha_k
  if not dry then N.alpha_k = a * vit.show_s end
  local w, h = vital_bar(e, k, vit.st, col(vit.st <= 0.2 and WARN or STAMINA_C, 220), nil, x, y, dry)
  N.alpha_k = a
  return w, h
end
-- the stim timer: green, shrinking from full as the stim's effect runs out
local STIM_C = { 120, 215, 140 }
function EL_DRAW.stim(e, k, d, x, y, dry, items, vit)
  if not vit or not vit.stim then return nil end
  return vital_bar(e, k, vit.stim, col(STIM_C, 225), nil, x, y, dry)
end
N.vital_bar, N.STAMINA_C, N.EL_DRAW = vital_bar, STAMINA_C, EL_DRAW

-- (research log: each element's time, for the timing line)
N.el_time = {}
local el_clock = cfg.research and os and os.clock or nil
-- (vitals: the health and stamina parts only, drawn on their own each frame; else every other part)
local function draw_custom(d, items, vitals)
  local w, h = chef.screen()
  if not w then return end
  local els, offsets = nil, nil
  if cfg.builtin then
    els, offsets = builtin_layout(cfg.builtin).els, true
  else
    if not layout.els then load_layout('Custom chosen') end
    els, offsets = layout.els, layout.offsets
  end
  local base = N.alpha_k
  -- (each part's box, for one placed after it: this pass's parts from this frame, the other pass's from its last
  -- frame, so health can follow the count and the other way round)
  local drawn = layout.drawn or {}
  layout.drawn = drawn
  for _, el in ipairs(ELEMENTS) do if (el.vitals == true) == (vitals ~= nil) then drawn[el.id] = nil end end
  for _, el in ipairs(ELEMENTS) do
    local e = els[el.id]
    local c0 = el_clock and el_clock()
    if e.on and e.opacity > 0 and (el.vitals == true) == (vitals ~= nil) then
      local k = (h / 1440) * cfg.size * e.size
      local fn = EL_DRAW[el.id]
      local ew, eh = fn(e, k, d, 0, 0, true, items, vitals)
      if ew then
        local an, al = ANCHORS[e.anchor], ALIGNS[e.align]
        local ox, oy = 0, 0
        if offsets then ox, oy = w * (cfg.off_x or 0) / 100, h * (cfg.off_y or 0) / 100 end
        local px = w * an[1] + h * e.x / 100 + ox
        local py = h * an[2] + h * e.y / 100 + oy
        local x = math.floor(px - ew * al[1] + 0.5)
        local y = math.floor(py - eh * al[2] + 0.5)
        local prev = e.after ~= 'none' and drawn[e.after]
        if prev then x = prev.x + prev.w + math.floor(e.gap * k + 0.5) end
        x = math.max(0, math.min(x, w - ew))
        y = math.max(0, math.min(y, h - eh))
        N.alpha_k = base * e.opacity / 100
        fn(e, k, d, x, y, false, items, vitals)
        drawn[el.id] = { x = x, w = ew }
      end
    end
    if c0 then N.el_time[el.id] = (N.el_time[el.id] or 0) + el_clock() - c0 end
  end
  N.alpha_k = base
end


N.layout, N.load_layout, N.draw_custom = layout, load_layout, draw_custom
