-- NarrowHUD, settings: the F9 menu: every option and its on_change; the special packs and the research types.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES = N.TYPES

------------------------------------------------------------------------------------------------ settings, learned
local cfg = { size = 1, side_size = 1.25, off_x = 0, off_y = 0, right = false, corner = false, mags_number = false,
              show_bar = true, show_count = true, show_mags = true, show_heat = true, show_charge = true,
              show_stims = true, show_grenades = true, pack = true, font = true, custom = false,
              research = false, any_build = false, opacity = 1, idle = 1, idle_secs = 4, show_rpm = true, show_fmode = true,
              show_mode = true, palette = 1, fire = 1, wheel = 1 }
N.apply_palette = nil                                  -- (set with the colours, below)
local MOUSE_BUTTONS = { 'left', 'right', 'middle', 'extra_1', 'extra_2' }
if chef.has and chef.has('menu') then
  chef.title('NarrowHUD')
  -- (beside the crosshair, each size is a step bigger: players found it small even at Huge. Its Small is Under's
  -- Medium, and Huge is new)
  local SIZES = { 0.8, 1.0, 1.25, 1.5 }
  local SIDE_SIZES = { 1.0, 1.25, 1.5, 1.9 }
  local function size_of(i) cfg.side_size = SIDE_SIZES[i] or 1.25 return SIZES[i] or 1 end
  cfg.size = size_of(chef.option('size', { type = 'choice', label = 'Size', choices = { 'Small', 'Medium', 'Large', 'Huge' }, default = 2 }))
  chef.on_change('size', function(v) cfg.size = size_of(v) end)
  -- three places, each with its own spot at offset 0 / 0: just under the crosshair, just right of it (compact), or
  -- by the game's weapon panel (bottom left). One X / Y offset moves any of them anywhere on the screen.
  local function position(v) cfg.right, cfg.corner, cfg.custom = v == 2 or v == 3, v == 3, v == 4 end
  position(chef.option('position', { type = 'choice', label = 'Position', choices = { 'Under the crosshair', 'Beside the crosshair (compact)', 'Screen corner, by the game\'s weapon panel (best with the bar and items off)', 'Custom (the layout file, from the layout editor)' }, default = 1 }))
  chef.on_change('position', position)
  cfg.off_x = chef.option('off_x', { type = 'slider', label = 'Offset left (-) or right (+) (% of the screen)', min = -50, max = 50, step = 0.5, default = 0 }) or 0
  chef.on_change('off_x', function(v) cfg.off_x = v or 0 end)
  cfg.off_y = chef.option('off_y', { type = 'slider', label = 'Offset down (-) or up (+) (% of the screen)', min = -50, max = 50, step = 0.5, default = 0 }) or 0
  chef.on_change('off_y', function(v) cfg.off_y = v or 0 end)
  -- what's shown, in the order it's on the screen; all off: nothing
  local function toggle(id, label)
    cfg[id] = chef.option(id, { type = 'toggle', label = label, default = true }) ~= false
    chef.on_change(id, function(v) cfg[id] = v ~= false end)
  end
  toggle('show_bar', 'Show the ammo / heat bar (with its heat marks)')
  toggle('show_count', 'Show the count (rounds, or heat %)')
  toggle('show_mags', 'Show the spare magazines')
  toggle('show_heat', 'Show the HEAT label')
  toggle('show_mode', 'Show weapon modes (UNGUIDED, APHET ..., UB)')
  toggle('show_fmode', 'Show the fire mode (AUTO, SEMI ...)')
  toggle('show_rpm', 'Show the rate of fire')
  toggle('show_charge', 'Show the charge and lock-on meter (Railgun, Epoch, Spear ...)')
  toggle('show_stims', 'Show stims')
  toggle('show_grenades', 'Show grenades')
  toggle('pack', 'Show the backpack bar (and the warp and jump packs)')
  -- the look
  cfg.mags_number = chef.option('mags', { type = 'choice', label = 'Beside and corner: spare magazines as', choices = { 'Squares', 'A number' }, default = 1 }) == 2
  chef.on_change('mags', function(v) cfg.mags_number = v == 2 end)
  -- the empty ones (up to the most this weapon has carried): drawn or not
  cfg.mags_hide = chef.option('mags_empty', { type = 'choice', label = 'Beside and corner: empty magazine squares', choices = { 'Shown', 'Hidden' }, default = 1 }) == 2
  chef.on_change('mags_empty', function(v) cfg.mags_hide = v == 2 end)
  -- what's empty (the ammo bar's, the backpack bar's, the magazine squares): faint, or an outline
  cfg.outline = chef.option('outline', { type = 'toggle', label = 'Empty parts as outlines (ammo bar, magazines, backpack)', default = false }) == true
  chef.on_change('outline', function(v) cfg.outline = v == true end)
  cfg.opacity = (chef.option('opacity', { type = 'slider', label = 'Opacity (%)', min = 20, max = 100, step = 5, default = 100 }) or 100) / 100
  chef.on_change('opacity', function(v) cfg.opacity = (v or 100) / 100 end)
  -- when nothing has changed for a while (the count, heat, magazines, modes, the weapon, the items ...) and you
  -- haven't pressed fire: shown, dimmed to a quarter, or hidden; back at once on the next change
  cfg.idle = chef.option('idle', { type = 'choice', label = 'When nothing changes for a while', choices = { 'Shown', 'Dimmed', 'Hidden' }, default = 1 }) or 1
  chef.on_change('idle', function(v) cfg.idle = v or 1 end)
  cfg.idle_secs = chef.option('idle_secs', { type = 'slider', label = '   After how many seconds', min = 2, max = 15, step = 1, default = 4 }) or 4
  chef.on_change('idle_secs', function(v) cfg.idle_secs = v or 4 end)
  cfg.mode_colors = chef.option('mode_colors', { type = 'toggle', label = 'Fire and weapon modes in their own colours', default = false }) == true
  chef.on_change('mode_colors', function(v) cfg.mode_colors = v == true end)
  cfg.palette = chef.option('palette', { type = 'choice', label = 'Colours', choices = { 'Standard', 'Colourblind (blue / yellow / magenta)' }, default = 1 }) or 1
  chef.on_change('palette', function(v) cfg.palette = v or 1 if N.apply_palette then N.apply_palette() end end)
  -- (from Chef 1.1 on, every mod's text is Chef's, in the game's font; its own "Game font" row, under Chef Shared
  -- Loader, switches all of them to the pixel font. Ours is only for Chef 1.0.x)
  if chef.text_fit == nil then
    cfg.font = chef.option('font', { type = 'toggle', label = 'Game font (off: pixel font)', default = true }) ~= false
    chef.on_change('font', function(v) cfg.font = v ~= false end)
  end
  cfg.research = chef.option('research', { type = 'toggle', label = 'Research log (for bug reports; from the next start)', default = false }) == true
  chef.on_change('research', function(v) cfg.research = v == true end)
  cfg.any_build = chef.option('any_build', { type = 'toggle', label = 'Run on a game version it wasn\'t made for (may crash the game)', default = false }) == true
  chef.on_change('any_build', function(v) cfg.any_build = v == true end)
