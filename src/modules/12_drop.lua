-- NarrowHUD, the drop line (1.4.0): where the shot of the weapon in hand goes, as a line in the world from your
-- view along the crosshair, bending down with the projectile's drop, with a mark every 50 m. For weapons whose shot
-- drops by half a metre or more over 100 m (grenade launchers, the Recoilless, the Epoch, the crossbow ...);
-- rifles and lasers get none.
-- The projectile: BALLISTICS (src/ballistics_generated.lua, tools/make_ballistics.py): speed, mass, drag and
-- gravity factors from the Helldivers 2 wiki, the diameter from HD2Runtime's catalogue. The flight as the game's
-- spawn code has it (HD2Runtime's notes): gravity 9.81 x the factor; the drag deceleration k v^2 / m with
-- k = pi/2 x r^2 x 1.2 (air) x drag, r the radius in metres. The shot starts at your Helldiver's right hand (the
-- unit's attach_hand_r node, as Integrated HUD finds the weapon model) and goes where the crosshair looks (the point
-- CONVERGE metres along the camera's line); when the hand can't be asked, from the view itself.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, input = N.cfg, N.input

local G = 9.81
-- The flight's step: the game seems to step its projectiles once a frame (a grenade flew about 2.5 % further than a
-- 60-a-second step said and about as much shorter than an exact flight: the 1.4.2 and 1.4.3 logs), so a plain step
-- at 120 a second, near the middle
local STEP = 1 / 120
local POINT_EVERY = 4                             -- metres of path between the line's points ...
local TURN = 0.05                                 -- ... or sooner, once the flight has turned this much (radians: a
                                                  -- steep lob's first metres looked broken, the 1.4.2 log)
local MUZZLE = 0.25                               -- metres from the hand node to the muzzle, along the shot
local HAND_LEFT = 0.1                             -- the shot starts a hand's width left of the hand node (as seen)
-- (from the hand: the first metres are of no use, and any mismatch with the muzzle shows there: 7 m out (2.1.4,
-- luka: never earlier than 7; 10 before), 3 m for the Ultimatum's lob (its whole curve is in the first metres).
-- 2.4.12, luka: with the Solid look the line can start closer — 3 m for every weapon, as the throws; and the
-- blast zone is then looked for from 3 m too, the Crossbow's showed no nearer than 11 m with the line from 7)
local function start_hand(b) return 3 end
local CONVERGE = 100                              -- metres along the camera's line where the shot is taken to go
local hand_of = { u = nil, node = nil }

-- the flight of one projectile from (0, 0, 0) along a unit direction (dx, dy, dz): the points every POINT_EVERY
-- metres of path, up to len metres of path or 24 s; cached per type and direction's pitch (the path only depends
-- on the pitch, so the cache holds one flight per weapon per 0.5 degree of pitch)
local function fly(b, pitch, len)
  local r = b.d * 0.0005
  local k = math.pi / 2 * r * r * 1.2 * b.drag
  local m = b.m * 0.001
  local g = G * b.g
  local cp, sp = math.cos(pitch), math.sin(pitch)
  local x, z = 0, 0                               -- along the horizontal of the aim, and up
  local vx, vz = b.v * cp, b.v * sp
  local pts, path, next_pt, t = {}, 0, 0, 0
  local first = start_hand(b)
  local dir_at = math.atan2(vz, vx)                -- the flight's direction at the last point
  -- (24 s, not 8 (1.5.40): a grenade launcher's round at 100 m/s has 218 m of path in 8 s, so "Drop line length
  -- 300" stopped at 218 for every launcher, a Nexus report; the flight is cached per half degree, so the extra
  -- steps cost nothing a frame)
  while path < len and t < 24 do
    local dir = math.atan2(vz, vx)
    if path >= next_pt or (#pts > 1 and math.abs(dir - dir_at) >= TURN) then
      pts[#pts + 1] = { x, z, path }
      dir_at = dir
      next_pt = #pts == 1 and first or (path + POINT_EVERY)   -- (a point where the line starts, then every 4 m or turn)
    end
    local speed = math.sqrt(vx * vx + vz * vz)
    local a = speed > 0 and k * speed / m or 0
    vx = vx - a * vx * STEP
    vz = vz - a * vz * STEP - g * STEP
    local nx, nz = x + vx * STEP, z + vz * STEP
    local d = math.sqrt((nx - x) ^ 2 + (nz - z) ^ 2)
    -- (2.4.12) the last point at the length exactly, not up to a step (0.8 m at 100 m/s) past it: the flights are
    -- blended between neighbouring half degrees (flight_of), and an end that overshot by a different amount each
    -- made the line's end jump at every half degree
    if path + d >= len and d > 0 then
      local f = (len - path) / d
      x, z, path = x + (nx - x) * f, z + (nz - z) * f, len
      break
    end
    path = path + d
    x, z, t = nx, nz, t + STEP
  end
  pts[#pts + 1] = { x, z, path }
  return pts
end
-- the drop over 100 m of level flight, once per type: under half a metre, no line
local drop100 = {}
local NO_LINE = { c7dfd9eb = true, ['1d3b01d7'] = true }   -- (2.4.12, luka: the Verdict's and the Re-Educator's lines got in the way)
-- (2.4.14, luka) the Recoilless and the EAT keep their line but get no landing mark and no blast zone: aimed at an
-- enemy, the mark landed on the ground behind it and got in the way of the aim, and their blast hardly matters
local NO_MARK = { b2bfd847 = true, ['6ec2a850'] = true }
local function drops(tid)
  if NO_LINE[tid] then return false end
  local v = drop100[tid]
  if v ~= nil then return v end
  local b = BALLISTICS[tid]
  v = false
  if b and b.v > 0 and b.g > 0 then
    local pts = fly(b, 0, 100)
    local last = pts[#pts]
    v = last[3] >= 99 and -last[2] >= 0.5 or (last[3] < 99)   -- (or the shot doesn't even reach 100 m)
  end
  drop100[tid] = v
  return v
end
-- (2.4.12, luka: "the line jumps up in increments, side to side it's smooth") the flight was cached per half degree
-- of pitch, so pitching the aim moved the line in half-degree steps. Now the two flights either side of the pitch
-- (cached, a few kept) are blended by where the pitch sits between them, each point of the lower one matched to the
-- upper one at the same path. A flight is one fly() per half degree as before; the blend is a walk over 40 points
local cache = { tid = nil, len = nil, flights = {}, out = {}, at = nil }
local function flight_key(tid, key, len)
  local f = cache.flights[key]
  if not f then
    f = fly(BALLISTICS[tid], key / 114.6, len)
    cache.flights[key] = f
    cache.n = (cache.n or 0) + 1
    if cache.n > 12 then cache.flights, cache.n = { [key] = f }, 1 end   -- (a dozen half degrees kept)
  end
  return f
end
local function flight_of(tid, pitch, len)
  if cache.tid ~= tid or cache.len ~= len then cache.tid, cache.len, cache.flights, cache.n, cache.at = tid, len, {}, 0, nil end
  local q = pitch * 114.6
  local k = math.floor(q)
  local f = q - k
  if cache.at == q then return cache.out end
  cache.at = q
  local A, B = flight_key(tid, k, len), flight_key(tid, k + 1, len)
  local out = cache.out
  local j = 1
  for i = 1, #A do
    local a = A[i]
    local s = a[3]
    -- B's point at path s: the pair of B's points around it (B's paths rise with i)
    while j < #B and B[j + 1][3] < s do j = j + 1 end
    local b1, b2 = B[j], B[math.min(#B, j + 1)]
    local bx, bz
    if b2 == b1 or b2[3] <= b1[3] then bx, bz = b2[1], b2[2]
    else
      local t = (s - b1[3]) / (b2[3] - b1[3])
      if t < 0 then t = 0 elseif t > 1 then t = 1 end
      bx, bz = b1[1] + (b2[1] - b1[1]) * t, b1[2] + (b2[2] - b1[2]) * t
    end
    local o = out[i]
    if not o then o = {} out[i] = o end
    o[1], o[2], o[3] = a[1] + (bx - a[1]) * f, a[2] + (bz - a[2]) * f, s
  end
  for i = #A + 1, #out do out[i] = nil end
  return out
end
-- (2.1.1, luka: the Verdict's and the Recoilless's lines began right by the hand with no drop to show) where the
-- line starts: the path at which the shot, fired level, has fallen cfg.drop_from centimetres below the straight aim
-- (0: the hand's 10 m). Level, once per weapon and setting, so the start doesn't wander with the aim (2.1.2, luka:
-- per pitch it moved as he aimed); the drop at a pitch differs a little, which is fine for a start
local dstart = { tid = nil, cm = nil, len = nil, path = 0 }
local function drop_start(tid, len)
  local cm = cfg.drop_from or 0
  if cm <= 0 then return 0 end
  if dstart.tid ~= tid or dstart.cm ~= cm or dstart.len ~= len then
    local path = 0
    for _, p in ipairs(fly(BALLISTICS[tid], 0, len)) do
      if -p[2] >= cm / 100 then path = p[3] break end
    end
    dstart.tid, dstart.cm, dstart.len, dstart.path = tid, cm, len, path
    if cfg.research then log('research: drop line start: %s from a drop of %s cm at %.1f m of path (the hand\'s %d m at least)', tid, tostring(cm), path, start_hand(BALLISTICS[tid])) end
  end
  return dstart.path
end
N.drop_lines = 0                                  -- (lines drawn this frame, for the timing line)
-- (2.2.4, research) the game's own aim points, from Blast & Trajectory Markers 1.2.4's notes (docs/RESEARCH.md):
-- your Helldiver's af97ede7 is look_at_position (its real name), where the view's ray meets the world (998 m out on
-- the sky), and bdc1cb8a the crosshair's hit point the rounds fly to (smoothed, about 0.25 s behind the view). Both
-- were "changes all the time, left out" in our all-fields log. Every half second while the line is drawn: the two
-- points' distances, the look point's height against our ground model's at that spot, and the mark's distance from
-- the look point — to see what a real raycast point would give the mark and the line
local LOOK_NAME = string.match(DATA.fieldnames or '', 'af97ede7 (%S+)')
local AIMPT_NAME = string.match(DATA.fieldnames or '', 'bdc1cb8a (%S+)')
local aimlog = { at = -100, n = 0 }
local function aim_points_research(cam, mx, my, mz)
  local now = chef.time()
  -- (2.4.9: 400 lines a session ran out 12 minutes before luka's marks: now only while aiming, 2000 a session, the
  -- count reset by a mark (13_main's N.mark_at), and every 0.25 s for the 20 s after one)
  local near_mark = N.mark_at and now - N.mark_at < 20
  if near_mark and not aimlog.mark_seen then aimlog.mark_seen, aimlog.n = N.mark_at, 0 elseif not near_mark then aimlog.mark_seen = nil end
  if not cfg.research or aimlog.n >= 2000 or now - aimlog.at < (near_mark and 0.25 or 0.5) or not (N.aim_now or near_mark) then return end
  local s, av = N.session_now, N.me.avatar
  if not (s and av and LOOK_NAME and AIMPT_NAME) then return end
  aimlog.at, aimlog.n = now, aimlog.n + 1
  if not N.alive(s, av, N.TYPES[2]) then return end
  local lx, ly, lz = N.xyz(N.call('avatar.look', 'GameSession.game_object_field', s, av, LOOK_NAME))
  local ax, ay, az = N.xyz(N.call('avatar.aimpt', 'GameSession.game_object_field', s, av, AIMPT_NAME))
  if not lx then log('research: aim points: the look point not read') return end
  local dl = math.sqrt((lx - cam.x) ^ 2 + (ly - cam.y) ^ 2 + (lz - cam.z) ^ 2)
  local da = ax and math.sqrt((ax - cam.x) ^ 2 + (ay - cam.y) ^ 2 + (az - cam.z) ^ 2) or nil
  local gh, gconf = nil, nil
  if N.ground_height and dl < 900 then gh, gconf = N.ground_height(lx, ly) end
  local mark = mx and string.format('; the mark %.1f m from the look point', math.sqrt((mx - lx) ^ 2 + (my - ly) ^ 2 + (mz - lz) ^ 2)) or '; no mark'
  -- (2.4.7, to test HUDdle 0.7.3's note that the round's point is set as a round is fired and raised over the
  -- crosshair's line to make up for the drop) the weapon, the point's angle over the camera's line and beside it
  -- (degrees), and the time since that weapon last fired
  local d = N.shown_d
  local tid = d and d.tid or '-'
  local o = d and N.objs and N.objs[d.goid or d.goid0]    -- (2.4.10: goid0 — the 2.4.9 line said "not fired yet" after shots)
  local since = o and o.fired_at and string.format('fired %.1f s ago', now - o.fired_at) or 'not fired yet'
  local over = ''
  if ax and cam.fx then
    local ex, ey, ez = ax - cam.x, ay - cam.y, az - cam.z
    local hl, fl = math.sqrt(ex * ex + ey * ey), math.sqrt(cam.fx * cam.fx + cam.fy * cam.fy)
    if hl > 1 and fl > 0.05 then
      local side = math.deg(math.acos(math.max(-1, math.min(1, (ex * cam.fx + ey * cam.fy) / (hl * fl)))))
      over = string.format('; the crosshair point %.2f deg over the camera\'s line, %.2f beside it', math.deg(math.atan2(ez, hl)) - math.deg(math.atan2(cam.fz, fl)), side)
    end
  end
  log('research: aim points: look %.1f m (%.1f, %.1f, %.1f)%s; crosshair point %s%s%s%s; %s, %s', dl, lx, ly, lz,
    dl >= 900 and ' (the sky)' or '', da and string.format('%.1f m', da) or 'not read',
    (da and ax) and string.format(' (%.1f m from the look point)', math.sqrt((ax - lx) ^ 2 + (ay - ly) ^ 2 + (az - lz) ^ 2)) or '', over,
    (gh and string.format('; our ground there %.1f m %s the look point (%s)', math.abs(gh - lz), gh > lz and 'above' or 'under', tostring(gconf)) or (dl < 900 and '; our ground there: none' or '')) .. mark,
    tostring(tid), since)
end
local aim_d = { d = nil, at = nil, at0 = nil }   -- (the aim's distance along the view, eased)
-- (2.4.15, luka: HUDdle's line follows the reticle, lagging the view in a turn and swaying with the sight) the game's
-- own reticle point, bdc1cb8a: where the rounds fly to, smoothed behind the view (his 2.4.11 research log, 1075
-- samples: a median 0.3 deg off the camera's line, p90 3.3 deg beside it, 15–35 deg in a fast turn). The line is
-- aimed from the hand at this point when F9 "Line aimed at" says the reticle; read once a frame, and taken only
-- when it's sane (2–600 m from the camera, within 45 deg of the view — HUDdle found it stale for some weapons
-- before their first shot), else the view's own aim as before. The throw line stays on the view (luka: less
-- important to be precise).
-- (2.4.16, luka's 2.4.15 test) the line blinked between the two aims: the reticle on the sky puts the point ~1000 m
-- out along its ray, which the 600 m gate took for stale — but a far point gives the direction just as well, so
-- only a point under 2 m (nothing to aim along) or off the view is refused. And the line ran a few frames behind
-- the reticle (the field is the game's smoothed aim, read once a frame, maybe written after our update): the point
-- is led by its own motion — the velocity from the last change it made, times LEAD frames (2: luka's 2.4.16 test,
-- "the correct value"; a slider there), the velocity forgotten 0.1 s after the point last moved, so a still reticle
-- stays still.
local LEAD = 2
local ret = { frame = nil, ok = false, why = 'off', x = 0, y = 0, z = 0, said = nil, said_at = -100,
  lx = nil, ly = nil, lz = nil, lt = nil, vx = 0, vy = 0, vz = 0 }
local function reticle_point(cam, any)   -- (any: asked for the crosshair, whatever "Line aimed at" says)
  if not any and (cfg.line_aim or 2) ~= 2 then return nil, 'off' end
  if ret.frame == N.frame then return ret.ok and ret or nil, ret.why end
  ret.frame, ret.ok = N.frame, false
  if not AIMPT_NAME then ret.why = 'no field name' return nil, ret.why end
  local s, av = N.session_now, N.me.avatar
  if not (s and av) or not N.alive(s, av, N.TYPES[2]) then ret.why = 'no avatar' return nil, ret.why end
  local ax, ay, az = N.xyz(N.call('avatar.aimpt', 'GameSession.game_object_field', s, av, AIMPT_NAME))
  if not (ax and ax == ax and ay == ay and az == az) then ret.why = 'not read' return nil, ret.why end
  local ex, ey, ez = ax - cam.x, ay - cam.y, az - cam.z
  local r = math.sqrt(ex * ex + ey * ey + ez * ez)
  if r < 2 then ret.why = string.format('%.1f m out', r) return nil, ret.why end
  local fl = math.sqrt(cam.fx * cam.fx + cam.fy * cam.fy + cam.fz * cam.fz)
  if fl < 1e-6 then ret.why = 'no view' return nil, ret.why end
  local dot = (ex * cam.fx + ey * cam.fy + ez * cam.fz) / (r * fl)
  if dot < 0.7071 then ret.why = string.format('%.0f deg off the view', math.deg(math.acos(math.max(-1, math.min(1, dot))))) return nil, ret.why end
  -- the lead: the point's own motion, from the last frame it moved — as a direction from the camera, not a point
  -- (2.5.11, luka: the crosshair "teleports to the centre even dragged slowly": the point jumps in depth whenever
  -- the aim crosses from a near surface to a far one or the sky, 30 m to 1000 m in a frame, and a lead along
  -- *that* motion put the point 2 km behind the camera for a frame — off the screen. Its direction barely moves
  -- in such a jump; led in direction, the point keeps its own distance)
  local now = chef.time()
  local ux, uy, uz = ex / r, ey / r, ez / r
  if ret.lt and (ux ~= ret.lx or uy ~= ret.ly or uz ~= ret.lz) then
    local dt = now - ret.lt
    if dt > 1e-4 and dt < 0.5 then ret.vx, ret.vy, ret.vz = (ux - ret.lx) / dt, (uy - ret.ly) / dt, (uz - ret.lz) / dt end
  end
  if not ret.lt or ux ~= ret.lx or uy ~= ret.ly or uz ~= ret.lz then ret.lx, ret.ly, ret.lz, ret.lt = ux, uy, uz, now end
  if now - ret.lt > 0.1 then ret.vx, ret.vy, ret.vz = 0, 0, 0 end
  local lead = (cfg.line_lead or LEAD) * (N.dt or 1 / 60)   -- (cfg.line_lead: the tests' knob, no F9 row)
  if lead > 0.1 then lead = 0.1 end
  local dx, dy, dz = ux + ret.vx * lead, uy + ret.vy * lead, uz + ret.vz * lead
  local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
  if dl < 1e-6 then dx, dy, dz, dl = ux, uy, uz, 1 end
  ret.x, ret.y, ret.z, ret.ok, ret.why = cam.x + dx / dl * r, cam.y + dy / dl * r, cam.z + dz / dl * r, true, nil
  return ret
end
-- (research: when the line falls back to the view and why, at most once a second; and the first use)
local function reticle_said(used, why)
  if not cfg.research then return end
  local now = chef.time()
  local what = used and 'the reticle' or ('the view: ' .. tostring(why))
  if ret.said == what or now - ret.said_at < 1 then return end
  ret.said, ret.said_at = what, now
  log('research: the drop line aimed at %s', what)
end
N.reticle_point = reticle_point
-- the line, from the view camera along the crosshair
local function draw_drop(tid)
  local mode = cfg.drop_line or 1
  if mode == 1 or not chef.line or not tid or not drops(tid) then return end
  if mode == 2 and not input.aiming then return end
  local cam = chef.camera()
  if not cam or not cam.fx then return end
  local fx, fy, fz = cam.fx, cam.fy, cam.fz
  local len = cfg.drop_len or 150
  -- The shot starts at the weapon: your Helldiver's right hand (its attach_hand_r node; 1.4.2: from the camera the
  -- line was one thin vertical stroke, the round coming from the left of it) and goes to where the crosshair looks,
  -- taken as the point CONVERGE metres along the camera's line (the game converges on what the crosshair hits)
  local x0, y0, z0, start = cam.x, cam.y, cam.z, 0
  local u = N.my_unit and N.my_unit()
  if u and chef.unit_node and chef.unit_position then
    if hand_of.u ~= u then hand_of.u, hand_of.node = u, chef.unit_node(u, 'attach_hand_r') end
    if hand_of.node then
      local px, py, pz = chef.unit_position(u, hand_of.node)
      if px then
        -- (2.2.5) the game aims a third-person shot at what the crosshair hits: the look point (12_ground reads it)
        -- when it's on something, else the old CONVERGE metres along the camera's line
        -- (2.2.7, luka: the point is read ten times a second and the line jumped with it, "like low fps": the
        -- point sits on the view's ray, so only its distance is taken from it — eased over 0.1 s — and the aim
        -- itself follows the camera every frame)
        local look = N.look_point and N.look_point()
        local now = chef.time()
        local want = CONVERGE
        if look then
          local d = math.sqrt((look.x - cam.x) ^ 2 + (look.y - cam.y) ^ 2 + (look.z - cam.z) ^ 2)
          if d > 2 then want = d end
        end
        local dt = math.min(0.1, now - (aim_d.at or now))
        aim_d.at = now
        if aim_d.d == nil or now - (aim_d.at0 or -100) > 0.5 then aim_d.d = want end
        aim_d.d = aim_d.d + (want - aim_d.d) * math.min(1, dt / 0.1)
        aim_d.at0 = now
        local tx, ty, tz = cam.x + cam.fx * aim_d.d, cam.y + cam.fy * aim_d.d, cam.z + cam.fz * aim_d.d
        -- (2.4.15) the reticle's own point instead, when it's there and sane
        local rp, why = reticle_point(cam)
        if rp then tx, ty, tz = rp.x, rp.y, rp.z end
        if (cfg.line_aim or 2) == 2 then reticle_said(rp ~= nil, why) end
        fx, fy, fz = tx - px, ty - py, tz - pz
        local l = math.sqrt(fx * fx + fy * fy + fz * fz)
        if l > 1 then                             -- (the muzzle: a little on from the hand along the shot, a hand's
          -- width to the left as seen from the camera)
          local lx, ly = -cam.fy, cam.fx
          local ll = math.sqrt(lx * lx + ly * ly)
          if ll > 1e-4 then lx, ly = lx / ll * HAND_LEFT, ly / ll * HAND_LEFT else lx, ly = 0, 0 end
          x0, y0, z0, start = px + fx / l * MUZZLE + lx, py + fy / l * MUZZLE + ly, pz + fz / l * MUZZLE, 1
        end
      end
    end
  end
  local hl = math.sqrt(fx * fx + fy * fy)
  if hl < 1e-4 then return end
  local pitch = math.atan2(fz, hl)
  local pts = flight_of(tid, pitch, len)
  local hx, hy = fx / hl, fy / hl                   -- the aim's horizontal direction
  local c = N.wcol(N.CREAM, 170)                  -- (2.0.17: the world's tone curve)
  local function world(p) return x0 + hx * p[1], y0 + hy * p[1], z0 + p[2] end
  -- thickness: the line drawn again beside itself, offset across the view by a share of its distance from the
  -- camera (the same width on the screen at any distance); the engine's lines are one pixel wide
  local lines = cfg.drop_thick or 1                 -- (Thin 1, Medium 2, Thick 3 lines side by side)
  local cx, cy, cz = cam.x, cam.y, cam.z
  local crx, cry = cam.fy, -cam.fx                  -- the camera's right (horizontal)
  local cl = math.sqrt(crx * crx + cry * cry)
  if cl < 1e-4 then lines = 1 else crx, cry = crx / cl, cry / cl end
  local n = 0
  -- (2.4.8) the look: dashes (12_decal), fading in over the first metre and a half, with dark edges; Classic as before
  local lst = N.line_state(chef.time())
  local dk = N.wcol({ 0, 0, 0 }, 110)
  local cfun = lst.look ~= 1 and function(f) return N.wcol(N.CREAM, 170 * f), N.wcol({ 0, 0, 0 }, 110 * f) end or nil
  local blast = BLAST and BLAST.weapons[tid]
  if NO_MARK[tid] then blast = nil end
  local lx, ly, lz, lpath = nil, nil, nil, 0
  local from = math.max(start_hand(BALLISTICS[tid]), drop_start(tid, len))
  local mark = cfg.landing_mark and not NO_MARK[tid] and N.ground_landing
  local marked, mst = false, {}
  local mkx, mky, mkz = nil, nil, nil             -- (2.2.4 research: where the mark went)
  local shit = cfg.struct_mark and N.struct_hit     -- (2.0.16) the enemies' structures: the mark red where the shot hits one
  local sst = shit and {}
  for i = 1, #pts do
    local p = pts[i]
    local wx, wy, wz = world(p)
    -- (2.0.13) where the flight meets the ground (12_ground's guess): a ring there; the line runs on to its end
    -- (2.0.14, luka: the game's own depth test hides the part under the ground, and a ring a little off keeps a
    -- whole line rather than a cut one); never within 20 m of you (7 m for the Ultimatum's lob)
    if shit and not marked and lx and lpath >= from then
      local hx, hy, hz = shit(lx, ly, lz, wx, wy, wz, sst, x0, y0)
      if hx then N.draw_ground_mark(hx, hy, hz, 'feet', N.RED, x0, y0, blast, 'drop') marked = true mkx, mky, mkz = hx, hy, hz end
    end
    -- (2.4.9, luka: the Crossbow's zone didn't show near him, so he couldn't tell he was close enough to hurt
    -- himself: with a blast known, the mark from 3 m, on sure ground only there (12_ground's gate). 2.4.11: and
    -- looked for from 3 m of path even where the line itself starts later — the Crossbow's begins where the bolt has
    -- dropped 10 cm, 14 m out)
    if mark and not marked and lx and (lpath >= from or (blast and lpath >= 3)) then
      local gx, gy, gz, conf = mark(lx, ly, lz, wx, wy, wz, x0, y0, mst, blast and 3 or (from == 3 and 7 or 20))
      if gx then N.draw_ground_mark(gx, gy, gz, conf, nil, x0, y0, blast, 'drop') marked = true mkx, mky, mkz = gx, gy, gz end
    end
    -- (2.1.2) the line begins at `from` exactly: the segment it falls in is cut there (the flight's points sit at
    -- different paths at different pitches, so a start at the next point wandered with the aim)
    if lx and lpath < from and p[3] > from and p[3] > lpath then
      local t = (from - lpath) / (p[3] - lpath)
      lx, ly, lz, lpath = lx + (wx - lx) * t, ly + (wy - ly) * t, lz + (wz - lz) * t, from
    end
    if lx and lpath >= from then
      -- (2.2.6: the strands across the view of this very segment, not the camera's horizontal: N.across)
      local ax, ay, az = N.across(cam, lx, ly, lz, wx, wy, wz)
      if not ax then ax, ay, az = crx, cry, 0 end
      -- (each line a pixel or so beside the last, centred on the flight: 12_decal's N.line_piece)
      n = n + N.line_piece(lst, cam, lx, ly, lz, wx, wy, wz, ax, ay, az, lines, c, dk, cfun)
    end
    lx, ly, lz, lpath = wx, wy, wz, p[3]
  end
  n = n + N.line_end(lst, cam, lines, c, dk, cfun)
  N.drop_lines = n
  aim_points_research(cam, mkx, mky, mkz)
end
-- Chef's line object keeps showing the last lines dispatched until a frame draws some again, so a line that goes
-- (the weapon swapped) stayed in the world (the 1.4.2 log): one line of nothing for a frame after takes it away
local function drop_clear()
  if not chef.line then return end
  local cam = chef.camera()
  if cam then chef.line(cam.x, cam.y, cam.z, cam.x, cam.y, cam.z, N.wcol(N.CREAM, 0)) end
end
N.draw_drop, N.drop_fly, N.drop_drops, N.drop_clear = draw_drop, fly, drops, drop_clear
