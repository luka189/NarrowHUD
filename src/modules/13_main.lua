-- NarrowHUD, main: each frame: new worlds, the version check, reading, idle dimming, drawing; shutdown.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local ROLE, TYPES, THROWABLE, call, norm_id, live_fields = N.ROLE, N.TYPES, N.THROWABLE, N.call, N.norm_id, N.live_fields
local blocked, alive, field, game_build, cfg, learned = N.blocked, N.alive, N.field, N.game_build, N.cfg, N.learned
local save_learned, learn, forget_type, forget_all, keys, distrust = N.save_learned, N.learn, N.forget_type, N.forget_all, N.keys, N.distrust
local objs, queue, me, queue_2, queue_b, classify = N.objs, N.queue, N.me, N.queue_2, N.queue_b, N.classify
local session, scan, input, read_fire_button, hand_pose, read_weapon = N.session, N.scan, N.input, N.read_fire_button, N.hand_pose, N.read_weapon
local av_refs, av_said, read_av_refs, pack_ammo, hand, swap = N.av_refs, N.av_said, N.read_av_refs, N.pack_ammo, N.hand, N.swap
local read_swap, research_switch, pick, heat_rate, watch_fire, CHARGE_METER = N.read_swap, N.research_switch, N.pick, N.heat_rate, N.watch_fire, N.CHARGE_METER
local shown, notice, layout, load_layout, draw = N.shown, N.notice, N.layout, N.load_layout, N.draw

local next_scan, next_read, next_items = 0, 0, 0
local shown_now, items_now = nil, nil
local session_ok = false

local world_seen = nil
-- (research log: where NarrowHUD's time goes, once a minute. os.clock counts in 1 ms steps on Windows, but its sums
-- over a minute come out right)
local clock = os and os.clock
local perf = { t = {}, frames = 0, at = nil, watched = 0, n = 0, reads0 = 0, tests0 = 0 }
local function lap(name, t0)
  if not t0 then return nil end
  local t1 = clock()
  perf.t[name] = (perf.t[name] or 0) + (t1 - t0)
  return t1
