-- HD2-Addon: mods/luka189/narrowhud
-- HD2-Keep-On-Crash: yes
-- NarrowHUD (luka189): your weapon's ammo, heat and reserve as a narrow bar under the crosshair, plus grenades and
-- stims. A Chef Shared Loader addon: plain Lua 5.1, read only, every engine call through chef.call_kind (crash
-- guarded). How it knows what you hold:
--   * your weapons are network game objects you own; their types and fields come from the game's network config
--     (DATA, made by tools/make_data.py), read by stand-in names with the same 32-bit hashes as the real ones;
--   * the game says nothing about which one is in your hand, so NarrowHUD reads your Helldiver's hand pose (the
--     animation value weapon_selected) and learns which weapon goes with which pose the first time you fire it
--     (its rounds, shells or heat change while that pose is up), and remembers it (narrowhud learned table);
--   * magazine sizes, overheat points, where heat comes to rest, how long a charge takes, how fast heat rises and
--     falls, and which weapons reload from the backpack are learned too.
-- Keep-On-Crash: if one of the engine calls below ever ends the game, Chef skips only that call from then on (the
-- game font is the likely one: then the pixel font is used).
-- DATA is put in front of this file by tools/build.py.
local chef = ...
local M = { version = '1.0.4' }
if type(chef.own_log) == 'function' then chef.own_log('narrowhud') end
local log = function(fmt, ...) chef.log(fmt, ...) end

------------------------------------------------------------------------------------------------ game data
local ROLE = {}            -- role -> { letter, id, name }
for role, r in pairs(DATA.roles) do ROLE[role] = r end
local LETTER = {}          -- letter -> role
for role, r in pairs(ROLE) do LETTER[r.letter] = role end

