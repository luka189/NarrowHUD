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

local world_seen = nil
-- (research log: where NarrowHUD's time goes, once a minute. os.clock counts in 1 ms steps on Windows, but its sums
-- over a minute come out right)
-- (1.5.29) research builds for the disconnect reports, made with tools/build.py --research R0 or R1: R0 reads nothing
-- and draws nothing (Chef's update hook and the vitals only), R1 reads everything and draws nothing. A reporter who
-- still drops with R0 has it from the loader being there at all; one who drops with R1 but not R0 has it from the
-- reads; one who drops only with the normal build has it from the drawing.
local RESEARCH_BUILD = M.research_build
if RESEARCH_BUILD then log('research build %s: %s', RESEARCH_BUILD, RESEARCH_BUILD == 'R0' and 'reads nothing, draws nothing' or 'reads everything, draws nothing') end
local clock = os and os.clock
local perf = { t = {}, frames = 0, at = nil, watched = 0, n = 0, reads0 = 0, tests0 = 0 }
-- (1.5.27) the game's own health, for the disconnect reports (players dropped from a host's mission, Nexus
-- 2026-10-29): a line a minute with the Lua heap (the game's one VM: a heap growing across missions makes every
-- collection longer) and the frames the whole game stalled (dt of a quarter second or more: a stall anywhere, not
-- just in NarrowHUD, and a client stalled for seconds is dropped by its host), and the last stalls when a mission
-- world ends. Always on: one line a minute, a reporter needn't have turned anything on.
-- (1.5.29) the first logs read (a client, four missions: heap flat, no stalls, nothing before the drop) left the
-- causes a client-side mod could have unseen from here, so more is counted, all of it cheap: the worst frame of the
-- minute and the frames over 50 and 100 ms (a client falls behind through hitches short of a stall too); the
-- objects that came or went (none for seconds is the freeze the reports describe: enemies stop, the host runs in
-- place, then the error; timed here against the end); fields read; the engine objects made (GUIs, material copies:
-- the engine's side, which the Lua heap doesn't show); every table of ours that grew; and the ping to the host,
-- if the engine answers Network.ping through the loader (tried once a session; refused, it says so once).
local vital = { at = nil, frames = 0, stalls = 0, worst = 0, heap0 = nil, mission = false, last = {}, started = nil,
  worst_dt = 0, over50 = 0, over100 = 0, churn = 0, scans = 0, reads0 = 0, sizes = {},
  host = { sig = nil, at = nil, said = false }, mates = { sig = nil, at = nil, said = false },
  still_since = nil, still_said = false, longest_still = 0, changed_at = nil, ping = nil, ping_lo = nil, ping_hi = nil,
  ping_state = nil }
local function heap_kb()
  if type(collectgarbage) ~= 'function' then return nil end
  local ok, v = pcall(collectgarbage, 'count')
  return ok and type(v) == 'number' and v or nil
end
-- every table of ours (N's, one level deep) that grew since the last minute: "name +n (total)"
local function grown_tables()
  local out, sizes = {}, vital.sizes
  local seen = {}
  for name, t in pairs(N) do
    if type(t) == 'table' then
      local n = 0
      for _ in pairs(t) do n = n + 1 end
      seen[name] = n
      local was = sizes[name]
      if was and n - was >= 20 then out[#out + 1] = string.format('%s +%d (%d)', name, n - was, n) end
    end
  end
  vital.sizes = seen
  table.sort(out)
  return out
end
-- the ping to the host, once a second: Network.ping(peer) is the engine's own (Vermintide's scripts show theirs with
-- it); the loader may refuse it or the game may lack it: then nothing, said once
local function ping_step(now)
  if vital.ping_state == 'no' or not session.host or session.host == session.peer then return end
  if vital.ping_at and now - vital.ping_at < 1 then return end
  vital.ping_at = now
  local v, why = call('ping', 'Network.ping', session.host)
  if type(v) ~= 'number' then
    if vital.ping_state == nil then
      vital.ping_state = 'no'
      log('ping to the host: Network.ping gives %s (%s): not logged', tostring(v), tostring(why))
    end
    return
  end
  vital.ping_state = 'yes'
  vital.ping = v
  vital.ping_lo = math.min(vital.ping_lo or v, v)
  vital.ping_hi = math.max(vital.ping_hi or v, v)
end
-- (1.5.30) the freeze seen directly, once a second: the host's Helldiver (the host's player object's avatar; in the
-- reports "the host runs in place") by its input, stamina, health and aim fields, and the teammates' units (every
-- Helldiver unit but the one nearest the camera, yours) by their positions to a tenth of a metre. Each: still for
-- 3 s logged once, moving again logged, and at the end how long before it each last changed. The object churn
-- (below) turned out too weak alone: a healthy mission had 20 s with nothing coming or going.
local function host_sig(s)
  local hp = session.host_player
  if not hp or not alive(s, hp, TYPES[1]) then return nil end
  local av = call('player.avatar', 'GameSession.game_object_field', s, hp, DATA.player.avatar)
  if type(av) ~= 'number' or av == N.NO_OBJECT or not alive(s, av, TYPES[2]) then return nil end
  local parts = {}
  for i, name in ipairs({ 'input', 'stamina', 'health', N.FNAME_AIM or 'ww3bwxa' }) do
    parts[i] = tostring(call('host.' .. name, 'GameSession.game_object_field', s, av, name))
  end
  return table.concat(parts, ' ')
