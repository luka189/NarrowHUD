-- NarrowHUD, learned: what NarrowHUD learns (the learned file, the shipped seed, forgetting), key bindings, hand poses per type.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local HANDHELD, cfg = N.HANDHELD, N.cfg

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
  -- (load_table's second value says why there's no table: called on its own, an 'and' would drop it)
  local ok, t, why = true, nil, nil
  if chef.load_table then ok, t, why = pcall(chef.load_table, 'learned') end
  if not ok then
    log('learned file: could not be read (%s): starting from the shipped knowledge', tostring(t))
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
N.dirty_at = nil
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
    cfg.fire = chef.option('fire', { type = 'choice', label = 'Fire button (as bound in the game)', choices = { 'Left mouse', 'Right mouse', 'Middle mouse', 'Mouse button 4', 'Mouse button 5', 'A keyboard key (next row)' }, default = 1 }) or 1
    chef.on_change('fire', function(v) cfg.fire = v or 1 end)
    keys.fire = (chef.bind('fire_key', 'off', '   Fire on a keyboard key: which (only with "A keyboard key" above)'))
    -- (each in parentheses: chef.bind gives the binding and its menu row, and a call last in a table would add both)
    local sw = { (chef.bind('swap_primary', '1', 'Swap key: primary (as in the game)')),
                 (chef.bind('swap_secondary', '2', 'Swap key: secondary (as in the game)')),
                 (chef.bind('swap_support', '3', 'Swap key: support weapon (as in the game)')) }
    if sw[1] and sw[2] and sw[3] then keys.swap = sw end
    -- the mouse wheel: the game swaps weapons with it by default; one bound to something else in the game (zoom, a
    -- fire mode ...) mustn't swap the HUD (a player's report, 1.0.5)
    cfg.wheel = chef.option('swap_wheel', { type = 'choice', label = 'Mouse wheel swaps weapons (as in the game)', choices = { 'Up and down', 'Up only', 'Down only', 'No' }, default = 1 }) or 1
    chef.on_change('swap_wheel', function(v) cfg.wheel = v or 1 end)
    -- held, the game's weapon options key (R, reload's) makes the wheel change the scope's zoom (up) or the light
    -- (down): no swap then (a player's report, the AMR's scope, 1.0.5)
    keys.weapon_menu = (chef.bind('weapon_menu', 'r', 'Weapon options key, held (as in the game): the wheel doesn\'t swap then'))
    keys.forget_weapon = (chef.bind('forget_weapon', 'off', 'Forget what\'s learned about the weapon in hand'))
    keys.forget_all = (chef.bind('forget_all', 'off', 'Forget everything learned (press twice)'))
    keys.reload_layout = (chef.bind('reload_layout', 'off', 'Read the layout file again (Position: Custom)'))
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
