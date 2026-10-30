-- NarrowHUD, settings: the F9 menu: every option and its on_change; the special packs and the research types.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES = N.TYPES

------------------------------------------------------------------------------------------------ settings, learned
local cfg = { size = 1, off_x = 0, off_y = 0, custom = true, builtin = 'horizontal',
              show_bar = true, show_count = true, show_mags = true, show_heat = true, show_charge = true,
              show_stims = true, show_grenades = true, pack = true, font = true,
              research = false, any_build = false, opacity = 1, idle = 1, idle_secs = 4, show_rpm = true, show_fmode = true,
              show_mode = true, palette = 1, fire = 1, wheel = 1, health = 2, stamina = 2, stim_timer = false, stim_secs = 1, warn = false,
              reload_line = false, hide_strat = true, hide_emote = true, map_pin = true, death_mark = true, drop_line = 2, drop_len = 150, drop_thick = 2, throw_line = true, reticle = true, icon_tex = N.CHEF14 and 5 or 7, builtin = nil }
N.apply_palette = nil                                  -- (set with the colours, below)
local MOUSE_BUTTONS = { 'left', 'right', 'middle', 'extra_1', 'extra_2' }
if chef.has and chef.has('menu') then
  chef.title('NarrowHUD')
  -- (1.5.82) The menu with Chef 1.4's headings, hints and folds (docs/MODDING.md in Th3chef's repo: any row's spec
  -- can carry `heading` (with `sub`), `hint`; an entry with more than 20 rows opens with every heading folded,
  -- the rows before the first heading always showing; `fold = false` keeps a heading open). The groups, in the
  -- order a player looks: Layout (which and how big: the always-open one), Show (each part's rule), Look, Extras
  -- (the stim timer, warnings, the reload line, idling), Motion, World (markers and lines), Keys (03_learned),
  -- Testing. Each row's hint is the sentence its label used to carry (1.5.64 cut the labels to Chef's compact
  -- panel: 40 characters a row, the value up to 16 of them). On a Chef before 1.4.0 (no headings) the labels get
  -- their group's word in front, as 1.5.64 had them. A row that belongs to the one above it is indented ("   ...").
  -- Row ids and choice lists keep their count and order (Chef saves a choice as its number).
  -- The new features are on by default: most players update through a mod manager and never open F9, so one that
  -- ships off is never seen; one that's on is turned off by those who don't want it.
  local HEAD = chef.has('option_headings') == true
  local grp = { name = nil, prefix = '', pending = false, open = false }
  -- group(name, prefix, keep_open): the rows from here on are under this heading (the first carries it)
  local function group(name, prefix, keep_open) grp.name, grp.prefix, grp.pending, grp.open = name, prefix or '', true, keep_open == true end
  local function spec_of(label, hint, t)
    t.label = HEAD and label or (grp.prefix .. label)
    if HEAD then
      if hint then t.hint = hint end
      if grp.pending then t.heading = grp.name if grp.open then t.fold = false end grp.pending = false end
    end
    return t
  end
  N.menu_spec = spec_of   -- (03_learned's rows)
  N.menu_label = function(label) return HEAD and label or (grp.prefix .. label) end   -- (a key row's label: chef.bind takes no spec)
  local function choice(id, label, choices, default, set, hint)
    local v = chef.option(id, spec_of(label, hint, { type = 'choice', choices = choices, default = default })) or default
    set(v)
    chef.on_change(id, function(nv) set(nv or default) end)
  end
  local function slider(id, label, min, max, step, default, set, hint)
    local v = chef.option(id, spec_of(label, hint, { type = 'slider', min = min, max = max, step = step, default = default })) or default
    set(v)
    chef.on_change(id, function(nv) set(nv or default) end)
  end
  local function toggle(id, label, default, hint)
    if default == nil then default = true end
    -- (a row that's on by default reads as on when the menu can't say; one off by default as off)
    local function as(v) if default then return v ~= false else return v == true end end
    cfg[id] = as(chef.option(id, spec_of(label, hint, { type = 'toggle', default = default })))
    chef.on_change(id, function(v) cfg[id] = as(v) end)
  end
  N.menu_group, N.menu_toggle = group, toggle

  ---------------------------------------------------------------------------------- the layout: which, how big
  -- (2.0) Layout: luka's four built-in layouts (10_custom: the horizontal stack, the arcs, the vertical pair, the
  -- block) or a Custom file from the editor. A new row (the old 'position' row's nine choices — Under, Beside, the
  -- corner, the curved pair, the Previews — are gone, and a saved number from it would land on the wrong layout),
  -- so everyone starts on the horizontal; a Custom user picks Custom layout again (the file is untouched).
  -- The two offsets move any of them (a Custom file only when it says so).
  group('Layout', '', true)
  local BUILTIN = { 'horizontal', 'arcs', 'vertical', 'block' }   -- (luka's order: 1 horizontal, 2 arcs, 3 vertical, 4 block)
  choice('layout', 'Layout', { 'Horizontal', 'Arcs', 'Vertical pair', 'Block', 'Custom layout' }, 1,
    function(v) cfg.custom, cfg.builtin = true, BUILTIN[v] end,
    'Four built-in layouts, or Custom layout: your own from the online editor (the README has the link), read from the layout file.')
  local SIZES = { 0.8, 1.0, 1.25, 1.5 }
  choice('size', 'Size', { 'Small', 'Medium', 'Large', 'Huge' }, 2, function(v) cfg.size = SIZES[v] or 1 end,
    'The whole HUD. The icons never go below Medium\'s size.')
  slider('off_x', 'Sideways, % (+ right)', -50, 50, 0.5, 0, function(v) cfg.off_x = v end,
    'Moves the layout left or right, in % of the screen\'s height. A Custom layout moves only when its file says so.')
  slider('off_y', 'Up / down, % (+ up)', -50, 50, 0.5, 0, function(v) cfg.off_y = v end,
    'Moves the layout down or up, in % of the screen\'s height.')
  -- (1.5.53) the two sides of the crosshair closer in or farther apart: the parts left of it move left, the parts
  -- right of it move right (a layout's sides, by each part's x from the centre or its own side field); nothing
  -- else changes.
  slider('spread', 'Spread, % (+ apart)', -30, 30, 0.5, 0, function(v) cfg.spread = v end,
    'The parts left of the crosshair move left and the parts right of it move right (or closer in); nothing else changes.')
  slider('opacity', 'Opacity, %', 20, 100, 5, 100, function(v) cfg.opacity = v / 100 end)

  ---------------------------------------------------------------------------------- Show: each part's rule
  -- (1.5.60) every Show row a rule (08_show): Off, Always, While not full, On a change, While aiming, or one of
  -- the two joined with aiming; the text parts without "not full". cfg.show_<part> stays the boolean (off or not)
  -- the draws test; cfg.vis[part] the rule.
  group('Show', 'Show: ')
  local BAR_RULES = { 'Off', 'Always', 'While not full', 'On a change', 'While aiming', 'Not full/aiming', 'Change/aiming' }
  local TEXT_RULES = { 'Off', 'Always', 'On a change', 'While aiming', 'Change/aiming' }
  local TEXT_MAP = { 1, 2, 4, 5, 7 }
  local RULE_HINT = 'When it shows: always; while it isn\'t full; for a few seconds after it changes; while you aim; or one of those joined with aiming. Held back, it keeps its place and fades.'
  local TEXT_HINT = 'When it shows: always; for a few seconds after it changes; while you aim; or both. Held back, it keeps its place and fades.'
  cfg.vis = {}
  local function rule(id, part, label, text, flag, default, hint)
    choice(id, label, text and TEXT_RULES or BAR_RULES, default or 2, function(v)
      local mode = text and (TEXT_MAP[v] or 2) or v
      cfg.vis[part] = mode
      if flag then cfg[flag] = mode ~= 1 end
    end, hint or (text and TEXT_HINT or RULE_HINT))
  end
  rule('vis_bar', 'bar', 'Ammo / heat bar', false, 'show_bar', nil, 'The magazine as a tick a round (a bar for big ones), or a weapon\'s heat with its marks. ' .. RULE_HINT)
  rule('vis_count', 'count', 'Count', false, 'show_count', nil, 'The rounds left, or the heat in %. ' .. RULE_HINT)
  rule('vis_mags', 'mags', 'Spare magazines', false, 'show_mags', nil, 'The spare magazines (x7, or squares in a layout that says so). ' .. RULE_HINT)
  rule('vis_charge', 'charge', 'Charge meter', false, 'show_charge', nil, 'The charge (Railgun, Epoch ...) or lock-on (Spear, WASP) meter. ' .. RULE_HINT)
  toggle('show_heat', 'HEAT label', true, 'The word HEAT with a heat weapon\'s mode.')
  rule('vis_mode', 'mode', 'Weapon mode', true, 'show_mode', nil, 'UNGUIDED, APHET, FLAK, the underbarrel ... ' .. TEXT_HINT)
  rule('vis_fmode', 'fmode', 'Fire mode', true, 'show_fmode', nil, 'AUTO, SEMI, BURST ... ' .. TEXT_HINT)
  -- (1.5.18) the game's own icons for the modes, drawn from its atlas through its icon material (docs/ICONS.md):
  -- cfg.mode_icons is the way: 1 off, 3 the icon's own material in the HUD's colour (shipped); the research row sets 2 and 4
  rule('vis_icons', 'icons', 'Mode icons', true, nil, nil, 'The game\'s own icons for the modes and the scope\'s zeroing. ' .. TEXT_HINT)
  cfg.mode_icons = cfg.vis.icons ~= 1 and 3 or 1
  chef.on_change('vis_icons', function(v) cfg.mode_icons = (TEXT_MAP[v or 2] or 2) ~= 1 and 3 or 1 end)
  rule('vis_rpm', 'rpm', 'Rate of fire', true, 'show_rpm', nil, 'The rate-of-fire setting (640 RPM ...). ' .. TEXT_HINT)
  rule('vis_stims', 'stims', 'Stims', false, 'show_stims')
  rule('vis_grenades', 'grenades', 'Grenades', false, 'show_grenades')
  rule('vis_pack', 'pack', 'Backpack bar', false, 'pack', nil, 'The backpack\'s ammo, the warp pack\'s heat, the jump pack\'s recharge. ' .. RULE_HINT)
  -- (1.1.0) health and stamina: off, always, or only while not full (then gone 2 s after it's full again); on since
  -- 1.5.13; (1.5.60) the same rules as the other parts, the first three choices as they were
  choice('health', 'Health', { 'Off', 'Always', 'When hurt', 'On a change', 'While aiming', 'Hurt/aiming', 'Change/aiming' }, 2,
    function(v) cfg.health = v cfg.vis.health = v end, 'Your health bar. ' .. RULE_HINT)
  choice('stamina', 'Stamina', BAR_RULES, 2, function(v) cfg.stamina = v cfg.vis.stamina = v end, 'Your stamina bar. ' .. RULE_HINT)
  slider('show_secs', 'A change lasts, s', 1, 15, 1, 4, function(v) cfg.show_secs = v end,
    'How long a part on "On a change" stays after its value moved.')
  choice('show_rest', 'Held-back parts', { 'Hidden', 'Dimmed' }, 1, function(v) cfg.show_rest = v end,
    'A part its rule holds back keeps its place in the layout, and is hidden or dimmed to a quarter.')

  ---------------------------------------------------------------------------------- the look
  group('Look', 'Look: ')
  -- (2.0: "magazines as squares / a number" is each layout's mags part now; the empty squares' row stays)
  choice('mags_empty', 'Empty squares', { 'Shown', 'Hidden' }, 1, function(v) cfg.mags_hide = v == 2 end,
    'The magazine squares you\'ve used (up to the most this weapon has carried), in a layout that shows squares.')
  -- (1.5.53) the bars' edge and shade apart (one toggle chose outlines or the faint fill before)
  choice('edge', 'Bar edges', { 'None', 'Outline', 'Brackets' }, 1, function(v) cfg.edge = v end,
    'The bars\' edges: none, an outline, or square brackets at the ends as the game\'s own bars have. A layout can set its own per bar.')
  toggle('shade', 'Shade behind bars', true, 'The faint fill behind a bar\'s empty part. A layout can set its own per bar.')
  toggle('mode_colors', 'Modes in colour', false, 'The fire and weapon modes (words and icons) each in a colour of their own, so a switch is easy to see.')
  choice('palette', 'Colours', { 'Standard', 'Colourblind' }, 1, function(v) cfg.palette = v if N.apply_palette then N.apply_palette() end end,
    'Colourblind: white, sky blue, yellow and magenta, told apart by brightness too.')
  -- (1.5.63) drawn in the game's UI layer: past its exposure and grading, the colours as coded; (1.5.61) in its
  -- world instead, the tone mapping undone on our colours (08_draw_kit TONE)
  toggle('top_world', 'In the game\'s UI layer', true,
    'Drawn above the game\'s own HUD, where its colour grading can\'t change the HUD\'s colours. Off: drawn in the world, as before 2.0.')
  toggle('tone_fix', 'Tone fix (world only)', true, 'With the UI layer off: the colours corrected for the world\'s tone mapping, so the cream stays a cream.')
  -- (from Chef 1.1 on, every mod's text is Chef's, in the game's font; its own "Game font" row, under Chef Shared
  -- Loader, switches all of them to the pixel font. Ours is only for Chef 1.0.x)
  if chef.text_fit == nil then
    cfg.font = chef.option('font', spec_of('Game font', nil, { type = 'toggle', default = true })) ~= false
    chef.on_change('font', function(v) cfg.font = v ~= false end)
  end

  ---------------------------------------------------------------------------------- extras
  group('Extras', 'Extras: ')
  -- (1.2.0) a line shrinking over a stim's effect (4 s; 6 s with the Med-Kit or Adreno-Defibrillator armour, which
  -- Auto learns per armour set the first time it can tell)
  toggle('stim_timer', 'Stim timer', false, 'A line shrinking while a stim works.')
  choice('stim_secs', '   Stim lasts', { 'Auto (armour)', '4 s', '6 s' }, 1, function(v) cfg.stim_secs = v end,
    'Auto: 6 s with the Med-Kit or Adreno-Defibrillator armour passives, learned per armour set, else 4 s.')
  toggle('warn', 'Warning pulses', false, 'The health bar pulses under 25 %; the stims pulse when you have none left while hurt.')
  toggle('reload_line', 'Reload line', false, 'A line filling over a reload, from a weapon\'s second reload on (the first teaches it the time).')
  -- when nothing has changed for a while (the count, heat, magazines, modes, the weapon, the items ...) and you
  -- haven't pressed fire: shown, dimmed to a quarter, or hidden; back at once on the next change
  choice('idle', 'Idle HUD is', { 'Shown', 'Dimmed', 'Hidden' }, 1, function(v) cfg.idle = v end,
    'When nothing has changed for a while and you haven\'t fired: shown, dimmed to a quarter, or hidden. Back at once on a change.')
  slider('idle_secs', '   Idle after, s', 2, 15, 1, 4, function(v) cfg.idle_secs = v end)

  ---------------------------------------------------------------------------------- motion
  -- (1.5.55) motion: the few things that move (08_motion) — off, quick (the times as set), or normal (1.6 times);
  -- aiming as a state: while you aim, the Spread changes by this and the opacity goes to this, eased
  group('Motion', 'Motion: ')
  choice('motion', 'Motion', { 'Off', 'Quick', 'Normal' }, 2, function(v) cfg.motion = v end,
    'Parts sliding to a new place, bars easing, a reload sweeping the ticks in, short flashes on an event. Off: everything snaps.')
  slider('aim_spread', 'Aim spread, %', -30, 30, 0.5, 0, function(v) cfg.aim_spread = v end,
    'While you aim, the Spread changes by this (eased). 0: no change.')
  slider('aim_opacity', 'Aim opacity, %', 20, 100, 5, 100, function(v) cfg.aim_opacity = v / 100 end,
    'While you aim, the opacity goes to this (eased). 100: as when not aiming.')

  ---------------------------------------------------------------------------------- the world: markers and lines
  -- (1.5.43) the sniper rifles' third-person crosshair (12_reticle); (1.3.0) your map pin and the spot of your last
  -- death, with their distance, an arrow at the screen's edge when out of view; (1.4.0) the drop line: the shot's
  -- flight from the crosshair, for weapons whose shot drops; (1.5.0) throw lines: a stratagem ball, a grenade or C4
  group('World', 'World: ')
  toggle('reticle', 'Sniper crosshair', true, 'A crosshair for the APW-1, R-40 and AMW-20 aimed in third person, where the game draws none: the game\'s own ring and dot.')
  slider('reticle_px', '   Crosshair size, px', 8, 64, 1, 17, function(v) cfg.reticle_px = v end,
    'Its width at 1440p (the game\'s is 17). It follows the screen, not Size.')
  toggle('map_pin', 'Map pin', true, 'Your map pin where it is in the world, with its distance; an arrow at the screen\'s edge when it\'s out of view.')
  toggle('death_mark', 'Death mark', true, 'Where you last died: a red diamond with its distance, for 3 minutes.')
  choice('drop_line', 'Drop line', { 'Off', 'While aiming', 'In hand' }, 2, function(v) cfg.drop_line = v end,
    'Where the shot goes, for grenade launchers, rockets, the crossbow and plasma: a line from the weapon, bending as the round drops.')
  slider('drop_len', '   Drop line length, m', 50, 300, 25, 150, function(v) cfg.drop_len = v end)
  toggle('throw_line', 'Throw line', true, 'Where a stratagem ball, a grenade or C4 goes while you aim it, from your hand to where it lands.')
  choice('drop_thick', '   Lines', { 'Thin', 'Medium', 'Thick' }, 2, function(v) cfg.drop_thick = v end, 'The drop and throw lines\' thickness.')

  -- the rows that go with the keys (03_learned registers the keys; these follow the stratagem key) and the testing
  -- rows at the very end
  function N.settings_hide()
    -- (the game's stratagem input and an emote: the HUD out of the way; health and stamina stay for the stratagems)
    toggle('hide_strat', 'Hide on stratagem', true, 'The HUD out of the way while the stratagem key is held (health and stamina stay).')
    toggle('hide_emote', 'Hide on emote', true, 'The HUD out of the way while you emote.')
  end
  function N.settings_testing()
    group('Testing', 'Testing: ')
    toggle('research', 'Research log', false, 'For bug reports: what the mod reads, in narrowhud_research.log, from the next start. Post it with narrowhud.log.')
    toggle('swatches', 'Colour swatches', false, 'Colour steps on the screen, for a screenshot of how this screen shows colours.')
    toggle('any_build', 'Any game version', false, 'Run on a game version the mod wasn\'t made for. It may crash the game.')
    -- (1.5.16) the icon texture test rows, only with the research log on (docs/ICONS.md: the strobe on one map)
    -- (1.5.38) the host's objects are never listed, sorted or read: with them, a client lost its host 12 to 17
    -- minutes into every mission (luka's three drops, the reporters'); without them, none in 44 minutes (the
    -- 2026-10-29 level-2 run; docs/DEVLOG.md). Level 2 is the default for everyone; level 1 (the host's objects
    -- too, as 1.5.37 and before) is a research choice. The other levels: the bisection within the reads.
    N.read_level = 2
    if cfg.research then
      N.read_level = chef.option('read_level', spec_of('Reads', 'Which of the mod\'s engine reads are made, for the disconnect bisection.', { type = 'choice', choices = { '1 All (host too)', '2 No host objects', '3 No fields', '4 No objects', '5 No unit calls', '6 No ref fields' }, default = 2 })) or 2
      chef.on_change('read_level', function(v) N.read_level = v or 2 log('Testing: reads %s', ({ 'all, the host\'s objects too', 'no host objects', 'no field reads', 'no object reads at all', 'no Unit calls', 'no floor / underbarrel reads (as 1.5.13)' })[v or 2]) end)
      local dflt = N.CHEF14 and 5 or 7                 -- (Chef 1.4: the plain bitmap; 1.3: the uv call, which doesn't strobe)
      cfg.icon_tex = chef.option('icon_tex', spec_of('Stim icon way', nil, { type = 'choice', choices = { '1 Pixel', '2 Ladder', '3 Ladder top', '4 One size', '5 Game bmp', '6 Game top', '7 Game uv', '8 Ladder uv' }, default = dflt })) or dflt
      chef.on_change('icon_tex', function(v) cfg.icon_tex = v or dflt end)
      local way = chef.option('mode_icons', spec_of('Mode icons drawn', nil, { type = 'choice', choices = { '1 As Show', '2 Chef plain', '3 Own cream', '4 Own blue' }, default = 1 }))
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
