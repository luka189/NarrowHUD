-- NarrowHUD, throw lines (1.5.0): where a stratagem ball, a grenade or a C4 charge will fly while you aim it, as a
-- line in the world from your hand (the game hides it behind the ground, so it ends where the throw lands).
-- What's aimed:
--   * a stratagem ball: its hand pose (40; it's thrown by a press, so the line shows all the while it's in hand),
--     from the ball's own unit (STRAT_BALL) when one is found within reach of your Helldiver, else from your hand;
--   * a grenade: its hand pose (41; it comes out while its key is held and flies when it's let go);
--   * C4: its hand pose (42) in DEPLOY (aimed or not: a quick throw flies the same).
-- The throw: SPEED m/s, LIFT above the camera's pitch, let go UP metres above the hand (or the ball), plus CARRY
-- times your own speed along the aim (never across). THROW's numbers are first guesses (the stratagem ball's and
-- C4's as Stratagem and C4 Trajectory fitted them from its throws, Nexus 17945; the grenade's the ball's): the
-- research log records each throw's flight (the thrown unit's positions) so tools/fit_throws.py can fit ours.
-- The unit ids: the stratagem ball's as that mod found it; the grenades' and C4's from their resource paths in
-- filediver's hash list (BSD-3-Clause), hashed the engine's way.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, THROWABLE, input = N.cfg, N.THROWABLE, N.input

local G = 9.81
local STRAT_BALL = '16f397ca5f51f271'
local C4_CHARGE = '9b75217d8312dd67'           -- (content/fac_helldivers/equipment/backpacks/c4_charge_backpack/c4_charge)
local GRENADES = {}
for id in string.gmatch([[6002622114037024 db922a7afc42894b 46333fc9e3d4bd34 8e325c933e55bf62 2968deba6d6c2f09 075b19b068fb1045
  ee89cc10d80b6afb 14368dc8784220b0 1ff81c46cc79fd34 1b9ac59697006337 0080869506299773 4ce9eab785a79b7b 0416984f4922757b
  693028644d27ffef 6b11fc757618c57e 7686544f539bb9b7 dab81b0d80b511c7 04653ab33f3ffb44 eb725c39fc38b87c e49a5ae078aad407
  a20683199dfc19e8 ee4c107b941ab7f4 5c14f27759dd3be0 2d398d1ec35e0838 5de8fd02a05b4b0a c5c05fcb5747c799 3fa94f58f596bc0b
  032489cf1d439bba f7b35a9c5ae340b6 03f31caf3a7d8f4e
  c5d0281e9dc848ef 02a13a2d0219d2e0 e2fd67303a498579 1b7138529f0e2b05 b881838c5e67f32e 8a1ef2d98178b97a
  f83cf0fa71370cf3 d865e969f6d8f4cd 07e8d82ee143de70]], '%x+') do GRENADES[id] = true end