end

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
-- (1.2.2) a mark in the log, for testing: the key set in F9 writes a numbered line with what's shown, so a moment
-- in play can be found in the log ("at mark 3 the HUD blinked")
local marks = 0
local function read_forget_keys(now)
  if keys.log_mark and keys.log_mark.pressed and keys.log_mark.pressed() == true then
    marks = marks + 1
    local o = hand.goid and objs[hand.goid]
    log('==== MARK %d ==== hand pose %s, shown: %s (object %s), fire button %.1f s ago, swap %.1f s ago', marks,
      tostring(hand.grip), o and o.t and TYPES[o.t].id or 'nothing', tostring(hand.goid), now - (input.last or -100), now - (swap.at or -100))
    flash.text, flash.till = string.format('NarrowHUD: mark %d in the log', marks), now + 1.5
  end
  if N.startup_flash then flash.text, flash.till, N.startup_flash = N.startup_flash, now + 8, nil end
  if keys.reload_layout and keys.reload_layout.pressed and keys.reload_layout.pressed() == true then
    local ok, dropped = load_layout('the reload key')
    flash.text, flash.till = not ok and 'NarrowHUD: the layout file can\'t be read (see narrowhud.log)'
      or ((dropped or 0) > 0 and string.format('NarrowHUD: layout file read, %d values left at their defaults', dropped)
      or 'NarrowHUD: layout file read again'), now + 3
    -- (1.2.1: read, but only Custom uses it: said, a player waited for a change that couldn't come)
    if ok and (not cfg.custom or cfg.builtin) then
      flash.text, flash.till = 'NarrowHUD: layout file read, but it\'s used only with F9 > NarrowHUD > Position: Custom', now + 5
    end
  end
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
  N.frame = N.frame + 1
  local now = chef.time()
  if N.dirty_at and now >= N.dirty_at then
    N.dirty_at = nil
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
    layout.els = nil                                 -- (the layout file read again each mission)
    for k in pairs(objs) do objs[k] = nil end
    for i = #queue, 1, -1 do queue[i] = nil end
    for i = #queue_2, 1, -1 do queue_2[i] = nil end
    for i = #queue_b, 1, -1 do queue_b[i] = nil end
    for k in pairs(N.checked) do N.checked[k] = nil end
    for k in pairs(N.pack_vals) do N.pack_vals[k] = nil end
    for k in pairs(distrust) do distrust[k] = nil end
    for k in pairs(av_refs) do av_refs[k] = nil end
    for k in pairs(av_said) do av_said[k] = nil end
    hand.goid, hand.grip, hand.said, hand.held_t, hand.bar_pack = nil, nil, nil, nil, nil
    swap.used, swap.from = true, nil
    hand.mask = nil
    blocked.n, blocked.types, blocked.yes, blocked.since, blocked.new_said = 0, 0, false, now, 0
    me.player, me.avatar = nil, nil
    shown_now, items_now, N.pack_prev = nil, nil, nil
    if N.stim then N.stim.prev_s, N.stim.at = nil, nil end   -- (a new mission's stim count isn't a stim used)
    if N.reload_reset then N.reload_reset() end
    if N.markers_reset then N.markers_reset() end
    next_scan = now
  end
  local t0 = cfg.research and clock and clock() or nil
  classify(s)
  t0 = lap('sorting', t0)
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
            .. ((o.map_pack and not o.mine) and ' (the map\'s)' or '')
        end
      end
      log('session: you %s, host %s; %d objects yours, %d the host\'s; your player %s; %d weapons on you; a weapon\'s owner field reads %s (%s); packs on you: %s',
        tostring(peer), tostring(session.host), session.mine, session.hosts, me.player and 'found' or 'not found', on,
        tostring(sample), type(sample), #packs > 0 and table.concat(packs, ' ') or 'none')
    end
  end
  read_fire_button(now)
  if (cfg.drop_line or 1) == 2 or cfg.throw_line then N.read_aim_button(now) end
  read_swap(now)
  read_forget_keys(now)

  t0 = lap('scan', t0)
  if now >= next_read then
    next_read = now + 0.1
    local grip = hand_pose(s)
    t0 = lap('scan', t0)
    watch_fire(s, grip)
    t0 = lap('weapons', t0)
    perf.watched, perf.n = perf.watched + (N.watched or 0), perf.n + 1
    local goid = pick(s, grip, now)
    -- A pose with no weapon of yours on it, but not a grenade's or a stratagem's: the weapon shown stays up to 2 s.
    -- Vaulting, a stim, a dive or a swap's first moments pass through such poses (10, 15, 20, 0: about 70 times a
    -- mission in a 2026-10-26 log, the HUD off for 0.1 to 1 s each time). A new weapon on a new pose shows from its
    -- first shot, as before; and after a swap key or the wheel, no wait.
    local ho = hand.goid and objs[hand.goid]
    if goid == nil and grip ~= nil and not THROWABLE[grip] and ho and ho.t and ho.on and not ho.notmine and now - (swap.at or -100) > 1 then
      hand.lost_at = hand.lost_at or now
      if now - hand.lost_at < 2 then goid = hand.goid end
    elseif goid ~= nil then
      hand.lost_at = nil
    end
    if goid ~= hand.goid or grip ~= hand.grip then
      if cfg.research and goid and hand.goid and goid ~= hand.goid and grip == hand.grip then research_switch(s, hand.goid, goid, grip, now) end
      local o = goid and objs[goid]
      local said = string.format('hand pose %s: %s', tostring(grip), o and TYPES[o.t].id or 'no weapon shown')
      if said ~= hand.said then
        log('%s', said)
        hand.said = said
        -- (the drop line needs each type's weapon name once, from a tester: which weapon this is)
        local b = o and BALLISTICS[TYPES[o.t].id]
        if o and (not b or b.guess) and not (hand.named or {})[o.t] then
          hand.named = hand.named or {}
          hand.named[o.t] = true
          log('weapon %s: %s (for the drop line, tell which weapon this is, with the magazine it shows)', TYPES[o.t].id,
            b and ('taken for the ' .. b.name .. ' by its magazine and rate of fire') or 'no projectile numbers known')
        end
      end
      hand.goid, hand.grip = goid, grip
    end
    local o = goid and objs[goid]
    if o and o.prev and cfg.research then
      local w = o.prev
      local line = string.format('fields %s: fire_mode=%s options=%s rpm=%s selected=%s', TYPES[o.t].id,
        tostring(w.fire_mode), tostring(w.options), TYPES[o.t].has.heat and '-' or tostring(w.rpm), tostring(w.selected))
      if line ~= hand.fields then hand.fields = line log('%s', line) end
    end
    t0 = lap('picking', t0)
    if cfg.research then N.batched_research(s, now, goid, grip) end
    t0 = lap('research', t0)
    local full = o and o.prev and not o.prev.lite and o.prev or (o and o.t and read_weapon(s, goid, TYPES[o.t]))
    shown_now = o and o.t and shown(s, goid, TYPES[o.t], full, o) or nil
    if shown_now and shown_now.kind == nil then shown_now = nil end
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
          -- (one of the map's from the mission's start (04_objects) is read, never shown, until it's used: yours)
          if o.sp_prev ~= nil and v ~= o.sp_prev then o.mine = true end
          local maps = o.map_pack and not o.mine
          if sp.kind == 'warp' and type(v) == 'number' then
            if not maps then items_now.warp = v end
          elseif sp.kind == 'timer' and type(v) == 'boolean' then
            if o.sp_prev ~= nil and v ~= o.sp_prev and v == sp.on_rise then o.sp_t = now end
            if v and not sp.on_rise then o.sp_t = nil end          -- (hovering: the recharge starts on landing)
            -- a flight starts when the flag comes on with no flight in the last 14 s (later ones are the landing assist)
            if sp.flight and v and o.sp_prev == false and (o.fly_t == nil or now - o.fly_t > 14) then o.fly_t = now end
            local f = 1
            if v and not sp.on_rise then
              f = sp.flight and o.fly_t and math.max(0, 1 - (now - o.fly_t) / sp.flight) or 0   -- (draining)
              items_now.draining = true
            elseif o.sp_t then f = math.min(1, (now - o.sp_t) / sp.secs) end
            if not maps then items_now.recharge = f else items_now.draining = nil end
          end
          o.sp_prev = v
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

  local vit = N.vitals_step(s, now, items_now)
  N.read_markers(s, now)
  t0 = lap('items', t0)
  -- Heat, every frame, between the field's values (12_heat)
  local d = shown_now
  if d and d.kind == 'heat' and d.o and d.o.h_last and not d.charge_anim then
    N.heat_model(s, d, now)
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
      -- (the Railgun in SAFE mode charges to 60 % in about 1.7 s and stops there, never blowing up: the meter fills to
      -- 60 % and stays, orange once it's there, no danger mark)
      local fm = d.t0.id == '26acc614' and d.t0.has.fire_mode and tonumber(field(s, d.goid0, d.t0, 'fire_mode'))
      if fm and math.floor(fm / 8) % 2 == 0 and fm % 8 == 5 then
        d.charge_frac, d.charge_mark, d.charge_safe = math.min(0.6, (now - hand.held_t) / 1.7 * 0.6), nil, true
        d.locked = d.charge_frac >= 0.6
      else
        d.charge_frac = (now - hand.held_t) / m.secs
        d.charge_mark = m.mark and m.mark / m.secs
      end
    else
      hand.held_t = nil
    end
  elseif d then
    hand.held_t = nil
  end
  N.reload_track(d, now)
  -- idle: dimmed or hidden when nothing changed for a while (idle_target)
  local target = idle_target(d, items_now, now)
  hand.fade = hand.fade or 1
  if target < hand.fade then hand.fade = math.max(target, hand.fade - (dt or 0.016) * 1.5) else hand.fade = target end
  -- (the stratagem input, an emote: hidden over a quarter second, back at once)
  local st8 = N.state8
  local hide = st8.strat or (cfg.hide_emote and st8.emote ~= -1 and st8.emote ~= 0)
  hand.hidef = hide and math.max(0, (hand.hidef or 1) - (dt or 0.016) * 4) or 1
  local vhide = cfg.hide_emote and st8.emote ~= -1 and st8.emote ~= 0
  N.alpha_k = cfg.opacity * hand.fade * hand.hidef
  if (shown_now or (items_now and hand.grip and hand.grip ~= 0)) and hand.fade > 0.01 and hand.hidef > 0.01 then
    local dd = shown_now
    if dd and not (cfg.show_rpm and cfg.show_fmode and cfg.show_mode and cfg.show_mags and (cfg.show_charge or dd.reload_line)) then
      dd = setmetatable({}, { __index = shown_now })
      if not cfg.show_rpm then dd.setting = false end
      if not cfg.show_fmode then dd.fmode = false end
      if not cfg.show_mode then dd.mode = false end
      if not cfg.show_mags then dd.reserve = false end
      if not cfg.show_charge and not shown_now.reload_line then dd.charge_frac = false end
    end
    draw(dd, items_now)
  end
  -- (health and stamina: dimmed or hidden with the rest when nothing changes, never while you're hurt or out of breath)
  if vit and (vit.show_h > 0 or vit.show_s > 0 or vit.stim) and not vhide then
    N.alpha_k = cfg.opacity * ((vit.busy or vit.stim) and 1 or (hand.fade or 1))
    N.draw_vitals(vit)
  end
  -- (1.3.0) your map pin and your last death, on the screen where they are; hidden with the stratagem input
  if hand.hidef > 0.01 then
    N.alpha_k = cfg.opacity * hand.hidef
    N.draw_markers()
    -- (1.4.0) the drop line of the weapon in hand
    N.drop_lines = 0
    if shown_now and shown_now.tid and hand.grip and hand.grip ~= 0 then N.draw_drop(shown_now.tid) end
    -- (1.5.0) a throw's line: a stratagem ball, a grenade or C4 aimed
    N.throw_step(now, hand.grip, shown_now)
  end
  -- (Chef keeps showing the last lines dispatched until a frame draws some again: a line of nothing for a few
  -- frames after the last, so a drop or throw line that goes doesn't stay in the world; the 1.4.2 and 1.5.1 logs)
  if N.drop_lines > 0 then hand.lines_at = now
  elseif hand.lines_at and now - hand.lines_at < 0.25 then N.drop_clear() end
  N.alpha_k = cfg.opacity
  if t0 then
    lap('drawing', t0)
    perf.frames = perf.frames + 1
    perf.at = perf.at or now
    if now - perf.at >= 60 then
      local f, parts, all = math.max(1, perf.frames), {}, 0
      for _, k in ipairs({ 'sorting', 'scan', 'weapons', 'picking', 'research', 'items', 'drawing' }) do
        local ms = (perf.t[k] or 0) * 1000 / f
        all = all + ms
        parts[#parts + 1] = string.format('%s %.3f', k, ms)
      end
      local els = {}
      for id, sec in pairs(N.el_time or {}) do els[#els + 1] = string.format('%s %.3f', id, sec * 1000 / f) end
      table.sort(els)
      if #els > 0 then parts[#parts + 1] = 'of the drawing: ' .. table.concat(els, ' ') end
      if (N.drop_lines or 0) > 0 then parts[#parts + 1] = string.format('%d drop line segments this frame', N.drop_lines) end
      N.el_time = {}
      local nobj, queued = 0, #queue + #queue_2 + #queue_b
      for _ in pairs(objs) do nobj = nobj + 1 end
      log('time a frame, the last %.0f s: %.3f ms (%s); %.0f weapon objects read a read, %.0f fields; %d objects of yours, %d waiting to be sorted, %.0f type tests a frame',
        now - perf.at, all, table.concat(parts, ', '), perf.watched / math.max(1, perf.n), (N.reads - perf.reads0) / math.max(1, perf.n),
        nobj, queued, ((N.type_tests or 0) - perf.tests0) / f)
      perf.t, perf.frames, perf.at, perf.watched, perf.n, perf.reads0, perf.tests0 = {}, 0, now, 0, 0, N.reads, N.type_tests or 0
    end
  end
  if (blocked.n >= 5 or (blocked.types or 0) > 2000 and not blocked.yes) and blocked.since and now - blocked.since < 25 then
    if not blocked.said then blocked.said = true log('GameSession.game_object_is_type refused: your weapons can\'t be read with this Chef version') end
    notice('NarrowHUD: this Chef version blocks the reads it needs (it needs Chef Shared Loader 1.2.3 or newer)')
  end
  if flash.text and now < flash.till then notice(flash.text) end
end

function M.debug_objs() return objs end   -- (tests)
function M.debug_fly(b, pitch, len) return N.drop_fly(b, pitch, len) end
function M.debug_cfg(k, v) cfg[k] = v end   -- (tests: a setting with no menu row, such as the texture test's way)
function M.shutdown()
  if N.dirty_at then save_learned() end
end

