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
local shown, notice, layout, load_layout, draw, rws = N.shown, N.notice, N.layout, N.load_layout, N.draw, N.rws

local next_scan, next_read, next_items = 0, 0, 0
local shown_now, items_now = nil, nil
local session_ok = false

local world_seen = nil
local probe_said = false
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
local rw_turn = 0

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
local function read_forget_keys(now)
  if keys.reload_layout and keys.reload_layout.pressed and keys.reload_layout.pressed() == true then
    local ok, dropped = load_layout('the reload key')
    flash.text, flash.till = not ok and 'NarrowHUD: the layout file can\'t be read (see narrowhud.log)'
      or ((dropped or 0) > 0 and string.format('NarrowHUD: layout file read, %d values left at their defaults', dropped)
      or 'NarrowHUD: layout file read again'), now + 3
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
    for k in pairs(rws) do rws[k] = nil end
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
    next_scan = now
  end
  local t0 = cfg.research and clock and clock() or nil
  classify(s)
  t0 = lap('sorting', t0)
  -- (research, once a session: what Network.object_info gives for the player's type, allowed again from Chef 1.2:
  -- a type's field list would let NarrowHUD check its data against a patched game instead of going off)
  if cfg.research and not probe_said then
    probe_said = true
    local ok, info = pcall(call, 'objinfo', 'Network.object_info', DATA.player.name)
    local function show(v, depth)
      if type(v) ~= 'table' then return tostring(v) end
      if depth > 3 then return '{...}' end
      local parts, n = {}, 0
      for k, x in pairs(v) do
        n = n + 1
        if n <= 12 then parts[#parts + 1] = tostring(k) .. '=' .. show(x, depth + 1) end
      end
      return '{' .. table.concat(parts, ' ') .. (n > 12 and (' ... ' .. n .. ' in all') or '') .. '}'
    end
    log('research: Network.object_info(player type) gives %s: %s', ok and type(info) or 'an error', string.sub(show(info, 0), 1, 600))
    if ok and type(info) == 'table' and type(info.fields) == 'table' then
      for i = 1, math.min(4, #info.fields) do log('research: object_info field %d: %s', i, string.sub(show(info.fields[i], 1), 1, 300)) end
      log('research: object_info: %d fields (NarrowHUD\'s data: the player type has the avatar field %s)', #info.fields, tostring(DATA.player.avatar))
    end
  end
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
        end
      end
      log('session: you %s, host %s; %d objects yours, %d the host\'s; your player %s; %d weapons on you; a weapon\'s owner field reads %s (%s); packs on you: %s',
        tostring(peer), tostring(session.host), session.mine, session.hosts, me.player and 'found' or 'not found', on,
        tostring(sample), type(sample), #packs > 0 and table.concat(packs, ' ') or 'none')
    end
  end
  read_fire_button(now)
  read_swap(now)
  read_forget_keys(now)

  t0 = lap('scan', t0)
  if now >= next_read then
    next_read = now + 0.1
    local grip = hand_pose()
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
      if said ~= hand.said then log('%s', said) hand.said = said end
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
    if o and o.t and cfg.research then N.research_watch(s, goid, TYPES[o.t]) end
    if cfg.research then
      -- your backpack (jump pack, hover pack ...: what it keeps), and while nothing is shown, the weapons on you not
      -- learned yet (what an Arc Thrower changes when fired). At most 25 a read, in turn: as host, everything a SEAF
      -- squad carries is yours too
      local list = {}
      for pgoid, po in pairs(objs) do
        local pt = po.t and TYPES[po.t]
        if pt and po.on and not po.notmine and (pt.pack or pt.other or (shown_now == nil and grip and grip ~= 0 and not THROWABLE[grip]
            and not pt.player and not pt.avatar and learned.grip[pt.id] == nil and not po.ub)) then
          list[#list + 1] = pgoid
        end
      end
      table.sort(list)
      local n = #list
      for i = 1, math.min(25, n) do
        rw_turn = rw_turn % n + 1
        local pgoid = list[rw_turn]
        N.research_watch(s, pgoid, TYPES[objs[pgoid].t])
      end
    end
    t0 = lap('research', t0)
    local full = o and o.prev and not o.prev.lite and o.prev or (o and o.t and read_weapon(s, goid, TYPES[o.t]))
    shown_now = o and o.t and shown(s, goid, TYPES[o.t], full, o) or nil
    if shown_now and shown_now.kind == nil then shown_now = nil end
    hand.throwable = THROWABLE[grip] == true
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
          if sp.kind == 'warp' and type(v) == 'number' then
            items_now.warp = v
          elseif sp.kind == 'timer' and type(v) == 'boolean' then
            if o.sp_prev ~= nil and v ~= o.sp_prev and v == sp.on_rise then o.sp_t = now end
            if v and not sp.on_rise then o.sp_t = nil end          -- (hovering: the recharge starts on landing)
            -- a flight starts when the flag comes on with no flight in the last 14 s (later ones are the landing assist)
            if sp.flight and v and o.sp_prev == false and (o.fly_t == nil or now - o.fly_t > 14) then o.fly_t = now end
            o.sp_prev = v
            local f = 1
            if v and not sp.on_rise then
              f = sp.flight and o.fly_t and math.max(0, 1 - (now - o.fly_t) / sp.flight) or 0   -- (draining)
              items_now.draining = true
            elseif o.sp_t then f = math.min(1, (now - o.sp_t) / sp.secs) end
            items_now.recharge = f
          end
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

  t0 = lap('items', t0)
  -- Heat, every frame: run on at the weapon's rate (up while the trigger is held, read every frame; down otherwise),
  -- and when the field brings a new value, fold the difference in over a quarter second instead of jumping to it.
  local d = shown_now
  if d and d.kind == 'heat' and d.o and d.o.h_last and not d.charge_anim then
    local o = d.o
    local held
    if d.t.has.held and learned.charge2[d.tid] == nil then held = field(s, d.goid, d.t, 'held') == true
    else held = o.firing == true end
    local dt = math.min(0.1, now - (o.sim_t or now))
    o.sim_t = now
    if o.sim == nil then
      o.sim, o.err, o.sim_seen = o.h_last, 0, o.h_last_t
    else
      local rate = held and heat_rate('up', d.tid) or (not held and heat_rate('down', d.tid) and -heat_rate('down', d.tid)) or 0
      o.sim = o.sim + rate * dt
      if o.sim_seen ~= o.h_last_t then                     -- a new value from the field
        o.sim_seen = o.h_last_t
        o.err = o.h_last - o.sim
      end
      local take = (o.err or 0) * math.min(1, dt / 0.25)
      o.sim, o.err = o.sim + take, (o.err or 0) - take
    end
    o.sim = math.max(0, math.min(d.top_raw, o.sim))
    d.value = math.max(0, o.sim - d.rest)
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
      d.charge_frac = (now - hand.held_t) / m.secs
      d.charge_mark = m.mark and m.mark / m.secs
    else
      hand.held_t = nil
    end
  elseif d then
    hand.held_t = nil
  end
  -- idle: dimmed or hidden when nothing changed for a while (idle_target)
  local target = idle_target(d, items_now, now)
  hand.fade = hand.fade or 1
  if target < hand.fade then hand.fade = math.max(target, hand.fade - (dt or 0.016) * 1.5) else hand.fade = target end
  N.alpha_k = cfg.opacity * hand.fade
  if (shown_now or (items_now and hand.grip and hand.grip ~= 0)) and hand.fade > 0.01 then
    local dd = shown_now
    if dd and not (cfg.show_rpm and cfg.show_fmode and cfg.show_mode and cfg.show_mags and cfg.show_charge) then
      dd = setmetatable({}, { __index = shown_now })
      if not cfg.show_rpm then dd.setting = false end
      if not cfg.show_fmode then dd.fmode = false end
      if not cfg.show_mode then dd.mode = false end
      if not cfg.show_mags then dd.reserve = false end
      if not cfg.show_charge then dd.charge_frac = false end
    end
    draw(dd, items_now)
  end
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
    notice('NarrowHUD: this Chef version blocks the reads it needs (it runs on Chef Shared Loader 1.0.x and 1.2 on)')
  end
  if flash.text and now < flash.till then notice(flash.text) end
end

function M.shutdown()
  if N.dirty_at then save_learned() end
end

