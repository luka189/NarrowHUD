-- NarrowHUD, the rocks (3.1, luka: "Lines stop on rocks, walls and trunks"): the drop and throw lines end on the
-- boulder, cliff, wall or log they would hit, with the landing mark there, instead of passing into it and marking
-- the ground beyond. luka: everything that stops a round and can't be destroyed — rocks, bug rocks, fortifications,
-- logs and roots.
-- How: tools/make_shapes.py --inner reads filediver's unit exports (the collision hull where the unit has one, the
-- LOD0 shell where not) and writes src/rock_parts_generated.lua: for each kind, by its resource hash, the mesh's box
-- (half sizes and middle, in the unit's own frame) and up to eight `stop` boxes inscribed in the solid, each a voxel
-- inside the surface — luka: the hitbox smaller than the rock, on the inner side, so a line never stops where the
-- game would let the round through. The ground walk (12_ground) lists every unit of such a kind; a unit's pose is
-- asked once (Unit.box, alive-checked: its axes and the engine's half sizes, which against the mesh's give the
-- unit's scale; the mesh's frame starts at the unit's root, as a structure's does), and a line's segments are tested
-- against the stop boxes in the unit's own frame — our own slab test, no engine ray. A hit ends the line there.
local cfg, call = N.cfg, N.call
local ROCKS = ROCK_PARTS or {}                   -- kind hash -> { name, box = { hx, hy, hz, cx, cy, cz }, stop = { ... } }
local CELL = 16                                  -- the listing's grid, metres
local ASKS = 6                                   -- Unit.box calls a frame, at most
-- (3.0.5, luka: "the line felt very jittery when dragging around") 3.0.4 counted every rock looked at against a
-- budget of 4000 a frame and gave up the rest of the line when it ran out, so in a rubble field the hit came and
-- went frame by frame and the line's end jumped between the rock and the ground 30 m behind it (the research log:
-- 311 hits in 10 s where a steady aim makes 830). The budget counts box tests only, is a safety cap (50000: a
-- pathological frame, never a rubble field), and the research log says when it was reached
local TESTS = 50000                              -- box tests a frame, at most
local NONE = {}
local STICK = 0.3                                -- metres: the box hit last frame is this much bigger, against the sway
local rk = { list = {}, grid = {}, pose = setmetatable({}, { __mode = 'k' }), asks = 0, tests = 0, hits = 0, asked = 0, said = -100, last = {} }
N.rocks = rk

-- (3.0.12: a kind with no stop box — two small debris pieces too thin for one — stops nothing: not listed)
local function rock_kind(k) local r = ROCKS[k] return r ~= nil and #r.stop > 0 end
N.rock_kind = rock_kind
function M.debug_rock_tests() return rk.tests end   -- (tests: the box tests of the frame so far)
function M.debug_rock(k, v) ROCKS[k] = v end     -- (tests: a kind by hash; M is the head's table, 13_main's debug helpers' home — that file is at Lua's upvalue limit)