end
-- Packs that aren't ammo backpacks but have something to show (seen in the research log, 2026-10-24): the warp pack's
-- heat (33 a warp, cooling a few points a second), the jump pack's jump (a flag for half a second: 15 s to recharge,
-- timed by the player) and the hover pack's flight (a flag while hovering: 8 s to recharge after landing). Always known.
local SPECIAL = {
  c89adf0c = { kind = 'warp', field = '35ff0b52' },
  ['3a9a3ab0'] = { kind = 'timer', field = 'faaa8598', on_rise = true, secs = 13.2 },  -- jump pack (15 s from the
  -- jump press; the flag comes 1.8 s after it, timed by the player)
  -- (the hover pack's recharge depends on the keys held while landing: not shown)
}
local KNOWN_FIELDS = {}                              -- (left out of the research log)
for id, sp in pairs(SPECIAL) do
  local name = string.match(DATA.others or '', id .. ' (%S+)')
  sp.fname = string.match(DATA.fieldnames or '', sp.field .. ' (%S+)')
  KNOWN_FIELDS[sp.field] = true
  if name and sp.fname then
    TYPES[#TYPES + 1] = { id = id, name = name, has = { carry = true }, other = true, special = sp }
  end
end
-- with the research log on (from the start of a session), every other carried thing too (jump, hover and warp packs
-- ...): known by type, its fields watched, never shown
if cfg.research then
  local n0 = #TYPES
  for line in string.gmatch(DATA.others or '', '[^\n]+') do
    local id, name = string.match(line, '^(%x+) (%S+)$')
    if id and not SPECIAL[id] then TYPES[#TYPES + 1] = { id = id, name = name, has = { carry = true }, other = true } end
  end
  log('research log on: %d other carried types', #TYPES - n0)
end

-- by type id: hand pose, most ammo seen, overheat point, the heat it cools down to, seconds a charge takes

N.cfg, N.MOUSE_BUTTONS, N.KNOWN_FIELDS = cfg, MOUSE_BUTTONS, KNOWN_FIELDS
