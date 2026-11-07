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
-- (2.4.1) 'shrieker' was the pattern: it took the shrieker nest (bug_spawner_shrieker is a spawner anyway, and the
-- objective nest is named here now) but also the shriekers themselves (fac_bugs/cha_shrieker/cha_shrieker, their
-- gloom kind, their meshes) — flying bugs that die and are destroyed, and Unit.box on a destroyed unit ends the
-- game: two players' crashes whenever the stratagem list opened over a shrieker nest (a player's logs, 2026-11-05:
-- one launch "ended inside Unit.box:struct.box.64090088502435dd", cha_shrieker; the next crashed right after two
-- shriekers' boxes were asked as the ball came up). Nothing living is a structure: fac_ (the factions' characters)
-- and m_ (meshes) are left out whatever else matches
-- (2.5.9) the spore spewer is env_bugs/assets/gameplay/bug_fog_generator: luka's MARKs on one (2.5.5's aim-point
-- line) had it 1.9 m from the reticle on the structure, 3.5–3.8 m at its base, intact and destroyed alike (the unit
-- stays, as a bug hole's does). 2.5.2's guess, the plain spore_light_01 / _02, was wrong: they're the hive's small
-- spore lights, 94 of them on one map (his 2.5.5 listing), and the objective's spore_light_0x_objective is a 0.3 m
-- anchor — both out. The Gloom's spore lung stays a guess by name (a gameplay unit like the fog generator)
local STRUCT_PAT = {
  -- (2.5.23, luka: "if we're making a red mark for any of those without a shape, disable it") only the kinds with
  -- a shape from their model (src/struct_parts_generated.lua): the three bug holes, the shrieker nest, the spore
  -- spewer; the tesla tower and the Illuminate turret (the warp ship's hull by hash below); the fabricator (its
  -- variants carry the name) and the big factory; the Automaton guns. Out until they have one: the bug colony's
  -- giant spawner, the hive lung and chimney, the laser tower, the bunker's HMG, the tank's hull MG
  'bug_spawner_small_01', 'bug_spawner_medium_01', 'bug_spawner_large_01', 'bug_spawner_shrieker', 'bug_fog_generator',
  'il_teslatower', 'il_turret_01', 'cyborg_spawner_factory', 'colony_cyborg_spawner',
  'cyborg_tank_turret_cannon', 'cyborg_tank_turret_autocannons', 'cyborg_tank_turret_mortar', 'cyborg_turret_small_autocannon',
}
local NOT_STRUCT = { '_marker$', 'decoration', '^fac_', '/cha_', '/m_' }
-- (2.5.6) structure kinds filediver has no name for, by hash (the Illuminate warp ship's hull, once found): a kind
-- here is a structure whatever its count, and named so in the listings. The hunt so far: 6a1942daca6a49d7 (2.5.6)
-- was a prop, 60 on the next map; 2.5.10's five candidates from the MARKs at a ship's base were its furniture
-- (luka's 2.5.10 log: boxes 1.2–6.8 m across, 10 / 17 / 27 / 28 / 39 on a map of ten ships) — named below for the
-- listings, structures no more. The hull never made a MARK's listing: 12 rows within 15 m, all furniture (2.5.12
-- lists 40 m, with each kind's count on the map)
-- (2.5.16) found: f5f3207ca1b3a5d6, a 23.3 x 33.3 x 11.5 m box, 3 m from luka's MARKs at a ship's base, four on a
-- map of four ships, still there after the kill (the wreck is the same unit, as a bug hole's is) — the 2.5.14 box
-- probe's answer. Its anchor 620769fb47f74906 (a 2 x 2 x 0 box, 29 m under) is no structure
local STRUCT_BY_ID = { ['f5f3207ca1b3a5d6'] = 'il_encounter_ship_landed (the warp ship\'s hull, 23 x 33 x 11.5 m)' }   -- (2.5.19: named by filediver's export)
local KIND_NAMES = {   -- (unnamed kinds known from the hunt, for the listings only)
  ['620769fb47f74906'] = 'il_warp_ship_anchor (2 x 2 x 0 m, 29 m under the ship)',
  ['2718f5edf8cbaf8b'] = 'il_warp_ship_furniture_A (5.4 x 3.8 x 1.4 m, one a ship)', ['b8cd315cb6a31a2f'] = 'il_warp_ship_furniture_B (6 x 2.4 x 6 m, two a ship)',
  ['c924a527039f21ae'] = 'il_warp_ship_furniture_C (6.8 x 3.8 x 5.2 m, three a ship)', ['92ced1c9a7ae1ff6'] = 'il_warp_ship_furniture_D (2.8 x 2.2 x 2.6 m, three a ship)',
  ['cad66c961d161485'] = 'il_warp_ship_furniture_E (1.2 x 1.4 x 2.2 m, four a ship)', ['6a1942daca6a49d7'] = 'il_prop (4.5 x 2.5 x 2.2 m, sixty a map)',
}
N.KIND_NAMES = KIND_NAMES
N.STRUCT_BY_ID = STRUCT_BY_ID
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
  if STRUCT_BY_ID[k] then v = true
  elseif name then
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
function N.debug_struct_by_id(k, name) STRUCT_BY_ID[k] = name sk[k] = nil end   -- (tests: a kind by hash)

-- the walk's listing: into `list` (the walk's own table, swapped in when the walk is done)
local function struct_seen(list, u, k, x, y, z)
  list[#list + 1] = { u = u, k = k, x = x, y = y, z = z }
end
N.struct_seen = struct_seen
local said_near = {}
local function struct_listed(list, unnamed)
  st.list = list
  if cfg.research and #list > 0 and (st.n ~= #list) then
    st.n = #list
    local counts, names = {}, {}
    for _, s in ipairs(list) do counts[s.k] = (counts[s.k] or 0) + 1 end
    for k, n in pairs(counts) do names[#names + 1] = string.format('%s x%d', string.gsub(UNIT_NAMES[k] or STRUCT_BY_ID[k] or KIND_NAMES[k] or k, '^content/', ''), n) end
    table.sort(names)
    log('research: structures: %d listed: %s', #list, table.concat(names, '; '))
  end
  -- (2.5.2, research) the unnamed kinds within 12 m of a listed structure, once per pair: a structure whose named
  -- unit is only an anchor has its mesh (the box the line should hit) in one of these
  if cfg.research and unnamed and #unnamed > 0 then
    local per = {}
    for _, s in ipairs(list) do per[s.k] = (per[s.k] or 0) + 1 end
    for _, s in ipairs(list) do
      local near = {}
      if per[s.k] > 20 then near = nil end   -- (2.5.9: a kind by the dozen is scenery, not a structure to decode)
      for _, q in ipairs(near and unnamed or {}) do
        local dx, dy = q[2] - s.x, q[3] - s.y
        if dx * dx + dy * dy < 144 then
          local key = s.k .. '/' .. q[1]
          if not said_near[key] then near[q[1]] = math.min(near[q[1]] or 999, math.sqrt(dx * dx + dy * dy)) end
        end
      end
      for k, d in pairs(near or {}) do
        said_near[s.k .. '/' .. k] = true
        log('research: structure neighbours: %s has an unnamed kind %s %.1f m away', string.gsub(UNIT_NAMES[s.k] or s.k, '^content/', ''), k, d)
      end
    end
  end
end
N.struct_listed = struct_listed

-- a unit's box (Unit.box's half sizes, once per unit): { hx, hy, hz, r = the half sizes' length, rh = the horizontal
-- half size } or false for none. luka's log: a small bug hole's box is 8 x 9 x 11 m, a medium's 10 x 11 x 12, the
-- large nest's 30 x 30 x 33 — the mesh's whole box, ground and all, so a ray into it says "near the hole", not
-- "in it": the mark goes where the shot then meets the ground inside the footprint (hit, below)
-- (2.5.8) a kind's box, from the first unit of it asked: every other unit of the kind takes the half sizes and
-- the middle's height over the root from it, no Unit.box asked — the one engine call that ended the game on a
-- dying unit (2.4.1) is made once per kind per session, not once per structure per walk
local kind_box = {}
-- (2.5.14, the warp ship hunt) a unit's box asked once, for the MARK line: half sizes and the middle's height over
-- the unit, or nil. Alive-checked the same frame, as box_of; only at a MARK, a dozen units at most
function N.box_probe(u, k)
  if chef.unit_alive and chef.unit_alive(u) ~= true then return nil, 'gone' end
  local pose, half = call('struct.box.' .. k, 'Unit.box', u)
  if pose == nil or half == nil then return nil, 'no box' end
  local hx, hy, hz = call('struct.xyz', 'Vector3.to_elements', half)
  if type(hx) ~= 'number' then
    local a, b, c = string.match(tostring(half), '%(%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)')
    hx, hy, hz = tonumber(a), tonumber(b), tonumber(c)
  end
  if not (hx and hy and hz and hx == hx) then return nil end
  local tx, ty, tz = N.xyz(call('struct.boxc', 'Matrix4x4.translation', pose))
  local ux, uy, uz = chef.unit_position and chef.unit_position(u)
  local dz = (tz and tz == tz and uz) and (tz - uz) or nil
  return hx, hy, hz, dz
end
-- (2.5.11, luka: the spore spewer's box is its whole mushroom, 19 x 19 x 19 m, and the mark went red in the air
-- under the cap) kinds whose box is far bigger than the thing: the parts the shot can hit, each a box of its own
-- inside the kind's. A hit on a part is a hit on the thing itself (the mark at the entry, as on a wall), not a bug
-- hole's "the ground inside the footprint".
-- (2.5.15, luka: "we can change the size, shape and position of the box to where it only shows red when the shot
-- would go in") a part is { fx, fy, z0, z1, ox, oy, pitch, roll, yaw }: its half widths as fractions of the box's
-- (fx, fy), the slab from z0 to z1 of the box's height from the bottom up, its middle moved ox, oy of the box's
-- half widths (x right, y forward, in the unit's frame), and its own turn in degrees about its middle (pitch about
-- x, roll about y, yaw about z); the last five 0 when left out. The layout file's `struct_parts` block overrides
-- a kind's list (keyed by a piece of the kind's name: `struct_parts = { bug_spawner_small_01 = { { 0.4, 0.3, 0.1,
-- 0.6, 0.3, -0.2 } } }`), read again on the reload key, so the red lines (Testing "Draw structure boxes") can be
-- fitted to the mesh without a build. The spewer: a stalk 0.3 of the box across, the whole height; the cap, the
-- box's full width, its top 45 %
-- (2.5.18) the built-in parts come from the meshes: tools/make_shapes.py reads filediver's unit exports and
-- writes src/struct_parts_generated.lua (STRUCT_PARTS: a kind's `hit` boxes — a hole's shaft and mouth, a nest's
-- trunk and cap — and `stop` boxes for later). The 2.5.11 spewer guess stays as the fallback for a kind the file
-- doesn't have
local PARTS = {}
for k, v in pairs(STRUCT_PARTS or {}) do
  if v.abs and #v.abs > 0 then PARTS[k] = { abs = v.abs } elseif v.hit and #v.hit > 0 then PARTS[k] = v.hit end
end
if not PARTS.bug_fog_generator then PARTS.bug_fog_generator = { { 0.3, 0.3, 0, 1 }, { 1, 1, 0.55, 1 } } end
local parts_file = nil                           -- the layout file's block, checked
local function rot3(pitch, roll, yaw)            -- R = Rz(yaw) Rx(pitch) Ry(roll), degrees; nil when all 0
  if pitch == 0 and roll == 0 and yaw == 0 then return nil end
  local a, b, c = math.rad(pitch), math.rad(roll), math.rad(yaw)
  local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
  -- Rx(pitch) Ry(roll)
  local m = { { cb, 0, sb }, { sa * sb, ca, -sa * cb }, { -ca * sb, sa, ca * cb } }
  -- Rz(yaw) times that
  return {
    { cc * m[1][1] - sc * m[2][1], cc * m[1][2] - sc * m[2][2], cc * m[1][3] - sc * m[2][3] },
    { sc * m[1][1] + cc * m[2][1], sc * m[1][2] + cc * m[2][2], sc * m[1][3] + cc * m[2][3] },
    { m[3][1], m[3][2], m[3][3] },
  }
end
-- (2.5.21) lx, ly, dz: the box middle's offset from the root (right, forward, up); the generated parts are in
-- metres from the root (`abs`), the layout file's in fractions of the box — a fraction scales with the box, and
-- the fabricator's variants have boxes of four sizes round one mesh, so the mesh's parts must not
local function parts_of(k, hx, hy, hz, lx, ly, dz0)
  local name = UNIT_NAMES[k] or STRUCT_BY_ID[k] or KIND_NAMES[k] or k   -- (a kind by hash: its name here, or the hash)
  if not name then return nil end
  local function from(src)   -- the longest key found in the name wins (bug_spawner_small_01 over bug_spawner)
    local best, bl
    for key, l in pairs(src) do
      if string.find(name, key, 1, true) and (not bl or #key > bl) then best, bl = l, #key end
    end
    return best
  end
  local list = (parts_file and from(parts_file)) or from(PARTS)   -- (the file's first)
  if not list then return nil end
  local out = {}
  local function abs_part(p)   -- metres from the root: { hx, hy, hz, cx, cy, cz }
    out[#out + 1] = { p[1], p[2], p[3], dx = p[4] - (lx or 0), dy = p[5] - (ly or 0), dz = p[6] - (dz0 or 0), spec = p }
  end
  if list.abs then
    for _, p in ipairs(list.abs) do abs_part(p) end
    return out
  end
  for _, p in ipairs(list) do
    if p.m then abs_part(p.m)   -- (the layout file's metres form: { m = { hx, hy, hz, cx, cy, cz } })
    else
      out[#out + 1] = { hx * p[1], hy * p[2], hz * (p[4] - p[3]), dx = hx * (p[5] or 0), dy = hy * (p[6] or 0), dz = -hz + hz * (p[3] + p[4]),
        R = rot3(p[7] or 0, p[8] or 0, p[9] or 0), spec = p }   -- (dx, dy, dz: the part's middle from the box's, in the unit's frame)
    end
  end
  return out
end
-- the layout file's block (10_custom's load_layout hands it over, nil for none): each entry a list of parts, each
-- a list of 4 to 9 numbers with fx, fy in (0, 1], 0 <= z0 < z1 <= 1; what doesn't fit is dropped and logged.
-- Every box's parts are made afresh (no engine call: the half sizes are kept per kind)
function N.struct_parts_set(t)
  local ok_t, bad = nil, {}
  if type(t) == 'table' then
    ok_t = {}
    for key, list in pairs(t) do
      local good = type(key) == 'string' and type(list) == 'table' and {} or nil
      for _, p in ipairs(good and list or {}) do
        local fine
        if type(p) == 'table' and type(p.m) == 'table' then   -- (2.5.21) metres from the root: six numbers, half sizes over 0
          local m = p.m
          fine = #m == 6
          for i = 1, 6 do if type(m[i]) ~= 'number' or m[i] ~= m[i] then fine = false end end
          if fine then fine = m[1] > 0 and m[2] > 0 and m[3] > 0 end
        else
          fine = type(p) == 'table' and #p >= 4 and #p <= 9
          for i = 1, (fine and #p or 0) do if type(p[i]) ~= 'number' or p[i] ~= p[i] then fine = false end end
          if fine then fine = p[1] > 0 and p[1] <= 1 and p[2] > 0 and p[2] <= 1 and p[3] >= 0 and p[4] > p[3] and p[4] <= 1 end
        end
        if fine then good[#good + 1] = p else bad[#bad + 1] = tostring(key) end
      end
      if good and #good > 0 then ok_t[key] = good elseif not good then bad[#bad + 1] = tostring(key) end
    end
  end
  parts_file = ok_t
  for k, kb in pairs(kind_box) do kb.parts = parts_of(k, kb[1], kb[2], kb[3], kb.lx, kb.ly, kb.dz) end
  for u, bx in pairs(st.box) do if bx and bx.k and kind_box[bx.k] then bx.parts = kind_box[bx.k].parts end end
  if ok_t then
    local n = 0
    for _ in pairs(ok_t) do n = n + 1 end
    log('structure parts: %d kind(s) from the layout file%s', n, #bad > 0 and (', dropped: ' .. table.concat(bad, ', ')) or '')
  elseif t ~= nil then
    log('structure parts: the layout file\'s struct_parts is not a table, ignored')
  end
end
-- a ray from (fx, fy, fz) along (dx, dy, dz) against a box's part: the ray into the part's own frame (the box's
-- yaw, the part's offset and turn), then Chef's box at the origin (an identity pose, no unit asked)
local function ray_part(fx, fy, fz, dx, dy, dz, bx, p)
  local c, s_ = math.cos(bx.yaw), math.sin(bx.yaw)
  local px, py, pz = fx - bx.cx, fy - bx.cy, fz - bx.cz
  local lx, ly, lz = px * c - py * s_ - p.dx, px * s_ + py * c - p.dy, pz - p.dz
  local vx, vy, vz = dx * c - dy * s_, dx * s_ + dy * c, dz
  local R = p.R
  if R then   -- into the part's frame: R^T (R is orthonormal)
    lx, ly, lz = R[1][1] * lx + R[2][1] * ly + R[3][1] * lz, R[1][2] * lx + R[2][2] * ly + R[3][2] * lz, R[1][3] * lx + R[2][3] * ly + R[3][3] * lz
    vx, vy, vz = R[1][1] * vx + R[2][1] * vy + R[3][1] * vz, R[1][2] * vx + R[2][2] * vy + R[3][2] * vz, R[1][3] * vx + R[2][3] * vy + R[3][3] * vz
  end
  return chef.ray_box({ lx, ly, lz }, { vx, vy, vz }, { x = 0, y = 0, z = 0, yaw = 0 }, { p[1], p[2], p[3] })
end
-- a part's corner (its own frame) in the world
local function part_point(bx, p, x, y, z)
  local R = p.R
  if R then x, y, z = R[1][1] * x + R[1][2] * y + R[1][3] * z, R[2][1] * x + R[2][2] * y + R[2][3] * z, R[3][1] * x + R[3][2] * y + R[3][3] * z end
  local lx, ly, lz = x + p.dx, y + p.dy, z + p.dz
  local c, s_ = math.cos(bx.yaw), math.sin(bx.yaw)
  return bx.cx + lx * c + ly * s_, bx.cy - lx * s_ + ly * c, bx.cz + lz
end
local function box_of(s)
  if s.gone then return false end
  local bx = st.box[s.u]
  if bx ~= nil then return bx end
  local kb = kind_box[s.k]
  if kb then
    bx = { kb[1], kb[2], kb[3], r = kb.r, rh = kb.rh, cx = s.x, cy = s.y, cz = s.z + kb.dz, yaw = 0, from = 'the kind', parts = kb.parts, k = s.k }
    if chef.unit_rotation and chef.unit_alive and chef.unit_alive(s.u) == true then
      local _, _, _, yaw = chef.unit_rotation(s.u)
      if type(yaw) == 'number' and yaw == yaw then bx.yaw = yaw end
    end
    -- (2.5.17, luka: "the box around the nest rotated 180 degrees between one mission and the next") the kind's
    -- box middle is off its root sideways too (the mound to one side), kept in the unit's frame (kb.lx, kb.ly) and
    -- turned by this unit's yaw — it was dropped, so every nest but the first asked had its box on the root, which
    -- on a nest facing the other way looks like the box turned round
    local c, sn = math.cos(bx.yaw), math.sin(bx.yaw)
    bx.cx, bx.cy = s.x + kb.lx * c + kb.ly * sn, s.y - kb.lx * sn + kb.ly * c
    st.box[s.u] = bx
    return bx
  end
  st.asked = st.asked + 1
  -- (2.4.1) a unit destroyed since the walk listed it: never asked (Unit.box on one ends the game; chef.call checks
  -- only the world, not Unit.alive). Its box stays unknown (nil), not false: a later walk lists it afresh if it's back
  if chef.unit_alive and chef.unit_alive(s.u) ~= true then return false end
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
    bx = { hx, hy, hz, r = math.sqrt(hx * hx + hy * hy + hz * hz), rh = math.max(hx, hy), cx = s.x, cy = s.y, cz = s.z, yaw = 0, from = 'the root', k = s.k }
    -- (2.5.8) the box's own middle and yaw, kept with it, so every ray after this is against a box of ours
    -- (chef.ray_box with a middle and extents: Vector3s and an identity pose, no unit asked) — the engine's
    -- Unit.box was asked on every ray before, and Unit.box of a unit destroyed since (the warp ship goes, its
    -- wreck is another unit) ended the game in 2.4.1. The middle from the pose's translation where the engine
    -- answers, else the root; the yaw from chef.unit_rotation, else 0 (an upright box either way)
    local tx, ty, tz = N.xyz(call('struct.boxc', 'Matrix4x4.translation', pose))
    if tx and tx == tx and math.abs(tx - s.x) < 50 and math.abs(ty - s.y) < 50 and math.abs(tz - s.z) < 50 then bx.cx, bx.cy, bx.cz, bx.from = tx, ty, tz, 'the pose' end
    if chef.unit_rotation then
      local fx, fy, fz, yaw = chef.unit_rotation(s.u)
      if type(yaw) == 'number' and yaw == yaw then bx.yaw = yaw end
    end
  end
  st.box[s.u] = bx
  if bx then
    -- the middle's offset from the root in the unit's frame (right, forward, up), for the kind's other units
    local c, sn = math.cos(bx.yaw), math.sin(bx.yaw)
    local ox, oy = bx.cx - s.x, bx.cy - s.y
    local lx, ly, dz = ox * c - oy * sn, ox * sn + oy * c, bx.cz - s.z
    bx.parts = parts_of(s.k, hx, hy, hz, lx, ly, dz)
    kind_box[s.k] = { bx[1], bx[2], bx[3], r = bx.r, rh = bx.rh, lx = lx, ly = ly, dz = dz, parts = bx.parts }
  end
  if cfg.research then
    log('research: structure box: %s %s', string.gsub(UNIT_NAMES[s.k] or STRUCT_BY_ID[s.k] or KIND_NAMES[s.k] or s.k, '^content/', ''),
      bx and string.format('half %.1f x %.1f x %.1f, the middle from %s (%.1f, %.1f, %.1f; %.1f m right, %.1f m forward, %.1f m up of the root), yaw %.2f; the kind\'s from now on',
        hx, hy, hz, bx.from, bx.cx, bx.cy, bx.cz, kind_box[s.k].lx, kind_box[s.k].ly, kind_box[s.k].dz, bx.yaw) or 'none')
    if bx and bx.parts then
      local ps = {}
      for _, p in ipairs(bx.parts) do
        ps[#ps + 1] = string.format('%.1f x %.1f m, %.1f to %.1f m up%s%s', p[1] * 2, p[2] * 2, p.dz - p[3] + hz, p.dz + p[3] + hz,
          (p.dx ~= 0 or p.dy ~= 0) and string.format(', moved %+.1f right %+.1f forward', p.dx, p.dy) or '',
          p.R and string.format(', turned pitch %g roll %g yaw %g', p.spec[7] or 0, p.spec[8] or 0, p.spec[9] or 0) or '')
      end
      log('research: structure parts: %s: the shot hits only %s', string.gsub(UNIT_NAMES[s.k] or s.k, '^content/', ''), table.concat(ps, '; '))
    end
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
  if N.units_held and N.units_held(N.now or chef.time()) then return nil end   -- (2.4.7: dead, in the hellpod, just landed)
  if not ls.near then ls.near = near(ox, oy) end
  if #ls.near == 0 then return nil end
  local vx, vy, vz = x2 - x1, y2 - y1, z2 - z1
  local len = math.sqrt(vx * vx + vy * vy + vz * vz)
  if len < 1e-3 then return nil end
  if not ls.inside then
    for _, s in ipairs(ls.near) do
      local bx = box_of(s)
      if bx and seg_dist2(bx.cx, bx.cy, bx.cz, x1, y1, z1, x2, y2, z2) < (bx.r + 0.5) ^ 2 then
        if st.rays >= RAYS then return nil end
        -- (2.5.7, luka's question) Chef's ray_box asks Unit.box of the unit on every call, and Unit.box of a
        -- destroyed unit ends the game (2.4.1): a structure destroyed since its box was cached (a hole closed, a
        -- ship killed) is checked alive before each ray, and dropped from the list's boxes once gone, until a walk
        -- lists it afresh
        -- (2.5.8: the ray against the cached box — no unit asked, so a structure gone since is no danger; the
        -- 2.5.7 alive check stays for the listing's sake: a gone one is dropped until a walk lists it afresh)
        if chef.unit_alive and chef.unit_alive(s.u) ~= true then
          st.box[s.u] = false
          s.gone = true
        else
        local d
        if bx.parts then   -- (2.5.11) the parts the shot can hit, the nearest entry of them
          for _, p in ipairs(bx.parts) do
            st.rays = st.rays + 1
            local dp = ray_part(x1, y1, z1, vx, vy, vz, bx, p)
            if type(dp) == 'number' and dp <= len and (not d or dp < d) then d = dp end
          end
        else
          st.rays = st.rays + 1
          d = chef.ray_box({ x1, y1, z1 }, { vx, vy, vz }, { x = bx.cx, y = bx.cy, z = bx.cz, yaw = bx.yaw }, { bx[1], bx[2], bx[3] })
        end
        if type(d) == 'number' and d <= len then
          st.hits = st.hits + 1
          ls.inside = { s = s, bx = bx, x = x1 + vx * d / len, y = y1 + vy * d / len, z = z1 + vz * d / len, gst = { clear = true }, solid = bx.parts and true or false }
          break
        end
        end
      end
    end
    if not ls.inside then return nil end
  end
  local i = ls.inside
  local s, bx = i.s, i.bx
  if i.solid then return i.x, i.y, i.z, s end   -- (a part hit: the thing itself, as a wall)
  local gx, gy, gz
  if N.ground_cross then gx, gy, gz = N.ground_cross(x1, y1, z1, x2, y2, z2, i.gst) end   -- (`and` would keep one value)
  if gx and (gx - bx.cx) ^ 2 + (gy - bx.cy) ^ 2 <= (bx.rh + 0.5) ^ 2 then return gx, gy, gz, s end
  if (x2 - bx.cx) ^ 2 + (y2 - bx.cy) ^ 2 > (bx.rh + 0.5) ^ 2 or z2 < bx.cz - bx[3] then return i.x, i.y, i.z, s end
  return nil
end
N.struct_hit = hit

-- once a frame (13_main): the rays' budget
-- (2.5.13, luka: "render the hitbox with red lines, so we both see how far off the model is from the game") F9
-- Testing "Draw structure boxes": every listed structure within 120 m of the camera gets its box's twelve edges
-- drawn in the world — the kind's whole box in a dim red, the parts the shot hits (the spewer's stalk and cap) in
-- full red. Chef's world lines, a dozen or two a structure; the boxes come from box_of (Unit.box once per kind)
local function box_edges(bx, p, c)   -- (p: a part of the box, or nil for the box itself)
  local P = {}
  local hx, hy, hz = (p or bx)[1], (p or bx)[2], (p or bx)[3]
  for i = 0, 7 do
    local sx_, sy_, sz_ = (i % 2 == 0) and -hx or hx, (math.floor(i / 2) % 2 == 0) and -hy or hy, (i < 4) and -hz or hz
    local wx, wy, wz = part_point(bx, p or { dx = 0, dy = 0, dz = 0 }, sx_, sy_, sz_)
    P[i] = { wx, wy, wz }
  end
  for _, e in ipairs({ { 0, 1 }, { 2, 3 }, { 0, 2 }, { 1, 3 }, { 4, 5 }, { 6, 7 }, { 4, 6 }, { 5, 7 }, { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 } }) do
    local a, b = P[e[1]], P[e[2]]
    chef.line(a[1], a[2], a[3], b[1], b[2], b[3], c)
  end
end
local function draw_boxes()
  if not (cfg.struct_boxes and chef.line and N.wcol) then return end
  local cam = chef.camera()
  if not cam then return end
  local dim, full = N.wcol(N.RED, 90), N.wcol(N.RED, 230)
  for _, s in ipairs(st.list) do
    if (s.x - cam.x) ^ 2 + (s.y - cam.y) ^ 2 < 120 * 120 then
      local bx = box_of(s)
      if bx and not (chef.unit_alive and chef.unit_alive(s.u) ~= true) then
        box_edges(bx, nil, bx.parts and dim or full)
        for _, p in ipairs(bx.parts or {}) do box_edges(bx, p, full) end
      end
    end
  end
end
local function struct_update(now)
  st.rays = 0
  draw_boxes()
  if cfg.research and st.hits > 0 and now - st.said >= 10 then
    st.said = now
    log('research: structure hits: %d in the last %s; %d boxes asked', st.hits, st.said_once and '10 s' or 'session', st.asked)
    st.hits, st.said_once = 0, true
  end
end
N.struct_update = struct_update
local function struct_reset() st.list = {} st.n = nil st.hits = 0 kind_box = {} end   -- (2.5.8: a new world's kinds may be built anew)
N.struct_reset = struct_reset