-- the walk's listing (12_ground): every unit of a rock kind, with its position, into the walk's own table; swapped
-- in when the walk is done, in a grid of CELL metre cells: a rock goes into every cell its reach covers, so a
-- segment looks only in the cells it crosses. The reach before its pose is asked: round the root, the mesh box's
-- radius and its middle's distance from the root (3.0.12: a boulder's middle is up to 3.5 m from its root), half as
-- much again for a scaled-up unit; once the pose is known, the pose's own (3.0.12: a unit scaled past that reached
-- no farther cells)
local function rock_seen(list, u, k, x, y, z)
  list[#list + 1] = { u = u, k = k, x = x, y = y, z = z }
end
N.rock_seen = rock_seen
local function into_grid(grid, s, x0, x1, y0, y1, ox0, ox1, oy0, oy1)
  -- (3.0.16: by the rectangle x0..x1, y0..y1 — a 86 m curb lying east-west is in the cells along it, not in a
  -- square 86 m a side. ox0..oy1: a rectangle the rock is in the grid by already: those cells are left alone)
  local a0, a1, b0, b1
  if ox0 then a0, a1, b0, b1 = math.floor(ox0 / CELL), math.floor(ox1 / CELL), math.floor(oy0 / CELL), math.floor(oy1 / CELL) end
  for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
    for cy = math.floor(y0 / CELL), math.floor(y1 / CELL) do
      if not (ox0 and cx >= a0 and cx <= a1 and cy >= b0 and cy <= b1) then
        local c = (cx + 2048) * 4096 + (cy + 2048)
        local g = grid[c]
        if not g then g = {} grid[c] = g end
        g[#g + 1] = s
      end
    end
  end
end
local function rock_listed(list)
  rk.list = list
  local grid = {}
  for _, s in ipairs(list) do
    local b = ROCKS[s.k].box
    s.r0 = (math.sqrt(b[1] * b[1] + b[2] * b[2] + b[3] * b[3]) + math.sqrt(b[4] * b[4] + b[5] * b[5] + b[6] * b[6])) * 1.5 + STICK
    local p = rk.pose[s.u]
    if p then s.gx0, s.gx1, s.gy0, s.gy1 = p.x0, p.x1, p.y0, p.y1
    else s.gx0, s.gx1, s.gy0, s.gy1 = s.x - s.r0, s.x + s.r0, s.y - s.r0, s.y + s.r0 end
    into_grid(grid, s, s.gx0, s.gx1, s.gy0, s.gy1)
  end
  rk.grid = grid
  if cfg.research and #list > 0 and rk.n ~= #list then
    rk.n = #list
    local counts, names = {}, {}
    for _, s in ipairs(list) do counts[s.k] = (counts[s.k] or 0) + 1 end
    for k, n in pairs(counts) do names[#names + 1] = string.format('%s x%d', ROCKS[k].name or k, n) end
    table.sort(names)
    log('research: rocks: %d listed of %d kinds: %s', #list, #names, table.concat(names, '; '))
  end
end
N.rock_listed = rock_listed

-- a unit's pose, asked once: { x, y, z = the unit's root in the world; R = the unit's axes (rows: x, y, z of the
-- unit in the world); sx, sy, sz = its scale; mx, my, mz = the mesh box's middle in the world and r its radius, for
-- the first look } or false. Unit.box on a dying unit ended the game (2.4.1): alive-checked the same frame, and
-- never on a unit the walk hasn't listed. The axes from the pose's columns (Matrix4x4.x, .y, .z) where the game has
-- them, else from the unit's rotation (Quaternion.right, .forward, .up), else an upright unit turned by its yaw
local function axes_of(pose, u)
  local xx, xy, xz = N.xyz(call('rock.ax', 'Matrix4x4.x', pose))
  local yx, yy, yz = N.xyz(call('rock.ay', 'Matrix4x4.y', pose))
  local zx, zy, zz = N.xyz(call('rock.az', 'Matrix4x4.z', pose))
  local how = 'the pose'
  if not (xx and yx and zx) then
    local q = call('rock.rot', 'Unit.world_rotation', u, 1)
    if q ~= nil then
      xx, xy, xz = N.xyz(call('rock.qr', 'Quaternion.right', q))
      yx, yy, yz = N.xyz(call('rock.qf', 'Quaternion.forward', q))
      zx, zy, zz = N.xyz(call('rock.qu', 'Quaternion.up', q))
      how = 'the rotation'
    end
  end
  if not (xx and yx and zx) and chef.unit_rotation then
    local _, _, _, yaw = chef.unit_rotation(u)
    if type(yaw) == 'number' and yaw == yaw then
      local c, s = math.cos(yaw), math.sin(yaw)
      xx, xy, xz, yx, yy, yz, zx, zy, zz = c, -s, 0, s, c, 0, 0, 0, 1
      how = 'the yaw'
    end
  end
  if not (xx and yx and zx) then return nil end
  local function unit(x, y, z)
    local l = math.sqrt(x * x + y * y + z * z)
    if not (l > 1e-6 and l == l) then return nil end
    return x / l, y / l, z / l, l
  end
  local lx, ly, lz
  xx, xy, xz, lx = unit(xx, xy, xz)
  yx, yy, yz, ly = unit(yx, yy, yz)
  zx, zy, zz, lz = unit(zx, zy, zz)
  if not (xx and yx and zx) then return nil end
  return { { xx, xy, xz }, { yx, yy, yz }, { zx, zy, zz } }, how, lx, ly, lz
end
-- (3.0.12) the unit's scale, and where its mesh sits. luka's 3.0.5 logs, 55 poses of 23 kinds: every axis 1.00
-- long, and the engine's box bigger than the mesh's by a fixed 0.00 to 0.06 m a side — a margin, not a scale: on a
-- log's thin axis 3.0.4 read it as "scale 1.12" and grew the stop boxes by as much — and by 0.25 m on the one stump
-- whose box holds more than its mesh, the box's middle 0.4 m off the mesh's with it. So the scale is the axes' own
-- lengths where the pose carries one (off 1 by more than 2 %); else one number for the whole unit, the smallest of
-- the three ratios (a margin inflates the thin axis most), and none when that is within 6 % of 1. And the mesh is
-- placed from the unit's root, as a structure's parts are (the box's middle was the anchor: right only where the
-- engine's box is the mesh's)
local function clamp(v) if v < 0.1 then return 0.1 elseif v > 20 then return 20 end return v end
local function scale_of(hx, hy, hz, b, lx, ly, lz)
  if lx and ly and lz and (math.abs(lx - 1) > 0.02 or math.abs(ly - 1) > 0.02 or math.abs(lz - 1) > 0.02) then
    return clamp(lx), clamp(ly), clamp(lz), 'the axes'
  end
  -- (3.0.17, luka's first 3.0.16 log: habs_crate_small_02, the engine's 0.39 x 0.55 x 0.37 against the mesh's
  -- 0.35 x 0.50 x 0.25, read "scale 1.10"; habs_crate_medium_01_2stack 1.07. On a thing half a metre across the
  -- same few centimetres of margin are past 6 %: the smallest ratio's axis must also differ by more than 0.1 m)
  local u, d = hx / math.max(b[1], 0.05), hx - b[1]
  local ry, rz = hy / math.max(b[2], 0.05), hz / math.max(b[3], 0.05)
  if ry < u then u, d = ry, hy - b[2] end
  if rz < u then u, d = rz, hz - b[3] end
  if math.abs(u - 1) < 0.06 or math.abs(d) <= 0.1 then return 1, 1, 1, 'none' end
  u = clamp(u)
  return u, u, u, 'the box'
end
-- (3.0.16) the box round all of a kind's stop boxes, asked before them: with the second export a kind has 16 boxes
-- on average (48 at most) where it had 8, and most segments that come within a unit's reach miss every one of them.
-- From the stop boxes themselves, not the mesh's box: a plate or a covering box may stand a little outside the mesh
local function env_of(kind)
  local e = kind.env
  if e then return e end
  local x0, x1, y0, y1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
  for _, q in ipairs(kind.stop) do
    local hx, hy = q[1], q[2]
    if q[7] then
      local c, s = math.abs(math.cos(q[7])), math.abs(math.sin(q[7]))
      hx, hy = c * q[1] + s * q[2], s * q[1] + c * q[2]
    end
    x0, x1 = math.min(x0, q[4] - hx), math.max(x1, q[4] + hx)
    y0, y1 = math.min(y0, q[5] - hy), math.max(y1, q[5] + hy)
    z0, z1 = math.min(z0, q[6] - q[3]), math.max(z1, q[6] + q[3])
  end
  e = { (x1 - x0) / 2, (y1 - y0) / 2, (z1 - z0) / 2, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2 }
  kind.env = e
  return e
end
-- a point of the unit's frame (the mesh's metres from the root) in the world, and back
local function to_world(p, lx, ly, lz)
  local R = p.R
  local dx, dy, dz = lx * p.sx, ly * p.sy, lz * p.sz
  return p.x + R[1][1] * dx + R[2][1] * dy + R[3][1] * dz, p.y + R[1][2] * dx + R[2][2] * dy + R[3][2] * dz, p.z + R[1][3] * dx + R[2][3] * dy + R[3][3] * dz
end
local function to_local(p, x, y, z)
  local R = p.R
  local dx, dy, dz = x - p.x, y - p.y, z - p.z
  return (R[1][1] * dx + R[1][2] * dy + R[1][3] * dz) / p.sx, (R[2][1] * dx + R[2][2] * dy + R[2][3] * dz) / p.sy, (R[3][1] * dx + R[3][2] * dy + R[3][3] * dz) / p.sz
end
local function pose_of(s)
  if s.gone then return false end
  local p = rk.pose[s.u]
  if p ~= nil then return p end
  if rk.asks >= ASKS then return nil end         -- (this frame's budget spent: asked another frame)
  rk.asks = rk.asks + 1
  if chef.unit_alive and chef.unit_alive(s.u) ~= true then s.gone = true return false end
  rk.asked = rk.asked + 1
  local kind = ROCKS[s.k]
  local pose, half = call('rock.box.' .. s.k, 'Unit.box', s.u)
  local hx, hy, hz
  if pose ~= nil and half ~= nil then hx, hy, hz = N.xyz(half) end
  p = false
  if hx and hy and hz and hx == hx and hx > 0 and hy > 0 and hz > 0 and hx < 1e4 and hy < 1e4 and hz < 1e4 then
    local R, how, lx, ly, lz = axes_of(pose, s.u)
    if R then
      local b = kind.box
      local sx, sy, sz, scaled = scale_of(hx, hy, hz, b, lx, ly, lz)
      p = { x = s.x, y = s.y, z = s.z, R = R, sx = sx, sy = sy, sz = sz, k = s.k }
      p.mx, p.my, p.mz = to_world(p, b[4], b[5], b[6])
      p.r = math.sqrt((b[1] * sx) ^ 2 + (b[2] * sy) ^ 2 + (b[3] * sz) ^ 2)
      -- (3.0.16) the stop boxes' own box in the world, STICK bigger (the hysteresis reaches that far): what a
      -- segment is held against first, and what the grid lists the unit by. (A ball round the mesh's middle was
      -- both: a thin 16 m platform or a curb was "near" every segment within 8 or 43 m of it)
      local e = env_of(kind)
      local x0, x1, y0, y1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
      for i = 0, 7 do
        local wx, wy, wz = to_world(p, e[4] + ((i % 2 == 0) and -e[1] or e[1]), e[5] + ((math.floor(i / 2) % 2 == 0) and -e[2] or e[2]), e[6] + ((i < 4) and -e[3] or e[3]))
        x0, x1, y0, y1, z0, z1 = math.min(x0, wx), math.max(x1, wx), math.min(y0, wy), math.max(y1, wy), math.min(z0, wz), math.max(z1, wz)
      end
      p.x0, p.x1, p.y0, p.y1, p.z0, p.z1 = x0 - STICK, x1 + STICK, y0 - STICK, y1 + STICK, z0 - STICK, z1 + STICK
      -- (a unit bigger than the listing allowed for: into the cells its real reach covers as well)
      if s.gx0 and (p.x0 < s.gx0 or p.x1 > s.gx1 or p.y0 < s.gy0 or p.y1 > s.gy1) then
        into_grid(rk.grid, s, p.x0, p.x1, p.y0, p.y1, s.gx0, s.gx1, s.gy0, s.gy1)
      end
      if cfg.research and not rk.said_kind then rk.said_kind = {} end
      if cfg.research and not rk.said_kind[s.k] then
        rk.said_kind[s.k] = true
        local tx, ty, tz = N.xyz(call('rock.boxc', 'Matrix4x4.translation', pose))
        log('research: rock pose: %s: the engine\'s half sizes %.2f x %.2f x %.2f, the mesh\'s %.2f x %.2f x %.2f: scale %.2f %.2f %.2f (from %s); the axes from %s (lengths %.2f %.2f %.2f); %d stop boxes; the engine box\'s middle (%.2f, %.2f, %.2f), the mesh\'s from the root (%.2f, %.2f, %.2f), the root (%.2f, %.2f, %.2f)',
          kind.name or s.k, hx, hy, hz, b[1], b[2], b[3], sx, sy, sz, scaled, how, lx or 0, ly or 0, lz or 0, #kind.stop, tx or 0, ty or 0, tz or 0, p.mx, p.my, p.mz, s.x, s.y, s.z)
      end
    end
  end
  rk.pose[s.u] = p
  return p
end

-- the segment a-b (the unit's frame) against the box q (half sizes q[1..3], middle q[4..6], grown by g on each
-- side): the entry's t in (0, 1], or nil; a segment that starts inside is no hit (the line was in the rock already)
local function slab1(a, d, c, h, t0, t1)
  local lo, hi = c - h, c + h
  if math.abs(d) < 1e-9 then
    if a < lo or a > hi then return nil end
    return t0, t1
  end
  local ta, tb = (lo - a) / d, (hi - a) / d
  if ta > tb then ta, tb = tb, ta end
  if ta > t0 then t0 = ta end
  if tb < t1 then t1 = tb end
  if t0 > t1 then return nil end
  return t0, t1
end
-- (3.0.15) a box with a 7th number is turned about z by that angle (a plate on a wall's face, a box laid along a
-- sheet: tools/make_shapes.py's plates and covering boxes): the segment is turned into the box's frame first
local function slab(ax, ay, az, bx, by, bz, q, gx, gy, gz)
  local cx, cy = q[4], q[5]
  local yaw = q[7]
  if yaw then
    local c, s = q[8], q[9]
    if not c then c, s = math.cos(yaw), math.sin(yaw) q[8], q[9] = c, s end
    local dax, day, dbx, dby = ax - cx, ay - cy, bx - cx, by - cy
    ax, ay, bx, by = dax * c + day * s, -dax * s + day * c, dbx * c + dby * s, -dbx * s + dby * c
    cx, cy = 0, 0
  end
  local t0, t1 = slab1(ax, bx - ax, cx, q[1] + gx, 0, 1)
  if not t0 then return nil end
  t0, t1 = slab1(ay, by - ay, cy, q[2] + gy, t0, t1)
  if not t0 then return nil end
  t0, t1 = slab1(az, bz - az, q[6], q[3] + gz, t0, t1)
  if not t0 or t0 <= 0 then return nil end
  return t0
end

-- does the segment a-b touch the box q grown by g (a start inside counts: a stop box may lie further in)?
local function touches(ax, ay, az, bx, by, bz, q, gx, gy, gz)
  local t0, t1 = slab1(ax, bx - ax, q[4], q[1] + gx, 0, 1)
  if not t0 then return false end
  t0, t1 = slab1(ay, by - ay, q[5], q[2] + gy, t0, t1)
  if not t0 then return false end
  return slab1(az, bz - az, q[6], q[3] + gz, t0, t1) ~= nil
end

-- does the segment (x1,y1,z1)-(x2,y2,z2) go into a listed rock? -> the hit's x, y, z and the rock, or nil. ls: the
-- line's own state ({} per line; `key` 'drop' or 'throw' for the hysteresis: the box the line stopped on last frame
-- is STICK metres bigger this frame, so a line grazing an edge doesn't flicker between the rock and the ground
-- behind). The rocks looked at: those listed in the grid cells the segment crosses, each first by the plain
-- distance from its middle, then its stop boxes
local hit
function hit(x1, y1, z1, x2, y2, z2, ls, key)
  if not cfg.rock_stop or #rk.list == 0 then return nil end
  if N.units_held and N.units_held(N.now or chef.time()) then return nil end
  local vx, vy, vz = x2 - x1, y2 - y1, z2 - z1
  local len2 = vx * vx + vy * vy + vz * vz
  if len2 < 1e-6 then return nil end
  local last = rk.last[key]
  local cx0, cx1 = math.floor(math.min(x1, x2) / CELL), math.floor(math.max(x1, x2) / CELL)
  local cy0, cy1 = math.floor(math.min(y1, y2) / CELL), math.floor(math.max(y1, y2) / CELL)
  local best, bs, bq
  local sx0, sx1, sy0, sy1, sz0, sz1 = math.min(x1, x2), math.max(x1, x2), math.min(y1, y2), math.max(y1, y2), math.min(z1, z2), math.max(z1, z2)
  local look = (rk.look or 0) + 1
  rk.look = look
  for cx = cx0, cx1 do
    for cy = cy0, cy1 do
      local g = rk.grid[(cx + 2048) * 4096 + (cy + 2048)]
      if g then
        for _, s in ipairs(g) do
          if rk.tests >= TESTS then rk.over = (rk.over or 0) + 1 return nil end
          if s.look ~= look then                -- (a rock is in every cell it reaches: looked at once a segment)
            s.look = look
            -- first the segment's box against the unit's own (3.0.16); a unit whose pose is not asked yet: the
            -- plain distance from its root to the segment against the kind's reach, and then its pose
            local p = rk.pose[s.u]
            local near
            if p then
              near = p.x1 >= sx0 and p.x0 <= sx1 and p.y1 >= sy0 and p.y0 <= sy1 and p.z1 >= sz0 and p.z0 <= sz1
            elseif p == nil then
              local t = ((s.x - x1) * vx + (s.y - y1) * vy + (s.z - z1) * vz) / len2
              if t < 0 then t = 0 elseif t > 1 then t = 1 end
              local dx, dy, dz = x1 + vx * t - s.x, y1 + vy * t - s.y, z1 + vz * t - s.z
              if dx * dx + dy * dy + dz * dz < (s.r0 + STICK) ^ 2 then
                p = pose_of(s)
                near = p and p.x1 >= sx0 and p.x0 <= sx1 and p.y1 >= sy0 and p.y0 <= sy1 and p.z1 >= sz0 and p.z0 <= sz1
              end
            end
            if near then
              do
                local ax, ay, az = to_local(p, x1, y1, z1)
                local bx, by, bz = to_local(p, x2, y2, z2)
                local kind = ROCKS[s.k]
                rk.tests = rk.tests + 1
                -- (the envelope grown as the stuck box is: the hysteresis below reaches STICK past a box)
                local stop = touches(ax, ay, az, bx, by, bz, env_of(kind), STICK / p.sx, STICK / p.sy, STICK / p.sz) and kind.stop or NONE
                for i, q in ipairs(stop) do
                  rk.tests = rk.tests + 1
                  local tq = slab(ax, ay, az, bx, by, bz, q, 0, 0, 0)
                  -- (the box the line stopped on last frame, grown by STICK, when the line grazes past it now: the
                  -- hit stays, at the grown box's face; a line inside the box proper takes its own entry, so the
                  -- mark doesn't move when the hysteresis sets in)
                  -- (3.0.15: only a graze. A segment that ends in the grown box's rim short of the box itself took
                  -- the grown face — the mark 0.3 m in front of the rock, in and out as the aim moved a segment's
                  -- end through the rim. If the line carried straight on a metre meets the box itself, the next
                  -- segment has the hit, at the true face)
                  if not tq and last and last.u == s.u and last.i == i then
                    local tg = slab(ax, ay, az, bx, by, bz, q, STICK / p.sx, STICK / p.sy, STICK / p.sz)
                    if tg then
                      local dx, dy, dz = bx - ax, by - ay, bz - az
                      local k = 1 / math.max(1e-6, math.sqrt(dx * dx + dy * dy + dz * dz))
                      if not slab(bx, by, bz, bx + dx * k, by + dy * k, bz + dz * k, q, 0, 0, 0) then tq = tg end
                    end
                  end
                  if tq and (not best or tq < best) then best, bs, bq = tq, s, i end
                end
              end
            end
          end
        end
      end
    end
  end
  if not best then return nil end
  -- (3.0.12) a rock destroyed since the walk listed it (the walk comes round every 20 s or so) stops nothing: it
  -- is struck off and the segment looked at again without it
  if chef.unit_alive and chef.unit_alive(bs.u) ~= true then
    bs.gone = true
    rk.pose[bs.u] = false
    return hit(x1, y1, z1, x2, y2, z2, ls, key)
  end
  rk.hits = rk.hits + 1
  if last then last.u, last.i, last.at = bs.u, bq, N.now or chef.time() else rk.last[key] = { u = bs.u, i = bq, at = N.now or chef.time() } end
  return x1 + vx * best, y1 + vy * best, z1 + vz * best, bs
end
N.rock_hit = hit

-- once a frame (12_ground's update): the budgets, the research line, and Testing "Draw structure boxes": one box
-- for each listed unit near the camera — the box round its stop boxes, which is what a line is held against first.
-- (3.0.17, luka's first look at 3.0.16: "draw structure boxes is unusable, it attempts to draw what I assume are
-- thousands of lines at once, hangs the game and crashes after a time. Any way to have it just mark in a visible
-- way what structures are detected, without all the boxes". Two faults. Every stop box of the nearest 24 units was
-- drawn: 9 boxes a unit in 3.0.5, 25 to 30 now, 8,000 lines a frame. And since 3.0.15 none of them was a line the
-- game could draw: box_edges took its colour as `c` and then named the turned box's cosine `c` too, so every
-- chef.line got a number for a colour — Chef's quick call fails on that and each line goes the guarded way, with
-- a trace line written to disk.) Now: the nearest BOX_UNITS within BOX_REACH, 12 lines each, the list made twice a
-- second and not every frame
local EDGES = { { 0, 1 }, { 2, 3 }, { 0, 2 }, { 1, 3 }, { 4, 5 }, { 6, 7 }, { 4, 6 }, { 5, 7 }, { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 } }
local BOX_UNITS, BOX_REACH = 60, 60
local P = { [0] = {}, {}, {}, {}, {}, {}, {}, {} }
local function box_edges(p, q, colour)
  local hx, hy, hz, mx, my, mz = q[1], q[2], q[3], q[4], q[5], q[6]
  local cs, sn = 1, 0
  if q[7] then cs, sn = math.cos(q[7]), math.sin(q[7]) end       -- (a turned box: its corners turned with it)
  for i = 0, 7 do
    local ox, oy = (i % 2 == 0) and -hx or hx, (math.floor(i / 2) % 2 == 0) and -hy or hy
    local c = P[i]
    c[1], c[2], c[3] = to_world(p, mx + cs * ox - sn * oy, my + sn * ox + cs * oy, mz + ((i < 4) and -hz or hz))
  end
  for _, e in ipairs(EDGES) do
    local a, b_ = P[e[1]], P[e[2]]
    chef.line(a[1], a[2], a[3], b_[1], b_[2], b_[3], colour)
  end
end
local function draw_boxes(now)
  if not (cfg.struct_boxes and chef.line and N.wcol) then rk.near = nil return end
  local cam = chef.camera()
  if not cam then return end
  -- (3.0.18: its time under "boxes" in the research log's timing line — it is inside the ground's share, and
  -- luka's 3.0.17 log has the ground at 0.7 to 0.9 ms a frame with the boxes on, 0.02 with them off)
  local t0 = cfg.research and N.el_time and os.clock()
  local near = rk.near
  if not near or now - rk.near_at >= 0.5 or rk.near_list ~= rk.list then
    near = {}
    for _, s in ipairs(rk.list) do
      local d2 = (s.x - cam.x) ^ 2 + (s.y - cam.y) ^ 2
      if d2 < BOX_REACH * BOX_REACH and not s.gone then near[#near + 1] = { s, d2 } end
    end
    table.sort(near, function(a, b) return a[2] < b[2] end)
    for i = #near, BOX_UNITS + 1, -1 do near[i] = nil end
    -- (alive asked here, twice a second, not of 60 units every frame; a box drawn is the cached pose's, no call
    -- on the unit)
    for i = #near, 1, -1 do
      if chef.unit_alive and chef.unit_alive(near[i][1].u) ~= true then table.remove(near, i) end
    end
    rk.near, rk.near_at, rk.near_list = near, now, rk.list
  end
  local full = N.wcol(N.LINES, 230)
  for i = 1, #near do
    local p = pose_of(near[i][1])
    if p then box_edges(p, env_of(ROCKS[near[i][1].k]), full) end
  end
  if t0 then N.el_time.boxes = (N.el_time.boxes or 0) + (os.clock() - t0) end
end
local function rock_update(now)
  rk.asks, rk.tests = 0, 0
  for key, l in pairs(rk.last) do if now - l.at > 0.5 then rk.last[key] = nil end end
  draw_boxes(now)
  if cfg.research and (rk.hits > 0 or rk.over) and now - rk.said >= 10 then
    rk.said = now
    log('research: rock hits: %d in the last %s; %d poses asked%s', rk.hits, rk.said_once and '10 s' or 'session', rk.asked, rk.over and string.format('; the box budget ran out %d time(s)', rk.over) or '')
    rk.hits, rk.said_once, rk.over = 0, true, nil
  end
end
N.rock_update = rock_update
-- (3.0.12: the poses too — they're kept by unit, and a new world's unit can come up under an old one's handle; the
-- ground's own caches start over for the same reason, 2.5.3)
local function rock_reset()
  rk.list, rk.grid, rk.n, rk.hits, rk.last, rk.near = {}, {}, nil, 0, {}, nil
  rk.pose = setmetatable({}, { __mode = 'k' })
end
N.rock_reset = rock_reset
