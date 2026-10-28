-- NarrowHUD, learned: what NarrowHUD learns (the learned file, the shipped seed, forgetting), key bindings, hand poses per type.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local HANDHELD, cfg = N.HANDHELD, N.cfg

local learned = { grip = {}, mag = {}, heat = {}, rest = {}, charge2 = {}, up = {}, down = {}, modes = {}, rpms = {},
                  pack = {}, options1 = {}, packres = {}, rest2 = {}, poses = {},
                  packshow = {}, rpmadj = {}, rpmbase = {}, slot = {}, resmax = {}, reload_t = {}, reload_e = {},
                  stim = {}, shot = {} }
-- The learned file: what each kind holds per type id (8 hex digits), and the file's version (_v). Entries that don't
-- fit (a damaged or hand-edited file) are dropped and counted in the log; a file from a newer NarrowHUD is read for
-- what fits.
local LEARNED_VERSION = 1
local LEARNED_SHAPE = { grip = 'number', mag = 'number', heat = 'number', rest = 'number', charge2 = 'number',
  up = 'number', down = 'number', modes = 'string', rpms = 'string', pack = 'number', options1 = 'string',
  packres = 'boolean', rest2 = 'number', poses = 'string', packshow = 'boolean', rpmadj = 'boolean',
  rpmbase = 'string', slot = 'number', resmax = 'number', reload_t = 'number', reload_e = 'number', stim = 'number', shot = 'number' }
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
  -- (load_table's second value says why there's no table: called on its own, an 'and' would drop it)
  local ok, t, why = true, nil, nil
  if chef.load_table then ok, t, why = pcall(chef.load_table, 'learned') end
  if not ok then
    log('learned file: could not be read (%s): starting from the shipped knowledge', tostring(t))
  elseif type(t) == 'table' and type(t.elements) == 'table' then
    -- (1.2.1: a layout pasted into this file instead of the layout file, a player's report: NarrowHUD rewrites this
    -- file as it learns, so the paste looked "overwritten". It's moved to the layout file, and said on screen)
    local moved = false
    if chef.save_table then
      local okc, done = pcall(chef.save_table, 'layout', t)
      moved = okc and done ~= false
    end
    log('learned file: it holds a layout (the layout editor\'s file): %s; the learned file starts from the shipped knowledge',
      moved and 'moved to the layout file (chef_data_luka189_2fnarrowhud__layout.lua)' or 'could not be moved to the layout file')
    N.startup_flash = moved and 'NarrowHUD: your layout was in the learned file: moved to the layout file'
      or 'NarrowHUD: your layout is in the learned file: paste it into the file ending in __layout.lua'
    N.learned_rewrite = true                         -- (the learned file written back as learned knowledge)
  elseif type(t) == 'table' then
    local kept, dropped = read_learned(t)
    local v = tonumber(t._v) or 0
    if v > LEARNED_VERSION then log('learned file: from a newer NarrowHUD (version %d): read what fits', v) end
    if dropped > 0 then log('learned file: %d entries kept, %d that didn\'t fit dropped', kept, dropped) end
  elseif why and not string.find(tostring(why), 'none saved') and not string.find(tostring(why), 'no such file')
      and not string.find(tostring(why), 'missing') then
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
-- A rate of fire setting learned from one rate and that rate 0.9 (Extreme Cold), or from one rate only: dropped (1.0.6:
-- the Sightliner, rates 40 and 36 on two planets, showed 40 RPM). Shipped ones stay.
for id in pairs(learned.rpmadj) do
  if not (SEED and SEED.rpmadj and SEED.rpmadj[id]) then
    local vals = {}
    for v in string.gmatch(learned.rpmbase[id] or '', '[^,]+') do
      local n = tonumber(v)
      local same = false
      for _, u in ipairs(vals) do
        if n and (math.abs(n - u) <= 1.5 or math.abs(n - u * 0.9) <= 1.5 or math.abs(u - n * 0.9) <= 1.5) then same = true end
      end
      if n and not same then vals[#vals + 1] = n end
    end
    if #vals <= 1 then learned.rpmadj[id], learned.rpmbase[id] = nil, nil end
  end
end
-- An overheat point under 30 was a misread (1.0.7: the Scythe "overheats at 0", its heat read 0 as it overheated)
for id, v in pairs(learned.heat) do if v < 30 then learned.heat[id] = nil end end
N.dirty_at = nil
if N.learned_rewrite then N.dirty_at = chef.time() + 5 end
local function learn(kind, id, value)
  if learned[kind][id] == value then return end
  learned[kind][id] = value
  N.dirty_at = N.dirty_at or (chef.time() + 5)
end
-- Forgetting (two keys in the F9 menu, none set by default): the weapon in hand, or everything (pressed twice within
-- 3 s). What's forgotten falls back to the shipped knowledge.
local function forget_type(id)
  for kind in pairs(learned) do learned[kind][id] = nil end
  apply_seed(id)
  N.dirty_at = chef.time()
end
local function forget_all()
  for kind in pairs(learned) do learned[kind] = {} end
  apply_seed()
  N.dirty_at = chef.time()
end
local keys = {}
if chef.bind and chef.has and chef.has('bind') then
  pcall(function()
    -- (as bound in the game: NarrowHUD can't read the game's own key settings). The fire button's row, then the key
    -- it can be (used only when the row says so: shown as none otherwise)
    cfg.fire = chef.option('fire', { type = 'choice', label = 'Keys: fire button (as bound in the game)', choices = { 'Left mouse', 'Right mouse', 'Middle mouse', 'Mouse button 4', 'Mouse button 5', 'A keyboard key (next row)' }, default = 1 }) or 1
    chef.on_change('fire', function(v) cfg.fire = v or 1 end)
    keys.fire = (chef.bind('fire_key', 'off', '   Fire key (with "A keyboard key" above)'))
    -- (each in parentheses: chef.bind gives the binding and its menu row, and a call last in a table would add both)
    local sw = { (chef.bind('swap_primary', '1', 'Keys: swap to the primary (as in the game)')),
                 (chef.bind('swap_secondary', '2', 'Keys: swap to the secondary (as in the game)')),
                 (chef.bind('swap_support', '3', 'Keys: swap to the support weapon (as in the game)')) }
    if sw[1] and sw[2] and sw[3] then keys.swap = sw end
    -- the mouse wheel: the game swaps weapons with it by default; one bound to something else in the game (zoom, a
    -- fire mode ...) mustn't swap the HUD (a player's report, 1.0.5)
    cfg.wheel = chef.option('swap_wheel', { type = 'choice', label = 'Keys: mouse wheel swaps weapons (as in the game)', choices = { 'Up and down', 'Up only', 'Down only', 'No' }, default = 1 }) or 1
    chef.on_change('swap_wheel', function(v) cfg.wheel = v or 1 end)
    -- held, the game's weapon options key (R, reload's) makes the wheel change the scope's zoom (up) or the light
    -- (down): no swap then (a player's report, the AMR's scope, 1.0.5)
    keys.weapon_menu = (chef.bind('weapon_menu', 'r', 'Keys: weapon options, held (as in the game; the wheel doesn\'t swap then)'))
    -- (1.2.4: the HUD out of the way while the stratagem key is held; a controller's left shoulder button too)
    -- (no key until set: Left Ctrl, the game's default, is many players' crouch key, and the HUD hid while they crouched)
    keys.strat = (chef.bind('strat_key', 'off', 'Keys: stratagem key (set it to yours; a controller\'s left shoulder counts too)'))
    if N.settings_hide then N.settings_hide() end
    keys.reload_layout = (chef.bind('reload_layout', 'off', 'Keys: read the layout file again (Position: Custom)'))
    keys.forget_weapon = (chef.bind('forget_weapon', 'off', 'Testing: forget what\'s learned about the weapon in hand'))
    keys.forget_all = (chef.bind('forget_all', 'off', 'Testing: forget everything learned (press twice)'))
    keys.log_mark = (chef.bind('log_mark', 'off', 'Testing: put a numbered mark in the log (say what happened at each)'))
  end)
elseif N.settings_hide then N.settings_hide()
end
if N.settings_testing then N.settings_testing() end

-- A weapon can have several hand poses (with a shield in the other hand: the Verdict at 1, 30 and 36): a set per type
-- ("10,30"), next to the single pose older versions kept (learned.grip).
local distrust = {}                                 -- types with an object that fired without your fire button
-- A type learned for 4 or more hand poses that didn't ship with NarrowHUD isn't one weapon's set: every real one
-- has 1 to 3 (the Verdict's 3, with a shield). As host, SEAF soldiers' guns got learned for every pose you fired at
-- (a 2026-10-25 log: five types, up to 7 poses each), and 1.0.6 learned swaps wrong (a player's Liberator Legacy
-- got the grenade pistol's pose and two more within a second, and was never shown again: a 2026-10-28 report).
-- Until 1.5.14 such a type was never shown again; now its poses are forgotten and it's learned again from your next
-- shot (whether a gun is yours is the aim field's and the trigger's call since 1.2.5).
local function many_poses(id)
  local l = learned.poses[id]
  if not l or (SEED and ((SEED.poses and SEED.poses[id]) or (SEED.grip and SEED.grip[id]))) or SEED_GRIPS[id] then return false end
  local n = 1
  for _ in string.gmatch(l, ',') do n = n + 1 end
  if n < 4 then return false end
  log('type %s: learned for %d hand poses (%s): not one weapon\'s set (an older version learned swaps wrong?): forgotten, learned again from your next shot', id, n, l)
  learn('grip', id, nil)
  learn('poses', id, nil)
  return false
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
-- one pose taken back (learned from a gun that proved someone else's)
local function remove_pose(id, grip)
  if learned.grip[id] == grip and not learned.poses[id] then learn('grip', id, nil) return end
  local l = learned.poses[id]
  if not l then return end
  local keep = {}
  for g in string.gmatch(l, '[^,]+') do if tonumber(g) ~= grip then keep[#keep + 1] = g end end
  learn('poses', id, #keep > 0 and table.concat(keep, ',') or nil)
  if learned.grip[id] == grip then learn('grip', id, nil) end
end


N.learned, N.save_learned, N.HEAT_RANGE, N.CHARGE_WEAPONS, N.learn, N.forget_type = learned, save_learned, HEAT_RANGE, CHARGE_WEAPONS, learn, forget_type
N.forget_all, N.keys, N.distrust, N.many_poses, N.has_pose, N.add_pose = forget_all, keys, distrust, many_poses, has_pose, add_pose
N.forget_poses, N.remove_pose = forget_poses, remove_pose
