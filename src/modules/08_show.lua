-- NarrowHUD, show (1.5.60): when each part is on the screen. Every Show row in F9 is a rule for its part: Off,
-- Always, While not full, On a change (for show_secs after the part's own value moved), While aiming, or one of
-- the two joined with aiming (either calls it up). The text parts (the modes, the rate of fire, the icons) have no
-- "full": theirs are Off, Always, On a change, While aiming, A change or aiming. A part a rule holds back isn't
-- switched off: in the layouts it keeps its place (the pins don't reflow: luka, "too much movement without
-- reason") and fades out, or dims to a quarter ("Show: a part its rule holds back is": Hidden / Dimmed); Under and
-- Beside hide it (their parts have fixed places anyway). Off collapses it, as before.
-- Rule numbers (cfg.vis[part]): 1 off, 2 always, 3 not full, 4 change, 5 aiming, 6 not full or aiming, 7 change or
-- aiming; a text part's row maps its five choices onto 1, 2, 4, 5, 7.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg = N.cfg

local PARTS = { 'bar', 'count', 'mags', 'charge', 'mode', 'fmode', 'rpm', 'icons', 'stims', 'grenades', 'pack', 'health', 'stamina' }
local state = {}                                   -- part -> { sig, changed_at, not_full }
for _, p in ipairs(PARTS) do state[p] = { changed_at = -100, not_full = false } end
local most = { stims = 0, grenades = 0 }           -- the most stims / grenades seen this session (the "full")
local mags_top = {}                                -- the most spare magazines seen, per weapon type
local showing, alpha = {}, {}                      -- part -> drawn at all (over 0.01); part -> the eased factor
N.showing, N.part_alpha = showing, alpha

local function note(part, sig, not_full, now)
  local st = state[part]
  if sig ~= st.sig then st.sig, st.changed_at = sig, now end
  not_full = not_full and true or false
  if st.not_full and not not_full then st.full_at = now end   -- (just full: "while not full" lingers a second, so the full flash shows)
  st.not_full = not_full
end
-- once a frame, before the draws: what each part shows now, and whether it's "full"
local function track(d, items, vit, now)
  if d and d.kind ~= 'none' then
    local tid = d.tid or '?'
    local ammo = d.kind == 'ammo'
    note('bar', tostring(d.value) .. '/' .. tostring(d.top) .. tid, ammo and (d.top and d.value and d.value < d.top) or (not ammo and (d.value or 0) > 0), now)
    note('count', tostring(d.value) .. tid, state.bar.not_full, now)
    if type(d.reserve) == 'number' then
      if d.reserve > (mags_top[tid] or 0) then mags_top[tid] = d.reserve end
      note('mags', tostring(d.reserve) .. tid, d.reserve < (mags_top[tid] or 0), now)
    else note('mags', 'none' .. tid, false, now) end
    local cf = d.charge_frac
    note('charge', cf and (math.floor(cf * 20) .. tid) or ('none' .. tid), cf ~= nil and cf > 0 and cf < 1, now)
    note('mode', tostring(d.mode) .. tostring(d.ub_label) .. tid, false, now)
    note('fmode', tostring(d.fmode) .. tostring(d.zoom) .. tid, false, now)
    note('rpm', tostring(d.setting) .. tid, false, now)
    note('icons', tostring(d.mode) .. tostring(d.fmode) .. tostring(d.zoom) .. tostring(d.ub_label) .. tid, false, now)
  end
  if items then
    if (items.s or 0) > most.stims then most.stims = items.s end
    if (items.g or 0) > most.grenades then most.grenades = items.g end
    note('stims', items.s, (items.s or 0) < most.stims, now)
    note('grenades', items.g, (items.g or 0) < most.grenades, now)
    local pf = nil
    if items.warp then pf = 1 - items.warp / 78
    elseif items.recharge then pf = items.recharge
    elseif items.pack and items.pack_top and items.pack_top > 0 then pf = items.pack / items.pack_top end
    note('pack', pf and math.floor(pf * 100) or 'none', pf ~= nil and pf < 0.999, now)
  end
  if vit then
    note('health', vit.hp, vit.hp ~= nil and vit.max and vit.hp < vit.max - 0.5, now)
    note('stamina', vit.st and math.floor(vit.st * 100) or nil, vit.st ~= nil and vit.st < 0.995, now)
  end
end
-- the rule: is the part called for now?
local function want(part, now)
  local mode = cfg.vis and cfg.vis[part] or 2
  if mode == 1 then return false end
  if mode == 2 then return true end
  local st = state[part]
  local aim = N.aim_now == true
  local changed = now - st.changed_at < (cfg.show_secs or 4)
  local not_full = st.not_full or (st.full_at ~= nil and now - st.full_at < 1)
  if mode == 3 then return not_full end
  if mode == 4 then return changed end
  if mode == 5 then return aim end
  if mode == 6 then return not_full or aim end
  return changed or aim
end
-- once a frame: the eased factor per part (1 called for; else 0, or a quarter when dimmed)
local function step(d, items, vit, now)
  track(d, items, vit, now)
  local rest = (cfg.show_rest or 1) == 2 and 0.25 or 0
  for _, p in ipairs(PARTS) do
    local on = want(p, now)
    local a = N.ease('vis:' .. p, on and 1 or rest, 150)
    alpha[p] = a
    showing[p] = a > 0.01
  end
end
-- a layout element's factor (the modes element shows both mode words: the stronger of the two rules)
local EL_PART = { bar = 'bar', count = 'count', mags = 'mags', charge = 'charge', mode1 = 'mode', mode2 = 'fmode', rpm = 'rpm',
  icon1 = 'icons', icon2 = 'icons', zoom = 'fmode', zoomicon = 'icons', stims = 'stims', grenades = 'grenades', pack = 'pack', health = 'health', stamina = 'stamina' }
local function el_alpha(id)
  if id == 'health' or id == 'stamina' then return 1 end   -- (through vit.show_h / show_s)
  local p = EL_PART[id]
  return p and alpha[p] or 1
end
N.show_step, N.show_want, N.el_alpha, N.EL_PART = step, want, el_alpha, EL_PART