local TYPES = {}           -- list of { id, name, has = { role = true }, pack = bool }
local function add_types(text, pack)
  for line in string.gmatch(text, '[^\n]+') do
    local id, name, letters = string.match(line, '^(%x+) (%S+) ?(%a*)$')
    if id then
      local has = {}
      for c in string.gmatch(letters, '.') do if LETTER[c] then has[LETTER[c]] = true end end
      -- fed: a weapon with no ammo of its own (it fires straight from its backpack)
      -- (and a reload stage: the types without one ride along with other equipment, seen 2026-10-24)
      local fed = not pack and not (has.rounds or has.slot0 or has.heat) and has.reload_stage == true
      local noammo = not pack and not (has.rounds or has.slot0 or has.heat) and not fed and has.held == true
      TYPES[#TYPES + 1] = { id = id, name = name, has = has, pack = pack, fed = fed, noammo = noammo }
    end
  end
end
-- the player and avatar first (one of each), then backpacks, then weapons
TYPES[1] = { id = DATA.player.id, name = DATA.player.name, has = {}, player = true }
TYPES[2] = { id = DATA.avatar.id, name = DATA.avatar.name, has = {}, avatar = true }
add_types(DATA.backpacks, true)
add_types(DATA.weapons, false)
-- In a hand: only types with an owner field. Every weapon learned in testing has one (59 types); a player's log as host
-- (1.0.1) had two without it (e45066e4, b747653b: objects a host owns, fired as the player fired) learned to the
-- rifles' pose and shown in place of the player's own weapon.
local HANDHELD = {}
for _, t in ipairs(TYPES) do if t.has.owner then HANDHELD[t.id] = true end end
log('NarrowHUD %s: %d types (game build %s)', M.version, #TYPES, tostring(DATA.build))

local AVATAR_RESOURCE = '4d1c334d294dfa97'   -- the third-person Helldiver unit
local GRIP_VARIABLE = 'weapon_selected'      -- the avatar's hand pose (0: nothing in hand)
local NO_OBJECT = 32767
local THROWABLE = { [40] = true, [41] = true }

------------------------------------------------------------------------------------------------ engine reads
local function call(kind, name, ...) return chef.call_kind(name, kind, ...) end
-- a field or type id as lower-case hex without leading zeros (Network.object_info's ids come without them)
local function norm_id(id)
  if type(id) == 'number' then id = string.format('%x', id) end
  if type(id) ~= 'string' then id = id ~= nil and tostring(id) or nil end
  return id and (string.gsub(string.lower(id), '^0+', '')) or nil
end
local function live_fields(name)
  local ok, info = pcall(call, 'objinfo', 'Network.object_info', name)
  if not ok or type(info) ~= 'table' or type(info.fields) ~= 'table' then return nil end
  local set = {}
  for _, f in ipairs(info.fields) do
    local id = type(f) == 'table' and norm_id(f.id)
    if id then set[id] = true end
  end
  return set
end
-- Chef 1.1 refuses the calls NarrowHUD reads your weapons with: said on screen for the first 25 s of a mission
local blocked = { n = 0, said = false, since = nil }
-- An object can go between two reads (an expendable weapon is dropped and destroyed the moment it's used, and its id
-- can come back as another type); reading a gone object's field can end the game. So before an object's fields are
-- read, once a frame: it still exists and is still that type. A gone one is forgotten until the next scan.
local frame, checked = 0, {}
local forget                                   -- set below (the objects list)
local function alive(s, goid, t)
  local c = checked[goid]
  if c and c.frame == frame and c.t == t then return c.ok end
  local ok = call('exists', 'GameSession.game_object_exists', s, goid) == true
  if ok and t then ok = call(t.id, 'GameSession.game_object_is_type', s, goid, t.name) == true end
  checked[goid] = { frame = frame, t = t, ok = ok }
  if not ok and forget then forget(goid) end
  return ok
end
local function field(s, goid, t, role)
  if not (t and t.has[role]) then return nil end
  if not alive(s, goid, t) then return nil end
  return call(t.id .. '.' .. role, 'GameSession.game_object_field', s, goid, ROLE[role].name)
end

------------------------------------------------------------------------------------------------ the game's version
-- NarrowHUD's data (types and fields, by hash) is taken from one game build's network config. A patch can rename or
-- move fields, and reading a field a type doesn't declare can end the game, so on a game version NarrowHUD wasn't
-- made for it stays off (with a message) unless the player turns on "Run on a game version it wasn't made for".
-- Application.build_identifier per Steam build (the engine's own string):
local BUILDS = {
  ['stingray:46659 e176252a3ac4eb5436b25e7cef665a8c71afa243'] = '26088801',   -- 2026-10-22
}
local game_build = { id = nil, known = nil }
do
  local id = chef.call and chef.call('Application.build_identifier')
  game_build.id = type(id) == 'string' and id or nil
  if game_build.id == nil then
    game_build.known = nil
    log('game version: unknown (no build identifier): running')
  elseif BUILDS[game_build.id] == DATA.build then
    game_build.known = true
    log('game version: %s (Steam build %s, as NarrowHUD\'s data)', game_build.id, DATA.build)
  else
    game_build.known = false
    log('game version: %s, not the one NarrowHUD\'s data is from (Steam build %s): off unless "Run on a game version it wasn\'t made for" is on', game_build.id, DATA.build)
  end
end

------------------------------------------------------------------------------------------------ settings, learned
local cfg = { size = 1, side_size = 1.25, off_x = 0, off_y = 0, right = false, corner = false, mags_number = false,
              show_bar = true, show_count = true, show_mags = true, show_heat = true, show_charge = true,
              show_stims = true, show_grenades = true, pack = true, font = true,
              research = false, any_build = false, opacity = 1, idle = 1, idle_secs = 4, show_rpm = true, show_fmode = true,
              show_mode = true, palette = 1, fire = 1 }
local apply_palette                                  -- (set with the colours, below)
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
  local function position(v) cfg.right, cfg.corner = v == 2 or v == 3, v == 3 end
  position(chef.option('position', { type = 'choice', label = 'Position', choices = { 'Under the crosshair', 'Beside the crosshair (compact)', 'Screen corner, by the game\'s weapon panel (best with the bar and items off)' }, default = 1 }))
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
  chef.on_change('palette', function(v) cfg.palette = v or 1 if apply_palette then apply_palette() end end)
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
local learned = { grip = {}, mag = {}, heat = {}, rest = {}, charge2 = {}, up = {}, down = {}, modes = {}, rpms = {},
                  pack = {}, options1 = {}, packres = {}, rest2 = {}, poses = {},
                  packshow = {}, rpmadj = {}, rpmbase = {}, slot = {}, resmax = {} }
-- The learned file: what each kind holds per type id (8 hex digits), and the file's version (_v). Entries that don't
-- fit (a damaged or hand-edited file) are dropped and counted in the log; a file from a newer NarrowHUD is read for
-- what fits.
local LEARNED_VERSION = 1
local LEARNED_SHAPE = { grip = 'number', mag = 'number', heat = 'number', rest = 'number', charge2 = 'number',
  up = 'number', down = 'number', modes = 'string', rpms = 'string', pack = 'number', options1 = 'string',
  packres = 'boolean', rest2 = 'number', poses = 'string', packshow = 'boolean', rpmadj = 'boolean',
  rpmbase = 'string', slot = 'number', resmax = 'number' }
local function read_learned(t)
  local kept, dropped = 0, 0
  for kind, want in pairs(LEARNED_SHAPE) do
    local src = t[kind]
    if type(src) == 'table' then
      local out = {}
      for id, v in pairs(src) do
        local ok = type(id) == 'string' and string.find(id, '^%x%x%x%x%x%x%x%x$') ~= nil and type(v) == want
        if ok and want == 'number' then ok = v == v and v > -1e9 and v < 1e9 end
        if ok then out[id], kept = v, kept + 1 else dropped = dropped + 1 end
      end
      learned[kind] = out
    elseif src ~= nil then
      dropped = dropped + 1
    end
  end
  return kept, dropped
end
do
  local ok, t, why = pcall(function() return chef.load_table and chef.load_table('learned') end)
  if not ok then
    log('learned file: could not be read (%s): starting from the shipped knowledge', tostring(t))
  elseif type(t) == 'table' then
    local kept, dropped = read_learned(t)
    local v = tonumber(t._v) or 0
    if v > LEARNED_VERSION then log('learned file: from a newer NarrowHUD (version %d): read what fits', v) end
    if dropped > 0 then log('learned file: %d entries kept, %d that didn\'t fit dropped', kept, dropped) end
  elseif why and not string.find(tostring(why), 'no such file') and not string.find(tostring(why), 'missing') then
    log('learned file: not read (%s): starting from the shipped knowledge', tostring(why))
  end
end
local function save_learned()
  if not chef.save_table then return end
  local t = { _v = LEARNED_VERSION }
  for k, v in pairs(learned) do t[k] = v end
  local ok, done, why = pcall(chef.save_table, 'learned', t)
  if not ok or done == false then log('learned file: not saved (%s)', tostring(ok and why or done)) end
end
-- hand poses measured in our own research rounds (2026-10-24);
-- anything else is learned on its first shot
local SEED_GRIPS = { ['8fcdd35c'] = 10, ['30294946'] = 10, ['17b02218'] = 80, ['a4eff4fa'] = 52, ['17783758'] = 52,
                     ['56e55184'] = 70, ['f94a73b3'] = 1 }
-- the shipped starting knowledge (src/learned_seed.lua): under what this game learned, theirs wins
local function apply_seed(only)
  for id, g in pairs(SEED_GRIPS) do if (only == nil or only == id) and learned.grip[id] == nil then learned.grip[id] = g end end
  for kind, tbl in pairs(SEED or {}) do
    if type(tbl) == 'table' and learned[kind] then
      for id, v in pairs(tbl) do
        if (only == nil or only == id) and learned[kind][id] == nil then learned[kind][id] = v end
      end
    end
  end
end
apply_seed()
-- Heat weapons whose heat goes past 100 (the player, 2026-10-25): the Double-Edge Sickle heats to 200, hurts you from
-- 50, more from 100, a lot from 180. Marks (heat, colour: 1 yellow, 2 orange, 3 red). Not a charge weapon (its first
-- shots were once taken for a charge).
local HEAT_RANGE = { ['960653cb'] = { top = 200, marks = { { 50, 1 }, { 100, 2 }, { 180, 3 } } } }
-- Charge weapons (the heat jumps once a charge is held to full): only these. Learning which weapons charge took
-- lasers for them (the Double-Edge Sickle, the Dagger: a burst seen in one read looks like a charge's jump), so the
-- list is fixed; the time is still refined from play. The Nova 1.6 s (timed in game), the Quasar 3 s (learned).
local CHARGE_WEAPONS = { ['17783758'] = 1.6, ['366d3622'] = 3 }
for id in pairs(learned.charge2) do if not CHARGE_WEAPONS[id] then learned.charge2[id] = nil end end
for id, secs in pairs(CHARGE_WEAPONS) do if learned.charge2[id] == nil then learned.charge2[id] = secs end end
if learned.rest2['17783758'] == nil then learned.rest2['17783758'] = 5 end       -- and it cools to about 5 (seen)
local dirty_at = nil
local function learn(kind, id, value)
  if learned[kind][id] == value then return end
  learned[kind][id] = value
  dirty_at = dirty_at or (chef.time() + 5)
end
-- Forgetting (two keys in the F9 menu, none set by default): the weapon in hand, or everything (pressed twice within
-- 3 s). What's forgotten falls back to the shipped knowledge.
local function forget_type(id)
  for kind in pairs(learned) do learned[kind][id] = nil end
  apply_seed(id)
  dirty_at = chef.time()
end
local function forget_all()
  for kind in pairs(learned) do learned[kind] = {} end
  apply_seed()
  dirty_at = chef.time()
end
local keys = {}
if chef.bind and chef.has and chef.has('bind') then
  pcall(function()
    -- (as bound in the game: NarrowHUD can't read the game's own key settings). The fire button's row, then the key
    -- it can be (used only when the row says so: shown as none otherwise)
    cfg.fire = chef.option('fire', { type = 'choice', label = 'Fire button (as bound in the game)', choices = { 'Left mouse', 'Right mouse', 'Middle mouse', 'Mouse button 4', 'Mouse button 5', 'A keyboard key (next row)' }, default = 1 }) or 1
    chef.on_change('fire', function(v) cfg.fire = v or 1 end)
    keys.fire = (chef.bind('fire_key', 'off', '   Fire on a keyboard key: which (only with "A keyboard key" above)'))
    -- (each in parentheses: chef.bind gives the binding and its menu row, and a call last in a table would add both)
    local sw = { (chef.bind('swap_primary', '1', 'Swap key: primary (as in the game)')),
                 (chef.bind('swap_secondary', '2', 'Swap key: secondary (as in the game)')),
                 (chef.bind('swap_support', '3', 'Swap key: support weapon (as in the game)')) }
    if sw[1] and sw[2] and sw[3] then keys.swap = sw end
    keys.forget_weapon = (chef.bind('forget_weapon', 'off', 'Forget what\'s learned about the weapon in hand'))
    keys.forget_all = (chef.bind('forget_all', 'off', 'Forget everything learned (press twice)'))
  end)
end

-- A weapon can have several hand poses (with a shield in the other hand: the Verdict at 1, 30 and 36): a set per type
-- ("10,30"), next to the single pose older versions kept (learned.grip).
local distrust = {}                                 -- types with an object that fired without your fire button
-- A type learned for 4 or more hand poses that didn't ship with NarrowHUD isn't a weapon of yours: every real one
-- has 1 to 3 (the Verdict's 3, with a shield). As host, SEAF soldiers' guns got learned for every pose you fired at
-- (a 2026-10-25 log: five types, up to 7 poses each). Never in your hand from then on.
local many_said = {}
local function many_poses(id)
  local l = learned.poses[id]
  if not l or (SEED and ((SEED.poses and SEED.poses[id]) or (SEED.grip and SEED.grip[id]))) or SEED_GRIPS[id] then return false end
  local n = 1
  for _ in string.gmatch(l, ',') do n = n + 1 end
  if n < 4 then return false end
  if not many_said[id] then
    many_said[id] = true
    log('type %s: learned for %d hand poses (%s): not a weapon of yours (a SEAF soldier\'s?), never shown', id, n, l)
  end
  return true
end
local function has_pose(id, grip)
  if not HANDHELD[id] or many_poses(id) then return false end
  if learned.grip[id] == grip then return true end
  local l = learned.poses[id]
  return l ~= nil and string.find(',' .. l .. ',', ',' .. grip .. ',', 1, true) ~= nil
end
local function add_pose(id, grip)
  if has_pose(id, grip) or not HANDHELD[id] or many_poses(id) then return end
  local l = learned.poses[id]
  if learned.grip[id] and not l then l = tostring(learned.grip[id]) end
  learn('poses', id, l and (l .. ',' .. grip) or tostring(grip))
end
local function forget_poses(id)
  learn('grip', id, nil)
  learn('poses', id, nil)
end

------------------------------------------------------------------------------------------------ your objects
local objs, queue = {}, {}       -- goid -> { t = index | false, next = n }; goids to type
local me = { player = nil, avatar = nil }
local BUDGET = 1000              -- type tests a frame
forget = function(goid) objs[goid] = nil checked[goid] = nil end

-- The order types are tried in: as host you own every soldier's and enemy's objects (thousands in a big mission), and
-- each object that's nothing of ours is tried against every type, so ours come first: the player and Helldiver, the
-- weapons known to have a hand pose, backpacks and special packs, the other weapons; the other carried things (research
-- log only) in a second pass, after every object has had its first. (A 46 s mission ended before the weapons were
-- reached when every object went through all 775 types in one pass.)
local ORDER_A, ORDER_2, ORDER_B = nil, nil, nil
local queue_2, queue_b = {}, {}
local function orders()
  if ORDER_A then return end
  local groups = { {}, {}, {}, {}, {} }
  for i, t in ipairs(TYPES) do
    local g
    if t.player or t.avatar then g = 1
    elseif not t.pack and not t.other and (learned.grip[t.id] or learned.poses[t.id]) then g = 2
    elseif t.pack or t.special then g = 3
    elseif not t.other then g = 4
    else g = 5 end
    local l = groups[g]
    l[#l + 1] = i
  end
  -- three passes: what's likely ours (player, Helldiver, weapons with a known pose, packs), the other weapons, the rest
  ORDER_A, ORDER_2, ORDER_B = {}, groups[4], groups[5]
  for g = 1, 3 do for _, i in ipairs(groups[g]) do ORDER_A[#ORDER_A + 1] = i end end
end
local classify_said = {}
local function classify_list(s, list, order, budget, on_miss)
  while budget > 0 and #list > 0 do
    local goid = list[#list]
    local o = objs[goid]
    if o == nil or o.t ~= nil then
      list[#list] = nil
    else
      o.next = o.next or 1
      if o.next == 1 and order == ORDER_A and not alive(s, goid, nil) then o.t = false o.next = #order + 1 budget = budget - 1 end
      while o.next <= #order and budget > 0 do
        local t = TYPES[order[o.next]]
        budget = budget - 1
        local r = not t.gone and call(t.id, 'GameSession.game_object_is_type', s, goid, t.name) or false
        if r == true then
          o.t = order[o.next] blocked.yes = true
          -- (research: a weapon that turns up later in the mission: a pick-up, a resupply, or a SEAF reinforcement's)
          local wt = TYPES[o.t]
          if cfg.research and HANDHELD[wt.id] and not wt.pack and not wt.player and not wt.avatar and not wt.other and blocked.since
             and o.seen_at and o.seen_at - blocked.since > 30 and (blocked.new_said or 0) < 300 then
            blocked.new_said = (blocked.new_said or 0) + 1
            log('research: new weapon object %s, type %s, %.0f s into the mission: carry=%s owner=%s held=%s%s', tostring(goid), wt.id,
              o.seen_at - blocked.since, tostring(wt.has.carry and field(s, goid, wt, 'carry')),
              tostring(wt.has.owner and field(s, goid, wt, 'owner')), tostring(wt.has.held and field(s, goid, wt, 'held')),
              o.host and ' (the host\'s)' or '')
          end
          break
        end
        if r == nil then blocked.types = (blocked.types or 0) + 1 end
        o.next = o.next + 1
      end
      if o.t == nil and o.next > #order then
        list[#list] = nil
        if on_miss then on_miss(goid, o) else o.t = false end
      elseif o.t ~= nil then
        list[#list] = nil
      end
    end
  end
  return budget
end
local function classify(s)
  orders()
  local w = chef.world_id and chef.world_id()
  if w ~= classify_said.wid then classify_said.wid, classify_said.t0 = w, chef.time() end
  local budget = classify_list(s, queue, ORDER_A, BUDGET, function(goid, o) o.next = 1 queue_2[#queue_2 + 1] = goid end)
  if #queue == 0 and budget > 0 then
    budget = classify_list(s, queue_2, ORDER_2, budget, function(goid, o)
      if #ORDER_B > 0 then o.next = 1 queue_b[#queue_b + 1] = goid else o.t = false end
    end)
  end
  if #queue == 0 and #queue_2 == 0 and next(objs) ~= nil then
    local wid = chef.world_id and chef.world_id()
    if wid and not classify_said[wid] and chef.in_mission() then
      classify_said[wid] = true
      local n, known = 0, 0
      for _, o in pairs(objs) do n = n + 1 if o.t then known = known + 1 end end
      log('objects sorted: %d of yours, %d of them known types (%.1f s into this world)', n, known, chef.time() - (classify_said.t0 or 0))
    end
    if budget > 0 then classify_list(s, queue_b, ORDER_B, budget) end
  end
end

-- an owner field's value as a peer id: lower-case hex without leading zeros (its format is still being checked)
local function as_peer(v)
  if type(v) == 'string' then return (string.gsub(string.lower(v), '^0+', '')) end
  return nil
end
local session = { host = nil, peer = nil, mine = 0, hosts = 0 }
local function scan(s, peer)
  local ids, why = call('owned', 'GameSession.objects_owned_by', s, peer)
  if type(ids) ~= 'table' then
    blocked.n = blocked.n + 1
    if blocked.n == 5 and not blocked.said then
      blocked.said = true
      log('GameSession.objects_owned_by refused (%s): your weapons can\'t be read with this Chef version', tostring(why))
    end
    return
  end
  blocked.n = 0
  -- in someone else's game the host may own your weapons: theirs too, kept only where the owner field says you
  local host = call('host', 'GameSession.game_session_host', s)
  session.host, session.peer = host, peer
  local hids = (host ~= nil and host ~= peer) and call('owned_host', 'GameSession.objects_owned_by', s, host) or nil
  local now = {}
  session.mine, session.hosts = 0, 0
  for _, goid in pairs(ids) do
    now[goid] = true
    session.mine = session.mine + 1
    if objs[goid] == nil then objs[goid] = { seen_at = chef.time() }; queue[#queue + 1] = goid end
  end
  if type(hids) == 'table' then
    for _, goid in pairs(hids) do
      if not now[goid] then
        now[goid] = true
        session.hosts = session.hosts + 1
        if objs[goid] == nil then objs[goid] = { host = true, seen_at = chef.time() }; queue[#queue + 1] = goid end
      end
    end
  end
  for goid in pairs(objs) do if not now[goid] then objs[goid] = nil end end
  me.player = nil
  for goid, o in pairs(objs) do
    if o.t == 1 then me.player = goid end
  end
  if me.player and alive(s, me.player, TYPES[1]) then
    local a = call('player.avatar', 'GameSession.game_object_field', s, me.player, DATA.player.avatar)
    me.avatar = (type(a) == 'number' and a ~= NO_OBJECT) and a or nil
  else
    me.avatar = nil
  end
  -- which weapons and backpacks are on you (types with a carry field: carried when it's a multiple of 4)
  for goid, o in pairs(objs) do
    local t = o.t and TYPES[o.t]
    if t and (t.pack or (not t.player and not t.avatar)) then
      if t.has.carry then
        local c = field(s, goid, t, 'carry')
        o.on = type(c) == 'number' and c % 4 == 0
        -- A backpack's carry field (the 2026-10-25 log): 0 worn, 1 in its hellpod, 2 dropped. One that isn't yours
        -- (a mission objective's, a soldier's: as host you own those) can read 0 too. A called backpack can't be
        -- worn in a mission's first 10 s (the call-in alone takes 10 s, after landing), so one already at 0 then
        -- isn't yours, until it's seen at another value (dropped, then picked up) or proves yours.
        if t.pack and type(c) == 'number' then
          if o.first_c == nil then
            o.first_c = c
            o.map_pack = c == 0 and blocked.since ~= nil and chef.time() - blocked.since < 10
            if o.map_pack and cfg.research then log('research: backpack %s (object %s) there from the start: not yours until used', t.id, tostring(goid)) end
          elseif c ~= o.first_c then
            o.map_pack = false
          end
        end
        -- (research: a backpack's carry value and ammo as they change, to tell one on your back from one in its pod
        -- or on the ground)
        if cfg.research and t.pack and c ~= o.carry_said then
          o.carry_said = c
          log('research: backpack %s (object %s): carry=%s remaining=%s owner=%s', t.id, tostring(goid), tostring(c),
            tostring(t.has.remaining and field(s, goid, t, 'remaining')), tostring(t.has.owner and field(s, goid, t, 'owner')))
        end
      else
        o.on = true
      end
      if o.host then
        local ow = t.has.owner and as_peer(field(s, goid, t, 'owner'))
        o.on = o.on and ow ~= nil and ow == as_peer(peer)
      end
    end
  end
  -- underbarrels (the Stoker's flamethrower, the Arbitrator's shotgun): their own objects, on your body too, but shown
  -- only through their rifle (when its fire mode selects them), never picked or learned as a weapon of their own
  for _, o in pairs(objs) do o.ub = nil end
  for goid, o in pairs(objs) do
    local t = o.t and TYPES[o.t]
    if t and o.on and t.has.underbarrel and not t.pack then
      local ub = field(s, goid, t, 'underbarrel')
      local uo = type(ub) == 'number' and ub ~= NO_OBJECT and objs[ub]
      if uo then
        uo.ub = true
        local ut = uo.t and TYPES[uo.t]
        if ut and (learned.grip[ut.id] ~= nil or learned.poses[ut.id] ~= nil) then
          log('type %s is an underbarrel: its hand pose forgotten', ut.id)
          forget_poses(ut.id)
        end
      end
    end
  end
end

------------------------------------------------------------------------------------------------ your hand pose
local watch = chef.watch and chef.watch({ [AVATAR_RESOURCE] = true }, 2) or nil
local grip_index = setmetatable({}, { __mode = 'k' })
local function my_unit()
  if not watch or not watch.items or #watch.items == 0 then return nil end
  if #watch.items == 1 then return watch.items[1].unit end
  local cam = chef.camera()
  if not cam then return nil end
  local best, bd = nil, nil
  for _, it in ipairs(watch.items) do
    local dx, dy, dz = it.x - cam.x, it.y - cam.y, it.z - cam.z
    local d = dx * dx + dy * dy + dz * dz
    if bd == nil or d < bd then best, bd = it.unit, d end
  end
  return best
end
-- Your fire button (the left mouse button), read every frame: as host you own every soldier's objects too (SEAF
-- troops' rifles ...), and their shots look like yours. A shot counts as yours only within 0.4 s of your fire button;
-- an object that fires three times without it is someone else's for the rest of the session. (0.3.5 tried the
-- weapons' position field instead: it isn't where a carried weapon is.)
-- A controller's right trigger counts too: R2 on a PlayStation pad.
--
-- The controllers: every pad the engine has (Pad1 to Pad8) that's active or connected, its buttons found by the names
-- the pad lists itself (num_buttons, button_name), so no button name a pad doesn't know is asked about. Looked for
-- every 2 s until one turns up, and again when one goes. A pad that doesn't list its buttons: the Xbox names on Pad1,
-- as before 1.0.2.
local PAD_FIRE = { 'right_trigger', 'r2', 'trigger_right', 'rt' }
local PAD_SWAP = { 'y', 'triangle' }
local pads = { list = nil, look_at = -100, said = false }
local function pad_list(now)
  if pads.list and now < pads.look_at then return pads.list end
  pads.look_at = now + 2
  local list = {}
  for n = 1, 8 do
    local p = 'Pad' .. n
    if call('pad', p .. '.active') == true or call('pad', p .. '.connected') == true then
      local count, by = call('pad', p .. '.num_buttons'), {}
      if type(count) == 'number' and count > 0 and count <= 64 then
        for i = 0, count - 1 do
          local nm = call('pad', p .. '.button_name', i)
          if type(nm) == 'string' and nm ~= '' then by[nm:lower()] = i end
        end
      end
      local e = { name = p, listed = next(by) ~= nil }
      for _, c in ipairs(PAD_FIRE) do if by[c] then e.fire = by[c] break end end
      for _, c in ipairs(PAD_SWAP) do if by[c] then e.swap = by[c] break end end
      if e.fire or e.swap then list[#list + 1] = e end
    end
  end
  if #list == 0 then
    -- (no pad listed its buttons: the Xbox names on the first one)
    local f, y = call('pad', 'Pad1.button_index', 'right_trigger'), call('pad', 'Pad1.button_index', 'y')
    if type(f) == 'number' or type(y) == 'number' then
      list[1] = { name = 'Pad1', fire = type(f) == 'number' and f or nil, swap = type(y) == 'number' and y or nil }
    end
  end
  for _, e in ipairs(list) do e.button, e.pressed = e.name .. '.button', e.name .. '.pressed' end
  if #list > 0 and not pads.said then
    pads.said = true
    local d = {}
    for _, e in ipairs(list) do d[#d + 1] = string.format('%s (fire %s, swap %s%s)', e.name, tostring(e.fire), tostring(e.swap), e.listed and '' or ', not listed') end
    log('controller: %s', table.concat(d, '; '))
  end
  -- (still there: looked at again in 10 s, for one plugged in or swapped)
  if #list > 0 then pads.look_at = now + 10 end
  pads.list = list
  return list
end
local input = { ok = nil, last = -100, pad_said = false }
local function read_fire_button(now)
  if input.ok == false then return end
  local v = nil
  if cfg.fire == 6 then
    v = keys.fire and keys.fire.down and (keys.fire.down() == true and 1 or 0) or nil
  else
    local name = MOUSE_BUTTONS[cfg.fire] or 'left'
    if input.idx_name ~= name then
      input.idx_name, input.idx = name, call('mouse', 'Mouse.button_index', name)
      if type(input.idx) ~= 'number' then log('fire button: mouse button %s not known to the game', name) end
    end
    v = type(input.idx) == 'number' and call('mouse', 'Mouse.button', input.idx) or nil
  end
  local pv = nil
  for _, p in ipairs(pad_list(now)) do
    if p.fire then
      local x = call('pad', p.button, p.fire)
      if x == true then x = 1 end
      if type(x) == 'number' and (pv == nil or x > pv) then pv = x end
    end
  end
  if type(v) ~= 'number' and type(pv) ~= 'number' then
    if input.ok == nil then input.ok = false log('fire button: not readable (%s), shots aren\'t checked against it', tostring(v)) end
    return
  end
  if input.ok == nil then input.ok = true end
  if type(v) == 'number' and v > 0.5 then input.last, input.ever = now, true end
  if type(pv) == 'number' and pv > 0.3 then
    input.last, input.ever = now, true
    if not input.pad_said then input.pad_said = true log('fire button: a controller\'s right trigger seen') end
  end
end
-- (blind: your weapon in hand keeps firing and no fire input of any kind has been seen for a while: a controller
-- NarrowHUD can't read. Shots aren't checked from then on, as when nothing can be read)
local function pressed_recently(now) return input.ok ~= true or input.blind or now - input.last <= 0.4 end
local function hand_pose()
  local u = my_unit()
  if u == nil or chef.unit_alive(u) ~= true then return nil end
  local idx = grip_index[u]
  if idx == nil then
    if call('asm', 'Unit.has_animation_state_machine', u) ~= true then return nil end
    if call('hasvar', 'Unit.animation_has_variable', u, GRIP_VARIABLE) ~= true then return nil end
    idx = call('findvar', 'Unit.animation_find_variable', u, GRIP_VARIABLE)
    if type(idx) ~= 'number' then return nil end
    grip_index[u] = idx
  end
  local v = call('getvar', 'Unit.animation_get_variable', u, idx)
  if type(v) ~= 'number' then return nil end
  return math.floor(v + 0.5)
end

------------------------------------------------------------------------------------------------ the weapon in hand
-- read a weapon's state; o.prev keeps the last one, to see it fire
local function read_weapon(s, goid, t)
  local w = { t = t }
  if not alive(s, goid, t) then w.gone = true return w end
  for _, role in ipairs({ 'rounds', 'magazines', 'slot0', 'slot1', 'selected', 'chamber', 'spare', 'heat',
                          'overheated', 'charging', 'reload_stage', 'fire_mode', 'rpm', 'options', 'held', 'guide' }) do
    if t.has[role] then w[role] = field(s, goid, t, role) end
  end
  return w
end
local function fired(prev, w)
  if prev == nil then return false end
  local function down(k) return type(prev[k]) == 'number' and type(w[k]) == 'number' and w[k] < prev[k] end
  if down('rounds') or down('slot0') or down('slot1') then return true end
  if prev.chamber == false and w.chamber == true then return true end   -- the chambered one left (a single shell, a C4)
  if type(prev.heat) == 'number' and type(w.heat) == 'number' and w.heat > prev.heat + 0.5 then return true end
  if w.charging == true and prev.charging ~= true then return true end
  return false
end

-- your backpack's ammo (the first one on you that has it)
-- your backpack: as host you own the SEAF troops' backpacks too, so the one proven yours (it went down with your
-- reload or your fire), else the only one there is
-- The Helldiver (avatar) has six fields that hold another object's id (research log only). In the 2026-10-25 log none
-- held the backpack: cf55c86e holds your player, 20efbed4 what you're looking at or near (it flicks between nearby
-- objects), 913af9a2 and 0c09236b two objects not among yours, the other two nothing.
local AV_REFS = {}
for id, name in string.gmatch(DATA.avatar.refs or '', '(%x+):(%S+)') do AV_REFS[#AV_REFS + 1] = { id = id, name = name } end
local av_refs = {}                                   -- the fields' values, read with the grenades and stims
local av_said = {}                                   -- (research lines per field this world: at most 60)
local function read_av_refs(s)
  for _, r in ipairs(AV_REFS) do
    local v = call('avatar.' .. r.id, 'GameSession.game_object_field', s, me.avatar, r.name)
    if cfg.research and v ~= av_refs[r.id] and (av_said[r.id] or 0) < 60 then
      av_said[r.id] = (av_said[r.id] or 0) + 1
      local o = type(v) == 'number' and objs[v]
      log('research: avatar field %s holds %s (%s)', r.id, tostring(v),
        o and o.t and (TYPES[o.t].id .. (TYPES[o.t].pack and ', a backpack' or '') .. (o.on and ', on you' or '')) or 'nothing of yours')
    end
    av_refs[r.id] = v
  end
end
local function pack_ammo(s)
  local only, n, mine = nil, 0, nil
  local me_peer = as_peer(session.peer)
  for pgoid, o in pairs(objs) do
    local pt = o.t and TYPES[o.t]
    -- (a pack's owner field, where it can be read, must be you: other players' and soldiers' packs aren't)
    local ow = pt and pt.pack and o.on and pt.has.owner and me_peer and as_peer(field(s, pgoid, pt, 'owner'))
    -- (and not one worn by something since the mission started, unless it proved yours or you've moved it)
    if pt and pt.pack and o.on and pt.has.remaining and (ow == nil or ow == me_peer)
       and not (o.map_pack and not o.mine) then
      if o.mine then mine = pgoid end
      only, n = pgoid, n + 1
    end
  end
  local pgoid = mine or (n == 1 and only) or nil
  -- (gone in the meantime: an owner read found it gone and forgot it)
  if not pgoid or not objs[pgoid] or not objs[pgoid].t then return nil end
  local pt = TYPES[objs[pgoid].t]
  local r = field(s, pgoid, pt, 'remaining')
  if type(r) == 'number' then return r, pgoid end
  return nil
end
-- every pack's ammo, to tell which one went down
local function packs_now(s)
  local l = {}
  for pgoid, o in pairs(objs) do
    local pt = o.t and TYPES[o.t]
    if pt and pt.pack and o.on and pt.has.remaining then l[pgoid] = field(s, pgoid, pt, 'remaining') end   -- (all, to watch)
  end
  return l
end

local hand = { goid = nil, grip = nil, said = nil }
-- With a shield the hand pose is the shield's (30, 36) whichever one-handed weapon is out, so the pose can't tell two of
-- them apart. The swap keys can: 1, 2 and 3 (the game's default binds for primary, secondary and support) and the
-- mouse wheel. Which key a weapon is on is learned when the key brings it out where the pose does tell (learned.slot).
local SWAP_KEYS = { '1', '2', '3' }
local swap = { key = nil, at = -100, used = true, from = nil }
local function read_swap(now)
  local key = nil
  if keys.swap then
    for i, b in ipairs(keys.swap) do
      if type(b) == 'table' and b.pressed and b.pressed() == true then key = i end
      local name = type(b) == 'table' and b.key and b.key()
      if type(name) == 'string' then SWAP_KEYS[i] = name end
    end
  elseif chef.key_pressed then
    for i, k in ipairs(SWAP_KEYS) do if chef.key_pressed(k) == true then key = i end end
  end
  if key == nil and chef.wheel then
    local w = chef.wheel()
    if type(w) == 'number' and w ~= 0 then key = 'wheel' end
  end
  -- a controller's weapon swap (Y, triangle on a PlayStation pad: the game's default): the other weapon, like the wheel
  if key == nil then
    for _, p in ipairs(pad_list(now)) do
      if p.swap and call('pad', p.pressed, p.swap) == true then key = 'wheel' end
    end
  end
  if key ~= nil then swap.prev_at, swap.key, swap.at, swap.used, swap.from = swap.at, key, now, false, hand.goid end
end
local research_watch                                -- (defined with the research log, below)
-- (research: the HUD going from one object to another on the same hand pose: both, to see how a soldier's gun gets in)
local switch_said = 0
local function research_switch(s, from, to, grip, now)
  if switch_said >= 200 then return end
  switch_said = switch_said + 1
  local function about(goid)
    local o = objs[goid]
    local t = o and o.t and TYPES[o.t]
    if not t then return tostring(goid) .. ' (gone)' end
    local refs = {}
    for id, v in pairs(av_refs) do if v == goid then refs[#refs + 1] = id end end
    return string.format('%s (object %s, first seen %s s in%s): carry=%s owner=%s held=%s, %d / %d shots with / without your fire button, fired %.1f s ago, avatar fields: %s',
      t.id, tostring(goid), o.seen_at and blocked.since and string.format('%.0f', o.seen_at - blocked.since) or '?', o.host and ', the host\'s' or '',
      tostring(t.has.carry and field(s, goid, t, 'carry')), tostring(t.has.owner and field(s, goid, t, 'owner')),
      tostring(t.has.held and field(s, goid, t, 'held')), o.pressed or 0, o.unpressed or 0, now - (o.fired_at or 0),
      #refs > 0 and table.concat(refs, ',') or 'none')
  end
  log('research: hand pose %d switched from %s to %s (fire button %.1f s ago, swap %.1f s ago)', grip, about(from), about(to),
    now - (input.last or -100), now - (swap.at or -100))
end
local HOLD_FIRST = { ['26acc614'] = true, ['314a1bf5'] = true }   -- (the Railgun, the Epoch: charged first)
local function pick(s, grip, now)
  now = now or chef.time()
  if grip == nil or grip == 0 or THROWABLE[grip] then return nil end   -- grenades and stratagems: no weapon
  local same, unknown, last = {}, {}, nil
  for goid, o in pairs(objs) do
    local t = o.t and TYPES[o.t]
    if t and HANDHELD[t.id] and not t.pack and not t.player and not t.avatar and not t.other and o.on and not o.ub
       and not o.notmine then
      if has_pose(t.id, grip) then same[#same + 1] = goid
      elseif learned.grip[t.id] == nil and learned.poses[t.id] == nil then unknown[#unknown + 1] = goid end
    end
  end
  -- the one fired or swapped to last; none yet (a mission's start): the lowest swap key, the primary first
  local function newest(list)
    local best, bt, bk = list[1], -1, 99
    for _, goid in ipairs(list) do
      local f = math.max(objs[goid].fired_at or 0, objs[goid].chosen_at or 0)
      local key = learned.slot[TYPES[objs[goid].t].id] or 9
      if f > bt or (f == bt and key < bk) then best, bt, bk = goid, f, key end
    end
    return best
  end
  if #same > 1 then
    -- a weapon fed from the backpack sharing a pose with a weapon of its own ammo: the fed one was learned wrongly
    -- (a backpack reload taken for its shot); its pose is forgotten
    local own = {}
    for _, goid in ipairs(same) do
      local t = TYPES[objs[goid].t]
      if not t.fed then own[#own + 1] = goid end
    end
    if #own > 0 and #own < #same then
      for _, goid in ipairs(same) do
        local t = TYPES[objs[goid].t]
        if t.fed then log('type %s: its hand pose %d forgotten (shared with a weapon of its own)', t.id, grip) forget_poses(t.id) end
      end
      same = own
    end
  end
  local alone = #same == 1                    -- (the pose is one weapon's: a key that brings it out can be learned)
  if #same > 1 then
    -- of a type someone else's has fired this session (a soldier's), only the one proven yours; the rest stay (two
    -- of your weapons on one pose: 0.4.13 kept only the one fired more, so swapping between them changed nothing)
    local keep = {}
    for _, goid in ipairs(same) do
      local o = objs[goid]
      if o.mine or not distrust[TYPES[o.t].id] then keep[#keep + 1] = goid end
    end
    if #keep > 0 then same = keep end
  end
  local recent = not swap.used and now - swap.at < 3
  if #same == 1 and alone and recent and type(swap.key) == 'number' and same[1] ~= swap.from then
    -- the key brought out a weapon the pose tells apart: that weapon is on that key
    -- (not after two keys in quick succession: the weapon may be the first key's; a weapon already on another key
    -- moves only when seen twice on the new one)
    local id = TYPES[objs[same[1]].t].id
    local k = learned.slot[id]
    if k ~= nil and k ~= swap.key then
      -- another key brought this weapon's pose up: something with the same pose NarrowHUD doesn't know is in hand
      -- (the Solo Silo's remote: held like a pistol, on key 3, the Warrant's pose). It isn't shown until the pose
      -- changes or it fires (then it is on that key after all)
      hand.mask = { goid = same[1], grip = grip, at = now, key = swap.key }
      if cfg.research then log('research: key %s brought up hand pose %d, %s\'s (on key %s): something else in hand', SWAP_KEYS[swap.key], grip, id, SWAP_KEYS[k]) end
    elseif k == nil and swap.at - (swap.prev_at or -100) >= 1.5 then
      log('learned: type %s is on swap key %s', id, SWAP_KEYS[swap.key])
      learn('slot', id, swap.key)
    end
    swap.used = true
  elseif #same > 1 and recent then
    -- several of your weapons share this pose (a shield's): the swap key or the wheel says which came out
    local cur = hand.goid
    local chosen = nil
    if type(swap.key) == 'number' then
      for _, goid in ipairs(same) do
        if learned.slot[TYPES[objs[goid].t].id] == swap.key then chosen = goid end
      end
      if chosen == nil and #same == 2 then
        -- not learned yet: the one not in hand, unless that one is known to be on another key
        for _, goid in ipairs(same) do
          local k = learned.slot[TYPES[objs[goid].t].id]
          if goid ~= cur and (k == nil or k == swap.key) then chosen = goid end
        end
      end
    elseif #same == 2 then
      for _, goid in ipairs(same) do if goid ~= cur then chosen = goid end end
    end
    if chosen then
      objs[chosen].chosen_at = now
      swap.chosen, swap.chosen_at = chosen, now
      if cfg.research then
        log('research: swap %s at hand pose %d (%d weapons share it): %s', type(swap.key) == 'number' and ('key ' .. SWAP_KEYS[swap.key]) or 'wheel',
          grip, #same, TYPES[objs[chosen].t].id)
      end
    end
    swap.used = true
  end
  -- (a weapon masked by a key not its: hidden while its pose stays up and it hasn't fired since)
  local m = hand.mask
  if m then
    local mo = objs[m.goid]
    -- (gone with the pose, a shot from it, or its own key pressed since)
    local own_key = mo and mo.t and swap.at > m.at and learned.slot[TYPES[mo.t].id] == swap.key
    if grip ~= m.grip or not mo or (mo.fired_at or 0) > m.at or own_key then
      hand.mask = nil
    else
      for i = #same, 1, -1 do if same[i] == m.goid then table.remove(same, i) end end
    end
  end
  -- Sticky: while you fire, the weapon in your hand fires (or its trigger reads held). Another object on the same pose
  -- (as host: a SEAF soldier's gun of the same kind, firing as you fire) takes the HUD over only when the pose
  -- changed, a swap key or the wheel was used, the shown one is gone, or it showed nothing for half a second of
  -- your firing (a swap or pick-up NarrowHUD didn't see). Not while your fire button can't be read.
  local cur = hand.goid
  local co = cur and objs[cur]
  local dtp = math.min(0.5, math.max(0, now - (hand.pick_t or now)))
  hand.pick_t = now
  if cur ~= hand.unlock_goid then hand.unlock, hand.unlock_goid = 0, cur end
  -- (the shown one active: fired in the last 0.4 s, reloading, or for a weapon that's held before it fires (a charge,
  -- a lock-on, the Arc Thrower) its trigger held)
  local ct = co and co.t and TYPES[co.t]
  local holds = ct and (HOLD_FIRST[ct.id] or CHARGE_WEAPONS[ct.id] or ct.has.charging or ct.has.lock)
  local active = co and ((co.fired_at and now - co.fired_at <= 0.4) or (holds and co.held_t and now - co.held_t <= 0.4)
    or (co.prev and (tonumber(co.prev.reload_stage) or 0) ~= 0))
  if co and input.ok == true and not input.blind and now - input.last <= 0.15 then
    hand.unlock = active and 0 or (hand.unlock or 0) + dtp
  end
  if #same > 0 then
    local best = newest(same)
    -- (or the other one fired twice with your fire button while the shown one did nothing)
    local bo = best ~= cur and objs[best]
    if bo and bo.fired_at and bo.fired_at ~= hand.ch_at then
      hand.ch_at = bo.fired_at
      if hand.ch_goid ~= best then hand.ch_goid, hand.ch_n = best, 0 end
      if active or now - input.last > 0.5 then hand.ch_n = 0 else hand.ch_n = (hand.ch_n or 0) + 1 end
    end
    local proven = hand.ch_goid == best and (hand.ch_n or 0) >= 2
    -- (not for a shown type with no ammo of its own or fed from the backpack: those ride along with other weapons)
    if best ~= cur and co and ct and not ct.noammo and not ct.fed and grip == hand.grip and now - (swap.at or -100) >= 3
       and input.ok == true and not input.blind
       and (hand.unlock or 0) < 0.5 and not proven then
      for _, g in ipairs(same) do
        if g == cur then
          if cfg.research and hand.kept_from ~= best and (hand.kept_n or 0) < 100 then
            hand.kept_from, hand.kept_n = best, (hand.kept_n or 0) + 1
            local bo = objs[best]
            log('research: kept the weapon in hand %s (object %s) over %s (object %s, fired %.1f s ago, %d / %d shots with / without your fire button, first seen %s s into the mission): yours is firing',
              TYPES[co.t].id, tostring(cur), TYPES[bo.t].id, tostring(best), now - (bo.fired_at or 0), bo.pressed or 0, bo.unpressed or 0,
              bo.seen_at and blocked.since and string.format('%.0f', bo.seen_at - blocked.since) or '?')
          end
          return cur
        end
      end
    end
    return best
  end
  return nil   -- not learned yet: shown from its first shot
end

-- every on-body weapon, often: a weapon whose ammo or heat moves while a pose is up is the one in hand
-- Heat rates (per second, in the heat field's units, the game's degrees) of weapons that heat while firing, from the
-- Helldivers 2 wiki (helldivers.wiki.gg: LAS-5 Scythe, LAS-98 Laser Cannon; standard heatsink, neutral planet).
-- Others are learned from the field (which changes only every few seconds, so learned rates are rougher).
local WIKI_HEAT = {
  ['42a6b5ba'] = { up = 12.5, down = 8.5 },   -- LAS-5 Scythe
  d100e0c8 = { up = 8, down = 5 },            -- LAS-98 Laser Cannon
}
-- The planet changes how fast heat weapons cool (the wiki: Extreme Cold about x1.5, Intense Heat about x0.75). It isn't
-- read anywhere known, so it's measured: while cooling, the field's fall over the model's neutral rate, per world
-- (a mission), from the weapons with a wiki rate, the middle of the last five, snapped to 0.75 / 1 / 1.5 when within 12 %.
local planet = { wid = nil, factor = 1, samples = {} }
local function planet_factor()
  local wid = chef.world_id and chef.world_id()
  if wid ~= planet.wid then planet.wid, planet.factor, planet.samples = wid, 1, {} end
  return planet.factor
end
local function planet_sample(ratio)
  planet_factor()
  local l = planet.samples
  l[#l + 1] = ratio
  if #l > 5 then table.remove(l, 1) end
  if #l < 2 then return end
  local sorted = {}
  for i = 1, #l do sorted[i] = l[i] end
  table.sort(sorted)
  local f = sorted[math.floor((#sorted + 1) / 2)]
  for _, snap in ipairs({ 0.75, 1, 1.5 }) do
    if math.abs(f / snap - 1) < 0.12 then f = snap break end
  end
  f = math.floor(f * 100 + 0.5) / 100
  if f ~= planet.factor then
    log('planet cooling x%.2f%s', f, f == 1.5 and ' (cold)' or (f == 0.75 and ' (hot)' or (f == 1 and '' or ' (measured)')))
    planet.factor = f
  end
end
-- neutral rates: the wiki's, else learned (learned cooling is kept neutral: divided by the planet factor)
local function base_rate(kind, id)
  local w = WIKI_HEAT[id]
  return (w and w[kind]) or learned[kind][id]
end
local function heat_rate(kind, id)
  local r = base_rate(kind, id)
  if r and kind == 'down' then r = r * planet_factor() end
  return r
end
-- the trigger held, for heat: a charge weapon's "charging"; else the trigger-held field (else "charging")
local function firing_of(t, w)
  if learned.charge2[t.id] == nil and t.has.held then return w.held == true end
  return w.charging == true
end

local function loaded(w)
  local n = tonumber(w.rounds) or tonumber(w.slot0) or 0
  if w.slot1 then n = n + (tonumber(w.slot1) or 0) end
  if w.chamber == false then n = n + 1 end
  return n
end

local pack_prev, pack_vals = nil, {}
local recent = { reload_t = -100, reload_t_type = nil, pack_drop_t = -100 }
local pending_learn = {}
local busy_said = 0
local function watch_fire(s, grip)
  -- last read's learning (see below): dropped for an object that fired while the weapon shown in hand did too
  if #pending_learn > 0 then
    local so = hand.goid and objs[hand.goid]
    local st = so and so.t and TYPES[so.t]
    for _, e in ipairs(pending_learn) do
      local busy = st and hand.goid ~= e.goid and so.fired_at and math.abs(so.fired_at - e.at) <= 0.4
        and has_pose(st.id, e.grip) and objs[e.goid] ~= nil
      if busy then
        if cfg.research and busy_said < 200 then
          busy_said = busy_said + 1
          log('research: not learned from %s (object %s) at hand pose %d: it fired as the weapon in hand (%s) did', e.t.id, tostring(e.goid), e.grip, st.id)
        end
      elseif objs[e.goid] then
        e.fn()
      end
    end
    pending_learn = {}
  end
  local any_fired = false
  local reloaded = {}
  for goid, o in pairs(objs) do
    local t = o.t and TYPES[o.t]
    if t and not t.pack and not t.player and not t.avatar and not t.other and o.on then
      local w = read_weapon(s, goid, t)
      if w.gone then break end                 -- forgotten (gone): the rest wait for the next read
      local now = chef.time()
      -- Heat: the field changes only now and then (the Quasar a few times a second, the Laser Cannon about every 3 s).
      -- The rates it rises at while the trigger is held ("charging") and falls at otherwise are learned per type, so
      -- the bar can run on between changes. A segment starts at the last change or at the trigger's last press or
      -- release, whichever came later.
      if type(w.heat) == 'number' then
        local firing = firing_of(t, w)
        if firing ~= o.firing then o.firing, o.state_t = firing, now end
        if w.heat ~= o.h_last then
          if o.h_last then
            local from = math.max(o.h_last_t or 0, o.state_t or 0)
            local r = (w.heat - o.h_last) / math.max(0.05, now - from)
            local up = w.heat > o.h_last
            if math.abs(r) < 200 and now - from > 0.15 then
              local kind = (up and firing) and 'up' or ((not up and not firing) and 'down' or nil)
              if kind == 'down' and o.h_last_t >= (o.state_t or 0) and o.h_fell_before then
                -- a whole interval of cooling: measures the planet (against the neutral rate) ...
                -- (only weapons whose neutral rate is known from the wiki, and not near where it rests)
                local base = WIKI_HEAT[t.id] and WIKI_HEAT[t.id].down
                if base and w.heat > (learned.rest2[t.id] or 0) + 2 then planet_sample(math.abs(r) / base) end
              end
              if kind and not (WIKI_HEAT[t.id] and WIKI_HEAT[t.id][kind]) then
                -- ... and the weapon's own rate, when the wiki has none (cooling kept neutral)
                local v = math.abs(r)
                if kind == 'down' then v = v / planet_factor() end
                local old = learned[kind][t.id]
                if old then v = old * 0.7 + v * 0.3 end
                learn(kind, t.id, math.floor(v * 10 + 0.5) / 10)
              end
            end
          end
          o.h_fell_before = o.h_last ~= nil and w.heat < o.h_last and not firing
          o.h_last, o.h_last_t = w.heat, now
        end
      end
      -- a charge (the Nova, the Quasar): the trigger held while the heat stays put, then the heat jumps (the shot).
      -- Weapons that heat up while firing (the Laser Cannon) are never charge weapons.
      if w.charging == true and (o.prev == nil or o.prev.charging ~= true) then o.charge_t0, o.charge_h0 = now, w.heat end
      if o.charge_t0 and o.prev and type(w.heat) == 'number' and type(o.prev.heat) == 'number'
         and w.heat > o.prev.heat + 5 then
        local took = now - o.charge_t0
        -- (a charged shot fills it, near the overheat point; a laser's heat seen late only steps part of the way)
        local full = w.overheated == true or w.heat >= (learned.heat[t.id] or 100) * 0.9
        if full and o.prev.heat == o.charge_h0 and took > 0.3 and took < 6 and CHARGE_WEAPONS[t.id] then
          learn('charge2', t.id, math.floor(took * 10 + 0.5) / 10)
        end
        o.charge_t0 = nil
      end
      if o.charge_t0 and type(w.heat) == 'number' and w.heat ~= o.charge_h0 and w.heat <= (o.prev and o.prev.heat or w.heat) + 5 then
        o.charge_t0 = nil                                  -- rising bit by bit while held: firing, not charging
      end
      -- the shot's heat can land a read or two after charging ends: forget the charge half a second after it ended
      if w.charging == true then o.charge_end = nil
      elseif o.charge_t0 then
        o.charge_end = o.charge_end or now
        if now - o.charge_end > 0.5 then o.charge_t0, o.charge_end = nil, nil end
      end
      -- where the heat comes to rest: after cooling it stayed put for 4.5 s (the field can sit unchanged for a few
      -- seconds mid-cooldown), low, not overheated or charging
      if type(w.heat) == 'number' and o.prev and o.prev.heat == w.heat then o.still = o.still or now else o.still = nil end
      if o.still and now - o.still >= 4.5 and o.cooling and w.overheated ~= true and w.charging ~= true
         and w.heat > 0 and w.heat < 15 then
        local r = math.floor(w.heat * 10) / 10
        -- (only ever lowered: a pause before cooling starts, or between the game's updates, can look like a rest)
        if learned.rest2[t.id] == nil or r < learned.rest2[t.id] then
          log('learned: type %s cools down to %.1f', t.id, r) learn('rest2', t.id, r)
        end
        o.cooling = false
      end
      if type(w.heat) == 'number' and o.prev and type(o.prev.heat) == 'number' then
        if w.heat < o.prev.heat then o.cooling = true elseif w.heat > o.prev.heat then o.cooling = false end
      end
      if o.prev and not w.gone and loaded(w) > loaded(o.prev) and goid == hand.goid then   -- (yours: the one in hand)
        reloaded[#reloaded + 1] = t
        recent.reload_t, recent.reload_t_type = now, t
        if cfg.research and objs[hand.goid or -1] == o then
          log('reload %s: rounds=%s magazines=%s slot0=%s slot1=%s selected=%s chamber=%s spare=%s', t.id,
            tostring(w.rounds), tostring(w.magazines), tostring(w.slot0), tostring(w.slot1), tostring(w.selected),
            tostring(w.chamber), tostring(w.spare))
        end
      end
      if (tonumber(w.reload_stage) or 0) ~= 0 and goid == hand.goid then recent.reload_t = now end
      -- the trigger: seen held within the last 0.6 s (for types whose trigger field has ever been seen held)
      if w.held == true then o.held_t, o.held_ever = now, true end
      local by_you = not t.has.held or not o.held_ever or (o.held_t and now - o.held_t <= 0.6)
      -- (a weapon whose trigger was never seen held can't take the hands from one whose trigger has been: the shown
      -- weapon keeps them while a dog's fires)
      if fired(o.prev, w) then
        -- the weapon in hand firing with no fire input seen in the last 20 s, twice: the fire input can't be read
        -- (never once a press was seen: then it can be read, and the weapon shown firing alone is someone else's: a
        -- SEAF soldier's gun, shown by mistake, set this off in a 1.0.2 log)
        if goid == hand.goid and not pressed_recently(now) and not input.ever and now - input.last > 20 then
          input.blind_shots = (input.blind_shots or 0) + 1
          if input.blind_shots >= 2 and not input.blind then
            input.blind = true
            log('fire button: your weapon fires with no fire button or trigger seen (a controller NarrowHUD can\'t read?): shots aren\'t checked from now on')
            o.unpressed, o.notmine, distrust[t.id] = 0, nil, nil
          end
        end
        -- (counted both ways: someone else's can fire just as you press)
        if pressed_recently(now) then o.pressed = (o.pressed or 0) + 1 else o.unpressed = (o.unpressed or 0) + 1 end
        local p, u = o.pressed or 0, o.unpressed or 0
        o.mine = p >= 2 and p > u
        if u >= 3 and u > p and not o.notmine then
          o.notmine = true
          distrust[t.id] = true
          if cfg.research then log('research: an object of type %s fires without your fire button: not yours', t.id) end
          if hand.goid == goid then hand.goid = nil end
        end
      end
      local shown_o = hand.goid and objs[hand.goid]
      local steals = shown_o and shown_o ~= o and shown_o.held_ever and not o.held_ever
      -- yours: fired with your fire button and never without it; once any object of its type fired without it this
      -- session (someone else's of the same kind), it must have fired with it twice and more than without
      local yours = (o.unpressed or 0) == 0 or o.mine
      if distrust[t.id] then yours = o.mine end
      if grip and grip ~= 0 and not THROWABLE[grip] and HANDHELD[t.id] and fired(o.prev, w) and not o.ub and by_you
         and not steals
         and not o.notmine and pressed_recently(now) and yours then
        any_fired = true
        o.fired_at = chef.time()
        -- fired while hidden for a key not its: that key is its after all (a rebind)
        if hand.mask and hand.mask.goid == goid then
          log('learned: type %s is on swap key %s (it fired after the key)', t.id, SWAP_KEYS[hand.mask.key])
          learn('slot', t.id, hand.mask.key)
          hand.mask = nil
        end
        -- (what's learned from this shot waits a moment: if the weapon shown in hand fired at the same time, this one
        -- isn't in your hand: as host, a SEAF soldier's gun firing as you fire)
        pending_learn[#pending_learn + 1] = { goid = goid, t = t, grip = grip, at = chef.time(), fn = function()
          -- a key's guess proved wrong (the other weapon on the pose fired just after): that key is this weapon's
          if swap.chosen and swap.chosen ~= goid and objs[swap.chosen] and objs[swap.chosen].t
             and now - (swap.chosen_at or -100) < 4 and type(swap.key) == 'number' then
            local wrong = TYPES[objs[swap.chosen].t].id
            if learned.slot[wrong] == swap.key then learn('slot', wrong, nil) end
            if learned.slot[t.id] ~= swap.key then
              log('learned: type %s is on swap key %s (it fired after the key; %s isn\'t)', t.id, SWAP_KEYS[swap.key], wrong)
              learn('slot', t.id, swap.key)
            end
            swap.chosen = nil
          end
          if (not has_pose(t.id, grip) and not many_poses(t.id)) then
            log('learned: type %s goes with hand pose %d', t.id, grip)
            add_pose(t.id, grip)
          end
        end }
      end
      -- a weapon with no ammo of its own (the Arc Thrower): learned when its trigger is held at a pose nothing else has
      if grip and grip ~= 0 and not THROWABLE[grip] and t.noammo and not o.ub and not o.notmine
         and w.held == true and (o.prev == nil or o.prev.held ~= true) and HANDHELD[t.id] and (not has_pose(t.id, grip) and not many_poses(t.id)) then
        -- (a pose another weapon of yours has is taken, unless that one's trigger field reads not held now: the
        -- Solo Silo's remote held like the Warrant)
        local taken = false
        for g2, o2 in pairs(objs) do
          local t2 = o2.t and TYPES[o2.t]
          if g2 ~= goid and t2 and o2.on and not t2.pack and not t2.other and has_pose(t2.id, grip)
             and not (t2.has.held and o2.prev and o2.prev.held == false) then taken = true break end
        end
        if not taken then
          log('learned: type %s (no ammo of its own) goes with hand pose %d', t.id, grip)
          add_pose(t.id, grip)
        end
      end
      o.prev = w
    end
  end
  -- a weapon fed from the backpack: the pack's ammo went down while no weapon's own ammo moved, and it's the one fed
  -- weapon on you
  local now = chef.time()
  -- which backpack is yours: the one that went down with your reload, or while you fired with nothing else firing
  local cur = packs_now(s)
  for pg, v in pairs(cur) do
    local was = pack_vals[pg]
    if type(v) == 'number' and type(was) == 'number' and v < was and objs[pg] then
      -- proven yours: it went down with your reload, while you fired a weapon fed from it, or while you threw something
      local shown_o = hand.goid and objs[hand.goid]
      local fed_fire = shown_o and shown_o.t and TYPES[shown_o.t].fed and pressed_recently(now)
      if now - recent.reload_t <= 1 or fed_fire or (grip and THROWABLE[grip]) then
        local pt = TYPES[objs[pg].t]
        if not objs[pg].mine and cfg.research then log('research: backpack type %s is yours', pt.id) end
        objs[pg].mine = true
      end
    end
  end
  pack_vals = cur
  local r = pack_ammo(s)
  -- a weapon that reloads from the backpack: it got more loaded within a second of the pack going down (either first)
  if r and pack_prev and r < pack_prev then recent.pack_drop_t = now end
  local rt = recent.reload_t_type
  if rt and math.abs(recent.pack_drop_t - recent.reload_t) <= 1 and not learned.packres[rt.id] and not rt.fed then
    log('learned: type %s reloads from the backpack', rt.id)
    learn('packres', rt.id, true)
  end
  -- (a pack going down near a reload is the reload, never a fed weapon firing)
  local reloading = now - recent.reload_t <= 1.5
  if r and pack_prev and r < pack_prev and not any_fired and not reloading and grip and grip ~= 0 and not THROWABLE[grip] then
    local only, n = nil, 0
    for goid, o in pairs(objs) do
      local t = o.t and TYPES[o.t]
      if t and t.fed and o.on and not o.ub and not o.notmine then only, n = goid, n + 1 end
    end
    if n ~= 1 and cfg.research and hand.fed_said ~= grip then
      hand.fed_said = grip
      local l = {}
      for _, o in pairs(objs) do
        local t = o.t and TYPES[o.t]
        if t and t.fed and o.on then l[#l + 1] = t.id .. (o.ub and '(ub)' or '') end
      end
      log('research: the backpack went down at hand pose %d with %d fed weapons on you: %s', grip, n, table.concat(l, ' '))
    end
    if n == 1 then
      local t = TYPES[objs[only].t]
      objs[only].fired_at = chef.time()
      if HANDHELD[t.id] and (not has_pose(t.id, grip) and not many_poses(t.id)) then
        log('learned: type %s (fed from the backpack) goes with hand pose %d', t.id, grip)
        add_pose(t.id, grip)
      end
    end
  end
  pack_prev = r
end

-- Fire modes and rates of fire: shown once a weapon has been seen with two of them (learned, so from then on at once).
-- The fire mode field's value 8 selects an underbarrel (seen: the Arbitrator); 1, 2, 3 are auto, semi, burst (seen in
-- the research log against the game's own display). Other values show as MODE <n> until named.
local MODE_NAMES = { [1] = 'AUTO', [2] = 'SEMI', [3] = 'BURST', [4] = 'VOLLEY', [5] = 'SAFE', [6] = 'UNSAFE', [7] = 'TOTAL' }
-- (seen against the game's own display, 2026-10-24: Pummeler, Autocannon, Bushwhacker, Railgun)
local function seen(kind, id, value)
  local list = learned[kind][id] or ''
  local key = ',' .. tostring(value) .. ','
  if not string.find(',' .. list .. ',', key, 1, true) then
    list = list == '' and tostring(value) or (list .. ',' .. tostring(value))
    learn(kind, id, list)
  end
  return string.find(list, ',', 1, true) ~= nil      -- two or more seen
end
-- the fire mode (on the left of the bar, with the weapon's own mode)
local function fire_mode_label(t, w)
  local fm = tonumber(w.fire_mode)
  if fm and math.floor(fm / 8) % 2 == 0 and seen('modes', t.id, fm % 8) then
    return MODE_NAMES[fm % 8] or ('MODE ' .. (fm % 8))
  end
  return nil
end
-- the rate of fire (small, under the count)
-- The rate field is the rate in effect: Extreme Cold lowers every weapon's by 10 % (the Helldivers 2 wiki), while the
-- game's menu shows the setting. So the setting is shown: each weapon's settings are learned (not while it's cold), a
-- reading 0.9 of a known setting is that setting and means it's cold (for every weapon, until a reading matches a
-- setting again), and the planet's measured cooling (x1.5) says so too.
local cold = { wid = nil, on = false }
local function is_cold()
  local wid = chef.world_id and chef.world_id()
  if wid ~= cold.wid then cold.wid, cold.on = wid, false end
  return cold.on or planet.factor == 1.5
end
local function in_list(list, v)
  for x in string.gmatch(list or '', '[^,]+') do
    local n = tonumber(x)
    if n and math.abs(n - v) <= 1.5 then return n end
  end
  return nil
end
local function rpm_setting(id, v)
  local base = learned.rpmbase[id]
  local exact = in_list(base, v)
  if exact then cold.on = false return exact end
  local warm = in_list(base, v / 0.9)
  if warm then cold.on = true return warm end
  if is_cold() then return math.floor(v / 0.9 + 0.5) end
  learn('rpmbase', id, base and (base .. ',' .. v) or tostring(v))
  return v
end
local rpm_last = {}
local function setting_label(t, w)
  local parts = {}
  local rpm = tonumber(w.rpm)
  if rpm and rpm > 0 and not t.has.heat then                  -- (heat weapons: the field isn't a rate of fire)
    local last = rpm_last[t.id]
    if last and last.fm == w.fire_mode and last.rpm ~= rpm and last.rpm > 0 and not learned.rpmadj[t.id] then
      log('learned: type %s has a rate of fire setting', t.id)
      learn('rpmadj', t.id, true)
    end
    rpm_last[t.id] = { fm = w.fire_mode, rpm = rpm }
    if learned.rpmadj[t.id] then parts[#parts + 1] = rpm_setting(t.id, math.floor(rpm + 0.5)) .. ' RPM' end
  end
  return #parts > 0 and table.concat(parts, '  ') or nil
end

-- A weapon's own mode is in its options field, two bits per setting (seen in the research log, 2026-10-24): the bits at
-- 4 are the ammo type or guidance (the Warrant 80 / 84, the Autocannon, Recoilless, Airburst and missile pistol the
-- same), the bits at 256 the C4's deploy / detonate (80 / 336), the bits at 4096 the fire mode (shown under the count
-- instead), the rest fixed. Named weapons show their mode at once; others show OPT <n> once the bits at 4 have been
-- seen with two values.
local OPTION_NAMES = {
  c920c2d3 = { at = 4, [0] = 'GUIDED', [1] = 'UNGUIDED' },     -- the Warrant
  fd585726 = { at = 4, [0] = 'GUIDED', [1] = 'UNGUIDED' },     -- the missile pistol
  ['7bfb2e06'] = { at = 4, [0] = 'APHET', [1] = 'FLAK' },      -- the Autocannon
  b2bfd847 = { at = 4, [0] = 'HEAT', [1] = 'HE' },             -- the Recoilless Rifle
  ['8a3c6fee'] = { at = 4, [0] = 'FLAK', [1] = 'CLUSTER' },    -- the Airburst Rocket Launcher
  ['6b2c3bed'] = { at = 256, [0] = 'DEPLOY', [1] = 'DETONATE' }, -- the C4
  ['656d507b'] = { at = 4, [0] = 'BURST', [1] = 'ARTILLERY' },  -- the WASP
}
local function option_mode(t, w)
  local v = tonumber(w.options)
  if not v then return nil end
  local names = OPTION_NAMES[t.id]
  if names then return names[math.floor(v / names.at) % 4] end
  local m = math.floor(v / 4) % 4
  if not seen('options1', t.id, m) then return nil end
  return 'OPT ' .. m
end

-- charge meters (seconds to the end of the meter, and a mark), from the Helldivers 2 wiki
local CHARGE_METER = {
  ['26acc614'] = { secs = 3, mark = 2.5 },      -- RS-422 Railgun (unsafe: 90 % at 2.5 s, explodes at 3 s)
  ['314a1bf5'] = { secs = 3.25, mark = 2.6 },   -- PLAS-45 Epoch (full charge at 2.6 s, explodes at 3.25 s)
}

-- what to show for a weapon state
local function shown(s, goid, t, w, o)
  local d = { kind = nil }
  d.setting = setting_label(t, w)
  d.fmode = fire_mode_label(t, w)
  d.t0, d.goid0 = t, goid                                        -- (the weapon itself, for its charge meter)
  d.mode = option_mode(t, w)
  -- laser guidance on / off (the Commando: a field of its own, seen in the research log 2026-10-24)
  if t.has.guide and w.guide ~= nil then
    local g = w.guide == true and 'LASER' or 'NO LASER'
    d.mode = d.mode and (d.mode .. '  ' .. g) or g
  end
  -- the underbarrel, when the fire mode selects it
  if t.has.underbarrel and type(w.fire_mode) == 'number' and math.floor(w.fire_mode / 8) % 2 == 1 then
    local ub = field(s, goid, t, 'underbarrel')
    local o = type(ub) == 'number' and ub ~= NO_OBJECT and objs[ub]
    local ut = o and o.t and TYPES[o.t]
    if ut then
      t, w, goid = ut, read_weapon(s, ub, ut), ub
      d.underbarrel = true
    end
  end
  if t.has.heat and not t.has.rounds then
    d.kind = 'heat'
    local h = tonumber(w.heat) or 0
    if w.overheated == true and h > (learned.heat[t.id] or 0) then learn('heat', t.id, math.floor(h + 0.5)) end
    local top = learned.heat[t.id] or 100
    local range = HEAT_RANGE[t.id]
    if range then top = range.top end
    local rest = learned.rest2[t.id] or 0
    -- a charge weapon while charging: the heat field stays put until the shot, so the bar rises over the charge time
    local secs = learned.charge2[t.id]
    if secs and w.charging == true and o and o.charge_t0 then
      d.charge_anim, d.charge_secs, d.charge_from = true, secs, h   -- (run every frame, below)
      h = h + (top - h) * math.min(1, (chef.time() - o.charge_t0) / secs)
    end
    d.top_raw, d.tid, d.t, d.goid = top, t.id, t, goid
    d.top = top - rest
    d.value = math.max(0, h - rest)
    d.overheated, d.charging = w.overheated == true, w.charging == true
    d.rest, d.o = rest, o
    -- (past 100: the bar runs to its top, the % reads the heat as it is, the mark where it starts to hurt)
    if range then
      d.heat_marks, d.pct_top = {}, top
      for _, m in ipairs(range.marks) do d.heat_marks[#d.heat_marks + 1] = { (m[1] - rest) / (top - rest), m[2] } end
    end
  elseif t.has.rounds then
    d.kind = 'ammo'
    local n = tonumber(w.rounds) or 0
    d.mag = n                                                     -- the magazine alone (its size is learned from it)
    if t.has.chamber and w.chamber == false then n = n + 1 end   -- a round in the chamber
    d.value = n
  elseif t.has.slot0 then
    d.kind = 'ammo'
    local sel = tonumber(w.selected) or 0
    local n = tonumber(sel == 1 and w.slot1 or w.slot0) or 0
    if t.has.chamber and w.chamber == false then n = n + 1 end   -- a shell in the chamber (single-shot launchers)
    d.value, d.mag = n, n                                         -- (the chamber is part of what it holds)
  elseif t.noammo then
    d.kind = 'none'                                               -- (only its modes and charge meter)
  elseif t.fed then
    local r, pg = pack_ammo(s)
    if r == nil then return d end                                -- no pack on you: nothing to show
    d.kind, d.value, d.mag, d.fed = 'ammo', r, r, true
    -- (its bar is the pack's: the most that pack type was seen holding, not the weapon's: the Maxigun's and the
    -- Cremator's share a hand pose)
    local pt = TYPES[objs[pg].t]
    if r > (learned.pack[pt.id] or 0) then learn('pack', pt.id, r) end
    d.pack_top = learned.pack[pt.id]
  end
  if d.kind == 'ammo' then
    -- the bar is the magazine: a tactical reload's extra round in the chamber shows in the count, not as a bigger
    -- magazine
    if d.pack_top then
      d.top = d.pack_top
    else
      if d.mag > (learned.mag[t.id] or 0) then learn('mag', t.id, d.mag) end
      -- The magazine's size is this weapon's in this mission: attachments change it (the Liberator Penetrator's
      -- shortened magazine: 30 instead of 45), and they're set for the whole mission. The most this object has held
      -- is its size, once it's known to have been full: it was there in the mission's first 30 s (you drop with
      -- full magazines), held as much as the most learned, or was reloaded. Until then, the most learned.
      local top = learned.mag[t.id] or d.mag
      local o = objs[goid]                                         -- (the underbarrel's own object when it's selected)
      if o then
        if o.mag_max == nil then
          o.mag_max = d.mag
          o.mag_full = (blocked.since ~= nil and chef.time() - blocked.since < 30) or d.mag >= (learned.mag[t.id] or 0)
        elseif d.mag > o.mag_max then
          o.mag_max, o.mag_full = d.mag, true
        elseif o.mag_prev and d.mag > o.mag_prev then
          o.mag_full = true
        end
        o.mag_prev = d.mag
        if o.mag_full then top = o.mag_max end
      end
      d.top = math.max(1, top)                                     -- (a single-shot weapon's magazine is always 0)
    end
  end
  d.reloading = (tonumber(w.reload_stage) or 0) ~= 0 and d.kind == 'ammo'
  -- the reserve: magazines, else spare rounds, else your backpack's
  if learned.packres[t.id] then
    d.reserve = pack_ammo(s)                                    -- (reloads from its backpack: the C4's charges ...)
  elseif d.fed then
    -- (the pack is the ammo)
  elseif t.has.magazines and tonumber(w.magazines) and (w.magazines > 0 or not t.has.heat) then d.reserve = w.magazines
  elseif t.has.spare then d.reserve = tonumber(w.spare)
  else
    for pgoid, o in pairs(objs) do
      local pt = o.t and TYPES[o.t]
      if pt and pt.pack and o.on and pt.has.remaining then
        local r = field(s, pgoid, pt, 'remaining')
        if type(r) == 'number' then d.reserve = r break end
      end
    end
  end
  return d
end

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
local RED = { 225, 75, 60 }
local YELLOW = { 236, 214, 96 }
-- Colourblind: told apart by brightness as well as hue (the Okabe-Ito colours): white for normal, sky blue for the
-- first mark, yellow for low or hot, magenta for empty or overheated.
-- (MODE2, MODE3: the modes' own colours: the colourblind palette's sky blue and bluish green in both palettes, none
-- of them a warning's colour)
local MODE2, MODE3 = { 86, 180, 233 }, { 0, 175, 130 }
local PALETTES = {
  { CREAM = { 236, 229, 206 }, YELLOW = { 236, 214, 96 }, WARN = { 240, 170, 90 }, RED = { 225, 75, 60 } },
  { CREAM = { 240, 240, 240 }, YELLOW = { 86, 180, 233 }, WARN = { 240, 228, 66 }, RED = { 230, 80, 200 } },
}
apply_palette = function()
  local p = PALETTES[cfg.palette] or PALETTES[1]
  for name, c in pairs({ CREAM = CREAM, YELLOW = YELLOW, WARN = WARN, RED = RED }) do
    for i = 1, 3 do c[i] = p[name][i] end
  end
end
apply_palette()
local alpha_k = 1                                    -- the opacity option times the fade, this frame
local function col(c, a) return chef.color(c[1], c[2], c[3], math.floor((a or 235) * alpha_k + 0.5)) end
-- an empty part (of the ammo bar, a magazine square, the backpack bar): a faint fill, or (the option) its outline,
-- lw thick; one too thin for a hole stays a faint fill
local function empty_rect(x, y, w, h, faint, L, lw)
  if w <= 0 or h <= 0 then return end
  lw = math.max(1, lw or 1)
  if not cfg.outline or w <= 2 * lw or h <= 2 * lw then chef.rect(x, y, w, h, col(CREAM, faint), L) return end
  local c = col(CREAM, 190)
  chef.rect(x, y, w, lw, c, L)
  chef.rect(x, y + h - lw, w, lw, c, L)
  chef.rect(x, y + lw, lw, h - 2 * lw, c, L)
  chef.rect(x + w - lw, y + lw, lw, h - 2 * lw, c, L)
end
-- a solid bar f full (0 to 1), its fill colour c: on a faint background, or (outlines) inside an outline of the whole
-- bar that stays put, the fill within it (a bar cooling down from red: only the inside changes). One too thin for a
-- hole: faint, as without outlines. Vertical: filling from the bottom up.
local function solid_bar(x, y, w, h, f, c, L, lw, vertical)
  f = math.max(0, math.min(1, f))
  lw = math.max(1, lw or 1)
  if not cfg.outline or w <= 2 * lw + 1 or h <= 2 * lw + 1 then
    chef.rect(x, y, w, h, col(CREAM, 45), L)
    if vertical then chef.rect(x, y, w, math.floor(h * f + 0.5), c, L + 1)
    else chef.rect(x, y, math.floor(w * f + 0.5), h, c, L + 1) end
    return
  end
  empty_rect(x, y, w, h, 45, L, lw)
  local iw, ih = w - 2 * lw, h - 2 * lw
  if vertical then chef.rect(x + lw, y + lw, iw, math.floor(ih * f + 0.5), c, L + 1)
  else chef.rect(x + lw, y + lw, math.floor(iw * f + 0.5), ih, c, L + 1) end
end
local function txt_right(x, y, str, cap, c, layer) txt(x - txt_width(str, cap), y, str, cap, c, layer) end
-- The mode labels ("HEAT  APHET  AUTO  750 RPM"), with the option each mode in its own colour: the same mode always
-- the same, and a weapon's modes never sharing one (cream, blue, green). HEAT, UB and the rate of fire stay cream.
local MODE_TONE = { SEMI = 1, AUTO = 2, BURST = 3, VOLLEY = 3, SAFE = 1, UNSAFE = 2, TOTAL = 3,
  GUIDED = 1, UNGUIDED = 2, APHET = 1, FLAK = 2, CLUSTER = 3, HE = 2, DEPLOY = 1, DETONATE = 2, ARTILLERY = 2,
  LASER = 2, ['NO LASER'] = 1 }
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
local GRENADE = {
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
local STIM = {        -- a syringe: plunger, barrel with the stim in it, needle
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
GRENADE, STIM = outlined(GRENADE), outlined(STIM)

-- a one-line message under the crosshair
local function notice(str)
  local w, h = chef.screen()
  if not w then return end
  local small = math.max(7, math.floor(16 * (h / 1440) * cfg.size + 0.5))
  local x = math.floor(w / 2 - txt_width(str, small) / 2)
  txt(x, math.floor(h / 2 - h * 0.12), str, small, col(WARN, 230), 905)
end

-- the grenades and stims line, the backpack's bar after it to xend; its top at top
-- heat marks' colours (HEAT_RANGE), and the count's: the colour of the last mark passed
local MARK_COLORS = { YELLOW, WARN, RED }
local function heat_tone(d, frac)
  local tone = CREAM
  for _, m in ipairs(d.heat_marks) do if frac >= m[1] then tone = MARK_COLORS[m[2]] end end
  return tone
end

local function draw_items(items, d, k, small, x0, top, xend, ph, icon_k, gap, bar)
  local L = 905
  local lw = math.max(1, math.floor(k * 0.8 + 0.5))
  local cell = math.max(1, math.floor(1.6 * (icon_k or k) + 0.5))
  gap = gap or math.floor(22 * k)
  local S = #GRENADE * cell                                -- the line's height: the grenade with its outline
  local iy = top - S
  local ty = iy + math.floor((S - small) / 2)
  local function icon_count(x, rows, n)
    local c = n == 0 and RED or CREAM
    local h = #rows * cell
    chef.sprite(x, iy + math.floor((S - h) / 2), rows, cell,
      { ['#'] = col(c, 220), ['+'] = col({ 40, 40, 40 }, 210), o = col({ 0, 0, 0 }, 110) }, L)
    x = x + #rows[1] * cell + math.floor(4 * k)
    txt(x, ty, tostring(n), small, col(c, 220), L)
    return x + txt_width(tostring(n), small)
  end
  local x = x0 - gap
  if cfg.show_stims then x = icon_count(x0, STIM, items.s) end
  if cfg.show_grenades then x = icon_count(cfg.show_stims and x + gap or x0, GRENADE, items.g) end
  if not cfg.pack then return end
  -- how full your backpack is: a thin bar from there to the main bar's right end
  if items.warp then
    -- the warp pack's heat, 0 to 78 (a warp adds 33 and one over 45 kills, so 78 is the most it gets), with the
    -- wiki's marks: a warp over 15 hurts, over 45 kills
    local px0, pw, py = x + gap, xend - (x + gap), iy + math.floor((S - ph) / 2)
    if bar then px0, pw, py = bar.x, bar.w, bar.y end            -- (beside the crosshair: over the count)
    if pw > 10 then
      local h = items.warp
      local pc = h > 45 and RED or (h > 15 and WARN or CREAM)
      solid_bar(px0, py, pw, ph, h / 78, col(pc, 215), L, lw)
      for _, m in ipairs({ { 15, WARN }, { 45, RED } }) do
        chef.rect(px0 + math.floor(pw * m[1] / 78), py - 1, math.max(1, math.floor(2 * k)), ph + 2, col(m[2], 220), L + 2)
      end
    end
  elseif items.recharge then
    -- the jump or hover pack recharging: fills up, cream when ready
    local px0, pw, py = x + gap, xend - (x + gap), iy + math.floor((S - ph) / 2)
    if bar then px0, pw, py = bar.x, bar.w, bar.y end            -- (beside the crosshair: over the count)
    if pw > 10 then
      local f = items.recharge
      local c = (f >= 1 or items.draining) and CREAM or WARN
      solid_bar(px0, py, pw, ph, f, col(c, (f >= 1 or items.draining) and 215 or 180), L, lw)
    end
  elseif items.pack and items.pack_top and items.pack_top > 0 and not (d and d.fed) then
    local px0, pw, py = x + gap, xend - (x + gap), iy + math.floor((S - ph) / 2)
    if bar then px0, pw, py = bar.x, bar.w, bar.y end            -- (beside the crosshair: over the count)
    if pw > 10 then
      local f = math.max(0, math.min(1, items.pack / items.pack_top))
      local pc = items.pack == 0 and RED or (f <= 0.25 and WARN or CREAM)
      solid_bar(px0, py, pw, ph, f, col(pc, 215), L, lw)
    end
  end
end

-- a magazine of up to this many rounds is drawn a tick a round, more as a solid bar: 25 (Small) to 50 (Huge)
local function seg_max() return math.floor(25 + (cfg.size - 0.8) / 0.7 * 25 + 0.5) end


-- Beside the crosshair (compact): a short vertical bar, the count right of it, the spare magazines as small squares
-- under the count, then the modes and the rate of fire, then the grenades and stims. A magazine of up to 10 rounds is
-- drawn a tick a round.
local function draw_side(d, items)
  local w, h = chef.screen()
  if not w then return end
  local k = (h / 1440) * (cfg.side_size or 1.25)
  local big = math.floor(28 * k + 0.5)
  local small = math.max(7, math.floor(16 * k + 0.5))
  local tiny = math.max(6, math.floor(12 * k + 0.5))
  local vw, vh = math.max(2, math.floor(4 * k + 0.5)), math.floor(big * 1.7 + 0.5)
  -- the bar's left edge and bottom (bottom-left origin): just right of the crosshair, or (the corner) by the game's
  -- weapon panel, bottom left; then the offsets; kept on the screen
  local x0, yb
  if cfg.corner then x0, yb = w * 0.02, h * 0.16
  else x0, yb = w / 2 + h * 0.03, h / 2 - vh / 2 end
  x0 = math.floor(x0 + w * (cfg.off_x or 0) / 100)
  yb = math.floor(yb + h * (cfg.off_y or 0) / 100)
  x0 = math.max(0, math.min(x0, w - math.floor(140 * k)))
  yb = math.max(math.floor(30 * k), math.min(yb, h - vh))
  local nx = cfg.show_bar and (x0 + vw + math.floor(8 * k)) or x0
  local ny = yb + vh - big                                   -- the count's baseline: its top level with the bar's
  local L = 905
  local below = ny                                           -- where the next line goes (top of it)
  local lw = math.max(1, math.floor(k * 0.8 + 0.5))           -- (an outline's width)

  local function vbar(frac, tone, alpha, n)
    if not cfg.show_bar then return end
    if n then
      local gap = math.max(1, math.min(vh / n * 0.3, 3 * k))
      local step = (vh + gap) / n
      for i = 0, n - 1 do
        local ya, yz = math.floor(yb + i * step + 0.5), math.floor(yb + i * step + step - gap + 0.5)
        if i < frac then chef.rect(x0, ya, vw, math.max(1, yz - ya), col(tone, alpha), L)
        else empty_rect(x0, ya, vw, math.max(1, yz - ya), 55, L, lw) end
      end
    else
      solid_bar(x0, yb, vw, vh, frac, col(tone, alpha), L, lw, true)
    end
  end

  local labels = {}
  local count_w = nil
  if d and d.kind == 'none' then
    local f = d.charge_frac or 0
    vbar(math.min(1, f), f >= 1 and WARN or CREAM, 230)
    local left = d.mode or d.fmode
    if left then txt_modes(nx, ny, left, small, 200, L) end
    below = ny
  elseif d then
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
    local alpha = d.reloading and 120 or 235
    if d.kind == 'ammo' and d.top and d.top <= 10 and d.top >= 1 then
      local n = math.max(d.top, math.min(d.value, d.top + 3))
      vbar(d.value, tone, alpha, n)
    else
      vbar(frac, tone, alpha)
      if d.kind == 'heat' and not learned.charge2[d.tid] and cfg.show_bar then
        for _, m in ipairs(d.heat_marks or { { 0.75, 3 } }) do
          chef.rect(x0 - 2, yb + math.floor(vh * m[1]), vw + 4, math.max(1, math.floor(2 * k)), col(MARK_COLORS[m[2]], 220), L + 2)
        end
      end
    end
    local str = d.kind == 'heat' and string.format('%d%%', math.floor(frac * (d.pct_top or 100) + 0.5)) or tostring(d.value)
    count_w = 0
    if cfg.show_count then
      txt(nx, ny, str, big, col(tone, 245), L)
      count_w = txt_width(str, big)
    end
    -- a charge meter (the Railgun, the Epoch, a lock-on): a thin vertical line just inside the bar (on the
    -- crosshair's side), filling from the bottom up
    if d.charge_frac then
      local cwid = math.max(1, math.floor(2 * k + 0.5))
      local cx0 = x0 - math.max(1, math.floor(2 * k + 0.5)) - cwid
      local f = d.charge_frac
      local cc = d.locked and WARN or (f >= 0.95 and not d.t0.has.lock and RED or (f >= (d.charge_mark or 2) and WARN or CREAM))
      chef.rect(cx0, yb, cwid, vh, col(CREAM, 40), L)
      chef.rect(cx0, yb, cwid, math.floor(vh * math.min(1, f) + 0.5), col(cc, 230), L + 1)
      if d.charge_mark then
        chef.rect(cx0 - 1, yb + math.floor(vh * d.charge_mark), cwid + 2, math.max(1, math.floor(2 * k)), col(WARN, 220), L + 2)
      end
    end
    -- the spare magazines: a square each, grey ones up to the most this weapon has carried (learned; more than 12:
    -- xN), or (the option) a number after the count, like Under: | xN
    if d.reserve then
      local o = d.o or {}
      if d.reserve > (o.res_top or 0) then o.res_top = d.reserve end
      local id = not d.underbarrel and d.t0 and d.t0.id
      if id and d.reserve > (learned.resmax[id] or 0) then learn('resmax', id, d.reserve) end
      local top = math.max(d.reserve, o.res_top or 0, id and learned.resmax[id] or 0)
      if cfg.mags_number then
        local rx = nx + (count_w > 0 and count_w + math.floor(8 * k) or 0)
        chef.rect(rx, ny, math.max(1, math.floor(2 * k)), big, col(CREAM, 150), L)
        txt(rx + math.floor(7 * k), ny, 'x' .. tostring(d.reserve), small, col(CREAM, 220), L)
      else
        local ps, pg = math.max(2, math.floor(6 * k + 0.5)), math.max(1, math.floor(3 * k + 0.5))
        local py = ny - math.floor(7 * k) - ps
        if cfg.mags_hide then top = d.reserve end
        if top <= 12 then
          for i = 0, top - 1 do
            local x = nx + i * (ps + pg)
            if i < d.reserve then chef.rect(x, py, ps, ps, col(CREAM, 220), L)
            elseif cfg.outline then empty_rect(x, py, ps, ps, 55, L, lw)
            else chef.rect(x, py, ps, ps, col({ 150, 150, 150 }, 120), L) end
          end
          below = py
        else
          txt(nx, ny - math.floor(7 * k) - tiny, 'x' .. tostring(d.reserve), tiny, col(CREAM, 220), L)
          below = ny - math.floor(7 * k) - tiny
        end
      end
    end
    if d.underbarrel then
      if cfg.show_mode then labels[#labels + 1] = 'UB' end
    elseif d.mode then labels[#labels + 1] = d.mode end
    if d.fmode and not d.underbarrel then labels[#labels + 1] = d.fmode end
    if d.kind == 'heat' and cfg.show_heat then table.insert(labels, 1, 'HEAT') end
    if d.setting then labels[#labels + 1] = d.setting end
  end
  if #labels > 0 then
    below = below - math.floor(6 * k) - tiny
    txt_modes(nx, below, table.concat(labels, '  '), tiny, 190, L)
  end
  if items and (cfg.show_stims or cfg.show_grenades or cfg.pack) then
    -- (the icons at the Small size's scale, the text as is; closer together)
    -- (the backpack's bar over the count, as wide as the count's line)
    local ph = math.max(2, math.floor(4 * k))
    local bar = { x = nx, y = yb + vh + math.max(3, math.floor(8 * k)), w = math.max(math.floor(60 * k), count_w or 0) }
    draw_items(items, d, k, tiny, nx, below - math.floor(8 * k), nx + math.floor(120 * k), ph, k * 0.8, math.floor(10 * k), bar)
  end
end

local function draw(d, items)
  if cfg.right then return draw_side(d, items) end
  local w, h = chef.screen()
  if not w then return end
  local k = (h / 1440) * cfg.size
  local big = math.floor(28 * k + 0.5)                       -- the count's cap height
  local small = math.max(7, math.floor(16 * k + 0.5))        -- labels and the reserve
  local bw, bh = math.floor(260 * k), math.max(3, math.floor(14 * k))
  -- the bar's bottom (bottom-left origin) and left edge: under the crosshair, then the offsets; kept on the screen
  local y = math.floor(h / 2 - h * 0.09 + h * (cfg.off_y or 0) / 100)
  local x0 = math.floor(w / 2 - bw / 2 + w * (cfg.off_x or 0) / 100)
  y = math.max(math.floor(40 * k), math.min(y, h - math.floor(60 * k)))
  x0 = math.max(math.floor(160 * k), math.min(x0, w - bw - math.floor(130 * k)))
  local L = 905
  -- the mode labels, left of the bar
  local function label(str)
    txt_modes(x0 - math.floor(10 * k), y + math.floor((bh - small) / 2), str, small, 200, L, true)
  end

  if d and d.kind == 'none' then
    -- no ammo of its own: its modes on the left of where the bar would be, and the charge meter
    local left = d.mode or d.fmode
    if left then label(left) end
    if d.charge_frac then
      local ch = math.max(2, math.floor(bh * 0.3))
      chef.rect(x0, y, bw, ch, col(CREAM, 40), L)
      chef.rect(x0, y, math.floor(bw * math.min(1, d.charge_frac) + 0.5), ch, col(d.charge_frac >= 1 and WARN or CREAM, 230), L + 1)
    end
  elseif d then
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
    local alpha = d.reloading and 120 or 235

    if not cfg.show_bar then
      -- (no bar: the rest stays where it was)
    elseif d.kind == 'ammo' and d.top and d.top <= seg_max() and d.top >= 1 then
      local n = math.max(d.top, math.min(d.value, d.top + 3))  -- a tactical reload's chambered round: a tick more
      -- one tick a round, the gaps narrow (at most 4 px at 1440p): few rounds make long ticks, end to end over the bar
      local gap = math.max(1, math.min(bw / n * 0.45, 4 * k))
      local step = (bw + gap) / n
      for i = 0, n - 1 do
        local xa, xb = math.floor(x0 + i * step + 0.5), math.floor(x0 + i * step + step - gap + 0.5)
        if i < d.value then chef.rect(xa, y, math.max(1, xb - xa), bh, col(tone, alpha), L)
        else empty_rect(xa, y, math.max(1, xb - xa), bh, 55, L, math.max(1, math.floor(k * 0.8 + 0.5))) end
      end
    else
      solid_bar(x0, y, bw, bh, frac, col(tone, alpha), L, math.max(1, math.floor(k * 0.8 + 0.5)))
      if d.kind == 'heat' and not learned.charge2[d.tid] then
        for _, m in ipairs(d.heat_marks or { { 0.75, 3 } }) do
          chef.rect(x0 + math.floor(bw * m[1]), y - 2, math.max(2, math.floor(2 * k)), bh + 4, col(MARK_COLORS[m[2]], 220), L + 2)
        end
      end
    end

    -- the count, then | xN
    local str = d.kind == 'heat' and string.format('%d%%', math.floor(frac * (d.pct_top or 100) + 0.5)) or tostring(d.value)
    local nx = x0 + bw + math.floor(12 * k)
    local ny = y + math.floor((bh - big) / 2)
    local rx = nx
    if cfg.show_count then
      txt(nx, ny, str, big, col(tone, 245), L)
      rx = nx + txt_width(str, big) + math.floor(8 * k)
    end
    local ex = rx                                            -- where the line ends
    if d.reserve then
      chef.rect(rx, ny, math.max(1, math.floor(2 * k)), big, col(CREAM, 150), L)
      txt(rx + math.floor(7 * k), ny, 'x' .. tostring(d.reserve), small, col(CREAM, 220), L)
      ex = rx + math.floor(7 * k) + txt_width('x' .. tostring(d.reserve), small)
    end
    local left = (d.underbarrel and (cfg.show_mode and 'UB' or nil)) or (not d.underbarrel and d.mode) or nil
    if d.fmode and not d.underbarrel then left = left and (left .. '  ' .. d.fmode) or d.fmode end
    if d.kind == 'heat' and cfg.show_heat then left = left and ('HEAT  ' .. left) or 'HEAT' end
    if left then label(left) end
    -- a charge meter (the Railgun, the Epoch): a thin line over the bar while the trigger is held
    if d.charge_frac then
      local ch = math.max(2, math.floor(bh * 0.3))
      local cy = y + bh + math.max(2, math.floor(4 * k))
      local f = d.charge_frac
      local cc = d.locked and WARN or (f >= 0.95 and not d.t0.has.lock and RED or (f >= (d.charge_mark or 2) and WARN or CREAM))
      chef.rect(x0, cy, bw, ch, col(CREAM, 40), L)
      chef.rect(x0, cy, math.floor(bw * math.min(1, f) + 0.5), ch, col(cc, 230), L + 1)
      if d.charge_mark then
        chef.rect(x0 + math.floor(bw * d.charge_mark), cy - 1, math.max(1, math.floor(2 * k)), ch + 2, col(WARN, 220), L + 2)
      end
    end
    if d.setting then                                        -- rate of fire, small, under the count
      local tiny = math.max(6, math.floor(12 * k + 0.5))
      txt(nx, ny - math.floor(7 * k) - tiny, d.setting, tiny, col(CREAM, 190), L)
    end
  end

  if items and (cfg.show_stims or cfg.show_grenades or cfg.pack) then draw_items(items, d, k, small, x0, y - math.floor(8 * k), x0 + bw, math.max(2, math.floor(bh * 0.5))) end
end

------------------------------------------------------------------------------------------------ research
-- Every field the weapon in hand's type declares (from the game's network config, all of them safe to read), read
-- every 0.1 s, and each change logged: to find what a toggle (the Commando's laser ...) or a mode changes. The fields
-- NarrowHUD already reads are left out, and so is one that changes all the time (logged once as noisy).
local RF = nil
local function research_fields(tid)
  if RF == nil then
    RF = { types = {}, names = {} }
    for line in string.gmatch(DATA.fieldnames or '', '[^\n]+') do
      local id, name = string.match(line, '^(%x+) (%S+)$')
      if id then RF.names[id] = name end
    end
    for _, r in pairs(ROLE) do RF.names[r.id] = nil end   -- (the fields NarrowHUD already reads: logged elsewhere)
    for f in pairs(KNOWN_FIELDS) do RF.names[f] = nil end
    for line in string.gmatch(DATA.fields or '', '[^\n]+') do
      local id, rest = string.match(line, '^(%x+) ?(.*)$')
      if id then RF.types[id] = rest end
    end
  end
  local l = RF.types[tid]
  if type(l) == 'string' then
    local list = {}
    for f in string.gmatch(l, '%x+') do if RF.names[f] then list[#list + 1] = f end end
    RF.types[tid] = list
    l = list
  end
  return l or {}
end
local rws, noisy = {}, {}
research_watch = function(s, goid, t)
  local rw = rws[goid]
  if rw == nil or rw.t ~= t then rw = { t = t, vals = {}, counts = {}, started = chef.time(), noisy = noisy } rws[goid] = rw end
  if not alive(s, goid, t) then rws[goid] = nil return end
  local changes = {}
  for _, f in ipairs(research_fields(t.id)) do
    if not rw.noisy[f] and not (t.live and not t.live[norm_id(f)]) then
      local v = call(t.id .. '.' .. f, 'GameSession.game_object_field', s, goid, RF.names[f])
      local sv
      if type(v) == 'table' then
        local parts, n = {}, 0
        for k, x in pairs(v) do
          n = n + 1
          if n <= 8 then parts[#parts + 1] = tostring(k) .. '=' .. tostring(x) end
        end
        table.sort(parts)
        sv = '{' .. table.concat(parts, ' ') .. (n > 8 and ' ...' or '') .. '}'
      else
        sv = tostring(v)
      end
      if string.find(sv, '^Vector') or string.find(sv, '^Quaternion') or string.find(sv, '^Matrix') then
        rw.noisy[f] = true                                -- (a position or rotation: changes as you move)
      end
      if rw.noisy[f] then
        -- (left out)
      elseif rw.vals[f] ~= nil and rw.vals[f] ~= sv then
        rw.counts[f] = (rw.counts[f] or 0) + 1
        if rw.counts[f] > 150 and chef.time() - rw.started < 30 then
          rw.noisy[f] = true
          log('research %s: field %s changes all the time, left out', t.id, f)
        else
          changes[#changes + 1] = string.format('%s %s>%s', f, rw.vals[f], sv)
        end
      end
      rw.vals[f] = sv
    end
  end
  if #changes > 0 then log('research %s: %s', t.id, table.concat(changes, ', ')) end
end

------------------------------------------------------------------------------------------------ each frame
local next_scan, next_read, next_items = 0, 0, 0
local shown_now, items_now = nil, nil
local session_ok = false

local world_seen = nil
local probe_said = false

-- On a game version NarrowHUD wasn't made for, with Chef 1.2's Network.object_info (a type's declared fields), it
-- checks its data instead of staying off: each type it reads must still exist and declare every field it reads. A type
-- that doesn't is left out (never sorted, never read); if the player's or the Helldiver's type fails, it stays off.
-- Checked a few types a frame, once a session.
local check = { state = nil, i = 0, dropped = 0, kept = 0 }    -- state: nil, 'running', 'ok', 'failed'
local function check_step()
  if check.state == nil then
    check.state, check.i = 'running', 0
    -- the player and the Helldiver first (their fields by id, from tools/make_data.py)
    local pf = live_fields(DATA.player.name)
    local af = live_fields(DATA.avatar.name)
    if not pf or not af then
      check.state = 'failed'
      log('game version check: Network.object_info gives nothing for the player or the Helldiver (Chef 1.1 refuses it): staying off')
      return
    end
    local need_p = { '0f27c68e' }
    local need_a = { 'd92082f9', '5f8eb478' }
    for _, id in ipairs(need_p) do if not pf[norm_id(id)] then check.state = 'failed' end end
    for _, id in ipairs(need_a) do if not af[norm_id(id)] then check.state = 'failed' end end
    if check.state == 'failed' then log('game version check: the player\'s or the Helldiver\'s fields moved: staying off') end
    return
  end
  if check.state ~= 'running' then return end
  for _ = 1, 25 do
    check.i = check.i + 1
    local t = TYPES[check.i]
    if t == nil then
      check.state = 'ok'
      log('game version check: done: %d types as NarrowHUD\'s data, %d left out (gone, or a field it reads moved): running', check.kept, check.dropped)
      return
    end
    if not t.player and not t.avatar then
      local set = live_fields(t.name)
      local ok = set ~= nil
      if ok then
        for role in pairs(t.has) do if ROLE[role] and not set[norm_id(ROLE[role].id)] then ok = false end end
        if t.special and not set[norm_id(t.special.field)] then ok = false end
      end
      if ok then t.live = set check.kept = check.kept + 1
      else t.gone = true check.dropped = check.dropped + 1 end
    end
  end
end
local flash = { text = nil, till = 0 }                -- a short message under the crosshair (forgetting)
local function build_gate(now)
  if game_build.known == false and not cfg.any_build then
    check_step()
    if check.state ~= 'ok' then
      local wid = chef.world_id and chef.world_id()
      if wid ~= flash.build_wid then flash.build_wid, flash.build_at = wid, now end
      if check.state == 'failed' and now - flash.build_at < 25 then
        notice('NarrowHUD is off: the game was updated since it was made (F9 menu to run it anyway)')
      end
      return true
    end
  end
  return false
end
local function read_forget_keys(now)
  if keys.forget_weapon and keys.forget_weapon.pressed and keys.forget_weapon.pressed() == true then
    local o = hand.goid and objs[hand.goid]
    if o and o.t then
      forget_type(TYPES[o.t].id)
      log('forgot what was learned about type %s (the weapon in hand)', TYPES[o.t].id)
      flash.text, flash.till = 'NarrowHUD: forgot this weapon (fire it to learn it again)', now + 3
    else
      flash.text, flash.till = 'NarrowHUD: no weapon shown to forget', now + 2
    end
  end
  if keys.forget_all and keys.forget_all.pressed and keys.forget_all.pressed() == true then
    if now - (flash.all_at or -100) < 3 then
      forget_all()
      flash.all_at = nil
      log('forgot everything learned (back to the shipped knowledge)')
      flash.text, flash.till = 'NarrowHUD: forgot everything learned', now + 3
    else
      flash.all_at = now
      flash.text, flash.till = 'NarrowHUD: press again to forget everything learned', now + 3
    end
  end
end
-- Idle: what's on screen, as a string (the count in whole percent for heat, so cooling counts as a change); a
-- different one, a press of fire or a swap is a change. Nothing changed for cfg.idle_secs: dimmed (a quarter) or
-- hidden, over half a second; back at once.
local idle = { sig = nil, at = -100 }
local function idle_target(d, items, now)
  local parts = { tostring(hand.goid), tostring(hand.grip) }
  if d then
    local v = d.kind == 'heat' and d.top and d.top > 0 and math.floor(d.value / d.top * 100 + 0.5) or d.value
    parts[#parts + 1] = table.concat({ tostring(d.kind), tostring(v), tostring(d.top), tostring(d.reserve),
      tostring(d.reloading), tostring(d.mode), tostring(d.fmode), tostring(d.setting), tostring(d.overheated),
      tostring(d.locked), d.charge_frac and tostring(math.floor(d.charge_frac * 20)) or '-' }, ',')
  end
  if items then
    parts[#parts + 1] = table.concat({ tostring(items.s), tostring(items.g), tostring(items.pack),
      items.warp and tostring(math.floor(items.warp)) or '-', items.recharge and tostring(math.floor(items.recharge * 20)) or '-',
      tostring(items.draining) }, ',')
  end
  local sig = table.concat(parts, '|')
  if sig ~= idle.sig then idle.sig, idle.at = sig, now end
  local last = math.max(idle.at, input.last or -100, swap.at or -100)
  if (cfg.idle or 1) == 1 or now - last <= (cfg.idle_secs or 4) then return 1 end
  return cfg.idle == 3 and 0 or 0.25
end

function M.update(dt)
  frame = frame + 1
  local now = chef.time()
  if dirty_at and now >= dirty_at then
    dirty_at = nil
    save_learned()
  end
  if not chef.in_mission() then shown_now, items_now = nil, nil return end
  if build_gate(now) then return end
  local s = call('session', 'Network.game_session')
  local peer = call('peer', 'Network.peer_id')
  if s == nil or peer == nil then shown_now, items_now = nil, nil return end
  -- A new world (each mission, the ship) starts its object ids over: an id of ours can be one that was something else
  -- last mission, and its old type was kept (an id found to be nothing of ours was never looked at again: our weapons
  -- went unseen for whole missions). Everything about objects is forgotten on a new world.
  local wid = chef.world_id and chef.world_id()
  if wid ~= world_seen then
    world_seen = wid
    for k in pairs(objs) do objs[k] = nil end
    for i = #queue, 1, -1 do queue[i] = nil end
    for i = #queue_2, 1, -1 do queue_2[i] = nil end
    for i = #queue_b, 1, -1 do queue_b[i] = nil end
    for k in pairs(checked) do checked[k] = nil end
    for k in pairs(rws) do rws[k] = nil end
    for k in pairs(pack_vals) do pack_vals[k] = nil end
    for k in pairs(distrust) do distrust[k] = nil end
    for k in pairs(av_refs) do av_refs[k] = nil end
    for k in pairs(av_said) do av_said[k] = nil end
    hand.goid, hand.grip, hand.said, hand.held_t, hand.bar_pack = nil, nil, nil, nil, nil
    swap.used, swap.from = true, nil
    hand.mask = nil
    blocked.n, blocked.types, blocked.yes, blocked.since, blocked.new_said = 0, 0, false, now, 0
    me.player, me.avatar = nil, nil
    shown_now, items_now, pack_prev = nil, nil, nil
    next_scan = now
  end
  classify(s)
  -- (research, once a session: what Network.object_info gives for the player's type, allowed again from Chef 1.2:
  -- a type's field list would let NarrowHUD check its data against a patched game instead of going off)
  if cfg.research and not probe_said then
    probe_said = true
    local ok, info = pcall(call, 'objinfo', 'Network.object_info', DATA.player.name)
    local function show(v, depth)
      if type(v) ~= 'table' then return tostring(v) end
      if depth > 3 then return '{...}' end
      local parts, n = {}, 0
      for k, x in pairs(v) do
        n = n + 1
        if n <= 12 then parts[#parts + 1] = tostring(k) .. '=' .. show(x, depth + 1) end
      end
      return '{' .. table.concat(parts, ' ') .. (n > 12 and (' ... ' .. n .. ' in all') or '') .. '}'
    end
    log('research: Network.object_info(player type) gives %s: %s', ok and type(info) or 'an error', string.sub(show(info, 0), 1, 600))
    if ok and type(info) == 'table' and type(info.fields) == 'table' then
      for i = 1, math.min(4, #info.fields) do log('research: object_info field %d: %s', i, string.sub(show(info.fields[i], 1), 1, 300)) end
      log('research: object_info: %d fields (NarrowHUD\'s data: the player type has the avatar field %s)', #info.fields, tostring(DATA.player.avatar))
    end
  end
  if now >= next_scan then
    next_scan = now + 1
    scan(s, peer)
    -- once a mission, 8 s in: what this session looks like (for games hosted by someone else)
    local wid = chef.world_id and chef.world_id()
    if wid ~= session.wid then session.wid, session.at = wid, now end
    if session.at and now - session.at >= 8 then
      session.at = nil
      local on, sample = 0, nil
      for goid, o in pairs(objs) do
        local t = o.t and TYPES[o.t]
        if t and o.on and not t.pack and not t.other and not t.player and not t.avatar then
          on = on + 1
          if not sample and t.has.owner then sample = field(s, goid, t, 'owner') end
        end
      end
      local packs = {}
      for goid, o in pairs(objs) do
        local t = o.t and TYPES[o.t]
        if t and o.on and (t.pack or t.special) then
          packs[#packs + 1] = t.id .. (t.has.carry and ('(carry ' .. tostring(field(s, goid, t, 'carry')) .. ')') or '')
        end
      end
      log('session: you %s, host %s; %d objects yours, %d the host\'s; your player %s; %d weapons on you; a weapon\'s owner field reads %s (%s); packs on you: %s',
        tostring(peer), tostring(session.host), session.mine, session.hosts, me.player and 'found' or 'not found', on,
        tostring(sample), type(sample), #packs > 0 and table.concat(packs, ' ') or 'none')
    end
  end
  read_fire_button(now)
  read_swap(now)
  read_forget_keys(now)

  if now >= next_read then
    next_read = now + 0.1
    local grip = hand_pose()
    watch_fire(s, grip)
    local goid = pick(s, grip, now)
    if goid ~= hand.goid or grip ~= hand.grip then
      if cfg.research and goid and hand.goid and goid ~= hand.goid and grip == hand.grip then research_switch(s, hand.goid, goid, grip, now) end
      local o = goid and objs[goid]
      local said = string.format('hand pose %s: %s', tostring(grip), o and TYPES[o.t].id or 'no weapon shown')
      if said ~= hand.said then log('%s', said) hand.said = said end
      hand.goid, hand.grip = goid, grip
    end
    local o = goid and objs[goid]
    if o and o.prev and cfg.research then
      local w = o.prev
      local line = string.format('fields %s: fire_mode=%s options=%s rpm=%s selected=%s', TYPES[o.t].id,
        tostring(w.fire_mode), tostring(w.options), TYPES[o.t].has.heat and '-' or tostring(w.rpm), tostring(w.selected))
      if line ~= hand.fields then hand.fields = line log('%s', line) end
    end
    if o and o.t and cfg.research then research_watch(s, goid, TYPES[o.t]) end
    if cfg.research then
      -- your backpack (jump pack, hover pack ...: what it keeps), and while nothing is shown, the weapons on you not
      -- learned yet (what an Arc Thrower changes when fired)
      for pgoid, po in pairs(objs) do
        local pt = po.t and TYPES[po.t]
        if pt and po.on and (pt.pack or pt.other or (shown_now == nil and grip and grip ~= 0 and not THROWABLE[grip]
            and not pt.player and not pt.avatar and learned.grip[pt.id] == nil and not po.ub)) then
          research_watch(s, pgoid, pt)
        end
      end
    end
    shown_now = o and o.t and shown(s, goid, TYPES[o.t], o.prev or read_weapon(s, goid, TYPES[o.t]), o) or nil
    if shown_now and shown_now.kind == nil then shown_now = nil end
    hand.throwable = THROWABLE[grip] == true
  end

  if me.avatar and now >= next_items and alive(s, me.avatar, TYPES[2]) then
    next_items = now + 0.25
    local g = call('avatar.grenades', 'GameSession.game_object_field', s, me.avatar, DATA.avatar.grenades)
    local st = call('avatar.stims', 'GameSession.game_object_field', s, me.avatar, DATA.avatar.stims)
    items_now = (type(g) == 'number' and type(st) == 'number') and { g = g, s = st } or nil
    -- (research: what the avatar's grenade and stim fields read, each time they change)
    if cfg.research then
      local said = string.format('research: items: grenades=%s stims=%s (avatar %s)', tostring(g), tostring(st), tostring(me.avatar))
      if said ~= hand.items_said then hand.items_said = said log('%s', said) end
    end
    if items_now then
      read_av_refs(s)
      local r, pgoid = pack_ammo(s)
      local po = pgoid and objs[pgoid]
      local pt = po and po.t and TYPES[po.t]
      -- the warp pack's heat; the jump and hover packs' recharge
      for sgoid, o in pairs(objs) do
        local t = o.t and TYPES[o.t]
        local sp = t and t.special
        if sp and o.on and alive(s, sgoid, t) then
          local v = call(t.id .. '.special', 'GameSession.game_object_field', s, sgoid, sp.fname)
          if sp.kind == 'warp' and type(v) == 'number' then
            items_now.warp = v
          elseif sp.kind == 'timer' and type(v) == 'boolean' then
            if o.sp_prev ~= nil and v ~= o.sp_prev and v == sp.on_rise then o.sp_t = now end
            if v and not sp.on_rise then o.sp_t = nil end          -- (hovering: the recharge starts on landing)
            -- a flight starts when the flag comes on with no flight in the last 14 s (later ones are the landing assist)
            if sp.flight and v and o.sp_prev == false and (o.fly_t == nil or now - o.fly_t > 14) then o.fly_t = now end
            o.sp_prev = v
            local f = 1
            if v and not sp.on_rise then
              f = sp.flight and o.fly_t and math.max(0, 1 - (now - o.fly_t) / sp.flight) or 0   -- (draining)
              items_now.draining = true
            elseif o.sp_t then f = math.min(1, (now - o.sp_t) / sp.secs) end
            items_now.recharge = f
          end
        end
      end
      if cfg.research and (pt and pt.id) ~= hand.bar_pack then
        hand.bar_pack = pt and pt.id
        log('research: backpack bar %s', pt and (pt.id .. ' (object ' .. tostring(pgoid) .. ')') or 'off')
      end
      if r and pt then
        if r > (learned.pack[pt.id] or 0) then learn('pack', pt.id, r) end
        items_now.pack, items_now.pack_top = r, learned.pack[pt.id]
      end
    end
  end

  -- Heat, every frame: run on at the weapon's rate (up while the trigger is held, read every frame; down otherwise),
  -- and when the field brings a new value, fold the difference in over a quarter second instead of jumping to it.
  local d = shown_now
  if d and d.kind == 'heat' and d.o and d.o.h_last and not d.charge_anim then
    local o = d.o
    local held
    if d.t.has.held and learned.charge2[d.tid] == nil then held = field(s, d.goid, d.t, 'held') == true
    else held = o.firing == true end
    local dt = math.min(0.1, now - (o.sim_t or now))
    o.sim_t = now
    if o.sim == nil then
      o.sim, o.err, o.sim_seen = o.h_last, 0, o.h_last_t
    else
      local rate = held and heat_rate('up', d.tid) or (not held and heat_rate('down', d.tid) and -heat_rate('down', d.tid)) or 0
      o.sim = o.sim + rate * dt
      if o.sim_seen ~= o.h_last_t then                     -- a new value from the field
        o.sim_seen = o.h_last_t
        o.err = o.h_last - o.sim
      end
      local take = (o.err or 0) * math.min(1, dt / 0.25)
      o.sim, o.err = o.sim + take, (o.err or 0) - take
    end
    o.sim = math.max(0, math.min(d.top_raw, o.sim))
    d.value = math.max(0, o.sim - d.rest)
  elseif d and d.o then
    d.o.sim = nil
  end
  -- a charge weapon charging (the Nova, the Quasar): the bar rises every frame over its charge time
  if d and d.kind == 'heat' and d.charge_anim and d.o and d.o.charge_t0 then
    local h = d.charge_from + (d.top_raw - d.charge_from) * math.min(1, (now - d.o.charge_t0) / d.charge_secs)
    d.value = math.max(0, h - d.rest)
  end
  -- lock-on (the Spear, the WASP ...): the weapon's lock progress, 0 to 1, as a line over the bar; orange once locked
  if d and d.t0 and d.t0.has.lock then
    local p = tonumber(field(s, d.goid0, d.t0, 'lock'))
    if p and p > 0 then
      d.charge_frac = math.min(1, p)
      d.locked = d.t0.has.locked and field(s, d.goid0, d.t0, 'locked') == true
    end
  end
  -- charge meters: the time the trigger has been held, over the weapon's charge time (the Helldivers 2 wiki: the
  -- Railgun's unsafe mode explodes at 3 s with 90 % at 2.5 s; the Epoch is fully charged at 2.6 s and explodes at
  -- 3.25 s), read every frame
  if d and d.t0 and (CHARGE_METER[d.t0.id] or d.t0.noammo) and d.t0.has.held then
    local m = CHARGE_METER[d.t0.id] or { secs = 1 }   -- (the Arc Thrower: 1 s, the Helldivers 2 wiki)
    local held = field(s, d.goid0, d.t0, 'held') == true
    if held then
      hand.held_t = hand.held_t or now
      d.charge_frac = (now - hand.held_t) / m.secs
      d.charge_mark = m.mark and m.mark / m.secs
    else
      hand.held_t = nil
    end
  elseif d then
    hand.held_t = nil
  end
  -- idle: dimmed or hidden when nothing changed for a while (idle_target)
  local target = idle_target(d, items_now, now)
  hand.fade = hand.fade or 1
  if target < hand.fade then hand.fade = math.max(target, hand.fade - (dt or 0.016) * 1.5) else hand.fade = target end
  alpha_k = cfg.opacity * hand.fade
  if (shown_now or (items_now and hand.grip and hand.grip ~= 0)) and hand.fade > 0.01 then
    local dd = shown_now
    if dd and not (cfg.show_rpm and cfg.show_fmode and cfg.show_mode and cfg.show_mags and cfg.show_charge) then
      dd = setmetatable({}, { __index = shown_now })
      if not cfg.show_rpm then dd.setting = false end
      if not cfg.show_fmode then dd.fmode = false end
      if not cfg.show_mode then dd.mode = false end
      if not cfg.show_mags then dd.reserve = false end
      if not cfg.show_charge then dd.charge_frac = false end
    end
    draw(dd, items_now)
  end
  alpha_k = cfg.opacity
  if (blocked.n >= 5 or (blocked.types or 0) > 2000 and not blocked.yes) and blocked.since and now - blocked.since < 25 then
    if not blocked.said then blocked.said = true log('GameSession.game_object_is_type refused: your weapons can\'t be read with this Chef version') end
    notice('NarrowHUD: this Chef version blocks the reads it needs (it runs on Chef Shared Loader 1.0.x and 1.2 on)')
  end
  if flash.text and now < flash.till then notice(flash.text) end
end

function M.shutdown()
  if dirty_at then save_learned() end
end

return M
