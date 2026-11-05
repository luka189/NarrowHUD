-- NarrowHUD, motion (1.5.55): the few things that move, and how. Three rules for a game this fast: everything
-- 80 to 250 ms, fast at first and soft at the end (ease-out: 1 - (1 - p)^3); information never eases (the count
-- shows the new number the frame it changes, the ammo ticks drop the frame you fire: only solid bars travel); motion
-- only on an event, one motion an event, then stillness.
-- What moves: a part whose place changed slides there (10_custom); solid bars ease to their value (a refill a
-- little longer); one-shot pulses (brighter, then back) on an event: stamina empty, the ammo bar at zero, the last
-- magazine, overheated, a stim or grenade used, the backpack empty; a weapon swap fades the new one in; a magazine
-- landing refills the ticks left to right; the HUD comes back fast and leaves slowly (13_main); while you aim the
-- Spread and the opacity ease to the Aim settings (10_custom, 13_main).
-- F9 "Motion": Off (everything snaps), Quick (these times), Normal (1.6 times them).
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg = N.cfg

local eased, slides, pulses = {}, {}, {}
local SCALES = { [1] = 0, [2] = 1, [3] = 1.6 }
local function scale() return SCALES[cfg.motion or 2] or 1 end
local function out3(p)
  p = math.max(0, math.min(1, p))
  local q = 1 - p
  return 1 - q * q * q
end
local function now_s() return N.now or chef.time() end

-- a value travelling to its target: an exponential approach (v moves (1 - e^(-dt / tau)) of the way each frame,
-- tau a third of ms, so a jump is nearly done in ms), which is ease-out for a jump and a short lag for a value that
-- moves every frame (the stim timer, a charge): a curve restarted at every change would never get going
local function ease(key, target, ms)
  local s = scale()
  if s == 0 then eased[key] = nil return target end
  local e = eased[key]
  if not e then eased[key] = { v = target } return target end
  local tau = math.max(0.001, ms * s / 3000)
  local a = 1 - math.exp(-(N.dt or 0.016) / tau)
  e.v = e.v + (target - e.v) * a
  if math.abs(target - e.v) < 0.0005 then e.v = target end
  return e.v
