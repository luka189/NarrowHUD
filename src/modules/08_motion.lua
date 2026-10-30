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
local function scale() return ({ [1] = 0, [2] = 1, [3] = 1.6 })[cfg.motion or 2] or 1 end
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
local function tick_lit(i, value)
  if i >= value then return false end
  local r = refill
  if not r or i < r.from then return true end
  local p = (now_s() - r.t0) / r.ms
  if p >= 1 then refill = nil return true end
  return i < r.from + (r.to - r.from) * p
end
-- the weapon swap: the new weapon's HUD from a third of its opacity to all of it over 100 ms
local swap_at = nil
local function swap_start() if scale() > 0 then swap_at = now_s() end end
local function swap_k()
  if not swap_at then return 1 end
  local p = (now_s() - swap_at) / (0.1 * scale())
  if p >= 1 then swap_at = nil return 1 end
  return 0.3 + 0.7 * out3(p)
end

-- the events, once a frame from 13_main: what changed since the last frame
local prev = {}
local function events(d, items, vit, goid)
  if goid ~= prev.goid then
    if prev.goid ~= nil and goid ~= nil then swap_start() end
    ease_reset('bar') ease_reset('charge') refill = nil
    prev.goid, prev.value, prev.reserve, prev.hot = goid, nil, nil, nil
  end
  if d and d.kind == 'ammo' and type(d.value) == 'number' then
    if prev.value ~= nil then
      if d.value == 0 and prev.value > 0 then pulse('bar') end
      if d.value > prev.value + 1 and d.top and d.top > 1 then refill_start(prev.value, d.value) end
    end
    prev.value = d.value
    if type(d.reserve) == 'number' then
      if prev.reserve ~= nil and d.reserve == 0 and prev.reserve > 0 then pulse('mags') end
      prev.reserve = d.reserve
    end
  elseif d and d.kind == 'heat' then
    edge_pulse('bar', d.overheated == true, nil, 'hot')
  end
  if items then
    if prev.s ~= nil and items.s < prev.s then pulse('stims') end
    if prev.g ~= nil and items.g < prev.g then pulse('grenades') end
    prev.s, prev.g = items.s, items.g
  end
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
