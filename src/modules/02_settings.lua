-- NarrowHUD, settings: the F9 menu: every option and its on_change; the special packs and the research types.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES = N.TYPES

------------------------------------------------------------------------------------------------ settings, learned
local cfg = { size = 1, off_x = 0, off_y = 0, custom = true, builtin = 'horizontal',
              show_bar = true, show_count = true, show_mags = true, show_heat = true, show_charge = true,
              show_stims = true, show_grenades = true, pack = true, font = true,
              research = false, any_build = false, opacity = 1, idle = 1, idle_secs = 4, show_rpm = true, show_fmode = true,
              show_mode = true, palette = 1, fire = 1, wheel = 1, health = 2, stamina = 2, stim_timer = false, stim_secs = 1, warn = false, low_ammo = 0.25,
              reload_line = false, hide_strat = true, hide_emote = true, hide_wheel = true, hide_terminal = true, map_pin = true, death_mark = true, drop_line = 2, drop_len = 150, drop_from = 10, drop_thick = 1, throw_line = true, landing_mark = true, mark_size = 0.5, struct_mark = true, line_alpha = 0.30, reticle = true, reticle_always = false, reticle_fp = true, reticle_flame = false, icon_tex = N.CHEF14 and 5 or 7, builtin = nil }
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
      -- (2.0.3: Chef makes no row at all for a hint over 200 characters — 2.0.0 lost five rows and a heading that
      -- way. Cut here, and said in the log, so a long one costs three dots and not the row)
      if hint and #hint > 200 then log('settings: the hint of "%s" is %d characters, cut to 200', label, #hint) hint = hint:sub(1, 197) .. '...' end
      if hint then t.hint = hint end
      if grp.pending then t.heading = grp.name if grp.open then t.fold = false end grp.pending = false end
    end
    return t
  end
  N.menu_spec = spec_of   -- (03_learned's rows)
  N.menu_label = function(label) return HEAD and label or (grp.prefix .. label) end   -- (a key row's label: chef.bind takes no spec)
  local function choice(id, label, choices, default, set, hint)
    -- (2.3.9: nil, not false, is "nothing saved": a row that was a toggle (Warning pulses, Shade behind bars) has its
    -- saved false read by its setter as Off, not as the default)
    local v = chef.option(id, spec_of(label, hint, { type = 'choice', choices = choices, default = default }))
    if v == nil then v = default end
    set(v)
    chef.on_change(id, function(nv) if nv == nil then nv = default end set(nv) end)
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
  -- The two offsets move any of them (a Custom file only when it says so). (2.0.3, luka: the aim Spread under the
  -- Spread and Motion here; the aim opacity and the old Extras under Visibility.)
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
  -- else changes. (1.5.55) While you aim, the Spread changes by the aim Spread, eased.
  slider('spread', 'Spread, % (+ apart)', -30, 30, 0.5, 0, function(v) cfg.spread = v end,
    'The parts left of the crosshair move left and the parts right of it move right (or closer in); a part on the up or down side (the horizontal layout as a whole) moves that way; nothing else changes.')
  slider('aim_spread', '   Aim spread, %', -30, 30, 0.5, 0, function(v) cfg.aim_spread = v end,
    'While you aim, the Spread changes by this (eased). 0: no change.')
  slider('opacity', 'Opacity, %', 20, 100, 5, 100, function(v) cfg.opacity = v / 100 end)
  -- (1.5.55) motion: the few things that move (08_motion) — off, quick (the times as set), or normal (1.6 times)
  choice('motion', 'Motion', { 'Off', 'Quick', 'Normal' }, 2, function(v) cfg.motion = v end,
    'Parts sliding to a new place, bars easing, a reload or resupply sweeping the pieces in, mode words fading over, short flashes on an event. Off: everything snaps.')
  toggle('shell_flash', 'Shell flash', true,
    'Each round fired jumps out of the ammo bar, square to it and away from the crosshair, and fades, like a shell thrown out. Needs Motion on.')
  slider('shell_len', '   Shell flash length, %', 10, 100, 5, 30, function(v) cfg.shell_len = v end,
    'How much of the shell\'s flight shows before it\'s gone: 30 a flick off the bar, 100 a short throw.')
  -- (2.4.5, luka: its own row and length, as the shell flash's)
  toggle('shell_load', 'Shell loading', true,
    'On weapons that load a round at a time (the Cookout, the Punisher), each round loaded flicks into the ammo bar, the shell flash backwards. Needs Motion on.')
  slider('shell_load_len', '   Shell loading length, %', 10, 100, 5, 30, function(v) cfg.shell_load_len = v end,
    'How far out each loaded round starts: 30 a flick into the bar, 100 a short throw in. It takes twice the shell flash\'s time.')

  ---------------------------------------------------------------------------------- Visibility: each part's rule
  -- (1.5.60) every part's row a rule (08_show): Off, Always, While not full, On a change, While aiming, or one of
  -- the two joined with aiming; the text parts without "not full". cfg.show_<part> stays the boolean (off or not)
  -- the draws test; cfg.vis[part] the rule. (2.0.3: "Visibility", with the aim opacity and the old Extras after
  -- the rules. The hints at 200 characters or under: Chef makes no row at all for a longer one, and 2.0.0 lost
  -- the bar, count, magazines, charge and backpack rows and the heading that way.)
  group('Visibility', 'Visibility: ')
  local BAR_RULES = { 'Off', 'Always', 'While not full', 'On a change', 'While aiming', 'Not full/aiming', 'Change/aiming' }
  local TEXT_RULES = { 'Off', 'Always', 'On a change', 'While aiming', 'Change/aiming' }
  local TEXT_MAP = { 1, 2, 4, 5, 7 }
  local RULE_HINT = 'When it shows: always; while not full; for a few seconds after a change; while you aim; or one of those and aiming. Held back, it keeps its place.'
  local TEXT_HINT = 'When it shows: always; for a few seconds after a change; while you aim; or both. Held back, it keeps its place.'
  cfg.vis = {}
  local function rule(id, part, label, text, flag, default, hint)
    choice(id, label, text and TEXT_RULES or BAR_RULES, default or 2, function(v)
      local mode = text and (TEXT_MAP[v] or 2) or v
      cfg.vis[part] = mode
      if flag then cfg[flag] = mode ~= 1 end
    end, hint or (text and TEXT_HINT or RULE_HINT))
  end
  rule('vis_bar', 'bar', 'Ammo / heat bar', false, 'show_bar', nil, 'The magazine as ticks, or a heat weapon\'s heat. ' .. RULE_HINT)
  rule('vis_count', 'count', 'Count', false, 'show_count', nil, 'The rounds left, or the heat in %. ' .. RULE_HINT)
  rule('vis_mags', 'mags', 'Spare magazines', false, 'show_mags', nil, 'The spare magazines (x7, or squares). ' .. RULE_HINT)
  rule('vis_charge', 'charge', 'Charge meter', false, 'show_charge', nil, 'The charge or lock-on meter. ' .. RULE_HINT)
  toggle('show_heat', 'HEAT label', true, 'The word HEAT with a heat weapon\'s mode.')
  rule('vis_mode', 'mode', 'Weapon mode', true, 'show_mode', nil, 'UNGUIDED, APHET, FLAK, the underbarrel ... ' .. TEXT_HINT)
  rule('vis_fmode', 'fmode', 'Fire mode', true, 'show_fmode', nil, 'AUTO, SEMI, BURST ... ' .. TEXT_HINT)
  -- (1.5.18) the game's own icons for the modes, drawn from its atlas through its icon material (docs/ICONS.md):
  -- cfg.mode_icons is the way: 1 off, 3 the icon's own material in the HUD's colour (shipped; 2 and 4 were research ways)
  rule('vis_icons', 'icons', 'Mode icons', true, nil, nil, 'The game\'s own icons for the modes and the scope\'s zeroing. ' .. TEXT_HINT)
  cfg.mode_icons = cfg.vis.icons ~= 1 and 3 or 1
  chef.on_change('vis_icons', function(v) cfg.mode_icons = (TEXT_MAP[v or 2] or 2) ~= 1 and 3 or 1 end)
  rule('vis_rpm', 'rpm', 'Rate of fire', true, 'show_rpm', nil, 'The rate-of-fire setting (640 RPM ...). ' .. TEXT_HINT)
  rule('vis_stims', 'stims', 'Stims', false, 'show_stims')
  rule('vis_grenades', 'grenades', 'Grenades', false, 'show_grenades')
  rule('vis_pack', 'pack', 'Backpack bar', false, 'pack', nil, 'The backpack\'s ammo, heat or recharge. ' .. RULE_HINT)
  -- (1.1.0) health and stamina: off, always, or only while not full (then gone 2 s after it's full again); on since
  -- 1.5.13; (1.5.60) the same rules as the other parts, the first three choices as they were
  choice('health', 'Health', { 'Off', 'Always', 'When hurt', 'On a change', 'While aiming', 'Hurt/aiming', 'Change/aiming' }, 2,
    function(v) cfg.health = v cfg.vis.health = v end, 'Your health bar. ' .. RULE_HINT)
  choice('stamina', 'Stamina', BAR_RULES, 2, function(v) cfg.stamina = v cfg.vis.stamina = v end, 'Your stamina bar. ' .. RULE_HINT)
  slider('show_secs', 'A change lasts, s', 1, 15, 1, 4, function(v) cfg.show_secs = v end,
    'How long a part on "On a change" stays after its value moved.')
  choice('show_rest', 'Held-back parts', { 'Hidden', 'Dimmed' }, 1, function(v) cfg.show_rest = v end,
    'A part its rule holds back keeps its place in the layout, and is hidden or dimmed to a quarter.')
  -- (1.5.55) while you aim, the opacity goes to this, eased
  slider('aim_opacity', 'Aim opacity, %', 20, 100, 5, 100, function(v) cfg.aim_opacity = v / 100 end,
    'While you aim, the opacity goes to this (eased). 100: as when not aiming.')
  -- when nothing has changed for a while (the count, heat, magazines, modes, the weapon, the items ...) and you
  -- haven't pressed fire: shown, dimmed to a quarter, or hidden; back at once on the next change
  choice('idle', 'Idle HUD is', { 'Shown', 'Dimmed', 'Hidden' }, 1, function(v) cfg.idle = v end,
    'When nothing has changed for a while and you haven\'t fired: shown, dimmed to a quarter, or hidden. Back at once on a change.')
  slider('idle_secs', '   Idle after, s', 2, 15, 1, 4, function(v) cfg.idle_secs = v end)
  -- (1.2.0) a line shrinking over a stim's effect (4 s; 6 s with the Med-Kit or Adreno-Defibrillator armour, which
  -- Auto learns per armour set the first time it can tell)
  toggle('stim_timer', 'Stim timer', false, 'A line shrinking while a stim works.')
  choice('stim_secs', '   Stim lasts', { 'Auto (armour)', '4 s', '6 s' }, 1, function(v) cfg.stim_secs = v end,
    'Auto: 6 s with the Med-Kit or Adreno-Defibrillator armour passives, learned per armour set, else 4 s.')
  -- (2.3.9: three ways; a saved on / off from the toggle it was reads as Pulsing / Off)
  choice('warn', 'Warning pulses', { 'Off', 'Pulsing', 'Flash once' }, 1, function(v)
    if v == true then v = 2 elseif v == false then v = 1 end
    cfg.warn = (v ~= 1) and v or false
  end, 'Under 25 % health, and with no stims while hurt: off, pulsing twice a second, or one flash as it happens (then just red).')
  -- (2.3.8) what a hit took, on the health bar: in chunks, each hit's own piece held and drained on its own (luka's
  -- wish); as one piece that a new hit holds back (2.3.7); or none. On a red bar none either way
  choice('trail', 'Hit trail', { 'Off', 'One piece', 'In chunks' }, 3, function(v) cfg.trail = v end,
    'What a hit took, in red on the health bar: each hit its own chunk, held then drained; or one piece a new hit holds back. None on a red bar.')
  slider('trail_hold', '   Hit trail held, s', 0, 1, 0.05, 0.4, function(v) cfg.trail_hold = v end,
    'How long a hit\'s red stays before it drains away (in 0.2 s).')
  toggle('reload_line', 'Reload line', false, 'A line filling over a reload, from a weapon\'s second reload on (the first teaches it the time).')

  ---------------------------------------------------------------------------------- the look
  group('Look', 'Look: ')
  -- (2.0: "magazines as squares / a number" is each layout's mags part now; the empty squares' row stays)
  choice('mags_empty', 'Empty squares', { 'Shown', 'Hidden' }, 1, function(v) cfg.mags_hide = v == 2 end,
    'The magazine squares you\'ve used (up to the most this weapon has carried), in a layout that shows squares.')
  -- (1.5.53) the bars' edge and shade apart (one toggle chose outlines or the faint fill before)
  choice('edge', 'Bar edges', { 'None', 'Outline', 'Brackets' }, 1, function(v) cfg.edge = v end,
    'The bars\' edges: none, an outline, or square brackets at the ends as the game\'s own bars have. A layout can set its own per bar.')
  -- (2.3.9) the shade: off, a faint fill, or hatched as the game's own bars (diagonal stripes on a dark ground,
  -- luka's screenshots of the game's health bar); a saved on / off from the toggle it was reads as Solid / Off
  choice('shade', 'Shade behind bars', { 'Off', 'Solid', 'Hatched' }, 2, function(v)
    if v == true then v = 2 elseif v == false then v = 1 end
    cfg.shade = v ~= 1
    cfg.hatch = v == 3
  end, 'Behind a bar\'s empty part: nothing, a faint fill, or diagonal stripes as the game\'s own bars have. A layout can set its own per bar.')
  -- (2.4.14) the stripes as one texture (cheap) or drawn stripe by stripe (crisp): luka compares the two in game
  choice('hatch_way', '   Hatch drawn as', { 'Triangles', 'Texture' }, 2, function(v) cfg.hatch_way = v end,
    'How the stripes are drawn: each stripe as triangles (the 2.3.9 way, up to ~70 engine calls a bar), or as one texture (a call or two a bar).')
  -- (2.2.0) the count's digits: fixed, the number right-aligned in a box as wide as it gets, so it never slides as
  -- it falls (a Nexus comment, 2026-11-01); a layout's count part can set its own
  choice('count_digits', 'Count digits', { 'Fixed', 'Tight' }, 1, function(v) cfg.count_tight = v == 2 end,
    'Fixed: the count sits right-aligned in a box as wide as a full magazine, so it and the parts after it never slide. Tight: the box is the number\'s own width. A layout can set its own.')
  toggle('mode_colors', 'Modes in colour', false, 'The fire and weapon modes (words and icons) each in a colour of their own, so a switch is easy to see.')
  choice('palette', 'Colours', { 'Standard', 'Colourblind' }, 1, function(v) cfg.palette = v if N.apply_palette then N.apply_palette() end end,
    'Colourblind: white, sky blue, yellow and magenta, told apart by brightness too.')
  -- (2.4.5, luka) where ammo turns low: the bar, the count and an ammo backpack orange (and the one flash) at this share
  slider('low_ammo', 'Low ammo at, %', 5, 50, 5, 25, function(v) cfg.low_ammo = v / 100 end,
    'The ammo bar and count turn orange, with one flash as they do, at this much of a magazine or less; an ammo backpack too.')
  -- (1.5.63) drawn in the game's UI layer: past its exposure and grading, the colours as coded. (2.0.3: no rows for
  -- it any more, luka: "it should always be drawn in the UI layer, otherwise it looks bad". cfg.top_world stays
  -- true; on a Chef without the layer (no chef.TOP) the HUD is drawn in the world with the tone fix, as 1.5.61.)
  cfg.top_world, cfg.tone_fix = true, true
  -- (from Chef 1.1 on, every mod's text is Chef's, in the game's font; its own "Game font" row, under Chef Shared
  -- Loader, switches all of them to the pixel font. Ours is only for Chef 1.0.x)
  if chef.text_fit == nil then
    cfg.font = chef.option('font', spec_of('Game font', nil, { type = 'toggle', default = true })) ~= false
    chef.on_change('font', function(v) cfg.font = v ~= false end)
  end

  ---------------------------------------------------------------------------------- the world: markers and lines
  -- (1.5.43) the sniper rifles' third-person crosshair (12_reticle); (1.3.0) your map pin and the spot of your last
  -- death, with their distance, an arrow at the screen's edge when out of view; (1.4.0) the drop line: the shot's
  -- flight from the crosshair, for weapons whose shot drops; (1.5.0) throw lines: a stratagem ball, a grenade or C4
  group('World', 'World: ')
  toggle('reticle', 'Sniper crosshair', true, 'A crosshair for the APW-1, R-40 and AMW-20 in third person, where the game draws none: the game\'s own ring and dot.')
  choice('reticle_when', '   Shown', { 'While aiming', 'Always' }, 1, function(v) cfg.reticle_always = v == 2 end,
    'Always: with the rifle out, aimed or not (third person only; in first person the scope is up).')
  toggle('reticle_fp', 'Maxigun crosshair', true, 'The same ring and dot for the Maxigun in first person, where the game draws none.')
  toggle('reticle_flame', 'Flamethrower crosshair', false, 'The ring and dot for the flamethrowers in first person, where the game draws none. Off: a flamethrower is aimed by its stream.')
  slider('reticle_px', '   Crosshair size, px', 8, 64, 1, 17, function(v) cfg.reticle_px = v end,
    'Its width at 1440p (the game\'s is 17). It follows the screen, not Size.')
  toggle('map_pin', 'Map pin', true, 'Your map pin where it is in the world, with its distance; an arrow at the screen\'s edge when it\'s out of view.')
  toggle('death_mark', 'Death mark', true, 'Where you last died: a red diamond with its distance, for 3 minutes.')
  choice('drop_line', 'Drop line', { 'Off', 'While aiming', 'In hand' }, 2, function(v) cfg.drop_line = v end,
    'Where the shot goes, for grenade launchers, rockets, the crossbow and plasma: a line from the weapon, bending as the round drops.')
  slider('drop_len', '   Drop line length, m', 50, 300, 25, 150, function(v) cfg.drop_len = v end)
  -- (2.4.15) the line aimed at the game's reticle point (it lags the view in a turn and sways with the sight) or at
  -- the view itself, as before
  choice('line_aim', '   Line aimed at', { 'The view', 'The reticle' }, 2, function(v) cfg.line_aim = v end,
    'The reticle: the line goes where the game\'s reticle points, which lags the view in a turn and sways with the sight. The view: straight along the camera, as before.')
  slider('drop_from', '   Line from a drop of, cm', 0, 50, 1, 10, function(v) cfg.drop_from = v end,
    'The line starts where the shot has fallen this far below a straight aim: a flat-shooting gun\'s line begins far out, a lobbed one\'s near the hand. 0: from the hand.')
  toggle('throw_line', 'Throw line', true, 'Where a stratagem ball, a grenade or C4 goes while you aim it, from your hand to where it lands.')
  -- (2.0.13) the landing mark: a ring where a line meets the ground as 12_ground guesses it (from the map's own
  -- props, calibrated by where Helldivers walk); faint where the ground is a guess between known cells
  toggle('landing_mark', 'Landing mark', true, 'A ring on the ground where a drop or throw line lands, from the map\'s own heights; faint where the ground is a guess.')
  slider('mark_size', '   Mark size, m', 0.3, 1, 0.1, 0.5, function(v) cfg.mark_size = v end, 'The landing mark\'s width: the ring and the arrow over it.')
  toggle('struct_mark', 'Structure hits', true, 'The mark turns red where the shot or throw would hit an enemy structure (a bug hole, a fabricator, a warp ship) before the ground.')
  choice('drop_thick', '   Lines', { 'Thin', 'Medium', 'Thick' }, 1, function(v) cfg.drop_thick = v end, 'The drop and throw lines\' thickness.')
  -- (2.4.8, luka: "our line and ending markers look like v0.5 next to a v2.5 HUD") the new look, the old one kept
  choice('line_look', '   Line look', { 'Classic', 'Solid', 'Dashes', 'Flowing dashes' }, 2, function(v) cfg.line_look = v end,
    'Classic: as before. Solid: one line with dark edges, fading in at the hand. Dashes: the same size on screen near and far (they cost frame time). Flowing: they move toward where it lands.')
  toggle('line_tri', '   Thick lines as a triangle', false, 'With Lines set to Thick: the third strand over the other two instead of beside them, so the line has a body at a glancing angle.')
  choice('mark_look', '   Landing mark look', { 'Classic', 'On the ground' }, 2, function(v) cfg.mark_look = v end,
    'On the ground: a pin painted on the ground where it lands, lying on rocks and slopes, with a chevron icon over it. Classic: the ring of lines, as before.')
  toggle('blast_zone', '   Blast zone', true,
    'For explosive rounds and grenades: the full-damage radius painted on the ground under the mark, the outer radius as a dashed ring; red while you stand within reach.')
  -- (2.0.18) the lines' and the mark's opacity: the world's tone mapping burns the cream to white and the red to
  -- pure red, and a correction goes wrong with the planet's grading (luka, 2.0.17); a lower opacity blends more of
  -- the scene in before the curve, which softens both
  -- (2.0.19, luka: anything over 50 % looks like 100 %, so the row's 20–100 is 10–50 in the engine, 60 (30) the default)
  slider('line_alpha', '   Line opacity, %', 20, 100, 5, 60, function(v) cfg.line_alpha = v / 200 end,
    'The drop and throw lines and the landing mark. Lower softens the white-out the game\'s tone mapping gives world lines.')

  -- the rows that go with the keys (03_learned registers the keys; these follow the stratagem key) and the testing
  -- rows at the very end
  function N.settings_hide()
    -- (the game's stratagem input and an emote: the HUD out of the way; health and stamina stay for the stratagems)
    toggle('hide_strat', 'Hide on stratagem', true, 'The HUD out of the way while the stratagem key is held (health and stamina stay).')
    toggle('hide_emote', 'Hide on emote', true, 'The HUD out of the way while you emote.')
    toggle('hide_wheel', 'Hide on weapon settings', true, 'The HUD out of the way while the weapon settings wheel is open.')
    toggle('hide_terminal', 'Hide at a terminal', true, 'The HUD, health and stamina out of the way while you work a terminal (its screen takes the middle).')
  end
  function N.settings_testing()
    group('Testing', 'Testing: ')
    toggle('research', 'Research log', false, 'For bug reports: what the mod reads, in narrowhud_research.log, from the next start. Post it with narrowhud.log.')
    if N.research_types then N.research_types() end
    toggle('any_build', 'Any game version', false, 'Run on a game version the mod wasn\'t made for. It may crash the game.')
    -- (1.5.38) the host's objects are never listed, sorted or read: with them, a client lost its host 12 to 17
    -- minutes into every mission (luka's three drops, the reporters'); without them, none in 44 minutes (the
    -- 2026-10-29 level-2 run; docs/DEVLOG.md). Level 2 for everyone. (2.0.3: the research rows below are gone from
    -- the menu, luka: they'd never change. The code they drove stays: N.read_level (the bisection's levels 1 to 6),
    -- cfg.icon_tex (the texture ways 1 to 8, docs/ICONS.md), cfg.mode_icons (2 Chef plain, 4 own blue) and
    -- cfg.swatches (08_draw_kit's colour steps) can be set from the tests, or by a row put back here.)
    N.read_level = 2
    cfg.swatches = false
    -- if cfg.research then
    --   N.read_level = chef.option('read_level', spec_of('Reads', 'Which of the mod\'s engine reads are made, for the disconnect bisection.', { type = 'choice', choices = { '1 All (host too)', '2 No host objects', '3 No fields', '4 No objects', '5 No unit calls', '6 No ref fields' }, default = 2 })) or 2
    --   chef.on_change('read_level', function(v) N.read_level = v or 2 log('Testing: reads %s', ({ 'all, the host\'s objects too', 'no host objects', 'no field reads', 'no object reads at all', 'no Unit calls', 'no floor / underbarrel reads (as 1.5.13)' })[v or 2]) end)
    --   local dflt = N.CHEF14 and 5 or 7                 -- (Chef 1.4: the plain bitmap; 1.3: the uv call, which doesn't strobe)
    --   cfg.icon_tex = chef.option('icon_tex', spec_of('Stim icon way', nil, { type = 'choice', choices = { '1 Pixel', '2 Ladder', '3 Ladder top', '4 One size', '5 Game bmp', '6 Game top', '7 Game uv', '8 Ladder uv' }, default = dflt })) or dflt
    --   chef.on_change('icon_tex', function(v) cfg.icon_tex = v or dflt end)
    --   local way = chef.option('mode_icons', spec_of('Mode icons drawn', nil, { type = 'choice', choices = { '1 As Show', '2 Chef plain', '3 Own cream', '4 Own blue' }, default = 1 }))
    --   if way and way > 1 then cfg.mode_icons = way end
    --   chef.on_change('mode_icons', function(v) if v and v > 1 then cfg.mode_icons = v else cfg.mode_icons = cfg.mode_icons == 1 and 1 or 3 end end)
    --   toggle('swatches', 'Colour swatches', false, 'Colour steps on the screen, for a screenshot of how this screen shows colours.')
    -- end
  end
end
-- Packs that aren't ammo backpacks but have something to show (seen in the research log, 2026-10-24): the warp pack's
-- heat (33 a warp, cooling a few points a second), the jump pack's jump (a flag for half a second: 15 s to recharge,
-- timed by the player) and the hover pack's flight (a flag while hovering: 8 s to recharge after landing). Always known.
local SPECIAL = {
  c89adf0c = { kind = 'warp', field = '35ff0b52' },
  ['3a9a3ab0'] = { kind = 'timer', field = 'faaa8598', on_rise = true, secs = 13.2 },  -- jump pack (15 s from the
  -- jump press; the flag comes 1.8 s after it, timed by the player)
  -- (2.1.3) the hover pack: the jump pack's twin in the network config (the same 16 fields), found by the probe in
  -- luka's 2026-11-01 log (object 469, taken from a pod). f8d23bd2 is true while it flies (on at each lift-off, off
  -- at each of his three touchdown marks within a second). No fuel field anywhere: the fuel is modelled — it drains
  -- for as long as the flag is on and refills in as long again (2.1.4: 1.0, from 1.3 — the flag stays on about a
  -- second past the touchdown, so measured from the flag going off his full marks came 7.4 / 9.0 / 6.3 s after
  -- flights of 7.1 / 9.5 / 7.1 s; at 1.3 the bar finished 1–2 s late, luka)
  -- (2.1.5: his ten flights to empty all had the flag on 8.1 s, two 10.9 s with a jump in them — the tank is 8.1 s,
  -- not "the longest flight seen"; the full marks came 9.4, 9.7, 8.5, 11.7, 7.3, 10.2, 9.2 s after a full drain:
  -- 1.1 x, between the two sessions' 0.96 and 1.15)
  -- (2.1.9: the fuel burns for as long as the flag is on, past the tank (a drop down a slope lends a little that
  -- directional input spends), and what comes back is the refill x that time: 1.15 fits his 2.1.5 plain flights
  -- (8.1 s, full 9.4 after) and his 2.1.8 slope ones (10.8 s, full 10.3 and 11.4 after; 6.5 s, 7.5 and 8.5) alike)
  efb4a22e = { kind = 'hover', field = 'f8d23bd2', refill = 1.15, most = 8.1 },
  -- (2.1.5) the shield backpack: 1ad6d70f is its strength, 150 full (luka's log: 150 > 110 > 15 as it took hits,
  -- 0 broken, 15 > 133.7 > 150 as it came back; b19ad128=active goes false when it breaks, 6fee6b03 true while
  -- it's down, 24cf7e78 true while it regenerates). The backpack bar: strength over 150, red at 0
  -- (2.1.6: the strength is sent only when it has moved by its tolerance (39), so a break can leave it reading 15
  -- and a refill 133.7 — the down flag says broken, the regen flag says it's coming back, and once that ends it's
  -- full; the refill itself is near-instant in the game and animated here over a second)
  b0b9f710 = { kind = 'shield', field = '1ad6d70f', top = 150, more = { down = '6fee6b03', regen = '24cf7e78' } },
}
local KNOWN_FIELDS = {}                              -- (left out of the research log)
for id, sp in pairs(SPECIAL) do
  local name = string.match(DATA.others or '', id .. ' (%S+)')
  sp.fname = string.match(DATA.fieldnames or '', sp.field .. ' (%S+)')
  KNOWN_FIELDS[sp.field] = true
  if sp.more then
    sp.mnames = {}
    for k, f in pairs(sp.more) do sp.mnames[k] = string.match(DATA.fieldnames or '', f .. ' (%S+)') KNOWN_FIELDS[f] = true end
  end
  if name and sp.fname then
    TYPES[#TYPES + 1] = { id = id, name = name, has = { carry = true }, other = true, special = sp }
  end
end
-- with the research log on (from the start of a session), every other carried thing too (jump, hover and warp packs
-- ...): known by type, its fields watched, never shown. (2.1.3: called from N.settings_testing once the Research
-- row has been read — since 2.0.3 put the Testing group last, this ran before it and cfg.research was still false,
-- so no other carried type was known in any research log since; luka's packs read as unknown types)
function N.research_types()
  if not cfg.research then return end
  local n0 = #TYPES
  for line in string.gmatch(DATA.others or '', '[^\n]+') do
    local id, name = string.match(line, '^(%x+) (%S+)$')
    if id and not SPECIAL[id] then TYPES[#TYPES + 1] = { id = id, name = name, has = { carry = true }, other = true } end
  end
  log('research log on: %d other carried types', #TYPES - n0)
end

-- by type id: hand pose, most ammo seen, overheat point, the heat it cools down to, seconds a charge takes

N.cfg, N.MOUSE_BUTTONS, N.KNOWN_FIELDS = cfg, MOUSE_BUTTONS, KNOWN_FIELDS
