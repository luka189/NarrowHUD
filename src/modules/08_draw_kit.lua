-- NarrowHUD, draw_kit: drawing helpers: text and fonts, palettes and mode colours, the bar and outline helpers, icons, the items line.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local call, cfg = N.call, N.cfg

------------------------------------------------------------------------------------------------ text
-- The game's own HUD font, FSSinclair Medium.
-- * Chef Shared Loader 1.1 and newer draw chef.text in it themselves (in capitals): used as it is.
-- * On 1.0.x NarrowHUD draws it in an immediate screen GUI of its own, the way Chef 1.1 does: the font's runtime copy
--   with the game's runtime-font material, both by name (the material the game makes itself; a development font's own
--   material can end the game, and 0.2.0's had a yellow edge). The cap height of 'H' is measured once to size it.
-- Any step failing (or skipped after a crash) falls back to Chef's pixel font for the rest of the session.
-- (The approach follows Chef Shared Loader 1.1's text; no code of it is copied.)
local CHEF_TEXT = chef.text_fit ~= nil                     -- Chef 1.1: chef.text is the game font already
local FONT = { font = 'content/fonts/fs_sinclair_medium_runtime', material = 'content/fonts/runtime_font' }
local gf = { failed = CHEF_TEXT, gui = nil, world = nil, wid = nil, widths = {}, cap100 = nil, base100 = 0 }
local function gf_fail(why)
  if not gf.failed then log('game font off (%s): pixel font from now on', tostring(why)) end
  gf.failed, gf.gui = true, nil
end
local function v3(x, y, z) return call('v3', 'Vector3', x, y, z) end
local function numbers(v)                                  -- x, y of an engine vector, from its text
  local a, b = string.match(tostring(v), '%(%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)')
  return tonumber(a), tonumber(b)
end
-- (Not used for now: the game font everywhere, to judge its look. 0.2.2 switched to the pixel font below native.)
-- Below native Render Scale, Chef 1.0.x draws in the UI world (the whole screen, colors converted for it); a GUI of
-- ours in the game's world there goes through the game's picture (upscaled, color-graded: red came out with yellow
-- edges). So there, on 1.0.x, the pixel font, drawn by Chef with the rest.
local native = { at = -100, yes = true }
local function at_native()
  local now = chef.time()
  if now < native.at + 5 then return native.yes end
  native.at = now
  local yes = true
  if chef.setting then
    local r, sc = chef.setting('render_settings.render_resolution'), chef.setting('screen_resolution')
    if type(r) == 'table' and type(sc) == 'table' and tonumber(r[2]) and tonumber(sc[2]) and sc[2] > 0 then
      yes = r[2] / sc[2] >= 0.98
    end
  end
  if yes ~= native.yes then log('render scale %s: %s', yes and 'native' or 'below native', yes and 'game font' or 'pixel font') end
  native.yes = yes
  return yes
end
-- (1.5.29) engine objects this mod has had made, for the vitals line (a count that climbs is a leak on the engine's
-- side, which the Lua heap doesn't show): screen GUIs (one a world) and material copies (one a material a world)
N.engine_made = { gui = 0, mat = 0 }
local function game_font()
  if gf.failed or not cfg.font then return nil end
  local world, wid = chef.world(), chef.world_id()
  if world == nil then return nil end
  if gf.gui and gf.world == world and gf.wid == wid then return gf.gui end
  gf.gui = nil                                             -- a GUI from an older world is never touched again
  if not gf.checked then
    gf.checked = true
    if call('can_get', 'Application.can_get', 'material', FONT.material) ~= true then gf_fail('no font material') return nil end
    if call('can_get', 'Application.can_get', 'runtime_font', FONT.font) ~= true then gf_fail('no font') return nil end
  end
  local g, why = call('gui', 'World.create_screen_gui', world, 'immediate')
  if not g then gf_fail(why or 'no gui') return nil end
  N.engine_made.gui = N.engine_made.gui + 1
  if not gf.cap100 then
    local lo, hi = call('extents', 'Gui.text_extents', g, 'H', FONT.font, 100)
    local _, y0 = numbers(lo)
    local _, y1 = numbers(hi)
    if not (y0 and y1 and y1 > y0) then gf_fail('no measure') return nil end
    gf.cap100, gf.base100 = y1 - y0, y0
  end
  gf.gui, gf.world, gf.wid = g, world, wid
  if not gf.said then gf.said = true log('game font on (cap height %.1f at size 100)', gf.cap100) end
  return g
end
-- (1.5.18 research) a sprite of the game's atlas drawn through the game's own icon material for it (the mask shader
-- the HUD draws it with: black empty, white the icon, blue a second layer) on a screen GUI of ours: Gui.material
-- gives this GUI its own copy of the material, the page is bound to its diffuse_map slot (bind = true; the copy may
-- point at the page already: bind = false leaves it), Gui.bitmap_uv draws the sprite's rectangle. Every engine
-- value made fresh in the frame it's used (docs/chef_bitmap_issue.md).
local im = { gui = nil, world = nil, wid = nil, mats = {}, handles = {} }
local UI_SLOT = '3aa8b87e00000000'
-- c: the vertex colour (an engine Color), which is the icon's colour: the icon shader (template 5f8113d2, its
-- library read 2026-10-28) tints the mask by it; its own variables are a glow and a shadow (glow_color, shadow_color
-- ...) and a per-object c0 that setting didn't change anything (research/materials, docs/ICONS.md)
-- (1.5.79) The GUI of ours lives in the game's world, and that world tone-maps what's drawn in it (1.5.63): the
-- icons came out white while the rest of the HUD, in the game's UI world since then, kept its cream (luka). With
-- the UI layer on, the GUI is made in that world instead — the first of Application.worlds that isn't the game's,
-- as Chef finds it (loader.lua top_world) — and forgotten when the list changes (a world gone). No list, or the UI
-- layer off: the game's world, as before.
local function icon_world()
  local world, wid = chef.world(), chef.world_id()
  if world == nil then return nil end
  if (N.L0 or 0) == 0 then return world, wid, 0, false end
  local ws = call('worlds', 'Application.worlds')
  if type(ws) ~= 'table' then return world, wid, 0, false end
  for i = 1, #ws do
    if ws[i] ~= world then return ws[i], wid, #ws, true end
  end
  return world, wid, #ws, false
end
local function own_sprite(e, x, y, w, h, c, layer)
  local world, wid, nw, top = icon_world()
  if world == nil then return false, 'no world' end
  if not (im.gui and im.world == world and im.wid == wid and im.nw == nw) then
    im.gui, im.mats, im.cols = nil, {}, {}
    local g, why = call('gui', 'World.create_screen_gui', world, 'immediate')
    if not g then return false, why or 'no gui' end
    N.engine_made.gui = N.engine_made.gui + 1
    im.gui, im.world, im.wid, im.nw, im.top, im.handles = g, world, wid, nw, top, {}
    if cfg.research then log('research: the mode icons\' GUI made in %s', top and 'the UI world' or 'the game\'s world') end
  end
  if im.top then layer = layer - (chef.TOP or 2000) end   -- (the layers of our own GUI: the UI world's numbers)
  local mat = e[6]
  local st = im.mats[mat]
  if st == nil then
    local mid = call('id', 'IdString64.from_hex', mat)
    local ok, why = call('can_get', 'Application.can_get', 'material', mid)
    st = ok == true and 'yes' or ('material not loaded (' .. tostring(why or ok) .. ')')
    im.mats[mat] = st
  end
  if st ~= 'yes' then return false, st end
  local mid, pid = call('id', 'IdString64.from_hex', mat), call('id', 'IdString64.from_hex', e[1])
  if not (mid and pid) then return false, 'no id' end
  -- (1.5.29: the GUI's copy of the material asked for once a world and kept, not once a frame an icon: should
  -- Gui.material make a copy each call, that was 60 copies a second an icon, never freed while the world lived)
  local mh = im.handles[mat]
  if not mh then
    local why
    mh, why = call('mat', 'Gui.material', im.gui, mid)
    if not mh then return false, 'Gui.material: ' .. tostring(why) end
    N.engine_made.mat = N.engine_made.mat + 1
    im.handles[mat] = mh
  end
  -- (the page bound to this copy of the material every frame: unbound, a first pickup drew white squares, the copy
  -- pointing at a texture that isn't loaded; 2026-10-28)
  local sid = call('id', 'IdString64.from_hex', UI_SLOT)
  local _, err = call('settex', 'Material.set_texture', mh, sid, pid)
  if err then return false, 'set_texture: ' .. tostring(err) end
  local a0, a1 = call('v2', 'Vector2', e[2], e[3]), call('v2', 'Vector2', e[4], e[5])
  local p, sz = v3(x, y, layer), call('v2', 'Vector2', w, h)
  if not (a0 and a1 and p and sz) then return false, 'no vectors' end
  local _, err2 = call('bitmap_uv', 'Gui.bitmap_uv', im.gui, mid, a0, a1, p, sz, c)
  if err2 then return false, 'bitmap_uv: ' .. tostring(err2) end
  return true
end
-- width of a string at a cap height, in pixels
local function txt_width(str, cap)
  if CHEF_TEXT then return chef.text_width(str, cap / 7) end
  local g = game_font()
  if g then
    local size = cap * 100 / gf.cap100
    local key = str .. '@' .. size
    local w = gf.widths[key]
    if w == nil then
      local lo, hi = call('extents', 'Gui.text_extents', g, str, FONT.font, size)
      local a = numbers(lo)
      local b = numbers(hi)
      w = (a and b) and (b - a) or (#str * size * 0.6)
      gf.widths[key] = w
    end
    return w
  end
  local px = math.max(1, math.floor(cap / 7 + 0.5))
  return chef.text_width(string.upper(str), px)
end
-- a string with its capitals' bottom-left at x, y (bottom-left origin)
local function txt(x, y, str, cap, c, layer)
  if CHEF_TEXT then chef.text(x, y, str, cap / 7, c, layer) return end
  local g = game_font()
  if g then
    local size = cap * 100 / gf.cap100
    local pos = v3(x, y - gf.base100 * size / 100, layer)  -- the pen sits on the baseline
    if pos then
      local _, why = call('text', 'Gui.text', g, str, FONT.font, size, FONT.material, pos, c)
      if why == nil then return end
      gf_fail(why)
    end
  end
  chef.text(x, y, string.upper(str), math.max(1, math.floor(cap / 7 + 0.5)), c, layer)
end

------------------------------------------------------------------------------------------------ drawing (the Bar)
local CREAM = { 236, 229, 206 }
local WARN = { 240, 170, 90 }
local RED = { 210, 80, 72 }   -- (1.5.59: a notch less vibrant, luka)
local YELLOW = { 236, 214, 96 }
-- Colourblind: told apart by brightness as well as hue (the Okabe-Ito colours): white for normal, sky blue for the
-- first mark, yellow for low or hot, magenta for empty or overheated.
-- (MODE2, MODE3: the modes' own colours: a sky blue and a bluish green in both palettes, none of them a warning's
-- colour. 1.5.78: lifted for the UI layer — the old 86 180 233 and 0 175 130 were chosen under the world's tone
-- curve, which showed them near white; drawn as they are they read dark against the cream (luka))
local MODE2, MODE3 = { 130, 205, 245 }, { 80, 220, 175 }
local PALETTES = {
  { CREAM = { 236, 229, 206 }, YELLOW = { 236, 214, 96 }, WARN = { 240, 170, 90 }, RED = { 210, 80, 72 } },
  { CREAM = { 240, 240, 240 }, YELLOW = { 86, 180, 233 }, WARN = { 240, 228, 66 }, RED = { 230, 80, 200 } },
}
N.apply_palette = function()
  local p = PALETTES[cfg.palette] or PALETTES[1]
  for name, c in pairs({ CREAM = CREAM, YELLOW = YELLOW, WARN = WARN, RED = RED }) do
    for i = 1, 3 do c[i] = p[name][i] end
  end
end
N.apply_palette()
N.alpha_k = 1                                    -- the opacity option times the fade, this frame
N.L0 = 0                                         -- (1.5.63) the layers' base: chef.TOP in the game's UI layer, else 0
-- (1.5.61) The game's world puts a HUD's colours through its tone mapping before they reach the screen: a steep
-- curve where 136 already comes out white (Chef Shared Loader's loader measured it with swatches on Th3chef's
-- screen, HDR on: the TONE rows below, the outputs at inputs 0, 17, 34 ... 255, per channel), which is why our
-- cream read 255 255 255 in luka's screenshots and the red a pure red. "Look: colours corrected for the game's tone
-- mapping" sends each channel through the curve's inverse, so what's asked for is what shows. One screen's curve:
-- "Testing: colour swatches" draws the steps for a screenshot, to fit another's.
-- (1.5.62: luka's screen, from his swatch screenshot of 2026-10-30 — steeper still, white from 119: red 0 20 49 84
-- 132 193 254; green 0 17 41 72 111 162 228 255; blue 0 8 42 75 116 170 238 254. Chef's, for the record: red 0 7
-- 27 51 78 110 148 196 255, green 0 7 25 44 65 89 120 165 221 255, blue 0 5 20 41 64 91 124 165 220 255.)
-- (1.5.63) And then his cave: the cream sent as 98 104 96 came out 161 204 174 — the curve isn't one curve: the
-- game's exposure and its colour grading (a teal cave, a warm jungle) are applied to the world, and a HUD drawn in
-- the game's world goes through them with the scene. No table fixes that. What does: the game's UI world (Chef's top
-- world, its layers from chef.TOP; its menu lives there), drawn after the game's own HUD, the map and the grading,
-- with a near-straight curve (Chef: 17 -> 35, 255 -> 255) — "Look: drawn in the game's UI layer", on by default,
-- adds chef.TOP to every layer (N.L0, set each frame by 13_main), and col() then sends the colours as they are. The
-- cost: that layer is over the game's map and its screens, so the HUD shows over an open map (hidden while the
-- stratagem key is held, as before). The correction below stays for the game's world (the toggle off).
local TONE = { { 0, 20, 49, 84, 132, 193, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255 },
               { 0, 17, 41, 72, 111, 162, 228, 255, 255, 255, 255, 255, 255, 255, 255, 255 },
               { 0, 8, 42, 75, 116, 170, 238, 255, 255, 255, 255, 255, 255, 255, 255, 255 } }
N.TONE = TONE
local function tone(ch, v)                       -- the curve: the output at input v
  local ys = TONE[ch]
  if v <= 0 then return ys[1] end
  if v >= 255 then return ys[16] end
  local i = math.floor(v / 17)
  local f = v / 17 - i
  return ys[i + 1] + (ys[i + 2] - ys[i + 1]) * f
end
local function tone_inv(ch, want)                -- the input whose output is want, over the curve's rising part
  local ys = TONE[ch]
  if want <= 0 then return 0 end
  for i = 2, 16 do
    if ys[i] >= want then
      if ys[i] == ys[i - 1] then return (i - 1) * 17 end
      return (i - 2) * 17 + 17 * (want - ys[i - 1]) / (ys[i] - ys[i - 1])
    end
  end
  return 255
end
-- A see-through colour blends with the scene before the curve (Chef's note), so the inverse alone leaves the faint
-- parts too dark: for alpha af the colour is solved so that, over a typical dark ground (TONE_BACK as given), the
-- screen shows the blend a designer expects — (1 - af) ground + af colour, in what's seen.
local TONE_BACK = 25
local TONE_BACK_OUT = { tone(1, TONE_BACK), tone(2, TONE_BACK), tone(3, TONE_BACK) }
local function tone_fix(ch, v, af)
  if af >= 0.999 then return tone_inv(ch, v) end
  if af <= 0.001 then return v end
  local want = (1 - af) * TONE_BACK_OUT[ch] + af * v
  local x = (tone_inv(ch, want) - (1 - af) * TONE_BACK) / af
  return math.max(0, math.min(255, x))
end
local function col(c, a)
  local r, g, b = c[1], c[2], c[3]
  local alpha = math.floor((a or 235) * N.alpha_k + 0.5)
  if cfg.tone_fix and (N.L0 or 0) == 0 then
    local af = alpha / 255
    r, g, b = math.floor(tone_fix(1, r, af) + 0.5), math.floor(tone_fix(2, g, af) + 0.5), math.floor(tone_fix(3, b, af) + 0.5)
  end
  return chef.color(r, g, b, alpha)
end
N.tone = tone
N.tone_inv = tone_inv
-- (research) the swatches: four rows of sixteen steps (grey, red, green, blue: 0, 17 ... 255) at the screen's bottom
-- left, as given to the engine (no correction), for a screenshot that measures this screen's curve
local function draw_swatches(w, h)
  local s = math.floor(h / 36)
  local x0, y0 = math.floor(w * 0.02), math.floor(h * 0.2)
  for row = 0, 3 do
    for i = 0, 15 do
      local v = i * 17
      local r, g, b = v, v, v
      if row == 1 then g, b = 0, 0 elseif row == 2 then r, b = 0, 0 elseif row == 3 then r, g = 0, 0 end
      chef.rect(x0 + i * (s + 2), y0 + (3 - row) * (s + 2), s, s, chef.color(r, g, b, 255), N.L0 + 940)
    end
  end
  txt(x0, y0 + 4 * (s + 2) + 4, 'SWATCHES 0..255 BY 17: GREY, RED, GREEN, BLUE (BOTTOM UP)', math.floor(h / 80), chef.color(255, 255, 255, 255), N.L0 + 940)
end
N.draw_swatches = draw_swatches
-- (1.5.53) The bars' look, two settings apart: the edge (none, an outline, or square brackets at the ends as the
-- game draws its own health and stamina) and the shade (the empty part faint, or nothing there). F9's rows set
-- both for every bar; a layout file can set them per bar (edge / shade fields, 'auto' for F9's). Before 1.5.53 one
-- toggle chose a faint fill or an outline, never both.
local EDGE_NONE, EDGE_OUTLINE, EDGE_BRACKETS = 1, 2, 3
local function bar_style(edge, shade)
  if edge == nil then edge = cfg.edge or EDGE_NONE end
  if shade == nil then shade = cfg.shade ~= false end
  return edge, shade
end
N.bar_style, N.EDGE_NONE, N.EDGE_OUTLINE, N.EDGE_BRACKETS = bar_style, EDGE_NONE, EDGE_OUTLINE, EDGE_BRACKETS
-- an empty part (of the ammo bar, a magazine square, the backpack bar): a faint fill (the shade), its outline (the
-- edge), both, or nothing; lw thick; one too thin for a hole stays a faint fill
local function empty_rect(x, y, w, h, faint, L, lw, edge, shade)
  if w <= 0 or h <= 0 then return end
  lw = math.max(1, lw or 1)
  edge, shade = bar_style(edge, shade)
  if edge ~= EDGE_OUTLINE or w <= 2 * lw or h <= 2 * lw then
    if shade or edge == EDGE_OUTLINE then chef.rect(x, y, w, h, col(CREAM, faint), L) end
    return
  end
  local c = col(CREAM, 190)
  chef.rect(x, y, w, lw, c, L)
  chef.rect(x, y + h - lw, w, lw, c, L)
  chef.rect(x, y + lw, lw, h - 2 * lw, c, L)
  chef.rect(x + w - lw, y + lw, lw, h - 2 * lw, c, L)
  if shade then chef.rect(x + lw, y + lw, w - 2 * lw, h - 2 * lw, col(CREAM, faint), L) end
end
-- square brackets at a bar's two ends, just outside it: a stroke lw thick the bar's height plus a little, with short
-- feet pointing in along the bar's edges; a vertical bar gets them at its bottom and top
-- (1.5.57: as the game's, after luka's screenshots: the stroke 2 lw thick, a gap of lw to the bar, reaching 2 lw past
-- the bar's edges, the feet lw thick and half the bar's height long (at least 4 lw))
local function brackets(x, y, w, h, lw, vertical, L)
  lw = math.max(1, lw or 1)
  local c = col(CREAM, 210)
  local sw, ext = 2 * lw, 2 * lw
  if vertical then
    local s = math.max(4 * lw, math.min(math.floor(w * 0.5 + 0.5), 10 * lw))
    chef.rect(x - ext, y - lw - sw, w + 2 * ext, sw, c, L)         -- the bottom stroke
    chef.rect(x - ext, y - lw, lw, s, c, L)                         -- its feet, up along the sides
    chef.rect(x + w + ext - lw, y - lw, lw, s, c, L)
    chef.rect(x - ext, y + h + lw, w + 2 * ext, sw, c, L)          -- the top stroke
    chef.rect(x - ext, y + h + lw - s, lw, s, c, L)
    chef.rect(x + w + ext - lw, y + h + lw - s, lw, s, c, L)
  else
    local s = math.max(4 * lw, math.min(math.floor(h * 0.5 + 0.5), 10 * lw))
    chef.rect(x - lw - sw, y - ext, sw, h + 2 * ext, c, L)         -- the left stroke
    chef.rect(x - lw, y - ext, s, lw, c, L)                         -- its feet, in along the bottom and the top
    chef.rect(x - lw, y + h + ext - lw, s, lw, c, L)
    chef.rect(x + w + lw, y - ext, sw, h + 2 * ext, c, L)          -- the right stroke
    chef.rect(x + w + lw - s, y - ext, s, lw, c, L)
    chef.rect(x + w + lw - s, y + h + ext - lw, s, lw, c, L)
  end
end
N.brackets = brackets
-- a solid bar f full (0 to 1), its fill colour c: on its shade (or on nothing), inside an outline of the whole bar
-- that stays put (the fill within it: a bar cooling down from red only changes inside), or between brackets. One
-- too thin for a hole: as with no outline. Vertical: filling from the bottom up.
local function solid_bar(x, y, w, h, f, c, L, lw, vertical, edge, shade)
  f = math.max(0, math.min(1, f))
  lw = math.max(1, lw or 1)
  edge, shade = bar_style(edge, shade)
  if edge ~= EDGE_OUTLINE or w <= 2 * lw + 1 or h <= 2 * lw + 1 then
    if edge == EDGE_BRACKETS then brackets(x, y, w, h, lw, vertical, L) end
    if shade then chef.rect(x, y, w, h, col(CREAM, 45), L) end
    if vertical then chef.rect(x, y, w, math.floor(h * f + 0.5), c, L + 1)
    else chef.rect(x, y, math.floor(w * f + 0.5), h, c, L + 1) end
    return
  end
  empty_rect(x, y, w, h, 45, L, lw, edge, shade)
  local iw, ih = w - 2 * lw, h - 2 * lw
  if vertical then chef.rect(x + lw, y + lw, iw, math.floor(ih * f + 0.5), c, L + 1)
  else chef.rect(x + lw, y + lw, math.floor(iw * f + 0.5), ih, c, L + 1) end
end
local function txt_right(x, y, str, cap, c, layer) txt(x - txt_width(str, cap), y, str, cap, c, layer) end
-- The mode labels ("HEAT  APHET  AUTO  750 RPM"), with the option each mode in its own colour: the same mode always
-- the same, and a weapon's modes never sharing one (cream, blue, green). HEAT, UB and the rate of fire stay cream.
local MODE_TONE = { SEMI = 1, AUTO = 2, BURST = 3, VOLLEY = 3, SAFE = 1, UNSAFE = 2, TOTAL = 3,
  GUIDED = 1, UNGUIDED = 2, APHET = 1, FLAK = 2, CLUSTER = 3, HE = 2, DEPLOY = 1, DETONATE = 2, ARTILLERY = 2,
  LASER = 2, ['NO LASER'] = 1, FLECHETTE = 1, STUN = 2 }
local function txt_modes(x, y, str, cap, a, layer, right)
  if not cfg.mode_colors then
    if right then txt_right(x, y, str, cap, col(CREAM, a), layer) else txt(x, y, str, cap, col(CREAM, a), layer) end
    return
  end
  local parts = {}
  for w in string.gmatch(str .. '  ', '(.-)  ') do if w ~= '' then parts[#parts + 1] = w end end
  local sep = txt_width('  ', cap)
  if right then x = x - txt_width(str, cap) end
  for _, w in ipairs(parts) do
    local n = MODE_TONE[w] or (string.match(w, '^OPT (%d)$') and math.min(3, tonumber(string.match(w, '^OPT (%d)$')) + 1)) or 1
    txt(x, y, w, cap, col(n == 3 and MODE3 or (n == 2 and MODE2 or CREAM), a), layer)
    x = x + txt_width(w, cap) + sep
  end
end

-- little icons, drawn in squares ('#' body, '+' detail, 'o' outline under them)
N.GRENADE = {
  '.##.......',
  '#..#......',
  '.######...',
  '...####...',
  '...####.#.',
  '..+++++++.',
  '.########.',
  '##########',
  '##########',
  '##########',
  '.########.',
  '..######..',
}
N.STIM = {        -- a syringe: plunger, barrel with the stim in it, needle
  '#..#........',
  '#..#######..',
  '####+++++###',
  '#..#######..',
  '#..#........',
}

-- the same picture with an 'o' ring around it (one cell wider on every side), drawn darker under the body
local function outlined(rows)
  local h, w = #rows, #rows[1]
  local function at(r, c) return r >= 1 and r <= h and c >= 1 and c <= w and rows[r]:sub(c, c) ~= '.' end
  local out = {}
  for r = 0, h + 1 do
    local line = {}
    for c = 0, w + 1 do
      local ch = (r >= 1 and r <= h and c >= 1 and c <= w) and rows[r]:sub(c, c) or '.'
      if ch == '.' then
        for dr = -1, 1 do for dc = -1, 1 do if at(r + dr, c + dc) then ch = 'o' end end end
      end
      line[#line + 1] = ch
    end
    out[#out + 1] = table.concat(line)
  end
  return out
end
N.GRENADE, N.STIM = outlined(N.GRENADE), outlined(N.STIM)

-- a one-line message under the crosshair
local function notice(str)
  local w, h = chef.screen()
  if not w then return end
  local small = math.max(7, math.floor(16 * (h / 1440) * cfg.size + 0.5))
  local x = math.floor(w / 2 - txt_width(str, small) / 2)
  txt(x, math.floor(h / 2 - h * 0.12), str, small, col(WARN, 230), N.L0 + 905)
end

-- the grenades and stims line, the backpack's bar after it to xend; its top at top
-- heat marks' colours (HEAT_RANGE), and the count's: the colour of the last mark passed
local MARK_COLORS = { YELLOW, WARN, RED }
local function heat_tone(d, frac)
  local tone = CREAM
  for _, m in ipairs(d.heat_marks) do if frac >= m[1] then tone = MARK_COLORS[m[2]] end end
  return tone
end

-- What the backpack bar shows: the warp pack's heat (0 to 78: a warp adds 33 and one over 45 kills, so 78 is the most
-- it gets; the wiki's marks: over 15 hurts, over 45 kills), the jump or hover pack recharging (cream when ready), or
-- how full an ammo backpack is. { f = 0 to 1, c = colour, a = alpha, marks = { { at, colour } } }, or nil.
local function pack_state(items, d)
  if items.warp then
    local h = items.warp
    return { f = h / 78, c = h > 45 and RED or (h > 15 and WARN or CREAM), a = 215, marks = { { 15 / 78, WARN }, { 45 / 78, RED } } }
  elseif items.recharge then
    local f = items.recharge
    local ready = f >= 1 or items.draining
    return { f = f, c = ready and CREAM or WARN, a = ready and 215 or 180, marks = {} }
  elseif items.pack and items.pack_top and items.pack_top > 0 and not (d and d.fed) then
    local f = math.max(0, math.min(1, items.pack / items.pack_top))
    -- (1.5.45) a pack counted in uses (the supply pack's 4, a launcher's rounds, the C4 pack's charges: a whole
    -- number up to 16) is drawn in as many segments, a thin dark line between; a pack with a charge (the jump
    -- pack's 1000, a shield's) stays one bar
    local top = items.pack_top
    local segs = (top <= 16 and top == math.floor(top)) and top or nil
    return { f = f, c = items.pack == 0 and RED or (f <= 0.25 and WARN or CREAM), a = 215, marks = {}, segs = segs, n = math.floor(items.pack + 0.5) }
  end
  return nil
end
-- a pack counted in uses, drawn as the ammo bar draws a magazine: a tick a use, the used ones faint, the gaps as the
-- ammo ticks' (at most 4 px at 1440p). A straight bar from x, y, w by h, lengthwise along w (vert false) or h.
-- Returns true when drawn (the caller draws a solid bar otherwise)
local function pack_ticks(st, x, y, w, h, vert, L, k, edge, shade)
  if not st.segs or st.segs < 2 then return false end
  edge, shade = bar_style(edge, shade)
  local n, lit = st.segs, st.n or 0
  local len = vert and h or w
  local gap = math.max(1, math.min(len / n * 0.45, 4 * k))
  if len < n * 3 then return false end
  local step = (len + gap) / n
  local lw = math.max(1, math.floor(k * 0.8 + 0.5))
  for i = 0, n - 1 do
    local a, b = math.floor(i * step + 0.5), math.floor(i * step + step - gap + 0.5)
    local sz = math.max(1, b - a)
    local on = i < lit   -- (a vertical bar fills from the bottom, as the ammo ticks: 1.5.59, it emptied bottom-up before)
    if vert then
      if on then chef.rect(x, y + a, w, sz, col(st.c, st.a), L) else empty_rect(x, y + a, w, sz, 55, L, lw, edge, shade) end
    else
      if on then chef.rect(x + a, y, sz, h, col(st.c, st.a), L) else empty_rect(x + a, y, sz, h, 55, L, lw, edge, shade) end
    end
  end
  if edge == EDGE_BRACKETS then brackets(x, y, w, h, lw, vert, L) end
  return true
end
N.pack_ticks = pack_ticks

-- the icon textures (TEXTURES, tools/make_textures.py): each a ladder of sizes told to Chef once; the largest is the
-- name drawn by, Chef picks the copy nearest the size drawn
local tex_tops, tex_said, tex_n, mode_icon_said = {}, {}, nil, nil
local function tex_top(name)
  local l = TEXTURES[name]
  if not l then return nil end
  local top = tex_tops[name]
  if top == nil then
    top = l[#l][3]
    if chef.texture_sizes then
      local ladder = {}
      for _, e in ipairs(l) do ladder[#ladder + 1] = e[1] ladder[#ladder + 1] = e[3] end
      chef.texture_sizes({ [top] = ladder })
    end
    tex_tops[name] = top
  end
  return top
end
-- (1.5.18) the stim or grenade icon as a texture: luka189's stim, dogo314's grenade (art/icons,
-- tools/make_textures.py), in the game's own icon layout (BC3, every mip level), drawn through chef.bitmap_uv with
-- the whole texture: the one call that doesn't strobe next to other mods' bitmaps (docs/chef_bitmap_issue.md).
-- A square of S (the line's height) at x, its bottom at iy, the icon centred in it and the square pushed left so the
-- icon starts at x. Returns whether it was drawn and the icon's own width (the line advances by it); the caller
-- draws the pixel sprite when not (Chef says why in its log). The research row's ways: 2 the size ladder through
-- chef.bitmap, 3 the same at a top layer (Chef's top world, over the game's HUD), 4 one size (the 128) with no
-- ladder, 5 and 6 the game layout through chef.bitmap in the main world and at the top layer, 7 the game layout
-- through the uv call (shipped), 8 the ladder through the uv call, its size picked by hand.
local function icon_texture(name, x, iy, S, c, p, L)
  local mode = cfg.icon_tex or (N.CHEF14 and 5 or 7)
  if mode >= 9 then mode = 7 end
  local game, ladder = TEXTURES[name .. '_game'], TEXTURES[name]
  if mode <= 1 or not (game and ladder and chef.bitmap) then return false, nil end
  local g = game[1]
  local iw = math.max(1, math.floor(S * g[4] / g[1] + 0.5))
  local sx = x - math.floor((S - iw) / 2)
  local tex = (mode == 4 and ladder[2][3]) or ((mode >= 5 and mode <= 7) and g[3]) or tex_top(name)
  local layer = ((mode == 3 or mode == 6) and N.L0 == 0) and (chef.TOP or 2000) + L - 900 or L
  local drawn
  if mode == 7 or mode == 8 then
    if mode == 8 then
      tex = ladder[#ladder][3]
      for _, e in ipairs(ladder) do if e[1] >= S then tex = e[3] break end end
    end
    drawn = tex and chef.bitmap_uv and chef.bitmap_uv(tex, 0, 0, 1, 1, sx, iy, S, S, col(c, 220 * p), layer) == true
  else
    drawn = tex and chef.bitmap(tex, sx, iy, S, S, col(c, 220 * p), layer) == true
  end
  local said = drawn and ('drawn, way ' .. mode) or 'not drawn'
  if tex_said[name] ~= said then
    tex_said[name] = said
    local rr = chef.setting and chef.setting('render_settings.render_resolution')
    local sw, sh = chef.screen()
    log('icons: the %s texture %s; screen %sx%s, render resolution %s', name, drawn and said or 'not drawn (Chef says why above): the pixel sprite instead',
      tostring(sw), tostring(sh), type(rr) == 'table' and (tostring(rr[1]) .. 'x' .. tostring(rr[2])) or tostring(rr))
  end
  -- (research: how many frames Chef drew it and how many it refused, every 10 s, to catch it coming and going)
  if cfg.research and name == 'stim' then
    tex_n = tex_n or { at = chef.time(), yes = 0, no = 0 }
    if drawn then tex_n.yes = tex_n.yes + 1 else tex_n.no = tex_n.no + 1 end
    if chef.time() - tex_n.at >= 10 then
      if tex_n.no > 0 then log('research: the stim texture: drawn %d frames, refused %d, in 10 s', tex_n.yes, tex_n.no) end
      tex_n.at, tex_n.yes, tex_n.no = chef.time(), 0, 0
    end
  end
  return drawn, iw
end
-- one of the game's own mode icons (N.ATLAS: an atlas sprite), a square of tw at x, y (bottom-left), in the HUD's
-- colour: way 2 through Chef's plain UI material (the mask's black comes out black), 3 through the sprite's own icon
-- material (the game's mask shader, the vertex colour its tint) on a GUI of ours (shipped), 4 the same in blue
-- the colour of a mode's word, as txt_modes gives the text (cream, or the mode's tone with Modes in their own colours)
local function mode_rgb(word)
  if not cfg.mode_colors or not word then return CREAM end
  local n = MODE_TONE[word] or (string.match(word, '^OPT (%d)$') and math.min(3, tonumber(string.match(word, '^OPT (%d)$')) + 1)) or 1
  return n == 3 and MODE3 or (n == 2 and MODE2 or CREAM)
end
local TEST_BLUE = { 60, 110, 255 }
-- e: the sprite; word: the mode it stands for (its colour follows the text's)
local function mode_icon(e, x, y, tw, L, word)
  local way = cfg.mode_icons
  local c = mode_rgb(word)
  if way == 2 then
    local ok = chef.bitmap_uv and chef.bitmap_uv(e[1], e[2], e[3], e[4], e[5], x, y, tw, tw, col(c, 220), L) == true
    return ok, ok and nil or 'Chef says why above'
  end
  -- (way 4: a blue vertex colour, the proof the tint takes (2026-10-28: it does); 3 as shipped)
  return own_sprite(e, x, y, tw, tw, col(way == 4 and TEST_BLUE or c, 220), L)
end
local function mode_icons_said(way, keys)
  local key = way .. ': ' .. table.concat(keys, ' ')
  if mode_icon_said ~= key then mode_icon_said = key log('icons: the game\'s mode sprites, way %s (+ drawn, - not)', key) end
end
N.icon_texture, N.mode_icon, N.mode_icons_said = icon_texture, mode_icon, mode_icons_said

-- (1.5.70, luka: Small shrank the icons too, too small to read: an icon's scale never goes below Medium's)
local function icon_scale(k) local s = cfg.size or 1 return s < 1 and k / s or k end
-- (1.5.77) the icons' sizes scale smoothly: a texture's square is 56 px at Medium (2 cells of the pixel sprite's 2
-- px, twice the stim's 14 cells) times the scale — not cells rounded to whole pixels, which stayed at 2 from
-- Medium to Huge while the gaps between the icons grew (luka: the spacing shrank with Size). The pixel sprites,
-- the fallback, keep whole cells.
local function icon_px(k) return math.max(1, math.floor(4 * #N.STIM[1] * icon_scale(k) + 0.5)) end
local function stim_px(k) return math.max(1, math.floor(2 * #N.GRENADE * icon_scale(k) + 0.5)) end
N.icon_scale, N.icon_px, N.stim_px = icon_scale, icon_px, stim_px
-- a magazine of up to this many rounds is drawn a tick a round, more as a solid bar: 25 (Small) to 50 (Huge)
local function seg_max() return math.floor(25 + (cfg.size - 0.8) / 0.7 * 25 + 0.5) end


N.txt_width, N.txt, N.CREAM, N.WARN, N.RED, N.col = txt_width, txt, CREAM, WARN, RED, col
N.empty_rect, N.solid_bar, N.txt_modes, N.notice, N.MARK_COLORS, N.heat_tone = empty_rect, solid_bar, txt_modes, notice, MARK_COLORS, heat_tone
N.pack_state, N.seg_max = pack_state, seg_max
