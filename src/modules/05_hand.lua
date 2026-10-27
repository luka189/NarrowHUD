-- NarrowHUD, hand: the weapon in your hand: hand pose, the fire button and controllers, the Helldiver's fields, backpack ammo, swap keys, picking the weapon shown.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES, HANDHELD, AVATAR_RESOURCE, GRIP_VARIABLE, THROWABLE, call = N.TYPES, N.HANDHELD, N.AVATAR_RESOURCE, N.GRIP_VARIABLE, N.THROWABLE, N.call
local blocked, alive, field, cfg, MOUSE_BUTTONS, learned = N.blocked, N.alive, N.field, N.cfg, N.MOUSE_BUTTONS, N.learned
local CHARGE_WEAPONS, learn, keys, distrust, has_pose, forget_poses = N.CHARGE_WEAPONS, N.learn, N.keys, N.distrust, N.has_pose, N.forget_poses
local objs, me, as_peer, session = N.objs, N.me, N.as_peer, N.session

------------------------------------------------------------------------------------------------ your hand pose
local watch = chef.watch and chef.watch({ [AVATAR_RESOURCE] = true }, 2) or nil
local grip_index = setmetatable({}, { __mode = 'k' })
local function nearest_unit()
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
-- Your Helldiver: the Helldiver unit nearest the camera. (1.0.7 to 1.2.5 asked the session's unit synchronizer for
-- your avatar object's unit first: Helldivers 2 keeps none, it answered nil in every game, hosted or joined.)
local function my_unit(s) return nearest_unit() end
N.my_unit = my_unit
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
local PAD_STRAT = { 'left_shoulder', 'l1', 'lb' }      -- (1.2.4: the stratagem button, the game's default)
local PAD_AIM = { 'left_trigger', 'l2', 'lt' }         -- (1.4.6: aiming, the game's default)
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
      for _, c in ipairs(PAD_STRAT) do if by[c] then e.strat = by[c] break end end
      for _, c in ipairs(PAD_AIM) do if by[c] then e.aim = by[c] break end end
      if e.fire or e.swap then list[#list + 1] = e end
    end
  end
  if #list == 0 then
    -- (no pad listed its buttons: the Xbox names on the first one)
    local f, y = call('pad', 'Pad1.button_index', 'right_trigger'), call('pad', 'Pad1.button_index', 'y')
    local l1, l2 = call('pad', 'Pad1.button_index', 'left_shoulder'), call('pad', 'Pad1.button_index', 'left_trigger')
    if type(f) == 'number' or type(y) == 'number' then
      list[1] = { name = 'Pad1', fire = type(f) == 'number' and f or nil, swap = type(y) == 'number' and y or nil,
                  strat = type(l1) == 'number' and l1 or nil, aim = type(l2) == 'number' and l2 or nil }
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
  -- (anything at all on the fire button or a trigger: a weapon's trigger field held with none of this isn't yours)
  if (type(v) == 'number' and v > 0) or (type(pv) == 'number' and pv > 0.02) then input.any_last = now end
  if type(pv) == 'number' and pv > 0.3 then
    input.last, input.ever = now, true
    if not input.pad_said then input.pad_said = true log('fire button: a controller\'s right trigger seen') end
  end
  -- (1.2.7: each press counted, for the heat of a laser that fires shots: the Talon's 15 a shot)
  local down = (type(v) == 'number' and v > 0.5) or (type(pv) == 'number' and pv > 0.3)
  if down and not input.down then input.presses = (input.presses or 0) + 1 end
  input.down = down
end
-- the aim button (the right mouse button, a controller's left trigger), for the drop line's "while aiming" (1.4.6:
-- the weapon stance field 95c46304 reads 4 only around a shot, not while you aim)
local function read_aim_button(now)
  if not input.aim_idx then input.aim_idx = call('mouse', 'Mouse.button_index', 'right') or false end
  local v = input.aim_idx and call('mouse', 'Mouse.button', input.aim_idx) or nil
  local aim = type(v) == 'number' and v > 0.5
  if not aim then
    for _, p in ipairs(pad_list(now)) do
      if p.aim then
        local x = call('pad', p.button, p.aim)
        if x == true or (type(x) == 'number' and x > 0.3) then aim = true break end
      end
    end
  end
  input.aiming = aim
end
N.read_aim_button = read_aim_button
-- (blind: your weapon in hand keeps firing and no fire input of any kind has been seen for a while: a controller
-- NarrowHUD can't read. Shots aren't checked from then on, as when nothing can be read)
local function pressed_recently(now) return input.ok ~= true or input.blind or now - input.last <= 0.4 end
local function hand_pose(s)
  local u = my_unit(s)
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
-- read a weapon's state; o.prev keeps the last one, to see it fire. lite: only what tells a shot, the trigger and a
-- reload (every weapon object but the one shown, ten times a second: as host, every SEAF soldier's gun too)
local ROLES_FULL = { 'rounds', 'magazines', 'slot0', 'slot1', 'selected', 'chamber', 'spare', 'heat',
                     'overheated', 'charging', 'reload_stage', 'fire_mode', 'rpm', 'options', 'held', 'guide' }
local ROLES_LITE = { 'rounds', 'slot0', 'slot1', 'chamber', 'heat', 'overheated', 'charging', 'held' }
N.reads = 0                                          -- (fields read, for the research log's timing line)
local function read_weapon(s, goid, t, lite)
  local w = { t = t, lite = lite or nil }
  if not alive(s, goid, t) then w.gone = true return w end
  for _, role in ipairs(lite and ROLES_LITE or ROLES_FULL) do
    if t.has[role] then w[role] = field(s, goid, t, role) N.reads = N.reads + 1 end
  end
  return w
end
-- the weapon can't fire now: overheated, or a charge weapon cooling from its shot (the Nova about 3 s, the Quasar 15):
-- your fire button held then isn't the shown one doing nothing
local function cooling_of(o, t)
  return o and o.prev and (o.prev.overheated == true or (t and CHARGE_WEAPONS[t.id] and type(o.prev.heat) == 'number'
    and o.prev.heat > (learned.rest2[t.id] or 0) + 5)) or false
end
N.cooling = cooling_of
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
  -- (the weapon options held, or let go a moment ago: the wheel is the scope's zoom or the light, not a swap)
  local menu = keys.weapon_menu
  if menu and menu.down and menu.down() == true then swap.menu_at = now end
  if key == nil and chef.wheel and now - (swap.menu_at or -100) > 0.2 then
    local w = chef.wheel()
    -- (up: a positive wheel value)
    local m = cfg.wheel or 1
    if type(w) == 'number' and w ~= 0 and (m == 1 or (m == 2 and w > 0) or (m == 3 and w < 0)) then key = 'wheel' end
  end
  -- a controller's weapon swap (Y, triangle on a PlayStation pad: the game's default): the other weapon, like the wheel
  if key == nil then
    for _, p in ipairs(pad_list(now)) do
      if p.swap and call('pad', p.pressed, p.swap) == true then key = 'wheel' end
    end
  end
  if key ~= nil then swap.prev_at, swap.key, swap.at, swap.used, swap.from = swap.at, key, now, false, hand.goid end
end
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
N.HOLD_FIRST = HOLD_FIRST
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
      objs[same[1]].taught_slot = swap.key
    end
    swap.used = true
  elseif #same > 1 and recent and now - swap.at >= 0.5 then
    -- several of your weapons share this pose (a shield's): the swap key or the wheel says which came out. Only half
    -- a second after the key: the hand pose changes about 0.4 s after a key, so a key bringing out a weapon on another
    -- pose found the old pose still up and chose a weapon on it (key 3 showed a Stalwart lying on the map, on the
    -- Sightliner's pose, for 0.4 s on the way to the AMR: a 2026-10-26 log)
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
  local holds = ct and (HOLD_FIRST[ct.id] or CHARGE_WEAPONS[ct.id] or ct.has.charging or ct.has.lock or ct.has.heat)
  local cooling = cooling_of(co, ct)
  local active = co and ((co.fired_at and now - co.fired_at <= 0.4) or (holds and co.held_t and now - co.held_t <= 0.4)
    or (holds and co.charging_t and now - co.charging_t <= 0.6)
    or (co.prev and (tonumber(co.prev.reload_stage) or 0) ~= 0) or cooling)
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

N.input, N.read_fire_button, N.pressed_recently, N.hand_pose, N.read_weapon, N.fired = input, read_fire_button, pressed_recently, hand_pose, read_weapon, fired
N.av_refs, N.av_said, N.read_av_refs, N.pack_ammo, N.packs_now, N.hand = av_refs, av_said, read_av_refs, pack_ammo, packs_now, hand
N.SWAP_KEYS, N.swap, N.read_swap, N.research_switch, N.pick = SWAP_KEYS, swap, read_swap, research_switch, pick
N.pad_list = pad_list
