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
-- (from the hand: the first metres are of no use, and any mismatch with the muzzle shows there: 10 m out, 3 m for
-- the Ultimatum's lob (its whole curve is in the first metres))
local function start_hand(b) return b.v <= 25 and 3 or 10 end
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
    path = path + math.sqrt((nx - x) ^ 2 + (nz - z) ^ 2)
    x, z, t = nx, nz, t + STEP
  end
  pts[#pts + 1] = { x, z, path }
  return pts
end
-- the drop over 100 m of level flight, once per type: under half a metre, no line
local drop100 = {}
local function drops(tid)
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
local cache = { tid = nil, key = nil, pts = nil, len = nil }
local function flight_of(tid, pitch, len)
  local key = math.floor(pitch * 114.6 + 0.5)       -- (half degrees)
  if cache.tid ~= tid or cache.key ~= key or cache.len ~= len then
    cache.tid, cache.key, cache.len, cache.pts = tid, key, len, fly(BALLISTICS[tid], pitch, len)
  end
  return cache.pts
end
N.drop_lines = 0                                  -- (lines drawn this frame, for the timing line)
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
        fx, fy, fz = cam.x + cam.fx * CONVERGE - px, cam.y + cam.fy * CONVERGE - py, cam.z + cam.fz * CONVERGE - pz
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
  local c = N.col(N.CREAM, 170)
  local function world(p) return x0 + hx * p[1], y0 + hy * p[1], z0 + p[2] end
  -- thickness: the line drawn again beside itself, offset across the view by a share of its distance from the
  -- camera (the same width on the screen at any distance); the engine's lines are one pixel wide
  local lines = cfg.drop_thick or 2                 -- (Thin 1, Medium 2, Thick 3 lines side by side)
  local cx, cy, cz = cam.x, cam.y, cam.z
  local crx, cry = cam.fy, -cam.fx                  -- the camera's right (horizontal)
  local cl = math.sqrt(crx * crx + cry * cry)
  if cl < 1e-4 then lines = 1 else crx, cry = crx / cl, cry / cl end
  local n = 0
  local lx, ly, lz, lpath = nil, nil, nil, 0
  local from = start_hand(BALLISTICS[tid])
  for i = 1, #pts do
    local p = pts[i]
    local wx, wy, wz = world(p)
    if lx and lpath >= from then
      for k = 1, lines do
        -- (each line a pixel or so beside the last, centred on the flight)
        local o = 0.0012 * (k - (lines + 1) / 2)
        local d1 = math.sqrt((lx - cx) ^ 2 + (ly - cy) ^ 2 + (lz - cz) ^ 2) * o
        local d2 = math.sqrt((wx - cx) ^ 2 + (wy - cy) ^ 2 + (wz - cz) ^ 2) * o
        chef.line(lx + crx * d1, ly + cry * d1, lz, wx + crx * d2, wy + cry * d2, wz, c)
        n = n + 1
      end
    end
    lx, ly, lz, lpath = wx, wy, wz, p[3]
  end
  N.drop_lines = n
end
-- Chef's line object keeps showing the last lines dispatched until a frame draws some again, so a line that goes
-- (the weapon swapped) stayed in the world (the 1.4.2 log): one line of nothing for a frame after takes it away
local function drop_clear()
  if not chef.line then return end
  local cam = chef.camera()
  if cam then chef.line(cam.x, cam.y, cam.z, cam.x, cam.y, cam.z, N.col(N.CREAM, 0)) end
end
N.draw_drop, N.drop_fly, N.drop_drops, N.drop_clear = draw_drop, fly, drops, drop_clear
