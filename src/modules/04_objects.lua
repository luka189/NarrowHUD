-- NarrowHUD, objects: your objects: the session scan, sorting them into types, whose is whose, your player and Helldiver.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES, HANDHELD, NO_OBJECT, call, blocked, alive = N.TYPES, N.HANDHELD, N.NO_OBJECT, N.call, N.blocked, N.alive
local field, cfg, learned, forget_poses = N.field, N.cfg, N.learned, N.forget_poses

------------------------------------------------------------------------------------------------ your objects
local objs, queue = {}, {}       -- goid -> { t = index | false, next = n }; goids to type
local me = { player = nil, avatar = nil }
local BUDGET = 1000              -- type tests a frame
N.forget = function(goid) objs[goid] = nil N.checked[goid] = nil end

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
        N.type_tests = (N.type_tests or 0) + 1
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
      -- (1.5.16 research: what tells one map from another in the log, for the icon strobe: the world id and where you
      -- landed; chef_loader.log's world line has the unit and level counts)
      if cfg.research and chef.camera then
        local cam = chef.camera()
        if cam then log('research: this world: id %s, landed near %.0f,%.0f,%.0f (chef_loader.log has its unit and level counts)', tostring(wid), cam.x, cam.y, cam.z) end
      end
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
  -- your player: the one you own. In someone else's game the host's objects are in the list too, the host's own
  -- player among them; taking that one showed the host's grenades and stims, flicking between theirs and yours (a
  -- 2026-10-25 log). One of the host's only when no player of yours is there and it's the only one.
  me.player = nil
  local host_player, host_players = nil, 0
  for goid, o in pairs(objs) do
    if o.t == 1 then
      if o.host then host_player, host_players = goid, host_players + 1 else me.player = goid end
    end
  end
  if me.player == nil and host_players == 1 then me.player = host_player end
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
        -- (onto your body during the mission: picked up from its hellpod or the ground. Until it fires, it's the one
        -- in your hand among the weapons held the same way, not one of them at random)
        if o.on and o.on_was == false and not t.pack and HANDHELD[t.id] and not o.host then
          o.chosen_at = chef.time()
          if cfg.research then log('research: weapon %s (object %s) picked up', t.id, tostring(goid)) end
        end
        o.on_was = o.on
        -- A backpack's carry field (the 2026-10-25 log): 0 worn, 1 in its hellpod, 2 dropped. One that isn't yours
        -- (a mission objective's, a soldier's: as host you own those) can read 0 too. A called backpack can't be
        -- worn in a mission's first 10 s (the call-in alone takes 10 s, after landing), so one already at 0 then
        -- isn't yours, until it's seen at another value (dropped, then picked up) or proves yours. The same for the
        -- jump and warp packs (a jump pack of the map's showed a recharge bar with none on your back: the 1.2.7 log).
        if (t.pack or t.special) and type(c) == 'number' then
          if o.first_c == nil then
            o.first_c = c
            o.map_pack = c == 0 and blocked.since ~= nil and chef.time() - blocked.since < 10
            if o.map_pack and cfg.research then log('research: pack %s (object %s) there from the start: not yours until used', t.id, tostring(goid)) end
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


N.objs, N.queue, N.me, N.queue_2, N.queue_b, N.classify = objs, queue, me, queue_2, queue_b, classify
N.as_peer, N.session, N.scan = as_peer, session, scan