end
local function ease_reset(key) eased[key] = nil end
-- (2.4.2) a value travelling to its target on a clock, with a speed profile: gathers speed over the first 15 % of
-- the time, runs at full speed for 70 %, slows over the last 15 % (luka: "covers the distance very fast, then slows
-- down for the last few frames"). A new target mid-way starts a fresh run from where it is. Unlike ease(), it is
-- advanced once a frame however often it's asked (the frame's number is kept), so two draw passes read one value
-- (2.4.6, luka on 2.4.5: "the start and end are too swift; fast at the start, the slow-down into place over about 3
-- frames") the profile takes its parts: a the share gathering speed (0: full speed from the first frame), d the share
-- slowing down; the Aim spread's is 0 and 0.4 (the last 48 of its 120 ms: 3 frames at 60 fps, 4 at 83)
local tweens = {}
local function profile(p, a, d)
  a, d = a or 0.15, d or 0.15
  local v = 1 / (1 - (a + d) / 2)                 -- (the full speed: the distance under the profile is 1)
  if p <= 0 then return 0 elseif p >= 1 then return 1 end
  if p < a then return v * p * p / (2 * a) end
  if p < 1 - d then return v * (a / 2 + (p - a)) end
  local q = p - (1 - d)
  return v * (a / 2 + (1 - d - a) + q - q * q / (2 * d))
end
local function tween(key, target, ms, a, d)
  local s = scale()
  if s == 0 then tweens[key] = nil return target end
  local t = tweens[key]
  local now = now_s()
  if not t then tweens[key] = { v = target, to = target, from = target, t0 = now, frame = N.frame } return target end
  if target ~= t.to then t.from, t.to, t.t0 = t.v, target, now end
  if t.frame == N.frame then return t.v end
  t.frame = N.frame
  local secs = ms * s / 1000
  local p = secs > 0 and (now - t.t0) / secs or 1
  t.v = t.from + (t.to - t.from) * profile(p, a, d)
  if p >= 1 then t.v = t.to end
  return t.v
end
N.tween, N.tween_profile = tween, profile
-- the ammo / heat bar's solid fill: 120 ms, a refill (ammo rising) 200
local last_bar = nil
local function bar_eased(frac, d)
  local ms = (d and d.kind == 'ammo' and last_bar and frac > last_bar) and 200 or 120
  last_bar = frac
  return ease('bar', frac, ms)
end
-- a place travelling to its target (x, y); a move farther than far snaps (another layout chosen)
local function slide(key, x, y, ms, far)
  local s = scale()
  local e = slides[key]
  if s == 0 or not e then slides[key] = { x = x, y = y, fx = x, fy = y, tx = x, ty = y, t0 = now_s(), ms = 0 } return x, y end
  if x ~= e.tx or y ~= e.ty then
    if far and (math.abs(x - e.x) > far or math.abs(y - e.y) > far) then e.x, e.y = x, y end
    e.fx, e.fy, e.tx, e.ty, e.t0, e.ms = e.x, e.y, x, y, now_s(), ms * s / 1000
  end
  local p = e.ms > 0 and (now_s() - e.t0) / e.ms or 1
  local q = out3(p)
  e.x, e.y = e.fx + (e.tx - e.fx) * q, e.fy + (e.ty - e.fy) * q
  return math.floor(e.x + 0.5), math.floor(e.y + 0.5)
end
local function slide_reset(key) slides[key] = nil end
-- a one-shot pulse: brighter then back over 250 ms; pulsed(key, c) gives the colour as it is now
-- (1.5.59: a pulse has a tone: 'warn' (faintly red: something ran out) or 'good' (cream: stamina back to full))
local pulse_tone = {}
local function pulse(key, tone) if scale() > 0 then pulses[key] = now_s() pulse_tone[key] = tone or 'warn' end end
local function pulse_k(key)
  local t0 = pulses[key]
  if not t0 then return 0 end
  local p = (now_s() - t0) / (0.25 * math.max(scale(), 0.01))
  if p >= 1 then pulses[key] = nil return 0 end
  return 1 - out3(p)
end
-- (1.5.61: over a red bar (overheated) the faint red wash came out purple: a light salmon there instead)
local GLOW_WARN, GLOW_GOOD, GLOW_HOT = { 235, 120, 110 }, { 236, 229, 206 }, { 255, 205, 190 }
local function glow_col(key)
  local t = pulse_tone[key]
  return t == 'good' and GLOW_GOOD or (t == 'hot' and GLOW_HOT or GLOW_WARN)
end
local pulse_cols = setmetatable({}, { __mode = 'k' })
local function pulsed(key, c)
  local b = pulse_k(key)
  if b <= 0 then return c end
  local out = pulse_cols[c]
  if not out then out = {} pulse_cols[c] = out end
  for i = 1, 3 do out[i] = math.floor(c[i] + (255 - c[i]) * 0.7 * b + 0.5) end
  return out
end
-- a pulse when a condition turns true (the edge, not the state)
local edges = {}
local function edge_pulse(key, on, pulse_key, tone)
  if on and edges[key] == false then pulse(pulse_key or key, tone) end
  edges[key] = on and true or false
end
-- a magazine landing: the ticks from `from` to `to` light left to right over 150 ms
local refill = nil
local function refill_start(from, to) if scale() > 0 then refill = { t0 = now_s(), from = from, to = to, ms = 0.15 * scale() } end end
local landing = {}                                     -- (2.4.4: tick i -> when its loaded shell lands: unlit till then)
local function tick_lit(i, value)
  if i >= value then return false end
  local land = landing[i]
  if land then
    if now_s() < land then return false end
    landing[i] = nil
  end
  local r = refill
  if not r or i < r.from then return true end
  local p = (now_s() - r.t0) / r.ms
  if p >= 1 then refill = nil return true end
  return i < r.from + (r.to - r.from) * p
end
-- (2.4.4) the same for other counts rising (luka's pick of the resupply sweep): the magazine squares and the
-- backpack's uses light in order as they're topped up, from `from` to `to` over ms, by key ('mags', 'pack')
local sweeps = {}
local function sweep_start(key, from, to, ms) if scale() > 0 then sweeps[key] = { t0 = now_s(), from = from, to = to, ms = ms * scale() } end end
local function sweep_lit(key, i, n)
  if i >= n then return false end
  local r = sweeps[key]
  if not r or i < r.from then return true end
  local p = (now_s() - r.t0) / r.ms
  if p >= 1 then sweeps[key] = nil return true end
  return i < r.from + (r.to - r.from) * p
end
N.sweep_start, N.sweep_lit = sweep_start, sweep_lit
-- the weapon swap: the new weapon's HUD from a third of its opacity to all of it over 100 ms
local swap_at = nil
local function swap_start() if scale() > 0 then swap_at = now_s() end end
local function swap_k()
  if not swap_at then return 1 end
  local p = (now_s() - swap_at) / (0.1 * scale())
  if p >= 1 then swap_at = nil return 1 end
  return 0.3 + 0.7 * out3(p)
end

-- (2.3.4, a test) a shell flash per round fired (F9 "Shell flash", off by default): the tick that just emptied jumps
-- out of the bar, square to it and away from the crosshair, and fades, like a shell thrown from the port (luka's
-- idea; the draw is the bar's, 10_custom). A round counts only when the count drops by 1 to 3 while your weapon
-- fired in the last 0.35 s (06_learning's fired_at) or your fire button was down in the last 0.4 s (2.3.5: the
-- Cookout's shot that empties a tube moves its selected field too, which reads as a switch, not a shot: every eighth
-- shell went missing), so a reload, a switch or a mode change throws nothing; at most 10 in the air.
-- (2.3.5) The flight is cut short: only the first "Shell flash length" % of the whole (default 30: luka, "it should
-- barely leave the bar and already disappear"), fading out over that part.
local shells = {}
local SHELL_S = 0.32                                   -- (the whole flight; the part shown is cfg.shell_len %)
-- (2.4.4) Loading, the same flight backwards (luka's pick): on a round-by-round reload (the Cookout, the Punisher)
-- each round that lands comes in from where a thrown shell ends and lands in its tick, which lights as it lands;
-- twice the throw's time (luka: "around 6 frames", the throw's 3 at 60 fps), fading in as the throw fades out
local LOAD_K = 2
-- (2.3.6: 100 % is half the old flight — luka: the most it should ever be — and the default 30 % is the old 15 %)
-- (2.4.5) a loaded round's own length row (Shell loading length): how far out it starts
local function shell_cut(load) return math.max(0.025, math.min(0.5, ((load and cfg.shell_load_len or cfg.shell_len) or 30) / 200)) end
local function shell_dur(load) return SHELL_S * shell_cut(load) * math.max(scale(), 0.01) * (load and LOAD_K or 1) end
local function shell_eject(i, top, load)
  if scale() <= 0 or not (load and cfg.shell_load or (not load and cfg.shell_flash)) then return end
  if #shells >= 10 then table.remove(shells, 1) end
  local t = now_s()
  shells[#shells + 1] = { t0 = t, i = i, top = top, load = load }
  if load then landing[i] = t + shell_dur(true) end
end
-- the shells in the air now, each with p (0 at the bar, 1 at the flight's end: thrown 0 to 1, loaded 1 to 0)
local live = {}
local function shells_live()
  local t, n, keep = now_s(), 0, 0
  local cut, dur, lcut, ldur = shell_cut(false), shell_dur(false), shell_cut(true), shell_dur(true)
  for j = 1, #shells do
    local sh = shells[j]
    local p = (t - sh.t0) / (sh.load and ldur or dur)
    if p < 1 then
      keep = keep + 1 shells[keep] = sh
      p = math.max(0, p)
      if sh.load then p = 1 - p end
      n = n + 1 live[n] = sh sh.p = p sh.u = p * (sh.load and lcut or cut)   -- (p: through the part shown; u: through the whole flight)
    end
  end
  for j = keep + 1, #shells do shells[j] = nil end
  for j = n + 1, #live do live[j] = nil end
  return live
end
N.shells_live = shells_live

-- the events, once a frame from 13_main: what changed since the last frame
local prev = {}
local function events(d, items, vit, goid)
  if goid ~= prev.goid then
    if prev.goid ~= nil and goid ~= nil then swap_start() end
    ease_reset('bar') ease_reset('charge') refill = nil
    for j = #shells, 1, -1 do shells[j] = nil end
    for i in pairs(landing) do landing[i] = nil end
    sweeps.mags = nil
    prev.goid, prev.value, prev.reserve, prev.hot = goid, nil, nil, nil
  end
  local t_now = now_s()
  if d and d.kind == 'ammo' and type(d.value) == 'number' then
    local same = prev.tid == d.tid and (prev.mode == d.mode or prev.mode == nil) and prev.ub == (d.underbarrel and true or false)
    if prev.value ~= nil then
      if d.value == 0 and prev.value > 0 then pulse('bar') end
      if d.value > prev.value + 1 and d.top and d.top > 1 then refill_start(prev.value, d.value) end
      -- (2.4.4) the orange turn (luka's pick): one flash as the ammo bar drops to a quarter and turns orange, as
      -- Flash once does for health — firing only (a reload, a switch, another mode never), and not to empty (the
      -- zero pulse is that one)
      local top = d.top
      local low = cfg.low_ammo or 0.25                     -- (2.4.5: F9 Low ammo at)
      if same and top and top > 0 and prev.top == top and d.value < prev.value and d.value > 0
         and d.value / top <= low and prev.value / top > low then pulse('bar', 'warn') end
      -- (2.4.4) a round loaded on its own: up by one as the reserve goes down by one, in the same read (the shown
      -- weapon is read whole). The Cookout's reload stage stays 0 while it loads (luka's 2026-11-04 logs: slot0 0>3,
      -- slot1 5>8 as its spare went 59>53, no stage), so the stage can't tell; a magazine's jump has the reserve down
      -- by one but the count up by many, the chamber's round after it no reserve change at all
      -- (2.4.5, luka: none on a weapon of one round, a launcher's rocket: its row and length its own, Shell loading)
      if d.value == prev.value + 1 and cfg.shell_load and same and d.top and d.top > 1 and type(d.reserve) == 'number'
         and type(prev.reserve) == 'number' and prev.reserve - d.reserve == 1 then
        shell_eject(prev.value, d.top or d.value, true)
      end
      local drop = prev.value - d.value
      if drop >= 1 and drop <= 3 and cfg.shell_flash and prev.tid == d.tid and (prev.mode == d.mode or prev.mode == nil) then
        local o = goid and N.objs and N.objs[goid]
        local t = chef.time()
        local inp = N.input
        if (o and o.fired_at and t - o.fired_at < 0.35) or (inp and inp.ok == true and t - (inp.last or -100) <= 0.4) then
          for i = d.value, prev.value - 1 do shell_eject(i, d.top or prev.value) end
        end
      end
    end
    prev.value, prev.tid, prev.mode, prev.top, prev.ub = d.value, d.tid, d.mode, d.top, d.underbarrel and true or false
    if type(d.reserve) == 'number' then
      if prev.reserve ~= nil and d.reserve == 0 and prev.reserve > 0 then pulse('mags') end
      -- (2.4.4) the resupply sweep (luka's pick): magazines topped up light in order, with the cream wash stamina
      -- has at full; the same weapon, the same magazines (not the underbarrel's after its switch)
      if prev.reserve ~= nil and same and d.reserve > prev.reserve then
        sweep_start('mags', prev.reserve, d.reserve, 0.2) pulse('mags', 'good')
      end
      prev.reserve = d.reserve
    end
  elseif d and d.kind == 'heat' then
    edge_pulse('bar', d.overheated == true, nil, 'hot')
  end
  if items then
    if prev.s ~= nil and items.s < prev.s then pulse('stims') end
    if prev.g ~= nil and items.g < prev.g then pulse('grenades') end
    prev.s, prev.g = items.s, items.g
    -- (2.4.4) the backpack's uses topped up (a pack counted in uses: the supply pack's 4, a launcher's rounds): lit
    -- in order with the cream wash, as the magazines; the same pack (its top unchanged), whole uses only
    local top = items.pack_top
    local segs = items.pack and top and top >= 2 and top <= 16 and top == math.floor(top)
    local n = segs and math.floor(items.pack + 0.5) or nil
    if n and prev.pack and prev.pack_top == top and n > prev.pack then sweep_start('pack', prev.pack, n, 0.2) pulse('pack', 'good') end
    prev.pack, prev.pack_top = n, top
  end
  -- (2.4.4) the charge mark (luka's pick): it brightens for a few frames as the charge crosses it
  if d and d.charge_mark and d.charge_frac and not d.reload_line then edge_pulse('chmark', d.charge_frac >= d.charge_mark, 'chmark', 'good')
  else edges.chmark = false end
  if vit and type(vit.st) == 'number' then
    edge_pulse('stamina', vit.st <= 0.02)
    edge_pulse('stamina_full', vit.st >= 0.995, 'stamina', 'good')   -- (1.5.58: and full again, luka's wish)
  end
end

N.ease, N.ease_reset, N.slide, N.slide_reset, N.bar_eased = ease, ease_reset, slide, slide_reset, bar_eased
N.pulse, N.pulse_k, N.pulsed, N.edge_pulse = pulse, pulse_k, pulsed, edge_pulse
-- (1.5.58) a pulse lights the whole bar, its empty part too (an empty stamina bar brightening its fill lit
-- nothing): a wash over the bar's box, 120 alpha at the pulse's peak (1.5.59: faintly red for something running
-- out, cream for stamina back to full; four fifths of 1.5.58's strength), drawn by the bars after their fill
local GLOW_A = 120
local function glow(key, x, y, w, h, L)
  local b = pulse_k(key)
  if b <= 0 then return end
  chef.rect(x, y, w, h, N.col(glow_col(key), GLOW_A * b), L + 3)
end
local function glow_k(key) return pulse_k(key) end
N.glow, N.glow_k, N.glow_col, N.GLOW_A = glow, glow_k, glow_col, GLOW_A
N.tick_lit, N.swap_k, N.motion_events, N.motion_scale = tick_lit, swap_k, events, scale
