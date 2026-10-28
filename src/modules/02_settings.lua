-- NarrowHUD, settings: the F9 menu: every option and its on_change; the special packs and the research types.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES = N.TYPES

------------------------------------------------------------------------------------------------ settings, learned
local cfg = { size = 1, side_size = 1.25, off_x = 0, off_y = 0, right = false, corner = false, mags_number = false,
              show_bar = true, show_count = true, show_mags = true, show_heat = true, show_charge = true,
              show_stims = true, show_grenades = true, pack = true, font = true, custom = false,
              research = false, any_build = false, opacity = 1, idle = 1, idle_secs = 4, show_rpm = true, show_fmode = true,
              show_mode = true, palette = 1, fire = 1, wheel = 1, health = 2, stamina = 2, stim_timer = false, stim_secs = 1, warn = false,
              reload_line = false, hide_strat = true, hide_emote = true, map_pin = true, death_mark = true, drop_line = 2, drop_len = 150, drop_thick = 2, throw_line = true, icon_tex = 7, builtin = nil }
N.apply_palette = nil                                  -- (set with the colours, below)
local MOUSE_BUTTONS = { 'left', 'right', 'middle', 'extra_1', 'extra_2' }
if chef.has and chef.has('menu') then
  chef.title('NarrowHUD')
  -- The rows in topic blocks, each row's label starting with its block's name (Chef's menu has no headings for a
  -- mod's rows; the prefix groups them to the eye and for the menu's / search): the layout, what's shown, the bars,
  -- the look, the world (markers and lines); then, from 03_learned, the keys and the testing rows. The new features
  -- are on by default: most players update through a mod manager and never open F9, so one that ships off is never
  -- seen; one that's on is turned off by those who don't want it.
  -- (beside the crosshair, each size is a step bigger: players found it small even at Huge. Its Small is Under's
  -- Medium, and Huge is new)
  local SIZES = { 0.8, 1.0, 1.25, 1.5 }
  local SIDE_SIZES = { 1.0, 1.25, 1.5, 1.9 }
  local function size_of(i) cfg.side_size = SIDE_SIZES[i] or 1.25 return SIZES[i] or 1 end
  cfg.size = size_of(chef.option('size', { type = 'choice', label = 'Size', choices = { 'Small', 'Medium', 'Large', 'Huge' }, default = 2 }))
  chef.on_change('size', function(v) cfg.size = size_of(v) end)
  -- Four places, each with its own spot at offset 0 / 0: just under the crosshair, just right of it (compact), by the
  -- game's weapon panel (bottom left), or the curved pair around the crosshair (a built-in layout, 1.5.13; after
  -- Custom in the list so that the saved choices keep their meaning); and the layout file. One X / Y offset moves any
  -- of them anywhere on the screen.
  -- (1.5.24) the Positions people have set up stay as they are (1 to 5); 6 to 9 are the Preview layouts (built in,
  -- 10_custom), kept apart until the offsets and the pinning of parts are redone for presets
  local BUILTIN = { [5] = 'curved', [6] = 'preview1', [7] = 'preview2', [8] = 'preview3', [9] = 'preview4' }
  local function position(v) cfg.right, cfg.corner, cfg.custom, cfg.builtin = v == 2 or v == 3, v == 3, v == 4 or BUILTIN[v] ~= nil, BUILTIN[v] end
  position(chef.option('position', { type = 'choice', label = 'Position', choices = { 'Under the crosshair', 'Beside the crosshair (compact)', 'Screen corner, by the game\'s weapon panel', 'Custom (the layout file, from the layout editor)', 'Curved pair around the crosshair', 'Preview 1 (horizontal stack)', 'Preview 2 (compact block)', 'Preview 3 (curved pair)', 'Preview 4 (vertical pair)' }, default = 1 }))
  chef.on_change('position', position)
  cfg.off_x = chef.option('off_x', { type = 'slider', label = 'Offset left (-) or right (+), % of the screen', min = -50, max = 50, step = 0.5, default = 0 }) or 0
  chef.on_change('off_x', function(v) cfg.off_x = v or 0 end)
  cfg.off_y = chef.option('off_y', { type = 'slider', label = 'Offset down (-) or up (+), % of the screen', min = -50, max = 50, step = 0.5, default = 0 }) or 0
  chef.on_change('off_y', function(v) cfg.off_y = v or 0 end)
  cfg.opacity = (chef.option('opacity', { type = 'slider', label = 'Opacity, %', min = 20, max = 100, step = 5, default = 100 }) or 100) / 100
  chef.on_change('opacity', function(v) cfg.opacity = (v or 100) / 100 end)
  -- what's shown, in the order it's on the screen; all off: nothing
  local function toggle(id, label, default)
    if default == nil then default = true end
    -- (a row that's on by default reads as on when the menu can't say; one off by default as off)
    local function as(v) if default then return v ~= false else return v == true end end
    cfg[id] = as(chef.option(id, { type = 'toggle', label = label, default = default }))
    chef.on_change(id, function(v) cfg[id] = as(v) end)
  end
  toggle('show_bar', 'Show: ammo / heat bar (with its heat marks)')
  toggle('show_count', 'Show: count (rounds, or heat %)')
  toggle('show_mags', 'Show: spare magazines')
  toggle('show_heat', 'Show: HEAT label')
  toggle('show_mode', 'Show: weapon modes (UNGUIDED, APHET, UB ...)')
  toggle('show_fmode', 'Show: fire mode (AUTO, SEMI ...)')
  -- (1.5.18) the game's own icons for the modes, drawn from its atlas through its icon material (docs/ICONS.md):
  -- cfg.mode_icons is the way: 1 off, 3 the icon's own material in the HUD's colour (shipped); the research row sets 2 and 4
  cfg.mode_icons = chef.option('mode_icon', { type = 'toggle', label = 'Show: the game\'s icons for the modes (beside the stim)', default = true }) ~= false and 3 or 1
  chef.on_change('mode_icon', function(v) cfg.mode_icons = v ~= false and 3 or 1 end)
  toggle('show_rpm', 'Show: rate of fire')
  toggle('show_charge', 'Show: charge and lock-on meter (Railgun, Epoch, Spear ...)')
  toggle('show_stims', 'Show: stims')
  toggle('show_grenades', 'Show: grenades')
  toggle('pack', 'Show: backpack bar (and the warp and jump packs)')
  -- (1.1.0) your health and stamina: off, always, or only while not full (then gone 2 s after it's full again);
  -- on since 1.5.13
  cfg.health = chef.option('health', { type = 'choice', label = 'Bars: health', choices = { 'Off', 'Always', 'When hurt' }, default = 2 }) or 1
  chef.on_change('health', function(v) cfg.health = v or 1 end)
  cfg.stamina = chef.option('stamina', { type = 'choice', label = 'Bars: stamina', choices = { 'Off', 'Always', 'While not full' }, default = 2 }) or 1
  chef.on_change('stamina', function(v) cfg.stamina = v or 1 end)
  -- (1.2.0) a line shrinking over a stim's effect (4 s; 6 s with the Med-Kit or Adreno-Defibrillator armour, which
  -- Auto learns per armour set the first time it can tell)
  toggle('stim_timer', 'Bars: stim timer (a line while a stim works)', false)
  cfg.stim_secs = chef.option('stim_secs', { type = 'choice', label = '   Stim duration', choices = { 'Auto (6 s with Med-Kit or Adreno-Defibrillator armour, else 4 s)', '4 s', '6 s' }, default = 1 }) or 1
  chef.on_change('stim_secs', function(v) cfg.stim_secs = v or 1 end)
  toggle('warn', 'Bars: warnings pulse (health under 25 %; no stims while hurt)', false)
  toggle('reload_line', 'Bars: reload progress line (from a weapon\'s second reload on)', false)
  -- when nothing has changed for a while (the count, heat, magazines, modes, the weapon, the items ...) and you
  -- haven't pressed fire: shown, dimmed to a quarter, or hidden; back at once on the next change
  cfg.idle = chef.option('idle', { type = 'choice', label = 'Bars: when nothing changes for a while', choices = { 'Shown', 'Dimmed', 'Hidden' }, default = 1 }) or 1
  chef.on_change('idle', function(v) cfg.idle = v or 1 end)
  cfg.idle_secs = chef.option('idle_secs', { type = 'slider', label = '   After how many seconds', min = 2, max = 15, step = 1, default = 4 }) or 4
  chef.on_change('idle_secs', function(v) cfg.idle_secs = v or 4 end)
  -- the look
  cfg.mags_number = chef.option('mags', { type = 'choice', label = 'Look: spare magazines beside the crosshair and in the corner as', choices = { 'Squares', 'A number' }, default = 1 }) == 2
  chef.on_change('mags', function(v) cfg.mags_number = v == 2 end)
  -- the empty ones (up to the most this weapon has carried): drawn or not
  cfg.mags_hide = chef.option('mags_empty', { type = 'choice', label = 'Look: empty magazine squares', choices = { 'Shown', 'Hidden' }, default = 1 }) == 2
  chef.on_change('mags_empty', function(v) cfg.mags_hide = v == 2 end)
  -- what's empty (the ammo bar's, the backpack bar's, the magazine squares): faint, or an outline
  toggle('outline', 'Look: empty parts as outlines (ammo bar, magazines, backpack)', false)
  toggle('mode_colors', 'Look: fire and weapon modes in their own colours', false)
  cfg.palette = chef.option('palette', { type = 'choice', label = 'Look: colours', choices = { 'Standard', 'Colourblind (blue / yellow / magenta)' }, default = 1 }) or 1
  chef.on_change('palette', function(v) cfg.palette = v or 1 if N.apply_palette then N.apply_palette() end end)
  -- (from Chef 1.1 on, every mod's text is Chef's, in the game's font; its own "Game font" row, under Chef Shared
  -- Loader, switches all of them to the pixel font. Ours is only for Chef 1.0.x)
  if chef.text_fit == nil then
    cfg.font = chef.option('font', { type = 'toggle', label = 'Look: game font (off: pixel font)', default = true }) ~= false
    chef.on_change('font', function(v) cfg.font = v ~= false end)
  end
  -- (1.3.0) markers in the world: your map pin and the spot of your last death, with their distance; an arrow at
  -- the screen's edge when out of view
  toggle('map_pin', 'World: your map pin, with its distance (an arrow at the edge when off screen)')
  toggle('death_mark', 'World: where you last died (a red diamond, for 3 minutes)')
  -- (1.4.0) the drop line: the shot's flight from the crosshair, for weapons whose shot drops
  cfg.drop_line = chef.option('drop_line', { type = 'choice', label = 'World: drop line (where the shot goes: grenade launchers, rockets, plasma ...)', choices = { 'Off', 'While aiming down the sights', 'Whenever the weapon is in hand' }, default = 2 }) or 1
  chef.on_change('drop_line', function(v) cfg.drop_line = v or 1 end)
  cfg.drop_len = chef.option('drop_len', { type = 'slider', label = '   Drop line length, m', min = 50, max = 300, step = 25, default = 150 }) or 150
  chef.on_change('drop_len', function(v) cfg.drop_len = v or 150 end)
  -- (1.5.0) throw lines: a stratagem ball, a grenade or C4 aimed
  toggle('throw_line', 'World: throw line (where a stratagem ball, grenade or C4 goes while you aim it)')
  cfg.drop_thick = chef.option('drop_thick', { type = 'choice', label = '   Line thickness (drop and throw lines)', choices = { 'Thin', 'Medium', 'Thick' }, default = 2 }) or 2
  chef.on_change('drop_thick', function(v) cfg.drop_thick = v or 2 end)
  -- the rows that go with the keys (03_learned registers the keys; these follow the stratagem key) and the testing
  -- rows at the very end
  function N.settings_hide()
    -- (the game's stratagem input and an emote: the HUD out of the way; health and stamina stay for the stratagems)
    toggle('hide_strat', 'Keys: hide the HUD while the stratagem key is held')
    toggle('hide_emote', 'Keys: hide the HUD while emoting')
  end
  function N.settings_testing()
    toggle('research', 'Testing: research log (for bug reports; from the next start)', false)
    toggle('any_build', 'Testing: run on a game version it wasn\'t made for (may crash the game)', false)
    -- (1.5.16) the icon texture test rows, only with the research log on (docs/ICONS.md: the strobe on one map)
    if cfg.research then
      cfg.icon_tex = chef.option('icon_tex', { type = 'choice', label = 'Testing: stim icon way', choices = { '1 Pixel', '2 Ladder', '3 Ladder top', '4 One size', '5 Game bmp', '6 Game top', '7 Game uv', '8 Ladder uv', '9 Atlas stim', '10 Atlas stims', '11 Atlas gren' }, default = 7 }) or 7
      chef.on_change('icon_tex', function(v) cfg.icon_tex = v or 7 end)
      local way = chef.option('mode_icons', { type = 'choice', label = 'Testing: how the mode icons are drawn', choices = { '1 As Show', '2 Chef plain', '3 Own cream', '4 Own blue' }, default = 1 })
      if way and way > 1 then cfg.mode_icons = way end
      chef.on_change('mode_icons', function(v) if v and v > 1 then cfg.mode_icons = v else cfg.mode_icons = cfg.mode_icons == 1 and 1 or 3 end end)
    end
  end
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
