-- NarrowHUD, the enemies' structures (docket 8): the drop or throw line's mark turns red where the shot would hit
-- one — a bug hole, a bot fabricator, an Illuminate warp ship or tower — before it lands. luka (2026-10-31):
-- no marks on enemies (they move); structures, yes.
-- How: the ground walk (12_ground) lists every unit of a structure kind it passes (the kind's name from the
-- censuses against STRUCT_PAT) with its position; a line asks, segment by segment, whether the segment goes into
-- one of the listed structures near it: first the plain distance from the unit's middle to the segment against the
-- unit's box (Unit.box's half sizes, asked once per unit), then the engine's own ray against the box (chef.ray_box:
-- Math.ray_box_intersection, which Chef 1.4 wraps; nothing else in the game raycasts for Lua). A hit before the
-- ground ends the search: the mark is drawn there, in red, and the landing ring not at all. At most RAYS engine
-- rays a frame.
local cfg, call = N.cfg, N.call
-- against the kind's name (content/ cut); the markers and decorations left out. luka: only what a drop line's
-- weapon can destroy — no bunkers, turret bases, detector towers, jammers or gunship factories (hellbomb jobs)
local STRUCT_PAT = {
  'gameplay/[%w_/]*spawner', 'il_laser_tower', 'il_teslatower', 'il_turret', 'spore_light_%d+_objective',
  'bug_hive_chimney', 'shrieker',
}
local NOT_STRUCT = { '_marker$', 'decoration' }
local RAYS = 40                                  -- engine rays a frame, at most
local REACH = 160                                -- metres from the thrower: structures farther are never asked
local sk = {}                                    -- kind id -> true / false: a structure kind
local st = { list = {}, box = setmetatable({}, { __mode = 'k' }), rays = 0, said = -100, hits = 0, asked = 0 }
N.structs = st

local function struct_kind(k)
  local v = sk[k]
  if v ~= nil then return v end
  local name = UNIT_NAMES[k]
  v = false
  if name then
    for _, p in ipairs(STRUCT_PAT) do
      if string.find(name, p) then v = true break end
    end
    for _, p in ipairs(NOT_STRUCT) do
      if string.find(name, p) then v = false break end
    end
  end
  sk[k] = v
  return v
end
N.struct_kind = struct_kind

