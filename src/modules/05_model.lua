-- NarrowHUD, model: the weapon model at your hand — which weapon type's unit sits on your Helldiver's right-hand node.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES, HANDHELD, cfg = N.TYPES, N.HANDHELD, N.cfg

-- (2.2.2) Each weapon network type has a unit (its model): WEAPON_UNITS (src/weapon_units_generated.lua, from
-- filediver's entity table: the entity's resource hash is the unit's path hash, and its game object id is the type).
-- Those units are watched, and the one within HAND m of the Helldiver's attach_hand_r node is the weapon in hand —
-- before it has fired, and told from another weapon on the same hand pose (the Nova and the Breacher). The idea is
-- HUDdle 0.7.0's (its own code; docs/RESEARCH.md); this is ours. A unit says its kind, not whose it is: as host a
-- SEAF soldier's rifle of your type is a body away from your hand, so the distance alone tells them apart; two
-- objects of one type (yours and a soldier's) can't be told by the model, so the pick uses it only between types.
-- (2.2.3) luka's first log: the held weapon's root reads 0.00 m from the hand node, every holstered one 0.37 m or
-- more (0.38–0.85): 0.2 m tells them apart with room; 0.4 took a holstered Ultimatum for the one in hand once
local HAND, NEAR = 0.2, 1.2                   -- at the hand; near enough to mention in the research log
local units_of = {}                           -- unit kind -> { type ids }
local kinds = {}
for tid, kind in pairs(WEAPON_UNITS or {}) do
  if HANDHELD[tid] then
    local l = units_of[kind] or {}
    l[#l + 1] = tid
    units_of[kind] = l
    kinds[kind] = true
  end
end
local watch = (chef.watch and next(kinds)) and chef.watch(kinds, 0.25) or nil
local hand_of = { u = nil, node = nil }
local cache = { at = -1, near = {}, best = nil, dist = nil }
local said, last_said = 0, nil
-- the types whose model is near the hand now: { [tid] = metres }, the nearest tid and its distance (nil: not known —
-- no watch, no Helldiver unit, no hand node)
local function model_at_hand(now)
  if now - cache.at < 0.1 then return cache.near, cache.best, cache.dist end
  cache.at = now
  cache.near, cache.best, cache.dist = {}, nil, nil
  local u = N.my_unit and N.my_unit()
  if not (watch and watch.items and u and chef.unit_node and chef.unit_position) then return nil end
  if hand_of.u ~= u then hand_of.u, hand_of.node = u, chef.unit_node(u, 'attach_hand_r') end
  if not hand_of.node then return nil end
  local hx, hy, hz = chef.unit_position(u, hand_of.node)
  if not hx then return nil end
  local near, best, bd = {}, nil, nil
  for _, it in ipairs(watch.items) do
    local k = it.kind or (chef.unit_kind and chef.unit_kind(it.unit))
    local l = k and units_of[k]
    if l and (not chef.unit_alive or chef.unit_alive(it.unit) == true) then
      local x, y, z = chef.unit_position(it.unit)
      if x then
        local d = math.sqrt((x - hx) ^ 2 + (y - hy) ^ 2 + (z - hz) ^ 2)
        if d <= NEAR then
          for _, tid in ipairs(l) do
            if near[tid] == nil or d < near[tid] then near[tid] = d end
            if bd == nil or d < bd then best, bd = tid, d end
          end
        end
      end
    end
  end
  cache.near, cache.best, cache.dist = near, best, bd
  -- (how long the same type has been at the hand: a pick waits for a steady 0.2 s)
  local at = best and bd <= HAND and best or nil
  if at ~= cache.at_type then cache.at_type, cache.at_since = at, now end
  -- (research: the nearest model as it changes, 200 lines a mission at most)
  if cfg.research and said < 200 then
    local key = best and (best .. (bd <= HAND and ' at' or ' near')) or 'none'
    if key ~= last_said then
      last_said, said = key, said + 1
      local others = {}
      for tid, d in pairs(near) do if tid ~= best then others[#others + 1] = string.format('%s %.2f', tid, d) end end
      log('research: model at hand: %s%s', best and string.format('%s %.2f m', best, bd) or 'none within 1.2 m',
        #others > 0 and (' (also ' .. table.concat(others, ', ') .. ')') or '')
    end
  end
  return near, best, bd
end
-- the type at the hand (within HAND m, for 0.2 s), or nil
local function type_at_hand(now)
  local near, best, bd = model_at_hand(now)
  if best and bd and bd <= HAND and cache.at_type == best and now - (cache.at_since or now) >= 0.2 then return best, bd end
  return nil
end
N.model_at_hand, N.type_at_hand, N.MODEL_HAND = model_at_hand, type_at_hand, HAND
N.model_watch = watch   -- (tests)
