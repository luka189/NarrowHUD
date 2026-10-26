-- NarrowHUD, learning: watching every weapon: shots, heat (the model and the planet), reloads, learning poses and keys, the SEAF guards.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES, HANDHELD, THROWABLE, cfg, learned, CHARGE_WEAPONS = N.TYPES, N.HANDHELD, N.THROWABLE, N.cfg, N.learned, N.CHARGE_WEAPONS
local learn, distrust, many_poses, has_pose, add_pose, objs = N.learn, N.distrust, N.many_poses, N.has_pose, N.add_pose, N.objs
local input, pressed_recently, read_weapon, fired, pack_ammo, packs_now = N.input, N.pressed_recently, N.read_weapon, N.fired, N.pack_ammo, N.packs_now
local hand, SWAP_KEYS, swap = N.hand, N.SWAP_KEYS, N.swap

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

N.pack_prev, N.pack_vals = nil, {}
local recent = { reload_t = -100, reload_t_type = nil, pack_drop_t = -100 }
local pending_learn = {}
local busy_said = 0
local watch_n = 0
-- an object proven someone else's (as host: a SEAF soldier's gun): never shown or learned from again this mission, its
-- type distrusted (another of its kind must prove itself yours), and what it taught this mission taken back
local function not_yours(goid, o, t, why)
  if o.notmine then return end
  o.notmine = true
  distrust[t.id] = true
  if cfg.research then log('research: an object of type %s %s: not yours', t.id, why) end
  for _, g in ipairs(o.taught or {}) do
    if has_pose(t.id, g) then
      log('type %s: hand pose %d forgotten (learned from a gun that isn\'t yours)', t.id, g)
      N.remove_pose(t.id, g)
    end
  end
  if o.taught_slot and learned.slot[t.id] == o.taught_slot then
    log('type %s: swap key %s forgotten (learned from a gun that isn\'t yours)', t.id, SWAP_KEYS[o.taught_slot])
    learn('slot', t.id, nil)
  end
  if hand.goid == goid then hand.goid = nil end
end
N.not_yours = not_yours
local function watch_fire(s, grip)
  -- last read's learning (see below): dropped for an object that fired while the weapon shown in hand did too
  if #pending_learn > 0 then
    local so = hand.goid and objs[hand.goid]
    local st = so and so.t and TYPES[so.t]
    for _, e in ipairs(pending_learn) do
      -- (the shown one busy: it fired, or it's one held before it fires (a charge, a lock-on: the Nova, in that log) and its
      -- trigger was held or it was charging at the time)
      local holds = st and (N.HOLD_FIRST[st.id] or CHARGE_WEAPONS[st.id] or st.has.charging or st.has.lock)
      local active = so and ((so.fired_at and math.abs(so.fired_at - e.at) <= 0.4)
        or (holds and ((so.held_t and math.abs(so.held_t - e.at) <= 0.4) or (so.prev and so.prev.charging == true))))
      local busy = st and hand.goid ~= e.goid and active and has_pose(st.id, e.grip) and objs[e.goid] ~= nil
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
  N.watched = 0
  watch_n = watch_n + 1
  for goid, o in pairs(objs) do
    local t = o.t and TYPES[o.t]
    -- (one proven someone else's isn't read again: as host, a SEAF squad's guns were most of the reads; the others
    -- but the one shown every other read, half each time: a shot still shows, as its ammo or heat moved since)
    if t and not t.pack and not t.player and not t.avatar and not t.other and o.on and not o.notmine
       and (goid == hand.goid or (goid + watch_n) % 2 == 0) then
      local w = read_weapon(s, goid, t, goid ~= hand.goid)
      if w.gone then break end                 -- forgotten (gone): the rest wait for the next read
      N.watched = N.watched + 1
      local now = chef.time()
      -- its trigger held with nothing on your fire button or trigger for over half a second, three reads: someone
      -- else's (a SEAF soldier's gun of a kind you carry, held=true while you weren't firing, in a 2026-10-26 log).
      -- Only once a press has been seen (a controller NarrowHUD can't read never shows one), and never for one that
      -- fired with your fire button 10 times and never without it.
      local proven = (o.unpressed or 0) == 0 and (o.pressed or 0) >= 10
      if w.held == true and input.ok == true and input.ever and not input.blind and not proven
         and now - (input.any_last or -100) > 0.6 then
        o.held_alone = (o.held_alone or 0) + 1
        if o.held_alone >= 3 then not_yours(goid, o, t, 'holds its trigger without your fire button') end
      end
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
        -- its own magazines or spare rounds went down: it reloads from those, never from the backpack (the Railgun
        -- reloading just as the Guard Dog reloaded from its backpack was learned as a backpack weapon, and showed the
        -- dog's magazines). Only
        -- sure when the last read had them too (a lite read doesn't).
        local function down(k) return type(w[k]) == 'number' and type(o.prev[k]) == 'number' and w[k] < o.prev[k] end
        local own = down('magazines') or down('spare')
        recent.reload_sure = not o.prev.lite and not own
        if own and learned.packres[t.id] then
          log('type %s reloads from its own magazines, not the backpack (learned wrongly before)', t.id)
          learn('packres', t.id, nil)
        end
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
        -- (three shots without it, and a quarter or more of all its shots: a soldier firing while you fire too got 10
        -- with and 6 without, and took the HUD; your own weapons fire without it never)
        if u >= 3 and u * 4 >= p then not_yours(goid, o, t, 'fires without your fire button') end
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
              if objs[goid] then objs[goid].taught_slot = swap.key end
            end
            swap.chosen = nil
          end
          if (not has_pose(t.id, grip) and not many_poses(t.id)) then
            log('learned: type %s goes with hand pose %d', t.id, grip)
            add_pose(t.id, grip)
            local lo = objs[goid]
            if lo then lo.taught = lo.taught or {} lo.taught[#lo.taught + 1] = grip end
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
    local was = N.pack_vals[pg]
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
  N.pack_vals = cur
  local r = pack_ammo(s)
  -- a weapon that reloads from the backpack: it got more loaded within a second of the pack going down (either first)
  if r and N.pack_prev and r < N.pack_prev then recent.pack_drop_t = now end
  local rt = recent.reload_t_type
  if rt and math.abs(recent.pack_drop_t - recent.reload_t) <= 1 and not learned.packres[rt.id] and not rt.fed
     and recent.reload_sure then
    log('learned: type %s reloads from the backpack', rt.id)
    learn('packres', rt.id, true)
  end
  -- (a pack going down near a reload is the reload, never a fed weapon firing)
  local reloading = now - recent.reload_t <= 1.5
  if r and N.pack_prev and r < N.pack_prev and not any_fired and not reloading and grip and grip ~= 0 and not THROWABLE[grip] then
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
  N.pack_prev = r
end

-- Fire modes and rates of fire: shown once a weapon has been seen with two of them (learned, so from then on at once).
-- The fire mode field's value 8 selects an underbarrel (seen: the Arbitrator); 1, 2, 3 are auto, semi, burst (seen in
-- the research log against the game's own display). Other values show as MODE <n> until named.

N.planet, N.heat_rate, N.watch_fire = planet, heat_rate, watch_fire
