-- NarrowHUD, heat: the heat bar between the field's values: a beam's rate while its trigger is held, a shot laser's
-- heat a shot, cooling, and the field's dead band.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local field, learned, learn, cfg, call = N.field, N.learned, N.learn, N.cfg, N.call
local heat_rate, input, CHARGE_WEAPONS = N.heat_rate, N.input, N.CHARGE_WEAPONS

-- The heat field moves in steps (the Scythe's 15.66, 31.34, 47 ...: a dead band of 15.6, Network.object_info's
-- tolerance for it), and lands a read late. So the bar runs its own model between values:
-- - a beam (the Scythe, the Laser Cannon, the Dagger: no rate of fire): up at the weapon's rate while the trigger
--   is held, down at its cooling otherwise (the rates: the wiki's or learned, 06_learning);
-- - a laser that fires shots (1.2.7; a rate of fire: the Talon, the Sickles, the Sai): each press of your fire
--   button a shot (two at most a frame), an automatic one firing on at its rate while the button is held, a burst
--   three; the heat a shot the wiki's (the Talon: 15) or learned from the field's rises over the shots counted; it
--   cools all along but for 0.3 s after a shot. A press is yours alone (the trigger field reads held for a soldier's
--   gun too), so with no fire button to read (a controller NarrowHUD can't see) the trigger field stands in.
-- A new value from the field is the heat as it was sent (a read late; a shot of the last 0.12 s may not be in it):
-- the difference is folded in over a quarter second, never jumped to. Between values the heat stays within the
-- band round the last one (the game would have sent a new one), so a model that runs past it is held at its edge.
local DELAY = 0.3
local tol_of = {}
local function heat_tol(t)
  local v = tol_of[t.id]
  if v ~= nil then return v or nil end
  v = false
  local ok, info = pcall(call, 'objinfo', 'Network.object_info', t.name)
  if ok and type(info) == 'table' and type(info.fields) == 'table' then
    for _, f in ipairs(info.fields) do
      if type(f) == 'table' and N.norm_id(f.id) == 'a5023836' and type(f.tolerance) == 'number' and f.tolerance > 0 then v = f.tolerance end
    end
  end
  if v == false then v = 15.6 end                 -- (every heat weapon seen so far)
  tol_of[t.id] = v
  return v
end
-- (the wiki's heat a shot is the start; the field's rises refine it (the 1.2.7 log: the Talon's 15 by the wiki,
-- about 12 by every rise read: 0 to 23.9 in two shots, 42.5 to 69.7 in three), so the bar doesn't run ahead)
local function shot_heat(id)
  local w = N.WIKI_HEAT and N.WIKI_HEAT[id]
  local wiki = w and w.shot or nil
  return learned.shot[id] or wiki, wiki
end
-- the model, every frame the weapon is shown (d: what's shown, o: its object)
local function heat_model(s, d, now)
  local o = d.o
  local by_shot = d.t.has.rpm == true and not CHARGE_WEAPONS[d.tid]
  -- (a shot laser's heat a shot not known yet: the beam model, up at the learned rate while the trigger is held,
  -- until the first rows teach it)
  local model_shots = by_shot and shot_heat(d.tid) ~= nil
  local trig
  if d.t.has.held and learned.charge2[d.tid] == nil then trig = field(s, d.goid, d.t, 'held') == true
  else trig = o.firing == true end
  local gap = now - (o.sim_t or -100)
  o.sim_t = now
  local top, rest = d.top_raw, d.rest or 0
  local tol = heat_tol(d.t)
  local cool = heat_rate('down', d.tid) or 0
  -- presses: your fire button's; when it can't be read, the trigger field going on
  local presses = input.presses or 0
  if input.ok ~= true or input.blind then
    if trig and not o.trig_was then o.trig_n = (o.trig_n or 0) + 1 end
    presses = o.trig_n or 0
  end
  o.trig_was = trig
  if o.sim == nil or gap > 0.5 then
    -- (first shown, or shown again: the field's last value, less what it has cooled since, within its band)
    local v = o.h_last
    if o.h_last_t and not trig then v = math.max(v - tol, v - cool * math.max(0, now - o.h_last_t - DELAY)) end
    o.sim, o.err, o.sim_seen, o.presses, o.shots, o.next_auto, o.burst_left = v, 0, o.h_last_t, presses, {}, nil, 0
    o.row = nil
    o.sim = math.max(0, math.min(top, o.sim))
    d.value = math.max(0, o.sim - rest)
    return
  end
  local dt = math.min(0.1, gap)
  local w = o.prev or {}
  local can = d.overheated ~= true and not d.reloading
  if by_shot then
    -- the shots this frame: presses (two at most), an automatic one's at its rate while the button is held, a
    -- burst's three
    local p = shot_heat(d.tid) or 0
    local rpm = tonumber(w.rpm)
    local every = (rpm and rpm > 0) and 60 / rpm or 0.1
    local mode = tonumber(w.fire_mode) and (w.fire_mode % 8) or 2
    local n = presses - (o.presses or presses)
    local fired = 0
    if n > 0 and can then
      fired = math.min(n, 2)
      o.next_auto, o.burst_left = now + every, mode == 3 and 2 or 0
    end
    local down = (input.ok == true and not input.blind) and input.down == true or trig
    if mode == 1 and can and down and o.next_auto then
      local k = 0
      while now >= o.next_auto and k < 4 do fired, o.next_auto, k = fired + 1, o.next_auto + every, k + 1 end
    elseif mode == 1 and not down then
      o.next_auto = nil
    end
    while (o.burst_left or 0) > 0 and can and o.next_auto and now >= o.next_auto do
      fired, o.burst_left, o.next_auto = fired + 1, o.burst_left - 1, o.next_auto + every
    end
    if fired > 0 then
      if model_shots then o.sim = o.sim + p * fired end
      o.shots = o.shots or {}
      table.insert(o.shots, 1, now)
      for k = #o.shots, 9, -1 do o.shots[k] = nil end
      if o.row then o.row.n = o.row.n + fired end
    end
    local cooling = not (o.shots and o.shots[1] and now - o.shots[1] < DELAY)
    if model_shots then
      if cooling then o.sim = o.sim - cool * dt end
    elseif trig then
      o.sim = o.sim + (heat_rate('up', d.tid) or 0) * dt
    else
      o.sim = o.sim - cool * dt
    end
    if cooling and o.row then o.row.tcool = o.row.tcool + dt end
  elseif trig then
    o.sim = o.sim + (heat_rate('up', d.tid) or 0) * dt
  else
    o.sim = o.sim - cool * dt
  end
  if o.sim_seen ~= o.h_last_t then                       -- a new value from the field
    o.sim_seen = o.h_last_t
    local v = o.h_last
    local e = v - o.sim
    -- (research: each value against the model's, 300 lines a weapon at most)
    if cfg.research and (o.hm_said or 0) < 300 then
      o.hm_said = (o.hm_said or 0) + 1
      log('research: %s heat %.1f, the bar had %.1f (%s; a shot %s, cooling %.1f a second)', d.tid, v, o.sim,
        model_shots and 'by shots' or (by_shot and 'beam model until its shot is learned' or 'beam'),
        tostring(shot_heat(d.tid)), cool)
    end
    -- (a value from just before the last shots: those aren't in it yet)
    if by_shot and e < 0 and o.shots then
      local recent = 0
      for _, ts in ipairs(o.shots) do if now - ts < 0.12 then recent = recent + 1 end end
      if recent > 0 then e = math.min(0, e + (shot_heat(d.tid) or 0) * recent) end
    end
    o.err, o.edge_t = e, nil
    -- (a shot laser's heat a shot learned from the rise between two values over the shots between them, the cooling
    -- in between put back; the wiki's kept where it has one)
    local r = o.row
    if by_shot and r and r.n > 0 and now - r.t <= 2 and can and r.v > rest + 1 and v < top * 0.95 then
      local est = (v - r.v + cool * r.tcool) / r.n
      local old, wiki = shot_heat(d.tid)
      -- (a rise within half of the wiki's number, where it has one; else anything a laser could heat a shot)
      local fits = wiki and (est >= wiki * 0.5 and est <= wiki * 1.5) or (not wiki and est >= 1 and est <= 60)
      if fits then
        local nv = math.floor((old and (old * 0.7 + est * 0.3) or est) * 100 + 0.5) / 100
        if cfg.research then log('research: %s heats %.1f a shot (%d shots, %.1f > %.1f, cooled %.2f s)', d.tid, est, r.n, r.v, v, r.tcool) end
        if learned.shot[d.tid] == nil then log('learned: type %s heats %.1f a shot%s', d.tid, nv, wiki and string.format(' (the wiki: %s)', tostring(wiki)) or '') end
        learn('shot', d.tid, nv)
      end
    end
    o.row = { v = v, t = now, n = 0, tcool = 0 }
  end
  local take = (o.err or 0) * math.min(1, dt / 0.25)
  o.sim, o.err = o.sim + take, (o.err or 0) - take
  o.presses = presses
  -- (the band: past its edge for a moment first, as a value may be on its way)
  if o.h_last_t and now - o.h_last_t > 0.3 then
    local lo, hi = o.h_last - tol - 1, o.h_last + tol + 1
    if o.sim < lo or o.sim > hi then
      o.edge_t = o.edge_t or now
      if now - o.edge_t > 0.35 then o.sim = math.max(lo, math.min(hi, o.sim)) end
    else
      o.edge_t = nil
    end
  end
  o.sim = math.max(0, math.min(top, o.sim))
  d.value = math.max(0, o.sim - rest)
end
N.heat_model, N.heat_tol = heat_model, heat_tol