-- the walk's listing: into `list` (the walk's own table, swapped in when the walk is done)
local function struct_seen(list, u, k, x, y, z)
  list[#list + 1] = { u = u, k = k, x = x, y = y, z = z }
end
N.struct_seen = struct_seen
local function struct_listed(list)
  st.list = list
  if cfg.research and #list > 0 and (st.n ~= #list) then
    st.n = #list
    local counts, names = {}, {}
    for _, s in ipairs(list) do counts[s.k] = (counts[s.k] or 0) + 1 end
    for k, n in pairs(counts) do names[#names + 1] = string.format('%s x%d', string.gsub(UNIT_NAMES[k] or k, '^content/', ''), n) end
    table.sort(names)
    log('research: structures: %d listed: %s', #list, table.concat(names, '; '))
  end
end
N.struct_listed = struct_listed

-- a unit's box (Unit.box's half sizes, once per unit): { hx, hy, hz, r = the half sizes' length, rh = the horizontal
-- half size } or false for none. luka's log: a small bug hole's box is 8 x 9 x 11 m, a medium's 10 x 11 x 12, the
-- large nest's 30 x 30 x 33 — the mesh's whole box, ground and all, so a ray into it says "near the hole", not
-- "in it": the mark goes where the shot then meets the ground inside the footprint (hit, below)
local function box_of(s)
  local bx = st.box[s.u]
  if bx ~= nil then return bx end
  st.asked = st.asked + 1
  local pose, half = call('struct.box.' .. s.k, 'Unit.box', s.u)
  local hx, hy, hz
  if pose ~= nil and half ~= nil then
    hx, hy, hz = call('struct.xyz', 'Vector3.to_elements', half)
    if type(hx) ~= 'number' then
      local a, b, c = string.match(tostring(half), '%(%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)')
      hx, hy, hz = tonumber(a), tonumber(b), tonumber(c)
    end
  end
  bx = false
  if hx and hy and hz and hx == hx and hx < 1e4 and hy < 1e4 and hz < 1e4 and hx > 0.1 and hy > 0.1 and hz > 0.1 then
    bx = { hx, hy, hz, r = math.sqrt(hx * hx + hy * hy + hz * hz), rh = math.max(hx, hy) }
  end
  st.box[s.u] = bx
  if cfg.research then
    log('research: structure box: %s %s', string.gsub(UNIT_NAMES[s.k] or s.k, '^content/', ''), bx and string.format('half %.1f x %.1f x %.1f', hx, hy, hz) or 'none')
  end
  return bx
end

-- the structures within reach of the thrower at ox, oy, for one line (its own table, built once per line)
local function near(ox, oy)
  local out = {}
  for _, s in ipairs(st.list) do
    local dx, dy = s.x - ox, s.y - oy
    if dx * dx + dy * dy < REACH * REACH then out[#out + 1] = s end
  end
  return out
end

-- the squared distance from the point p to the segment a-b
local function seg_dist2(px, py, pz, ax, ay, az, bx, by, bz)
  local vx, vy, vz = bx - ax, by - ay, bz - az
  local l2 = vx * vx + vy * vy + vz * vz
  local t = 0
  if l2 > 0 then
    t = ((px - ax) * vx + (py - ay) * vy + (pz - az) * vz) / l2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
  end
  local dx, dy, dz = ax + vx * t - px, ay + vy * t - py, az + vz * t - pz
  return dx * dx + dy * dy + dz * dz
end

-- does the segment (x1,y1,z1)-(x2,y2,z2) go into a listed structure? -> the hit's x, y, z and the structure, or
-- nil. ls: the line's own state ({} per line; ox, oy the thrower's position on the first call). The ray's entry
-- into the box is only the start: the mark goes where the line then meets the ground (12_ground's guess) while
-- still within the box's footprint; when the line leaves the box first (out of the footprint, or under its
-- bottom) the mark goes at the entry (a wall hit, or the ground unknown there)
local function hit(x1, y1, z1, x2, y2, z2, ls, ox, oy)
  if not chef.ray_box or not cfg.struct_mark then return nil end
  if not ls.near then ls.near = near(ox, oy) end
  if #ls.near == 0 then return nil end
  local vx, vy, vz = x2 - x1, y2 - y1, z2 - z1
  local len = math.sqrt(vx * vx + vy * vy + vz * vz)
  if len < 1e-3 then return nil end
  if not ls.inside then
    for _, s in ipairs(ls.near) do
      local bx = box_of(s)
      if bx and seg_dist2(s.x, s.y, s.z, x1, y1, z1, x2, y2, z2) < (bx.r + 0.5) ^ 2 then
        if st.rays >= RAYS then return nil end
        st.rays = st.rays + 1
        local d = chef.ray_box({ x1, y1, z1 }, { vx, vy, vz }, s.u)
        if type(d) == 'number' and d <= len then
          st.hits = st.hits + 1
          ls.inside = { s = s, bx = bx, x = x1 + vx * d / len, y = y1 + vy * d / len, z = z1 + vz * d / len, gst = { clear = true } }
          break
        end
      end
    end
    if not ls.inside then return nil end
  end
  local i = ls.inside
  local s, bx = i.s, i.bx
  local gx, gy, gz
  if N.ground_cross then gx, gy, gz = N.ground_cross(x1, y1, z1, x2, y2, z2, i.gst) end   -- (`and` would keep one value)
  if gx and (gx - s.x) ^ 2 + (gy - s.y) ^ 2 <= (bx.rh + 0.5) ^ 2 then return gx, gy, gz, s end
  if (x2 - s.x) ^ 2 + (y2 - s.y) ^ 2 > (bx.rh + 0.5) ^ 2 or z2 < s.z - bx[3] then return i.x, i.y, i.z, s end
  return nil
end
N.struct_hit = hit

-- once a frame (13_main): the rays' budget
local function struct_update(now)
  st.rays = 0
  if cfg.research and st.hits > 0 and now - st.said >= 10 then
    st.said = now
    log('research: structure hits: %d in the last %s; %d boxes asked', st.hits, st.said_once and '10 s' or 'session', st.asked)
    st.hits, st.said_once = 0, true
  end
end
N.struct_update = struct_update
local function struct_reset() st.list = {} st.n = nil st.hits = 0 end
N.struct_reset = struct_reset
