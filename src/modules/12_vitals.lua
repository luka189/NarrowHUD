-- NarrowHUD, vitals: your health and stamina, the stim timer, your Helldiver's state (the stratagem input, emotes),
-- the warnings and the reload progress.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES, call, alive, cfg, learned, learn, me = N.TYPES, N.call, N.alive, N.cfg, N.learned, N.learn, N.me

-- (1.1.0) Health and stamina: your Helldiver's health, max_health and stamina fields (their real names; health 125
-- full and 0 dead, stamina 0 to 1, from the 1.0.10 research log), read every frame while a bar is on (two reads,
-- max_health once a second). A hit leaves what it took as a red "trail" that shrinks to the health after half a
-- second. Each bar's own fade: F9 says always, or while not full (and 2 s after); none while dead.
local vs = { goid = nil, max = 125, max_at = -100, trail = nil, prev_hp = nil, hit_at = nil, full_h = nil, full_s = nil,
  show_h = 0, show_s = 0, t = nil }
local function read_vitals(s, now)
  local av = me.avatar
  if not av or not alive(s, av, TYPES[2]) then vs.goid = nil return nil end
  if vs.goid ~= av then
    vs.goid, vs.trail, vs.prev_hp, vs.hit_at, vs.max_at, vs.show_h, vs.show_s = av, nil, nil, nil, -100, 0, 0
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
  if hp and hp <= 0 then vs.show_h, vs.show_s = 0, 0 return nil end           -- (dead)
  local dt = math.min(0.1, now - (vs.t or now))
  vs.t = now
  if hp then
    if vs.trail == nil or hp >= vs.trail then vs.trail, vs.hit_at = hp, nil
    else
      if vs.prev_hp and hp < vs.prev_hp then vs.hit_at = now end
      if not vs.hit_at or now - vs.hit_at > 0.5 then vs.trail = math.max(hp, vs.trail - vs.max * 0.8 * dt) end
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
  return { hp = hp, max = vs.max, st = st, trail = vs.trail, show_h = vs.show_h, show_s = vs.show_s, busy = hurt or tired }
end
N.vitals_state = vs

-- Your Helldiver's state, every 0.1 s: an emote (active_emote: -1 or 0 when none), and (research) the aim field
-- 95c46304: 3 with the weapon raised (firing from the hip, overheated, a charge), 4 aiming down the sights, 1 around a
-- throw (the 1.2.2 log; 1.2.1 hid the HUD for 3, taking it for a stratagem's code). The stratagem key is read from F9's
-- key (Left Ctrl, the game's default) and a controller's left shoulder button. Stand-in names from DATA where the
-- real one isn't known.
local FNAME = {}
for id, name in string.gmatch(DATA.fieldnames or '', '(%x+) (%S+)') do FNAME[id] = name end
local st8 = { at = -100, aim = 0, emote = -1, strat = false, goid = nil, armor = nil, armor_at = -100 }
local function strat_held()
  local k = N.keys and N.keys.strat
  if k and k.down and k.down() == true then return true end
  for _, p in ipairs(N.pad_list and N.pad_list(chef.time()) or {}) do
    if p.strat and (tonumber(call('pad', p.button, p.strat)) or 0) > 0.5 then return true end
  end
  return false
end
local function read_state(s, now)
  st8.strat = cfg.hide_strat and strat_held() or false
  local av = me.avatar
  if not av or not alive(s, av, TYPES[2]) then return end
  if st8.goid ~= av then st8.goid, st8.aim, st8.emote = av, 0, -1 end
  if now - st8.at < 0.1 then return end
  st8.at = now
  local e = call('avatar.emote', 'GameSession.game_object_field', s, av, 'active_emote')
  st8.emote = tonumber(e) or -1
  -- (the weapon's stance, for the research log and the drop line's "while aiming": 4 down the sights)
  if cfg.research or cfg.throw_line then
    local a = tonumber(call('avatar.aim', 'GameSession.game_object_field', s, av, FNAME['95c46304'] or 'ww3bwxa')) or 0
    if cfg.research and a ~= st8.aim then log('research: field 95c46304 (aim) %s > %s at hand pose %s', tostring(st8.aim), tostring(a), tostring(N.hand and N.hand.grip)) end
    st8.aim = a
  end
  -- (the armour: your player object's armor_set, once a second, for the stim duration)
  if me.player and now - st8.armor_at >= 1 then
    st8.armor_at = now
    local v = call('player.armor', 'GameSession.game_object_field', s, me.player, 'armor_set')
    if type(v) == 'number' then st8.armor = string.format('%08x', v % 4294967296) end
  end
end
N.state8 = st8

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
    if not rl or rl.goid ~= goid then
      -- (from empty or not: the magazine before the reload began; the game empties it as the reload starts, 7 > 0 on
      -- the Sightliner's first read of a reload with 7 left)
      local before = last_mag.goid == goid and last_mag.mag or d.mag or d.value
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
    last_mag.goid, last_mag.mag = goid, d.mag or d.value
  elseif rl then
    if d and goid == rl.goid and d.value > rl.v0 then
      local took = now - rl.t0
      if took > 0.4 and took < 12 then
        local old = learned[rl.kind][rl.tid]
        local v = math.floor((old and (old * 0.6 + took * 0.4) or took) * 10 + 0.5) / 10
        if cfg.research then
          local key = rl.tid .. rl.kind
          if not seq_said[key] then
            seq_said[key] = true
            log('research: reload %s (%s) took %.1f s, stages %s', tostring(rl.tid), rl.kind == 'reload_e' and 'from empty' or 'with rounds left', took, table.concat(rl.seq, ' '))
          else
            log('research: reload %s (%s) took %.1f s', tostring(rl.tid), rl.kind == 'reload_e' and 'from empty' or 'with rounds left', took)
          end
        end
        learn(rl.kind, rl.tid, v)
      end
    end
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
  if cfg.warn and vit.hp then
    local f = vit.hp / math.max(1, vit.max)
    if f <= 0.25 then vit.pulse_h = pulse(now) end
    N.warn_stims = f < 0.5 and items_now and items_now.s == 0 and pulse(now) or nil
  end
  return vit
end
N.reload_track = reload_track
N.reload_reset = function() rl, last_mag = nil, {} end
