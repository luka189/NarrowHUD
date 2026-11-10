-- NarrowHUD, vitals: your health and stamina, the stim timer, your Helldiver's state (the stratagem input, emotes),
-- the warnings and the reload progress.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES, call, alive, cfg, learned, learn, me = N.TYPES, N.call, N.alive, N.cfg, N.learned, N.learn, N.me

-- (1.1.0) Health and stamina: your Helldiver's health, max_health and stamina fields (their real names; health 125
-- full and 0 dead, stamina 0 to 1, from the 1.0.10 research log), read every frame while a bar is on (two reads,
-- max_health once a second). A hit leaves what it took as a red "trail" that drains to the health after half a
-- second (2.3.7: over 0.2 s; none drawn on a red bar). Each bar's own fade: F9 says always, or while not full (and 2 s after); none while dead.
local vs = { goid = nil, max = 125, max_at = -100, trail = nil, prev_hp = nil, hit_at = nil, full_h = nil, full_s = nil,
  show_h = 0, show_s = 0, t = nil }
local function read_vitals(s, now)
  local av = me.avatar
  if not av or not alive(s, av, TYPES[2]) then vs.goid = nil N.dead = nil return nil end
  if vs.goid ~= av then
    vs.goid, vs.trail, vs.prev_hp, vs.hit_at, vs.max_at, vs.show_h, vs.show_s = av, nil, nil, nil, -100, 0, 0
    vs.chunks = {}
    vs.full_h, vs.full_s = -100, -100                    -- (full from the start: not shown)
  end
  if now - vs.max_at >= 1 then
    vs.max_at = now
    local m = call('avatar.max_health', 'GameSession.game_object_field', s, av, 'max_health')
    if type(m) == 'number' and m > 0 then vs.max = m end
  end
  local hp = call('avatar.health', 'GameSession.game_object_field', s, av, 'health')
  local st = call('avatar.stamina', 'GameSession.game_object_field', s, av, 'stamina')
  hp = type(hp) == 'number' and hp or nil
  st = type(st) == 'number' and st or nil
  if hp then N.dead = hp <= 0 end                                              -- (the vitals log: a freeze while dead isn't one)
  if hp and hp <= 0 then vs.show_h, vs.show_s = 0, 0 return nil end           -- (dead)
  local dt = math.min(0.1, now - (vs.t or now))
  vs.t = now
  -- (2.3.7) the trail, "One piece": held after the last hit (F9 "Hit trail held", 0.3 s; 0.5 in 2.3.7), then
  -- drained to the health over 0.2 s (eased; × the Motion scale, at once with Motion Off). A hit while it drains
  -- holds it where it is and starts the wait again
  local hold = cfg.trail_hold or 0.4
  local dsecs = 0.2 * (N.motion_scale and N.motion_scale() or 1)
  if hp then
    -- (2.3.8) "In chunks": each hit its own piece (from the health before it to the health after), held and drained
    -- on its own timer, so a new hit doesn't stop the older ones draining (luka). A heal clips them from below
    vs.chunks = vs.chunks or {}
    if vs.prev_hp and hp < vs.prev_hp then vs.chunks[#vs.chunks + 1] = { lo = hp, hi = vs.prev_hp, t = now } end
    local keep = 0
    for i = 1, #vs.chunks do
      local c = vs.chunks[i]
      local age = now - c.t - hold
      local p = age <= 0 and 0 or (dsecs > 0 and math.min(1, age / dsecs) or 1)
      local q = 1 - (1 - p) * (1 - p)
      c.top = c.hi - (c.hi - c.lo) * q
      if c.lo < hp then c.lo = hp end
      if p < 1 and c.top > c.lo then keep = keep + 1 vs.chunks[keep] = c end
    end
    for i = keep + 1, #vs.chunks do vs.chunks[i] = nil end
    if vs.trail == nil or hp >= vs.trail then vs.trail, vs.hit_at, vs.drain = hp, nil, nil
    else
      if vs.prev_hp and hp < vs.prev_hp then vs.hit_at, vs.drain = now, nil end
      if not vs.hit_at or now - vs.hit_at > hold then
        if not vs.drain then vs.drain = { from = vs.trail, t0 = now } end
        local p = dsecs > 0 and math.min(1, (now - vs.drain.t0) / dsecs) or 1
        local q = 1 - (1 - p) * (1 - p)
        vs.trail = math.max(hp, vs.drain.from + (hp - vs.drain.from) * q)
        if p >= 1 then vs.trail, vs.drain = hp, nil end
      end
    end
    vs.prev_hp = hp
  end
  local hurt, tired = hp ~= nil and hp < vs.max - 0.5, st ~= nil and st < 0.995
  if hurt then vs.full_h = nil elseif hp then vs.full_h = vs.full_h or now end
  if tired then vs.full_s = nil elseif st then vs.full_s = vs.full_s or now end
  local function fade(cur, want)
    if want then return math.min(1, cur + dt * 8) end
    return math.max(0, cur - dt * 2)
  end
  local hm, sm = cfg.health or 1, cfg.stamina or 1
  vs.show_h = fade(vs.show_h, hp ~= nil and (hm == 2 or (hm == 3 and (hurt or (vs.full_h ~= nil and now - vs.full_h < 2)))))
  vs.show_s = fade(vs.show_s, st ~= nil and (sm == 2 or (sm == 3 and (tired or (vs.full_s ~= nil and now - vs.full_s < 2)))))
  return { hp = hp, max = vs.max, st = st, trail = vs.trail, chunks = vs.chunks, show_h = vs.show_h, show_s = vs.show_s, busy = hurt or tired }
end
N.vitals_state = vs

-- Your Helldiver's state, every 0.1 s: an emote (active_emote: -1 or 0 when none), and (research) the aim field
-- 95c46304: 3 with the weapon raised (firing from the hip, overheated, a charge), 4 aiming down the sights, 1 around a
-- throw (the 1.2.2 log; 1.2.1 hid the HUD for 3, taking it for a stratagem's code). The stratagem key is read from F9's
-- key (Left Ctrl, the game's default) and a controller's left shoulder button. Stand-in names from DATA where the
-- real one isn't known.
local FNAME = {}
for id, name in string.gmatch(DATA.fieldnames or '', '(%x+) (%S+)') do FNAME[id] = name end
N.FNAME_AIM = FNAME['95c46304']
-- (2.5.25) vehicle guns fired from inside the armour: a gunner with one of these shown is hidden like the driver
-- (luka's Maelstrom tank, 2026-11-07: its gun 9df87863 shows as a weapon of ours); the FRV's turrets (66f5d393,
-- 0df6deff) are open and stay. 13_main's rule
N.ENCLOSED_GUNS = { ['9df87863'] = true }
local st8 = { at = -100, aim = 0, emote = -1, strat = false, goid = nil, armor = nil, armor_at = -100, view = nil, ads = nil, wheel = nil, role = nil }
local function strat_held()
  local k = N.keys and N.keys.strat
  if k and k.down and k.down() == true then return true end
  for _, p in ipairs(N.pad_list and N.pad_list(chef.time()) or {}) do
    if p.strat and (tonumber((call('pad', p.button, p.strat))) or 0) > 0.5 then return true end
  end
  return false
end
local function read_state(s, now)
  local held = strat_held()
  st8.strat = cfg.hide_strat and held or false
  if held then st8.strat_at = now end   -- (1.5.56: the throw line tells a stratagem ball from a mine at the same pose by it)
  local av = me.avatar
  if not av or not alive(s, av, TYPES[2]) then return end
  if st8.goid ~= av then
    st8.goid, st8.aim, st8.emote, st8.view, st8.ads, st8.wheel = av, 0, -1, nil, nil, nil
    st8.landed, st8.pod_t, st8.land_t, st8.seat, st8.pod_seen = false, now, nil, nil, nil   -- (2.4.7: a new Helldiver comes in its hellpod)
  end
  if now - st8.at < 0.1 then return end
  st8.at = now
  local e = call('avatar.emote', 'GameSession.game_object_field', s, av, 'active_emote')
  st8.emote = tonumber(e) or -1
  -- (the weapon's stance, for the research log and the drop line's "while aiming": 4 down the sights)
  if cfg.research or cfg.throw_line then
    local a = tonumber((call('avatar.aim', 'GameSession.game_object_field', s, av, FNAME['95c46304'] or 'ww3bwxa'))) or 0
    if cfg.research and a ~= st8.aim then log('research: field 95c46304 (aim) %s > %s at hand pose %s', tostring(st8.aim), tostring(a), tostring(N.hand and N.hand.grip)) end
    st8.aim = a
  end
  -- (2.0.1) your Helldiver's flags block 6ff0e58a, three 64-bit words as hex strings, read every 0.1 s like the
  -- rest. Word 1 bit 48: first person (luka's 2026-10-31 log: 8 of 8 flips within 0.1 s of the camera test, the
  -- Sightliner and the Maxigun). Word 2 bit 18 (0x40000): aiming, as a state — set while the aim is held or toggled
  -- on, through a swap to first person and back, cleared when the aim ends; the stance field 95c46304 stayed 0
  -- through all of it, so it's the signal for toggle-aim players, for whom the aim button isn't held. Both nil
  -- when the field can't be read (the camera and the button decide then, as before).
  local f = call('avatar.flags', 'GameSession.game_object_field', s, av, FNAME['6ff0e58a'] or 'gz3n3yj')
  local w1, w2 = type(f) == 'table' and f[1], type(f) == 'table' and f[2]
  local view = type(w1) == 'string' and #w1 == 16 and (tonumber(w1:sub(4, 4), 16) or 0) % 2 or nil
  local ads = type(w2) == 'string' and #w2 == 16 and math.floor((tonumber(w2:sub(12, 12), 16) or 0) / 4) % 2 or nil
  -- (2.1.1) word 2 bit 22 (0x400000): the weapon settings wheel is open (luka's 2026-11-01 log: six opens, each with
  -- it and with the Helldiver's cd889dbc going 90 > 122; nothing else set it)
  local wheel = type(w2) == 'string' and #w2 == 16 and math.floor((tonumber(w2:sub(11, 11), 16) or 0) / 4) % 2 or nil
  if wheel ~= st8.wheel then
    if cfg.research and (st8.wheel ~= nil or wheel ~= nil) then log('research: wheel bit (6ff0e58a word 2, bit 22) %s > %s', tostring(st8.wheel), tostring(wheel)) end
    st8.wheel = wheel
  end
  if view ~= st8.view then
    if cfg.research and (st8.view ~= nil or view ~= nil) then
      local cam = N.first_person and N.first_person()
      log('research: view bit (6ff0e58a word 1, bit 48) %s > %s; the camera says %s person, hand pose %s', tostring(st8.view), tostring(view), cam and 'first' or 'third', tostring(N.hand and N.hand.grip))
    end
    st8.view = view
  end
  -- (2.4.7) word 2 bit 50: in a vehicle seat (HUDdle 0.7.1's note from Blast & Trajectory Markers and Universal
  -- Trajectory Indicator; ours to confirm in the research log): no drop or throw line there
  local seat = type(w2) == 'string' and #w2 == 16 and math.floor((tonumber(w2:sub(4, 4), 16) or 0) / 4) % 2 or nil
  if seat ~= st8.seat then
    if cfg.research and (st8.seat ~= nil or seat ~= nil) then log('research: seat bit (6ff0e58a word 2, bit 50) %s > %s; hand pose %s', tostring(st8.seat), tostring(seat), tostring(N.hand and N.hand.grip)) end
    st8.seat = seat
  end
  -- (2.5.24, luka's nine seats of 2026-11-07) word 1's ninth hex digit (bits 28-31) is the seat's role while the
  -- seat bit is set: 1 a passenger (the FRV's and the tank's), 2 the driver (FRV, tank), 4 a gunner (the FRV's
  -- turret, the tank's gun), 8 the exosuit's pilot. 0 on foot
  local role = type(w1) == 'string' and #w1 == 16 and tonumber(w1:sub(9, 9), 16) or nil
  if role ~= st8.role then
    if cfg.research and (st8.role ~= nil or role ~= nil) then log('research: seat role (6ff0e58a word 1, bits 28-31) %s > %s; the seat bit %s, hand pose %s', tostring(st8.role), tostring(role), tostring(seat), tostring(N.hand and N.hand.grip)) end
    st8.role = role
  end
  -- (2.4.7) the hellpod: your Helldiver's d49efb40 reads false in the pod and true once it has landed (its first
  -- true: it flips in jumps and ragdolls later; HUDdle 0.5.4's finding). Unreadable counts as landed; 30 s at most
  -- (the 10 s after only for a pod seen: a Helldiver standing at the first read — the mod started mid-mission — has
  -- landed long ago)
  if st8.landed == false then
    local g = call('avatar.landed', 'GameSession.game_object_field', s, av, FNAME['d49efb40'] or 'qj687ja')
    if g == false then st8.pod_seen = true end
    if g ~= false or now - (st8.pod_t or now) > 30 then
      st8.landed, st8.land_t = true, st8.pod_seen and now or nil
      if cfg.research and st8.pod_seen then log('research: your Helldiver (object %s) %s', tostring(av), g == true and 'landed' or (g == nil and 'has no landing field' or 'not seen landing in 30 s')) end
    end
  end
  if ads ~= st8.ads then
    if cfg.research and (st8.ads ~= nil or ads ~= nil) then
      log('research: aim bit (6ff0e58a word 2, bit 18) %s > %s; the aim button %s, stance %s, hand pose %s', tostring(st8.ads), tostring(ads), tostring(N.input and N.input.aiming), tostring(st8.aim), tostring(N.hand and N.hand.grip))
    end
    st8.ads = ads
  end
  -- (the armour: your player object's armor_set, once a second, for the stim duration)
  -- (3.0.12: the player object checked first, like every other object read — the one read that went without)
  if me.player and now - st8.armor_at >= 1 and alive(s, me.player, TYPES[1]) then
    st8.armor_at = now
    local v = call('player.armor', 'GameSession.game_object_field', s, me.player, 'armor_set')
    if type(v) == 'number' then st8.armor = string.format('%08x', v % 4294967296) end
  end
end
N.state8 = st8
-- (2.4.7, HUDdle 0.7.3's crash fix, our own way) no reads of the world's units while you're dead, in your hellpod, or
-- in the first 10 s after it lands: a crash "about 30 s after dying in a hellpod that landed in a bug-nest hole" came
-- from reading units there ("the world around a death may still be changing"). Held: the ground walk, the feet and
-- vehicle samples, the structures' boxes (12_ground, 12_struct)
local hold = { on = nil }
function N.units_held(now)
  local on = N.dead == true or not (N.me and N.me.avatar) or st8.landed == false
    or (st8.land_t ~= nil and now - st8.land_t < 10)
  if on ~= hold.on then
    if cfg.research and hold.on ~= nil then log('research: unit reads %s', on and 'held (dead, in the hellpod or just landed)' or 'resumed') end
    hold.on = on
  end
  return on
end

-- The stim timer: a stim of yours (your stim count going down) lasts 4 s, 6 s with the Med-Kit or Adreno-Defibrillator
-- armour passive (the Helldivers wiki). The armours with them: from HD2Runtime's armour passive catalog (SkyeShade,
-- https://github.com/SkyeShade/HD2Runtime, build F5FEE03DCFDB), by the armour's id, which your player object's
-- armor_set field holds (the CM-09 Bonesnapper read 1c6c05fa in game, as the catalog has it). (1.2.2 tried to learn it
-- from an effects counter: that counter doesn't follow stims.) An armour newer than the list: 4 s, or F9's 6 s.
local STIM6 = {}
for id in string.gmatch([[
1c6c05fa d52bb413 95903adf 7a07031f 38aa207d 9f73133e 8b9ed77d f8fadb6c 01c2a674 0a18c237
]], '%x+') do STIM6[id] = true end
local stim = { at = nil, secs = 4, prev_s = nil }
N.stim = stim
local function stim_secs()
  if cfg.stim_secs == 2 then return 4 elseif cfg.stim_secs == 3 then return 6 end
  return st8.armor and STIM6[st8.armor] and 6 or 4
end
local function stim_used(n, now)
  if stim.prev_s and n < stim.prev_s then
    stim.at, stim.secs = now - 0.12, stim_secs()                       -- (read every 0.25 s: half of it back)
    if cfg.research then log('research: stim used (%d left), timer %d s (armour set %s)', n, stim.secs, tostring(st8.armor)) end
  end
  stim.prev_s = n
end

-- (1.2.0) Reload progress: the time from reload_stage leaving 0 to its return, learned per weapon type, a reload from
-- empty and one with rounds left apart; while reloading, the part of it gone by as a line over the bar (the charge
-- meter's place), from the second reload of a weapon on. A reload that ends with no more rounds (cancelled by a
-- sprint, a dive) isn't learned.
local rl, seq_said, last_mag = nil, {}, {}
local function reload_track(d, now)
  local t = d and (d.t or d.t0)
  local tid, goid = t and t.id, d and (d.goid or d.goid0)
  if d and d.kind == 'ammo' and d.reloading and tid then
    if not rl or rl.goid ~= goid or rl.done_at then
      -- (from empty or not: the magazine before the reload began; the game empties it as the reload starts, 7 > 0 on
      -- the Sightliner's first read of a reload with 7 left)
      local before = last_mag.goid == goid and last_mag.mag or d.mag or d.value
      if before == 0 and last_mag.goid == goid and (last_mag.prev or 0) > 1 and last_mag.at and now - last_mag.at < 0.4 then
        before = last_mag.prev                               -- (2.3.9: emptied by the reload itself, not by shots)
      end
      rl = { goid = goid, tid = tid, t0 = now, v0 = d.value, kind = before == 0 and 'reload_e' or 'reload_t', seq = {} }
    end
    -- (research: the stages a reload goes through, logged once per weapon type and kind)
    local stg = d.reload_stage
    if stg and rl.seq[#rl.seq] ~= stg then rl.seq[#rl.seq + 1] = stg end
    local secs = learned[rl.kind][rl.tid]
    if secs and cfg.reload_line and (not d.charge_frac or d.reload_line) then
      d.charge_frac, d.charge_mark, d.charge_safe, d.locked, d.reload_line = math.min(1, (now - rl.t0) / secs), nil, true, false, true
    end
  elseif rl == nil and d and d.kind == 'ammo' then
    -- (2.3.9: the one before the last too, and when it changed: the game empties the magazine as a reload starts, and
    -- a read can see the 0 a moment before the reload's stage — luka's AMR, 3 left, taken for a reload from empty)
    local m = d.mag or d.value
    if last_mag.goid ~= goid then last_mag.prev, last_mag.at = nil, nil
    elseif m ~= last_mag.mag then last_mag.prev, last_mag.at = last_mag.mag, now end
    last_mag.goid, last_mag.mag = goid, m
  elseif rl and d and goid == rl.goid then
    -- (2.3.7) not reloading any more: the rounds waited for. The Apex's stage ends 0.1-0.2 s before its rounds show
    -- (luka's log, 172.3 / 172.5 s): up to 2 s. (2.3.8) Timed to the rounds, the line drawn on through the wait.
    -- (2.3.9) From empty, a rifle chambers a round as well: the AMR's rounds rose with the chamber still empty and it
    -- filled 1.2 s later (luka's log, 290.5 / 291.8 s; it learned 0.8 s), so from empty the chamber is waited for too
    -- (up to 2.5 s after the rounds; a gun that never shows it chambered is timed to its rounds)
    rl.done_at = rl.done_at or now
    local risen = d.value > rl.v0
    if risen and not rl.rise_at then rl.rise_at = now end
    local needs = rl.kind == 'reload_e' and t and t.has.rounds and t.has.chamber
    -- (2.6.11, luka's Railgun: the line stayed 2.5 s after its round showed) a single-round gun never reads chambered
    -- (its flag stays "empty" with the round in): with its one round back it's done
    local chambered = not needs or d.value > (d.mag or d.value) or ((d.top or 0) <= 1 and d.value >= 1)
    local waiting = (not risen and now - rl.done_at <= 2) or (risen and not chambered and now - rl.rise_at <= 2.5)
    if waiting then
      local secs = learned[rl.kind][rl.tid]
      if secs and cfg.reload_line and (not d.charge_frac or d.reload_line) then
        d.charge_frac, d.charge_mark, d.charge_safe, d.locked, d.reload_line = math.min(1, (now - rl.t0) / secs), nil, true, false, true
      end
      return
    end
    if risen then
      local took = (chambered and now or rl.rise_at) - rl.t0
      local stage, rounds = rl.done_at - rl.t0, rl.rise_at - rl.t0
      if took > 0.4 and took < 12 then
        local old = learned[rl.kind][rl.tid]
        local v = math.floor((old and (old * 0.6 + took * 0.4) or took) * 10 + 0.5) / 10
        if cfg.research then
          local key = rl.tid .. rl.kind
          local first = not seq_said[key]
          seq_said[key] = true
          log('research: reload %s (%s) took %.1f s (its stage %.1f s, the rounds %.1f s%s)%s', tostring(rl.tid),
            rl.kind == 'reload_e' and 'from empty' or 'with rounds left', took, stage, rounds,
            needs and (chambered and ', chambered' or ', never seen chambered') or '',
            first and (', stages ' .. table.concat(rl.seq, ' ')) or '')
        end
        learn(rl.kind, rl.tid, v)
      end
    end
    if d.reload_line then d.charge_frac, d.reload_line, d.charge_safe = nil, nil, nil end
    rl = nil
  elseif rl then
    if d and d.reload_line then d.charge_frac, d.reload_line, d.charge_safe = nil, nil, nil end
    rl = nil
  end
end

-- a pulse for the warnings: 1 down to 0.35 and back, twice a second
local function pulse(now) return 0.675 + 0.325 * math.cos(now * math.pi * 4) end


-- each frame: the state, the stim timer, health and stamina; nil when nothing of it is wanted or readable
N.vitals_step = function(s, now, items_now)
  read_state(s, now)
  if stim.at and now - stim.at > 9 then stim.at = nil end
  if items_now then stim_used(items_now.s, now) end
  N.warn_stims = nil
  local want = (cfg.health or 1) > 1 or (cfg.stamina or 1) > 1 or cfg.stim_timer or cfg.warn
  local vit = want and read_vitals(s, now) or nil
  if not vit then return nil end
  if (cfg.health or 1) == 1 then vit.show_h = 0 end
  if (cfg.stamina or 1) == 1 then vit.show_s = 0 end
  local left = stim.at and (stim.secs - (now - stim.at)) or nil
  if cfg.stim_timer and left and left > 0 then vit.stim, vit.stim_secs = left / stim.secs, left end
  -- (2.3.9) F9 "Warning pulses": Off, Pulsing (the bar under 25 % and the stims while hurt with none, twice a
  -- second), or Flash once (luka: the health bar flashes once as it turns red, then simply shows red; the stims the
  -- same as they run out while you're hurt)
  if cfg.warn == 2 and vit.hp then
    local f = vit.hp / math.max(1, vit.max)
    if f <= 0.25 then vit.pulse_h = pulse(now) end
    N.warn_stims = f < 0.5 and items_now and items_now.s == 0 and pulse(now) or nil
  elseif cfg.warn == 3 and vit.hp then
    local f = vit.hp / math.max(1, vit.max)
    N.edge_pulse('low_hp', f <= 0.25, 'health', 'warn')
    N.edge_pulse('no_stims', f < 0.5 and items_now ~= nil and items_now.s == 0, 'stims', 'warn')
  end
  return vit
end
N.reload_track = reload_track
N.reload_reset = function() rl, last_mag = nil, {} end