end
local function mates_sig()
  local w = N.mates_watch
  if not w or not w.items or #w.items < 2 or not chef.unit_position then return nil end
  local mine = N.my_unit and N.my_unit()
  local parts = {}
  for _, it in ipairs(w.items) do
    if it.unit ~= mine and N.unit_ready(it.unit) then     -- (3.0.13: not a teammate's unit in its first 3 s)
      local x, y, z = chef.unit_position(it.unit)
      if x then parts[#parts + 1] = string.format('%.1f %.1f %.1f', x, y, z) end
    end
  end
  table.sort(parts)
  return #parts > 0 and table.concat(parts, ' ') or nil
end
local function still_step(key, what, sig, now)
  local v = vital[key]
  -- (nothing to read, the host's objects gone at the end: the last change's time is kept for the end line)
  if sig == nil then v.sig, v.said = nil, false return end
  -- (1.5.33: "(you're dead)" on the lines: luka's host stood still every time luka was dead; a freeze while dead
  -- isn't the one before a drop)
  local dead = N.dead and ' (you\'re dead)' or ''
  if sig ~= v.sig then
    if v.at and v.said then log('%s moving again after %.0f s%s', what, now - v.at, dead) end
    v.sig, v.at, v.said = sig, now, false
  elseif v.at and now - v.at >= 3 and not v.said then
    v.said = true
    log('%s still for 3 s at %.0f s%s', what, now, dead)
  end
end
local function still_since(key, now)
  local v = vital[key]
  if key == 'host' and not session.host_player and N.read_level ~= 1 then return 'not read (the host\'s objects aren\'t)' end
  return v.at and string.format('%.0f s', now - v.at) or 'unknown'
end
-- after each scan (once a second in a mission): the objects' churn, and the freeze when there's none for 5 s
local function churn_step(now)
  vital.churn, vital.scans = vital.churn + session.churn, vital.scans + 1
  if session.churn > 0 then
    if vital.still_since and now - vital.still_since >= 5 then
      log('objects moving again after %.0f s with none coming or going', now - vital.still_since)
    end
    vital.still_since, vital.still_said, vital.changed_at = nil, false, now
  else
    vital.still_since = vital.still_since or now
    local still = now - vital.still_since
    if still > vital.longest_still then vital.longest_still = still end
    if still >= 5 and not vital.still_said then
      vital.still_said = true
      log('objects still: none came or went for 5 s (yours %d, the host\'s %d) at %.0f s', session.mine, session.hosts, now)
    end
  end
end
-- after each scan (once a second in a mission): all of the above (one name for M.update, which is near Lua's 60 upvalues)
local function scan_vitals(s, now)
  churn_step(now)
  ping_step(now)
  still_step('host', 'the host\'s Helldiver', host_sig(s), now)
  still_step('mates', 'the teammates', mates_sig(), now)
end
-- (1.5.31) who's in the session, for the disconnect logs: Chef 1.4's players event (someone starts joining, is in,
-- or leaves) logged as it comes, and the count in the end line (chef.players: you too; chef.in_session)
if N.CHEF14 and chef.on then
  pcall(chef.on, 'players', function(n, joining, before)
    log('players: %s in the session (%s joining), %s before', tostring(n), tostring(joining), tostring(before))
  end)
end
local function who_is_in()
  if not chef.players then return '' end
  local ok, n = pcall(chef.players)
  local ok2, j = pcall(chef.joining or function() return nil end)
  local ok3, ins = pcall(chef.in_session or function() return nil end)
  return string.format('; players %s (%s joining), in a session: %s', ok and tostring(n) or '?', ok2 and tostring(j) or '?', ok3 and tostring(ins) or '?')
end
local function vitals(now, dt)
  vital.frames = vital.frames + 1
  if (N.read_level or 2) ~= 2 and vital.level_said ~= N.read_level and chef.in_mission() then
    vital.level_said = N.read_level
    log('Testing: reads %s this mission', ({ 'all, the host\'s objects too', 'no host objects', 'no field reads', 'no object reads at all', 'no Unit calls', 'no floor / underbarrel reads (as 1.5.13)' })[N.read_level] or tostring(N.read_level))
  end
  if type(dt) == 'number' then
    if dt > vital.worst_dt then vital.worst_dt = dt end
    if dt >= 0.1 then vital.over100 = vital.over100 + 1 elseif dt >= 0.05 then vital.over50 = vital.over50 + 1 end
    if dt >= 0.25 then
      vital.stalls = vital.stalls + 1
      if dt > vital.worst then vital.worst = dt end
      local l = vital.last
      l[#l + 1] = string.format('%.2f s at %.0f s', dt, now)
      if #l > 8 then table.remove(l, 1) end
    end
  end
  local mission = chef.in_mission() == true
  if mission ~= vital.mission then
    vital.mission = mission
    if mission then
      vital.started, vital.heap0 = now, heap_kb()
      vital.still_since, vital.still_said, vital.longest_still, vital.changed_at = nil, false, 0, nil
      vital.host, vital.mates, vital.dead_at = { said = false }, { said = false }, nil
    else
      local h = heap_kb()
      log('mission world ended after %.0f s: lua heap %s, %d stalled frame(s) this minute (worst %.2f s), the last stalls: %s',
        now - (vital.started or now), h and string.format('%.1f MB (%+.1f since the mission started)', h / 1024, (h - (vital.heap0 or h)) / 1024) or 'unknown',
        vital.stalls, vital.worst, #vital.last > 0 and table.concat(vital.last, ', ') or 'none')
      log('at the end: the host\'s Helldiver last changed %s before it, the teammates last moved %s before it, the last object came or went %s before it; you were %s; the longest spell with none %.0f s; worst frame this minute %.0f ms; objects yours %d, the host\'s %d%s',
        still_since('host', now), still_since('mates', now),
        vital.changed_at and string.format('%.0f s', now - vital.changed_at) or 'never (no scan ran)',
        N.dead and 'dead' or (vital.dead_at and string.format('alive (last dead %.0f s before it)', now - vital.dead_at) or 'alive (never dead this mission)'),
        vital.longest_still, vital.worst_dt * 1000,
        session.mine, session.hosts, (vital.ping and string.format('; ping to the host %.0f ms (%.0f to %.0f this minute)', vital.ping, vital.ping_lo, vital.ping_hi) or '') .. who_is_in())
    end
  end
  vital.at = vital.at or now
  if now - vital.at >= 60 then
    local h = heap_kb()
    log('a minute: %d frames, lua heap %s, %d frame(s) stalled a quarter second or more (worst %.2f s)%s', vital.frames,
      h and string.format('%.1f MB%s', h / 1024, vital.heap0 and string.format(' (%+.1f this mission)', (h - vital.heap0) / 1024) or '') or 'unknown',
      vital.stalls, vital.worst, vital.stalls > 0 and (': ' .. table.concat(vital.last, ', ')) or '')
    if mission then
      local grown = grown_tables()
      local made = N.engine_made or { gui = 0, mat = 0 }
      log('  frames: worst %.0f ms, %d over 50 ms, %d over 100 ms; objects: yours %d, the host\'s %d, %d came or went in %d scans%s; %d fields read; engine objects made so far: %d GUIs, %d materials%s%s',
        vital.worst_dt * 1000, vital.over50, vital.over100, session.mine, session.hosts, vital.churn, vital.scans,
        vital.still_since and string.format(' (none for the last %.0f s)', now - vital.still_since) or '',
        (N.reads or 0) - vital.reads0, made.gui, made.mat,
        vital.ping and string.format('; ping to the host %.0f ms (%.0f to %.0f)', vital.ping, vital.ping_lo, vital.ping_hi) or '',
        (vital.host.at and now - vital.host.at >= 3 and string.format('; the host\'s Helldiver still %.0f s', now - vital.host.at) or '')
        .. (vital.mates.at and now - vital.mates.at >= 3 and string.format('; the teammates still %.0f s', now - vital.mates.at) or '')
        .. (#grown > 0 and ('; tables grown: ' .. table.concat(grown, ', ')) or ''))
    else
      vital.sizes = {}
    end
    vital.at, vital.frames, vital.stalls, vital.worst = now, 0, 0, 0
    vital.worst_dt, vital.over50, vital.over100, vital.churn, vital.scans, vital.reads0 = 0, 0, 0, 0, 0, N.reads or 0
    vital.ping_lo, vital.ping_hi = vital.ping, vital.ping
  end
end
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
-- (2.4.7, HUDdle 0.7.1's idea 3) no drop line where it can't apply: in a vehicle seat (your Helldiver's seat bit;
-- a mounted gun shown from its seat keeps its line: the Grenadier Battlement lobs), in the hellpod (its landing field
-- still false: 12_vitals; HUDdle goes by the camera's distance, which our own landing field makes unneeded), while a launcher that kneels to reload reloads (the Recoilless, the Epoch, the
-- Airburst: their stage not 0), and, not aiming, while you sprint (your stamina falling: only a Drop line set to
-- Always shows then). The throw line keeps the last two. -> why, or nil
local KNEEL = { b2bfd847 = true, ['314a1bf5'] = true, ['8a3c6fee'] = true }
local arcs = { st = nil, st_at = -100, said = nil }
function N.arc_blocked(now, d, vit)
  local why
  local st8 = N.state8
  if vit and type(vit.st) == 'number' then
    if arcs.st and vit.st < arcs.st - 0.0005 then arcs.st_at = now end
    arcs.st = vit.st
  end
  local seat = N.seat
  if st8 and st8.seat == 1 and not (seat and seat.gun and hand.goid == seat.gun) then why = 'seated' end
  if not why and st8 and st8.landed == false then why = 'in the hellpod' end
  local id = d and d.t0 and d.t0.id
  if not why and id and KNEEL[id] and (tonumber(d.reload_stage) or 0) ~= 0 then why = 'kneeling to reload' end
  if not why and not N.aim_now and now - arcs.st_at < 0.6 then why = 'sprinting' end
  if why ~= arcs.said then
    if cfg.research and (why or arcs.said) then log('research: drop line %s', why and ('hidden: ' .. why) or 'back') end
    arcs.said = why
  end
  return why
end
local flash = { text = nil, till = 0 }                -- a short message under the crosshair (forgetting)
local function build_gate(now)
  if game_build.known == false and not cfg.any_build then
    check_step()
    if check.state ~= 'ok' then
      local wid = N.world_id()
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
local probed = {}                                  -- (2.5.14) the kinds whose box a MARK has asked
local function read_forget_keys(now, s)
  if keys.hide_hud and keys.hide_hud.pressed and keys.hide_hud.pressed() == true then   -- (2.5.23: the hide key, a toggle)
    N.hud_off = not N.hud_off
    log('the HUD %s (the hide key)', N.hud_off and 'hidden' or 'back')
  end
  if keys.log_mark and keys.log_mark.pressed and keys.log_mark.pressed() == true then
    marks = marks + 1
    local o = hand.goid and objs[hand.goid]
    -- (1.5.16: the camera too, for the icon strobe that comes with one half of a map's view)
    local cam = chef.camera and chef.camera()
    local where = cam and string.format(', camera at %.0f,%.0f,%.0f yaw %.0f', cam.x, cam.y, cam.z, math.deg(cam.yaw or 0)) or ''
    local kit = (cfg.research and s and o and o.t) and (', kit ' .. N.kit_text(s, hand.goid, TYPES[o.t])) or ''
    log('==== MARK %d ==== hand pose %s, shown: %s (object %s), fire button %.1f s ago, swap %.1f s ago%s%s', marks,
      tostring(hand.grip), o and o.t and TYPES[o.t].id or 'nothing', tostring(hand.goid), now - (input.last or -100), now - (swap.at or -100), where, kit)
    flash.text, flash.till = string.format('NarrowHUD: mark %d in the log', marks), now + 1.5
    N.mark_at = now                                -- (2.4.9: the aim-points research line counts afresh for 20 s)
    -- (2.5.5, research) what stands where the reticle points at the MARK: the units within 15 m of the game's
    -- reticle point (else the look point), named or not, from the walk's caches — so a MARK on a warp ship, a
    -- spore tower or anything else says which unit kind it is
    if cfg.research and N.reticle_point and chef.camera then
      local cam = chef.camera()
      local rp = cam and N.reticle_point(cam, true)
      local lp = not rp and N.look_point and N.look_point()
      local pt = rp or lp
      if pt and N.units_near then
        local near = N.units_near(pt.x, pt.y, 40, pt.z)   -- (2.5.12: 40 m, with each kind's count on the map)
        log('research: at the MARK\'s aim point (%.1f, %.1f, %.1f; %s): %s', pt.x, pt.y, pt.z, rp and 'the reticle' or 'the look point',
          #near > 0 and table.concat(near, '; ') or 'no walked unit within 40 m')
        -- (2.5.14, the warp ship hunt: its furniture is all the listing shows) the box of the nearest unit of each
        -- unnamed kind within 15 m, a dozen at most, each alive-checked the frame it's asked — the hull's box is
        -- the big one. Once per kind per session
        if N.box_probe and N.units_near_handles then
          local n, out = 0, {}
          for _, e in ipairs(N.units_near_handles(pt.x, pt.y, 15)) do
            if n >= 12 then break end
            if not UNIT_NAMES[e.k] and not probed[e.k] then
              probed[e.k] = true
              n = n + 1
              local hx, hy, hz, dz = N.box_probe(e.u, e.k)
              out[#out + 1] = hx and string.format('%s: %.1f x %.1f x %.1f m%s', e.k, hx * 2, hy * 2, hz * 2, dz and string.format(', its middle %+.1f m over the root', dz) or '') or (e.k .. ': ' .. tostring(hy or 'no box'))
            end
          end
          if #out > 0 then log('research: at the MARK, the boxes: %s', table.concat(out, '; ')) end
        end
      end
    end
  end
  if N.startup_flash then flash.text, flash.till, N.startup_flash = N.startup_flash, now + 8, nil end
  if keys.reload_layout and keys.reload_layout.pressed and keys.reload_layout.pressed() == true then
    local ok, dropped = load_layout('the reload key')
    flash.text, flash.till = not ok and 'NarrowHUD: the layout file can\'t be read (see narrowhud.log)'
      or ((dropped or 0) > 0 and string.format('NarrowHUD: layout file read, %d values left at their defaults', dropped)
      or 'NarrowHUD: layout file read again'), now + 3
    -- (1.2.1: read, but only Custom uses it: said, a player waited for a change that couldn't come)
    if ok and cfg.builtin then
      flash.text, flash.till = 'NarrowHUD: layout file read, but it\'s used only with F9 > NarrowHUD > Layout: Custom layout', now + 5
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

-- (1.5.70) the game's pause / settings screen: the HUD is in the game's UI layer since 1.5.63, over that screen
-- too (luka). The one time the game shows its own mouse cursor is that screen (Th3chef's note in Chef's loader:
-- the map, the chat and the HUD never do), so Window.show_cursor on the main window says when it's up; read four
-- times a second, through chef.call (nil, an odd answer, or no chef.call: never hidden by it)
local gm = { at = -100, up = false, win = nil }
local function game_menu(now)
  if not chef.call then return false end
  if now - gm.at < 0.25 then return gm.up end
  gm.at = now
  if gm.win == nil then gm.win = chef.call('Window.get_main_window') or false end
  if not gm.win then return false end
  local v = chef.call('Window.show_cursor', gm.win)
  gm.up = v == true
  return gm.up
end
function M.update(dt)
  N.frame = N.frame + 1
  local now = chef.time()
  N.now, N.dt = now, dt or 0.016
  N.L0 = (cfg.top_world and type(chef.TOP) == 'number') and chef.TOP or 0
  vitals(now, dt)
  if N.dirty_at and now >= N.dirty_at then
    N.dirty_at = nil
    save_learned()
  end
  if not chef.in_mission() then shown_now, items_now = nil, nil return end
  if RESEARCH_BUILD == 'R0' then return end            -- (reads nothing, draws nothing: Chef's update hook only)
  if build_gate(now) then return end
  local s = call('session', 'Network.game_session')
  local peer = call('peer', 'Network.peer_id')
  if s == nil or peer == nil then shown_now, items_now = nil, nil return end
  N.session_now = s                                -- (2.2.4: the drawing modules' research reads)
  -- A new world (each mission, the ship) starts its object ids over: an id of ours can be one that was something else
  -- last mission, and its old type was kept (an id found to be nothing of ours was never looked at again: our weapons
  -- went unseen for whole missions). Everything about objects is forgotten on a new world.
  local wid = N.world_id()
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
    if N.units_forget then N.units_forget() end     -- (3.0.13: a new world's units are all new)
    if N.ground_reset then N.ground_reset() end
    next_scan = now
  end
  local t0 = cfg.research and clock and clock() or nil
  classify(s)
  t0 = lap('sorting', t0)
  if now >= next_scan then
    next_scan = now + 1
    scan(s, peer)
    scan_vitals(s, now)
    -- once a mission, 8 s in: what this session looks like (for games hosted by someone else)
    local wid = N.world_id()
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
      if cfg.research then
        for goid, o in pairs(objs) do
          local t = o.t and TYPES[o.t]
          if t and o.on and not t.pack and not t.other and not t.player and not t.avatar and alive(s, goid, t) then
            log('research: kit of weapon %s (object %s%s): %s', t.id, tostring(goid), goid == hand.goid and ', in hand' or '', N.kit_text(s, goid, t))
          end
        end
        if me.avatar and alive(s, me.avatar, TYPES[2]) then log('research: kit of your Helldiver: %s', N.kit_text(s, me.avatar, TYPES[2])) end
      end
    end
  end
  read_fire_button(now)
  if (cfg.drop_line or 1) == 2 or cfg.throw_line or (cfg.aim_spread or 0) ~= 0 or (cfg.aim_opacity or 1) ~= 1 then N.read_aim_button(now) end
  read_swap(now)
  read_forget_keys(now, s)

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
        -- (a heat weapon with no rounds, a laser, has no drop to draw: no name asked for it)
        local laser = o and TYPES[o.t].has.heat and not TYPES[o.t].has.rounds
        if o and (not b or b.guess) and not laser and not (hand.named or {})[o.t] then
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
    N.shown_d = shown_now                            -- (1.5.16 research: the fire-mode icon test reads its label)
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
          elseif sp.kind == 'hover' and type(v) == 'boolean' then
            -- (2.1.3) the hover pack's fuel, modelled (02_settings' SPECIAL): used up for as long as the flag is on,
            -- back at 1 / refill of that rate on the ground; the bar against the longest flight seen (sp.most to begin)
            local dt = math.min(1, now - (o.sp_at or now))
            o.sp_at = now
            o.fuel = o.fuel or 0
            if v then
              -- (2.1.9) burnt for the whole time the flag is on, past the 8.1 s tank: dropping down a slope the pack
              -- stops burning for a moment and takes a little back, which luka spends on the way with directional
              -- input, landing at zero — 2.1.7's refill in flight had the bar climbing while the game's sat empty,
              -- 2.1.5's cap had it full too soon. What comes back is the refill x the flag's time: his 2.1.8 run's
              -- flights of 8.7 to 10.9 s were full 10.3 to 11.4 s after the flag went off (one 8.0, landed with some
              -- left), 6.5 s ones 7.5 and 8.5; 2.1.5's plain 8.1 s drains 9.4 on average. The bar: empty from 8.1 s
              -- on, then climbing from touchdown to full over the whole refill
              o.fuel, o.fuel_land = o.fuel + dt, nil
              items_now.draining = true
            else
              o.fuel_land = o.fuel_land or o.fuel
              o.fuel = math.max(0, o.fuel - dt / sp.refill)
            end
            if not maps then items_now.recharge = math.max(0, 1 - o.fuel / math.max(sp.most, o.fuel_land or 0)) else items_now.draining = nil end
          elseif sp.kind == 'shield' and type(v) == 'number' then
            -- (2.1.5) the shield backpack's strength as the pack bar; (2.1.6) with its flags: down = broken, shown
            -- empty and red whatever the last strength sent (a break left it reading 15, luka); regen = coming back,
            -- animated from the last strength to full over a second (the field jumps: it's sent by tolerance); once
            -- the regen ends it's full until the strength moves again
            local top = o.sp_top or sp.top
            if v > top then o.sp_top, top = v, v end
            local mn = sp.mnames or {}
            local down = mn.down and call(t.id .. '.special', 'GameSession.game_object_field', s, sgoid, mn.down) == true
            local regen = mn.regen and call(t.id .. '.special', 'GameSession.game_object_field', s, sgoid, mn.regen) == true
            if v ~= o.sh_v then o.sh_v, o.sh_full = v, false end
            local shown = v
            if down then
              shown, o.sh_regen_t, o.sh_full = 0, nil, false
            elseif regen then
              if not o.sh_regen_t then o.sh_regen_t, o.sh_regen_from = now, math.min(v, top) end
              shown = math.max(v, o.sh_regen_from + (top - o.sh_regen_from) * math.min(1, (now - o.sh_regen_t) / 1))
              -- (2.1.7: the animation runs every frame, below, not only on this quarter-second tick: luka saw steps)
              if not maps then items_now.sh_anim = { t0 = o.sh_regen_t, from = o.sh_regen_from, top = top, floor = v } end
            else
              if o.sh_regen_t then o.sh_regen_t, o.sh_full = nil, true end
              if o.sh_full then shown = top end
            end
            if not maps then items_now.pack, items_now.pack_top = shown, top end
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

  -- (2.1.7) the shield backpack's refill animated every frame (its reads come every quarter second)
  if items_now and items_now.sh_anim then
    local a = items_now.sh_anim
    items_now.pack = math.max(a.floor, a.from + (a.top - a.from) * math.min(1, (now - a.t0) / 1))
  end
  local vit = N.vitals_step(s, now, items_now)
  if N.dead then vital.dead_at = now end
  N.read_markers(s, now)
  t0 = lap('items', t0)
  if N.ground_update then N.ground_update(now) end   -- (2.0.4: the ground grid's samples and the research census)
  t0 = lap('ground', t0)                             -- (2.5.3: the walk timed apart from the items)
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
  -- (1.5.55: back fast (80 ms), away slowly (300 ms); Motion off: as 1.5.54, away at 1.5 a second, back at once)
  local ms = N.motion_scale and N.motion_scale() or 1
  if target < hand.fade then hand.fade = math.max(target, hand.fade - (dt or 0.016) * (ms > 0 and 1 / (0.3 * ms) or 1.5))
  elseif ms > 0 then hand.fade = math.min(target, hand.fade + (dt or 0.016) / (0.08 * ms))
  else hand.fade = target end
  -- (1.5.55) the events that move something (08_motion), and aiming as a state
  N.motion_events(shown_now, items_now, vit, hand.goid)
  -- (2.0.1: the aim as the game's own state bit where it reads — a toggled aim counts, a knock out of it ends it;
  -- the aim button or the stance field where it doesn't, as before)
  local st8a = N.state8
  if st8a and st8a.ads ~= nil then N.aim_now = st8a.ads == 1
  else N.aim_now = (N.input and N.input.aiming) or (st8a and st8a.aim == 4) or false end
  local aim_alpha = N.ease('aimalpha', N.aim_now and (cfg.aim_opacity or 1) or 1, 120)
  -- (1.5.60) each part's Show rule, eased (08_show); health and stamina take theirs through vit.show_h / show_s
  N.show_step(shown_now, items_now, vit, now)
  if vit then
    vit.show_h = (cfg.health or 1) == 1 and 0 or (N.part_alpha.health or 1)
    vit.show_s = (cfg.stamina or 1) == 1 and 0 or (N.part_alpha.stamina or 1)
  end
  -- (the stratagem input, an emote: hidden over 80 ms (2.2.9; a quarter second before), back at once)
  local st8 = N.state8
  -- (2.5.24, luka) in a vehicle: hidden as the driver (the FRV's, the tank's), the exosuit's pilot, or a gunner with
  -- no gun of ours shown (the tank's: you can't be hurt in there); shown as a passenger or on the FRV's turret (its
  -- gun is shown, and you're out in the open). 12_vitals' seat bit and role
  -- (2.5.25, luka: the Maelstrom's gunner wasn't hidden — its gun 9df87863 is a weapon object of ours, shown
  -- through "the object you're at"; the FRV's turrets 66f5d393 and 0df6deff are out in the open) a gun type that
  -- sits inside armour counts as no gun shown
  local gun_shown = shown_now and not N.ENCLOSED_GUNS[shown_now.tid]   -- (12_vitals' set: 13_main is at Lua's 60 upvalues)
  local in_vehicle = cfg.hide_vehicle ~= false and st8.seat == 1 and (st8.role == 2 or st8.role == 8 or (st8.role == 4 and not gun_shown)) or false
  if in_vehicle ~= hand.in_vehicle then
    hand.in_vehicle = in_vehicle
    if cfg.research then log('research: the HUD %s: in a vehicle (seat role %s, a gun shown: %s%s)', in_vehicle and 'hidden' or 'back', tostring(st8.role), tostring(shown_now ~= nil), shown_now and (' ' .. tostring(shown_now.tid) .. (N.ENCLOSED_GUNS[shown_now.tid] and ', enclosed' or '')) or '') end
  end
  local hide = N.hud_off or in_vehicle or st8.strat or (cfg.hide_emote and st8.emote ~= -1 and st8.emote ~= 0) or game_menu(now)   -- (2.5.23: N.hud_off, the hide key)
    or (cfg.hide_wheel and st8.wheel == 1)   -- (2.1.1: the weapon settings wheel)
    or (cfg.hide_terminal and N.at_terminal())   -- (2.2.3: a terminal worked)
  -- (2.2.9, luka: the hide "instant or very quick", and the HUD and the vitals together — the HUD faded over a
  -- quarter second while the vitals cut at once: 80 ms for both now, the same curve, from the same frame)
  local HIDE_FADE = 0.08
  hand.hidef = hide and math.max(0, (hand.hidef or 1) - (dt or 0.016) / HIDE_FADE) or 1
  local vhide = N.hud_off or in_vehicle or (cfg.hide_emote and st8.emote ~= -1 and st8.emote ~= 0) or game_menu(now)   -- (1.5.72: the game's menu hides the vitals too; 2.5.23: the hide key; 2.5.24: a vehicle)
    or (cfg.hide_wheel and st8.wheel == 1)   -- (2.1.2, luka: the wheel hides them too, unlike the stratagem key)
    or (cfg.hide_terminal and N.at_terminal())
  hand.vhidef = vhide and math.max(0, (hand.vhidef or 1) - (dt or 0.016) / HIDE_FADE) or 1
  N.alpha_k = cfg.opacity * hand.fade * hand.hidef * N.swap_k() * aim_alpha
  if RESEARCH_BUILD == 'R1' then N.drop_lines = 0 end   -- (reads everything, draws nothing)
  if RESEARCH_BUILD ~= 'R1' and (shown_now or (items_now and hand.grip and hand.grip ~= 0)) and hand.fade > 0.01 and hand.hidef > 0.01 then
    local dd = shown_now
    -- (the parts switched Off are masked out; a layout keeps a held-back part's place and fades it itself)
    local on = cfg
    if dd and not (on.show_rpm and on.show_fmode and on.show_mode and on.show_mags and (on.show_charge or dd.reload_line)) then
      dd = setmetatable({}, { __index = shown_now })
      if not on.show_rpm then dd.setting = false end
      if not on.show_fmode then dd.fmode = false end
      if not on.show_mode then dd.mode = false end
      if not on.show_mags then dd.reserve = false end
      if not on.show_charge and not shown_now.reload_line then dd.charge_frac = false end
    end
    draw(dd, items_now)
  end
  -- (health and stamina: dimmed or hidden with the rest when nothing changes, never while you're hurt or out of breath)
  if RESEARCH_BUILD ~= 'R1' and vit and (vit.show_h > 0 or vit.show_s > 0 or vit.stim) and hand.vhidef > 0.01 then
    N.alpha_k = cfg.opacity * ((vit.busy or vit.stim) and 1 or (hand.fade or 1)) * aim_alpha * hand.vhidef
    local tv = t0 and clock()
    N.draw_vitals(vit)
    if tv then N.el_time.vitals = (N.el_time.vitals or 0) + (clock() - tv) end   -- (2.4.11: the parts' timing covers everything drawn)
  end
  -- (1.3.0) your map pin and your last death, on the screen where they are; hidden with the stratagem input
  if cfg.swatches and chef.screen then local sw, sh = chef.screen() if sw then N.draw_swatches(sw, sh) end end
  if RESEARCH_BUILD ~= 'R1' and hand.hidef > 0.01 then
    N.alpha_k = cfg.opacity * hand.hidef
    local tm = t0 and clock()
    N.draw_markers()
    -- (1.5.43) the sniper rifles' crosshair, aimed in third person
    N.draw_reticle(shown_now, now)
    local td = t0 and clock()
    if td then N.el_time.markers = (N.el_time.markers or 0) + (td - tm) end
    -- (1.4.0) the drop line of the weapon in hand
    N.drop_lines = 0
    N.decal_time = 0
    local no_arc = N.arc_blocked(now, shown_now, vit)
    if shown_now and shown_now.tid and hand.grip and hand.grip ~= 0 and not no_arc then N.draw_drop(shown_now.tid) end
    local tt = t0 and clock()
    if tt then N.el_time.drop = (N.el_time.drop or 0) + (tt - td) end
    -- (1.5.0) a throw's line: a stratagem ball, a grenade or C4 aimed (2.4.7: not seated, nor in the hellpod)
    if no_arc ~= 'seated' and no_arc ~= 'in the hellpod' then N.throw_step(now, hand.grip, shown_now) end
    if tt then
      N.el_time.throw = (N.el_time.throw or 0) + (clock() - tt)
      -- (the ground pictures' share, counted inside the two lines: taken out of theirs and listed on its own)
      N.el_time.ground_pics = (N.el_time.ground_pics or 0) + N.decal_time
      N.el_time.drop = N.el_time.drop - N.decal_time
    end
  end
  -- (Chef keeps showing the last lines dispatched until a frame draws some again: a line of nothing for a few
  -- frames after the last, so a drop or throw line that goes doesn't stay in the world; the 1.4.2 and 1.5.1 logs)
  if N.drop_lines > 0 then hand.lines_at = now
  elseif hand.lines_at and now - hand.lines_at < 0.25 and not N.CHEF14 then N.drop_clear() end   -- (Chef 1.4 clears them itself)
  N.decal_sweep()                                  -- (2.4.8: the ground pictures not painted this frame parked)
  N.alpha_k = cfg.opacity
  if t0 then
    lap('drawing', t0)
    perf.frames = perf.frames + 1
    perf.at = perf.at or now
    if now - perf.at >= 60 then
      local f, parts, all = math.max(1, perf.frames), {}, 0
      for _, k in ipairs({ 'sorting', 'scan', 'weapons', 'picking', 'research', 'items', 'ground', 'drawing' }) do
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
    notice('NarrowHUD: this Chef version blocks the reads it needs (it needs Chef Shared Loader 1.4.0 or newer)')
  end
  if flash.text and now < flash.till then notice(flash.text) end
end

function M.debug_objs() return objs end   -- (tests)
function M.debug_N() return N end   -- (tests: the shared table)
function M.debug_fly(b, pitch, len) return N.drop_fly(b, pitch, len) end
function M.debug_cfg(k, v) cfg[k] = v end
function M.debug_vis() return cfg.vis end   -- (tests, 2.5.24)
function M.debug_struct_by_id(k, name) if N.debug_struct_by_id then N.debug_struct_by_id(k, name) end end   -- (tests, 2.5.12: a structure kind by hash)
function M.debug_tone(ch, v) return N.tone(ch, v) end   -- (tests: the world's tone curve)   -- (tests: a setting with no menu row, such as the texture test's way)
function M.debug_read_level(v) if v ~= N.read_level then log('Testing: reads %s', tostring(v)) end N.read_level = v end   -- (tests: the reads bisection, 2.0.3: no menu row)
function M.debug_made() return N.engine_made and N.engine_made.mat end   -- (tests: material copies made)
function M.debug_hosts() return session.hosts end   -- (tests: the host's objects seen by the last scan)
function M.debug_handheld(id) return N.HANDHELD[id] end   -- (tests)
function M.debug_seat() local st = N.seat return string.format('goid=%s gun=%s since=%s pose_since=%s ref=%s', tostring(st.goid), tostring(st.gun), tostring(st.since), tostring(st.pose_since), tostring(N.av_refs['20efbed4'])) end
function M.debug_seat_try(g) return N.seat_gun(nil, g, chef.time()) end
function M.debug_icons() local l = N.mode_icons and N.mode_icons() local out = {} for i, e in ipairs(l or {}) do out[i] = e[6] .. ':' .. tostring(e.word) end return out end
function M.debug_boxes()
  local out = {}
  for _, el in ipairs(N.ELEMENTS) do
    local b = (N.layout.pass_boxes or {})[el.vitals and 2 or 1]
    b = b and b[el.id]
    if b then out[el.id] = string.format('%d,%d %dx%d%s%s', b.x + math.floor((b.ax or 0) + 0.5), b.y + math.floor((b.ay or 0) + 0.5), b.w, b.h, b.hidden and ' hidden' or '', b.held and ' held' or '') end
  end
  return out
end
function M.debug_state8(k, v) N.state8[k] = v end   -- (tests)
function M.debug_aim() return N.last_aim end   -- (tests: the last throw line drawn)
function M.debug_ground(x, y) local g = N.ground local h, conf if N.ground_height then h, conf = N.ground_height(x, y) end return g and g.n, g and g.samples, g and g.skipped, h, conf end   -- (tests, 2.0.4 / 2.0.13)
function M.debug_ground_kind(k) return N.ground_kind_offset and N.ground_kind_offset(k) end   -- (tests, 2.0.13: a kind's trusted offset)
function M.debug_learned(kind, id) return learned[kind] and learned[kind][id] end   -- (tests: what's learned or seeded)
function M.debug_my_unit() return N.my_unit and N.my_unit(call('session', 'Network.game_session')) end   -- (tests)
function M.debug_hide() return hand.hidef, hand.vhidef end   -- (tests, 2.2.9)
function M.debug_top() local d = N.shown_d return d and d.top, d and d.kind end
function M.debug_charge() local d = N.shown_d local o = d and d.o return o and { t0 = o.charge_t0 or false, wait = o.charge_wait or false, sim = o.sim or false, anim = d.charge_anim or false, from = d.charge_from or false, h_last = o.h_last or false } or nil end   -- (tests, 3.0.2)
function M.debug_reload_line() local d = N.shown_d return d and d.reload_line == true or false end   -- (tests, 2.6.11)   -- (tests, 2.1.12: the shown bar's top)
function M.shutdown()
  if N.dirty_at then save_learned() end
end
-- (2.2.1) Chef 1.5: a mod with an on_stop is stopped for real when it's switched off in F9 (or after errors, a hang,
-- "Try again now") and started fresh when switched back on, in the same launch; without one it's only paused and
-- resumed as the same copy. Nothing of the game is changed by NarrowHUD, so there's nothing to put back: the learned
-- file is saved, and the GUIs made for the icons and the text are left to the world (an immediate GUI no one draws
-- with shows nothing; a destroy on a world that may be gone is the one call that could end the game)
function M.on_stop()
  if N.dirty_at then save_learned() end
end