-- (the last nine are guesses at paths not in the list: thermite, stun, seeker, pyrotech, drone, cluster, urchin,
-- disruptor grenades; a grenade whose flight the research log never records is one whose unit isn't known yet)
-- (the 1.5.1 and 1.5.2 logs, 35 throws fitted by tools/fit_throws.py, standing throws: the ball 20.7-20.8 m/s and
-- 6.5-9.5 degrees, C4 22 m/s and 4-5.6 degrees, grenades 20-22 m/s and 4-11 degrees)
-- (1.5.7: the ball is let go about half a metre above where it's held while you aim (the arm swings up), a degree
-- or so above the camera's line plus 4.5: a tester's screenshots and the 1.5.6 log's flights against the line as
-- drawn while aiming. 1.5.4's "up 0" came from comparing flights with the line at the moment of the throw, when
-- the arm was already up: the wrong line to compare with)
-- (1.5.8: ten more ball throws against the line as drawn while aiming, fitted together: 20.3 m/s, 5.8 degrees, let
-- go 0.9 m above the held ball)
local THROW = {
  ball = { speed = 20.3, lift = math.rad(5.8), up = 0.9 },
  c4 = { speed = 22.5, lift = math.rad(5), up = 1.0 },
  grenade = { speed = 21, lift = math.rad(8), up = 0.4 },
}
local CARRY, CARRY_MOST = 1.4, 3                  -- your speed along the aim carried into the throw
local STEP, MOST_T, DEEPEST = 0.03, 6, 15         -- the flight: 0.03 s a segment, 6 s or 15 m under your feet at most
local REACH, REACH_LOW, REACH_HIGH = 1.5, -0.5, 2.5   -- a ball in hand: this close to your Helldiver's feet

local kinds = { [STRAT_BALL] = true, [C4_CHARGE] = true }
for id in pairs(GRENADES) do kinds[id] = true end
local watch = chef.watch and chef.watch(kinds, 0.5) or nil
local hand_of = { u = nil, node = nil }
local BALL_GRIP = 40
local ball_said = nil
local trail = {}                                  -- your feet: { t, x, y, z } over the last 0.15 s
local function my_speed(now)
  local a, b = trail[1], trail[#trail]
  if not (a and b and b[1] - a[1] > 0.02) then return 0, 0 end
  local dt = b[1] - a[1]
  return (b[2] - a[2]) / dt, (b[3] - a[3]) / dt
end
-- the thrown things near you: the ball in your hand, and (research) what flies after a throw
local flights = {}                                -- unit -> { kind, t0, pts }
local said = 0
local function ball_in_hand(u, fx, fy, fz)
  if not watch or not watch.items then return nil end
  for _, it in ipairs(watch.items) do
    if chef.unit_kind(it.unit) == STRAT_BALL and chef.unit_alive(it.unit) then
      local x, y, z = chef.unit_position(it.unit)
      if x and fx then
        local d = math.sqrt((x - fx) ^ 2 + (y - fy) ^ 2)
        if d <= REACH and z - fz >= REACH_LOW and z - fz <= REACH_HIGH then return it.unit, x, y, z end
      end
    end
  end
  return nil
end
-- research: each thrown unit's flight for 2.5 s after it appears, logged as one line, with the aim at the throw
local aim_log = nil                               -- { kind, pitch, speed, t } of the last aim, for the flight's line
local aim_hist = {}                               -- the aims of the last half second
local function research_flights(now, fx, fy, fz)
  if not cfg.research or not watch or not watch.items or said >= 300 then return end
  for _, it in ipairs(watch.items) do
    local u = it.unit
    if chef.unit_alive(u) and not flights[u] then
      local kind = chef.unit_kind(u)
      local x, y, z = chef.unit_position(u)
      -- (a ball in hand isn't a flight; one of the map's far away isn't either)
      local near = x and fx and (x - fx) ^ 2 + (y - fy) ^ 2 <= 100
      local held = kind == STRAT_BALL and x and fx and (x - fx) ^ 2 + (y - fy) ^ 2 <= REACH * REACH
      if near and not held then flights[u] = { kind = kind, t0 = now, pts = {}, aim = aim_log } end
    end
  end
  for u, f in pairs(flights) do
    -- (a grenade is a unit from the moment it's in hand, a few seconds before it flies: recorded until 2 s after it
    -- started moving fast, or 12 s; the 1.5.3 log cut grenade flights off 2.5 s after the unit appeared)
    local alive = chef.unit_alive(u)
    if alive and (f.flying and now - f.flying <= 10 or (not f.flying and now - f.t0 <= 12)) then
      -- (1.5.50: the samples for 2 s of flight, then watched until the unit goes, for each kind's fuse)
      local x, y, z = chef.unit_position(u)
      if x and (not f.flying or now - f.flying <= 2) and (#f.pts == 0 or now - f.pts[#f.pts][1] >= 0.05) then
        local lp = f.pts[#f.pts]
        if lp and not f.flying and now > lp[1] then
          local sp = math.sqrt((x - lp[2]) ^ 2 + (y - lp[3]) ^ 2 + (z - lp[4]) ^ 2) / (now - lp[1])
          if sp > 8 then
            f.flying = now
            -- (the aim as drawn 0.4 s before the throw, else the latest)
            f.aim = aim_log
            for _, e in ipairs(aim_hist) do if now - e.t >= 0.4 then f.aim = e end end
          end
        end
        f.pts[#f.pts + 1] = { now, x, y, z }
      end
    elseif not f.done then
      f.done = true
      said = said + 1
      local l = {}
      local from = f.flying and f.flying - 0.3 or f.t0
      for _, p in ipairs(f.pts) do
        if p[1] >= from then l[#l + 1] = string.format('%.2f:%.2f,%.2f,%.2f', p[1] - f.t0, p[2], p[3], p[4]) end
      end
      local a = f.aim
      local fuse = f.flying and (alive and string.format('still there at %.1f s', now - f.flying) or string.format('gone after %.2f s', now - f.flying)) or 'never flew'
      log('research: throw flight: %s %s; aim %s%s pitch %.3f lift %.3f speed %.1f at %.2f s before from %s; feet %s; armour %s; %s; %s', f.kind,
        GRENADES[f.kind] and 'grenade' or (f.kind == STRAT_BALL and 'ball' or (f.kind == C4_CHARGE and 'C4' or '?')),
        a and a.kind or 'none', a and (a.aiming and ' (aimed)' or ' (quick)') or '', a and a.pitch or 0, a and a.lift or 0, a and a.speed or 0, a and ((f.flying or f.t0) - a.t) or 0,
        a and string.format('%.2f,%.2f,%.2f', a.x, a.y, a.z) or '?',
        fx and string.format('%.2f,%.2f,%.2f', fx, fy, fz) or '?', tostring(N.state8 and N.state8.armor) .. ((N.armour_up and select(2, N.armour_up('c4'))) and (' ' .. select(2, N.armour_up('c4'))) or ''), fuse, table.concat(l, ' '))
    end
  end
  if said >= 300 then log('research: throw flights: 300 logged, no more this session') end
end
-- The throw-range armour passives (1.5.16): Servo-Assisted throws 30 % farther, Desert Stormer 20 % (the Helldivers
-- wiki; HD2Runtime's armour passive catalog: throw_range x1.3 and x1.2). The armours, by the id your player object's
-- armor_set holds (HD2Runtime's armour catalogue, as the stim timer's Med-Kit list). The game reaches the range with a
-- faster throw, more than the square root of the range bonus: Stratagem and C4 Trajectory (Nexus 17945) measured the
-- ball 1.2x and C4 1.3x with Servo-Assisted, 1.1x and 1.2x with Desert Stormer; those were the first numbers
-- here. Our own fit (tools/fit_throws.py on luka's 2026-10-29 log, Servo-Assisted, 21 throws): the ball 26.7 to
-- 26.9 m/s against its 20.3 (1.32x, not 1.2: the drawn line fell 1.4 m short at 30 m), C4 28.8 to 29.1 against
-- 22.5 (1.29x), one grenade 29.2 against 21 (1.39x, one throw: kept at 1.3). So Servo-Assisted is 1.3 on
-- everything, as the passive says. Desert Stormer (luka's 2026-10-30 log, 11 balls, 12 C4, 7 grenades), read as
-- the speed each throw needs at the lift drawn (a fit's own speed and pitch trade off; 1.5.46 read the speeds alone
-- and put the grenade at 1.25): the ball 24.6 against 22.3 drawn at 1.1 → 1.2; C4 26.6 against 27.0 → 1.2; the
-- grenades 25.3 against 25.2 → 1.2. And 15 grenades with no passive need 21.1–21.2 at the drawn lift: 21 holds.
local SERVO, STORMER = {}, {}
for id in string.gmatch('dae4a744 f2b7d3f5 3c3ebaf0 537e8e45 14209e3a 7346edc6 0b5cd386', '%x+') do SERVO[id] = true end
for id in string.gmatch('c60c706d 4a545f06 0ade6719', '%x+') do STORMER[id] = true end
local THROW_UP = { ball = { 1.3, 1.2 }, c4 = { 1.3, 1.2 }, grenade = { 1.3, 1.2 } }   -- { Servo-Assisted, Desert Stormer }
local function armour_up(kind)
  local a = N.state8 and N.state8.armor
  local up = THROW_UP[kind]
  if not (a and up) then return 1, nil end
  if SERVO[a] then return up[1], 'Servo-Assisted' end
  if STORMER[a] then return up[2], 'Desert Stormer' end
  return 1, nil
end
N.armour_up = armour_up
-- the arc, from the release point along the throw
-- (1.5.49) each grenade kind its own throw, by the thrown unit's kind: the game says which grenade you carry only
-- through the unit it makes, and the grenade is a unit from the moment it's in hand, at the hand. The one in your
-- hand (within HAND_REACH of the hand node, seen in the last 0.6 s) names the kind drawn; none there, the standard
-- grenade's line (1.5.50; 1.5.49 took any grenade unit within 10 m, which a mine lying at your feet would be).
-- The kinds with throws of their own (luka's 2026-10-30 session, tools/fit_throws.py: the Melta Mine and the Giga
-- against the grenade line as drawn, "needed at the drawn lift"; the mines thrown at pose 40 from their own fit, the
-- lift and speed together): { speed, lift, up }; a kind not here throws as THROW.grenade (the Thermite, Impact,
-- Stun, Throwing Knife and Dynamite all fitted at the grenade's 21 m/s). HUDdle's table (HUD Ballistic Trajectory
-- Overlay's measurements) has the Giga 16.6, the Melta 10.6, the Caltrops, Lure and Shield 10.0: ours agree but the
-- Melta's. The hand poses: 40 the mines (the ball's pose, told apart by the grenade unit in hand), 41 the standard
-- grenades, 42 the Melta Mine and the Giga (underhand, the C4 detonator's pose, told apart by no C4 shown).
local GRENADE_KINDS = {
  ['ee4c107b941ab7f4'] = { speed = 10.7, lift = math.rad(8), up = 0.4 },     -- the Melta Mine (11 throws, 10.0-11.4)
  ['46333fc9e3d4bd34'] = { speed = 15.6, lift = math.rad(8), up = 0.4 },     -- the Giga (5 throws, 14.9-16.0)
  ['2968deba6d6c2f09'] = { speed = 10, lift = math.rad(4), up = 0.4 },       -- Caltrops (14 throws, median range miss 0.7 m)
  ['a20683199dfc19e8'] = { speed = 10, lift = math.rad(4), up = 0.4 },       -- the Lure Mine (8 throws, 0.1 m)
  ['1b9ac59697006337'] = { speed = 10, lift = math.rad(4), up = 0.4 },       -- the Shield (6 throws, 0.3 m)
}
local GRENADE_NAMES = {
  ['ee4c107b941ab7f4'] = 'Melta Mine', ['46333fc9e3d4bd34'] = 'Giga', ['2968deba6d6c2f09'] = 'Caltrops',
  ['a20683199dfc19e8'] = 'Lure Mine', ['1b9ac59697006337'] = 'Shield', ['c5c05fcb5747c799'] = 'Thermite',
  ['7686544f539bb9b7'] = 'Impact', ['0080869506299773'] = 'Stun', ['f7b35a9c5ae340b6'] = 'Throwing Knife',
  ['14368dc8784220b0'] = 'Dynamite', ['5c14f27759dd3be0'] = 'a standard grenade', ['4ce9eab785a79b7b'] = 'a standard grenade',
}
N.GRENADE_KINDS, N.GRENADE_NAMES = GRENADE_KINDS, GRENADE_NAMES
local HAND_REACH = 0.8                            -- a grenade this close to the hand node is the one in hand
local last_kind = nil                             -- the kind of the last grenade seen in hand
local in_hand_at = -100                           -- when one was last seen there
local kind_at = 0
local function grenade_kind_step(now, hx, hy, hz, grip)
  -- (every 0.1 s while a throw pose is up, so the kind is confirmed within a frame or two of it; else every 0.5 s)
  local every = (grip == 40 or grip == 41 or grip == 42) and 0.1 or 0.5
  if not watch or not watch.items or not hx or now - kind_at < every then return end
  kind_at = now
  for _, it in ipairs(watch.items) do
    local k = it.kind or (chef.unit_kind and chef.unit_kind(it.unit))
    if k and GRENADES[k] and chef.unit_alive(it.unit) then
      local x, y, z = chef.unit_position(it.unit)
      if x and (x - hx) ^ 2 + (y - hy) ^ 2 + (z - hz) ^ 2 <= HAND_REACH * HAND_REACH then
        in_hand_at = now
        if k ~= last_kind then
          last_kind = k
          if cfg.research then
            log('research: the grenade in hand (by its unit): %s (%s)%s', k, GRENADE_NAMES[k] or 'not named yet',
              GRENADE_KINDS[k] and ', its own throw' or ', thrown as the standard grenade')
          end
        end
        return
      end
    end
  end
end
local function grenade_in_hand(now) return now - in_hand_at <= 0.6 and last_kind or nil end
N.grenade_kind = function() return last_kind end
N.grenade_in_hand = grenade_in_hand
-- (1.5.56) The kind drawn from the first frame of a throw pose, not from the frame the unit is seen in the hand (luka:
-- the wrong line for a fraction of a second at every throw): you carry one grenade kind a mission, so the last one
-- seen in hand is the one now, until the unit says otherwise. At the ball's pose (40), where the mines also come
-- out: the unit in hand decides; before it's seen, a stratagem input within 3 s before the pose began means a
-- ball, else the last kind if it's one thrown at that pose; else a ball.
local POSE40_KINDS = { ['2968deba6d6c2f09'] = true, ['a20683199dfc19e8'] = true, ['1b9ac59697006337'] = true }
local pose40 = { at = nil, ball = true }
local function kind_now(grip, now)
  local held = grenade_in_hand(now)
  if held then return held end
  if grip == 41 or grip == 42 then return last_kind end
  if grip == 40 then
    local st8 = N.state8
    if pose40.at == nil then
      pose40.at = now
      pose40.ball = not (last_kind and POSE40_KINDS[last_kind]) or (st8 and st8.strat_at and now - st8.strat_at < 3) or false
    end
    if not pose40.ball then return last_kind end
  end
  return nil
end
local function draw_arc(kind, ox, oy, oz, cam, now, feet_z, gk)
  local p = THROW[kind]
  if kind == 'grenade' and gk and GRENADE_KINDS[gk] then p = GRENADE_KINDS[gk] end
  local fh = math.sqrt(cam.fx * cam.fx + cam.fy * cam.fy)
  if fh < 1e-4 then return end
  local hx, hy = cam.fx / fh, cam.fy / fh
  local pitch = math.atan2(cam.fz, fh) + p.lift
  local mx, my = my_speed(now)
  local carried = math.max(-CARRY_MOST, math.min(CARRY_MOST, CARRY * (mx * hx + my * hy)))
  local speed = p.speed * armour_up(kind) + carried
  -- (an aimed throw (the aim button held) and a quick one differ a little: a tester's 1.5.3 round had quick grenade
  -- throws 0.2 m past the line over 25 m)
  if kind == 'grenade' and not input.aiming then speed = speed * 1.004 end
  -- (the aim as drawn: kept for half a second, so a flight is compared with the line as it was while aiming, not
  -- with the one at the throw itself, when the arm has already swung up)
  local entry = { kind = kind, pitch = pitch, lift = p.lift, speed = speed, t = now, x = ox, y = oy, z = oz + p.up, aiming = input.aiming }
  aim_hist[#aim_hist + 1] = entry
  while #aim_hist > 1 and now - aim_hist[1].t > 0.5 do table.remove(aim_hist, 1) end
  aim_log = entry
  N.last_aim = entry
  local vx, vy, vz = hx * speed * math.cos(pitch), hy * speed * math.cos(pitch), speed * math.sin(pitch)
  local x, y, z = ox, oy, oz + p.up
  local c = N.col(N.CREAM, 170)
  local lines = cfg.drop_thick or 2
  local crx, cry = cam.fy, -cam.fx
  local cl = math.sqrt(crx * crx + cry * cry)
  if cl < 1e-4 then lines = 1 else crx, cry = crx / cl, cry / cl end
  local n, t = 0, 0
  local floor = (feet_z or z) - DEEPEST
  while t < MOST_T and z > floor do
    local nx, ny, nz = x + vx * STEP, y + vy * STEP, z + (vz - G * STEP / 2) * STEP
    vz = vz - G * STEP
    for k = 1, lines do
      local o = 0.0012 * (k - (lines + 1) / 2)
      local d1 = math.sqrt((x - cam.x) ^ 2 + (y - cam.y) ^ 2 + (z - cam.z) ^ 2) * o
      local d2 = math.sqrt((nx - cam.x) ^ 2 + (ny - cam.y) ^ 2 + (nz - cam.z) ^ 2) * o
      chef.line(x + crx * d1, y + cry * d1, z, nx + crx * d2, ny + cry * d2, nz, c)
      n = n + 1
    end
    x, y, z, t = nx, ny, nz, t + STEP
  end
  -- (1.5.6 to 1.5.12 had an end mark where the arc came down to the feet's height: of no use on the game's slopes)
  N.drop_lines = (N.drop_lines or 0) + n
end
-- every frame: the aim, if any, and its line
local function throw_step(now, grip, shown)
  if not chef.line or not chef.camera then return end
  local u = N.my_unit and N.my_unit()
  local fx, fy, fz
  if u then fx, fy, fz = chef.unit_position(u) end
  if fx then
    trail[#trail + 1] = { now, fx, fy, fz }
    while #trail > 2 and now - trail[2][1] >= 0.15 do table.remove(trail, 1) end
  else
    trail = {}
  end
  research_flights(now, fx, fy, fz)
  if not cfg.throw_line then return end
  local cam = chef.camera()
  if not cam or not cam.fx then return end
  -- the hand's position (else right of your chest)
  local hx, hy, hz
  if u and chef.unit_node then
    if hand_of.u ~= u then hand_of.u, hand_of.node = u, chef.unit_node(u, 'attach_hand_r') end
    if hand_of.node then hx, hy, hz = chef.unit_position(u, hand_of.node) end
  end
  if not hx and fx then hx, hy, hz = fx, fy, fz + 1.3 end
  if not hx then return end
  grenade_kind_step(now, hx, hy, hz, grip)
  if grip ~= BALL_GRIP then pose40.at = nil end
  local gk = kind_now(grip, now)
  -- the hand poses (the 1.5.1 log): 40 a stratagem ball, 41 a grenade. The ball's own unit, when it's found in
  -- reach, is where its throw starts; else the hand (1.5.1 never found it in the hand: research below)
  if grip == BALL_GRIP and gk then
    -- (1.5.50) the mines (Caltrops, the Lure, the Shield) come out at the ball's pose: the grenade unit in the hand
    -- tells them from a stratagem ball (1.5.56: or the last kind, when no stratagem input came before the pose)
    draw_arc('grenade', hx, hy, hz, cam, now, fz, gk)
  elseif grip == BALL_GRIP then
    local ball, bx, by, bz = ball_in_hand(u, fx, fy, fz)
    if cfg.research and now - (ball_said or -100) >= 1 then
      ball_said = now
      local l = {}
      for _, it in ipairs(watch and watch.items or {}) do
        if chef.unit_kind(it.unit) == STRAT_BALL then
          local x, y, z = chef.unit_position(it.unit)
          l[#l + 1] = x and fx and string.format('%.2f across, %.2f up', math.sqrt((x - fx) ^ 2 + (y - fy) ^ 2), z - fz) or 'no position'
        end
      end
      log('research: ball pose: %d ball units (%s), hand %s, fire %s', #l, table.concat(l, '; '),
        hx and string.format('%.2f across, %.2f up', math.sqrt((hx - fx) ^ 2 + (hy - fy) ^ 2), hz - fz) or '?', tostring(input.down))
    end
    -- (the ball is thrown by a press, not let go from a hold: the 1.5.2 log read fire up the whole time the ball was
    -- in hand, so the line shows all the while)
    if ball then draw_arc('ball', bx, by, bz, cam, now, fz) else draw_arc('ball', hx, hy, hz, cam, now, fz) end
  elseif grip and THROWABLE[grip] then
    draw_arc('grenade', hx, hy, hz, cam, now, fz, gk)
  elseif shown and shown.mode and string.find(shown.mode, 'DEPLOY', 1, true) then
    draw_arc('c4', hx, hy, hz, cam, now, fz)
  elseif grip == 42 and gk then
    -- (1.5.57: also while the weapon in hand is still shown by 13_main's two-second hold through a pose with no
    -- weapon on it — luka's quick Melta throws drew nothing for those two seconds. A C4 in hand is the branch above)
    -- (1.5.49) pose 42 with no C4 in hand: the underhand throw of a Melta Mine or a Giga (luka's 2026-10-30 log:
    -- their flights at pose 42, the Caltrops' at 40), its grenade kind known from the unit in the hand (1.5.56: or
    -- the last kind seen there)
    draw_arc('grenade', hx, hy, hz, cam, now, fz, gk)
  end
end
N.throw_step = throw_step
