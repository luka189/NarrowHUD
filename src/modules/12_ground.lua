-- NarrowHUD, the ground (docket 7): a guess at the ground's height anywhere on the map, for a landing mark where the
-- drop and throw lines meet it. luka's scoping (2026-10-31): no marks on enemies (they move; the detection lags); a
-- height map from where things stand; marks on the enemies' structures (later).
-- What stands on the ground: the map itself. luka's logs (2.0.11-2.0.12): a mission world holds 10-22k units of
-- 500-850 kinds, the thousands being the map's rocks, trees and bushes, spread over the whole map (10,684 cells of
-- 5 m on a city map against the 503 one player walked in eight minutes), and a kind's root sits at a fixed height
-- against the ground — six kinds at 0.0 +-0.1 m, others sunk a fixed 0.5-3 m, consistent to half a metre. So:
-- - the feet grid: every Helldiver unit's position every 0.25 s (yours and your teammates': the engine's units, on
--   every machine, never the host's objects), into 5 m cells, unless it's falling, flying or jumping (the height
--   moving faster than 3 m/s): the truth where someone has walked;
-- - the walk: every unit in the world (World.units, as Chef's own camera search walks it; each unit checked alive
--   before it's asked anything, the list being frames old), its kind by Unit.debug_name (cached per unit), its
--   position (Unit.world_position with its node, 1); a count of the kinds first, then 100 units a frame on a
--   world's first walk of positions, 20 after, over and over (the enemies move; the map streams). Never the runtime-built kind (asking where one is ends the game,
--   Chef's note), the Helldivers' own things (vehicles, hellpods, what comes out of them), the enemies' hand weapons,
--   or an unnamed kind with fewer than 10 units (the odd networked thing);
-- - per kind, the height offset: unit z minus the feet grid's height in the same cell, summed over the cells where
--   both exist (each cell once per kind); a kind with 3 cells and a spread of 0.6 m or under is trusted, and its
--   units become ground samples (z minus the offset). Kept in the learned file ("sum,sumsq,n" per kind; kinds are
--   per biome, mostly, so each biome teaches its own once) and shipped as a seed from luka's logs;
-- - the height at a point: the cell's feet (2+ samples), else the median of its trusted units, else the cells
--   around within 15 m weighted by nearness, else the lowest untrusted unit in the cell (loose). The confidence
--   goes with it: the mark is drawn faint past the feet and the trusted props.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, call, learned = N.cfg, N.call, N.learned
local clock = os and os.clock or function() return 0 end
local AVATAR_RESOURCE = '4d1c334d294dfa97'   -- the third-person Helldiver unit (05_hand's watch)
local RUNTIME = '46cab355bd8d4d37'            -- runtime-built units: never asked where they are
local CELL = 5                                -- metres
local MAX_CELLS = 40000
local MAX_US = 6                              -- trusted unit heights kept per cell
local TRUST_N, TRUST_SD = 3, 0.6
local gr = { cells = {}, n = 0, samples = 0, skipped = 0, last = {}, at = -100, said = -100, full = false,
             kinds = {}, walks = 0, dirty = false }
N.ground = gr
local watch = chef.watch and chef.watch({ [AVATAR_RESOURCE] = true }, 2) or nil
-- (2.4.3) the vehicles a Helldiver rides in: every exosuit, the FRVs, the tank (their bodies, by unit kind). A
-- Helldiver in one moves at walking or driving speed 2-3 m over the ground, which the 3 m/s rule can't tell from
-- walking: luka's 2026-11-04 mission, a quarter of it in an exosuit, pulled 12 kinds' offsets past trust (their
-- spread 0.3-0.6 m before, 0.6-1.4 after; 89 trusted kinds in the seed without it, 78 with). A Helldiver unit within
-- VEH_R metres (across) of one, at the live position, gives no feet sample; teammates' rides too (their units are
-- the engine's, and the vehicle's unit is near them whoever drives)
local VEHICLE_KINDS = {}
for id in string.gmatch([[
79e4b3d2da5e45e3 17c5d12d8d5dee2c bf4167fd26917ab1 35dbf54f016f3624 df51fe8d62f294be 0736bee2d6328726 7b2326f6fd9c8069
a526dc7d89ff696d 824b7e0c4c879eb5 c2d449ecf7facab1 65489809a8181b96 08f6089289c83d22 cc21c7ffd3ebefb9 e9cd1d0d118886af
2d85bfe3d8717fe5 0df7e312f561f8b9 9b2140378640432e 16474112801385b6
]], '%x+') do VEHICLE_KINDS[id] = true end
local VEH_R = 3.5
local vwatch = chef.watch and chef.watch(VEHICLE_KINDS, 1) or nil
local vpos, vkind = {}, {}                    -- (this sample's vehicles: x, y pairs, and their kinds)
local vsaid = {}                              -- (research: a kind seen, a Helldiver at one: said once a mission each)
local function vname(k) local n = UNIT_NAMES and UNIT_NAMES[k] return n and n:match('[^/]+$') or k end

local function cell_key(x, y)
  return (math.floor(x / CELL) + 50000) * 100000 + (math.floor(y / CELL) + 50000)
end
local function cell_of(x, y, make)
  local k = cell_key(x, y)
  local c = gr.cells[k]
  if c == nil and make then
    if gr.n >= MAX_CELLS then gr.full = true return nil, k end
    c = { fs = 0, fn = 0, us = nil, lo = nil, lz = nil, ln = 0 }   -- (lz / ln: the lowest look point seen, 2.2.5)
    gr.cells[k] = c
    gr.n = gr.n + 1
  end
  return c, k
end

------------------------------------------------------------------------------------------ the kinds' offsets
-- "sum,sumsq,n" in the learned file (learned.ground, 16-hex kind ids) and the seed
local function kind_stats(k)
  local st = gr.kinds[k]
  if st then return st end
  st = { d = 0, d2 = 0, n = 0, seen = {} }
  local saved = learned.ground and learned.ground[k]
  if type(saved) == 'string' then
    local a, b, c = string.match(saved, '^([-%d%.e]+),([-%d%.e]+),(%d+)$')
    if a then st.d, st.d2, st.n = tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0 end
  end
  st.d0, st.d20, st.n0 = st.d, st.d2, st.n                -- what came from the file/seed (the research line reports this session's share)
  gr.kinds[k] = st
  return st
end
local function kind_offset(st)
  if st.n < TRUST_N then return nil end
  local mean = st.d / st.n
  local sd = math.sqrt(math.max(0, st.d2 / st.n - mean * mean))
  if sd > TRUST_SD or math.abs(mean) > 8 then return nil end
  return mean, sd
end
local function kind_learn(k, st, ck, dz)
  if st.seen[ck] then return end
  st.seen[ck] = true
  st.d, st.d2, st.n = st.d + dz, st.d2 + dz * dz, st.n + 1
  if st.n <= 60 and learned.ground then                 -- (enough: the file isn't rewritten for every cell after)
    learned.ground[k] = string.format('%.2f,%.2f,%d', st.d, st.d2, st.n)
    N.dirty_at = N.dirty_at or (chef.time() + 10)
  end
end
N.ground_kind_offset = function(k) local st = gr.kinds[k] return st and kind_offset(st) end

------------------------------------------------------------------------------------------ samples
-- a feet sample at x, y
local function sample(x, y, z)
  local c = cell_of(x, y, true)
  if not c then return end
  c.fs, c.fn = c.fs + z, c.fn + 1
  gr.samples = gr.samples + 1
end
N.ground_sample = sample
-- a unit of kind k standing at x, y, z
local function unit_sample(k, x, y, z)
  local c, ck = cell_of(x, y, true)
  if not c then return end
  local st = kind_stats(k)
  if c.fn >= 2 then kind_learn(k, st, ck, z - c.fs / c.fn) end
  local off = kind_offset(st)
  if off then
    local us = c.us
    if not us then us = {} c.us = us end
    local g = z - off
    if #us < MAX_US then us[#us + 1] = g else us[(gr.walks % MAX_US) + 1] = g end
  else
    if c.lo == nil or z < c.lo then c.lo = z end
  end
end
N.ground_unit_sample = unit_sample

------------------------------------------------------------------------------------------ the height at a point
local function median(t)
  local n = #t
  if n == 0 then return nil end
  if n == 1 then return t[1] end
  local s = {}
  for i = 1, n do s[i] = t[i] end
  table.sort(s)
  if n % 2 == 1 then return s[(n + 1) / 2] end
  return (s[n / 2] + s[n / 2 + 1]) / 2
end
-- a cell's own height and how sure: 'feet', 'look', 'props', or nil
-- (2.2.5: 'look' — the lowest point the view has met in the cell (the game's own raycast, below), between feet and
-- props: luka's crossbow run had our model a median 0.5 m under the look point, 90 % within 3–4 m, the look point on
-- flat ground within 0.1 m of the feet)
local function cell_height(c)
  if c == nil then return nil end
  if c.fn >= 2 then return c.fs / c.fn, 'feet' end
  if c.ln >= 1 and c.lz then return c.lz, 'look' end
  if c.us and #c.us > 0 then return median(c.us), 'props' end
  return nil
end
-- the height at x, y and the confidence: 'feet', 'props', 'near' (interpolated within 15 m), 'loose' (the lowest
-- untrusted unit), or nil
local function height_at(x, y)
  local c = cell_of(x, y, false)
  local h, conf = cell_height(c)
  if h then return h, conf end
  local cx, cy = math.floor(x / CELL), math.floor(y / CELL)
  -- the known cells round the point: the distance-weighted mean, and a least-squares plane through them
  local function ring(reach)
    local wsum, zsum, n = 0, 0, 0
    local sx, sy, sz, sxx, syy, sxy, sxz, syz = 0, 0, 0, 0, 0, 0, 0, 0
    for i = -reach, reach do
      for j = -reach, reach do
        if i ~= 0 or j ~= 0 then
          local nc = gr.cells[(cx + i + 50000) * 100000 + (cy + j + 50000)]
          local nh = cell_height(nc)
          if nh then
            local mx, my = (cx + i + 0.5) * CELL, (cy + j + 0.5) * CELL
            local d = math.sqrt((mx - x) ^ 2 + (my - y) ^ 2)
            local w = 1 / (1 + d)
            wsum, zsum, n = wsum + w, zsum + w * nh, n + 1
            local ux, uy = mx - x, my - y                  -- (the plane fit about the point itself)
            sx, sy, sz = sx + ux, sy + uy, sz + nh
            sxx, syy, sxy, sxz, syz = sxx + ux * ux, syy + uy * uy, sxy + ux * uy, sxz + ux * nh, syz + uy * nh
          end
        end
      end
    end
    if n == 0 then return nil end
    local plane = nil
    if n >= 3 then
      local mxx, myy, mxy = sxx - sx * sx / n, syy - sy * sy / n, sxy - sx * sy / n
      local mxz, myz = sxz - sx * sz / n, syz - sy * sz / n
      local det = mxx * myy - mxy * mxy
      if det > 1e-6 then
        local b, c = (mxz * myy - myz * mxy) / det, (myz * mxx - mxz * mxy) / det
        plane = (sz - b * sx - c * sy) / n               -- (the plane's height at ux = uy = 0: the point)
      elseif mxx + myy > 1e-6 then
        -- (the cells in a line, as along a path walked: the slope along that line)
        local ax, ay
        if mxx >= myy then ax, ay = mxx, mxy else ax, ay = mxy, myy end
        local al = math.sqrt(ax * ax + ay * ay)
        ax, ay = ax / al, ay / al
        local st = sx * ax + sy * ay
        local stt = ax * ax * sxx + 2 * ax * ay * sxy + ay * ay * syy
        local stz = ax * sxz + ay * syz
        local vtt = stt - st * st / n
        if vtt > 1e-6 then
          local b = (stz - st * sz / n) / vtt
          plane = (sz - b * st) / n
        end
      end
    end
    return zsum / wsum, n, plane
  end
  -- (2.2.8) the slope carried on, downhill only: the known cells round an unviewed one are where you walked and
  -- looked — uphill of it on a slope falling away — so their mean sits too high and the mark floats (luka's 2.2.7
  -- run: of the marks our model put over a metre above the look point, all but two were 'near' or 'props' guesses,
  -- none a viewed cell). The plane through the known cells (the near ring when it has three, else the wide one),
  -- evaluated at the point, is taken where it's lower than the mean, down to 20 m under it (uphill it overshoots,
  -- HUDdle's finding too)
  local h1, n1, p1 = ring(1)
  local h, plane = h1, p1
  if n1 == nil or n1 < 3 then
    local h3, n3, p3 = ring(3)
    if h == nil then h = h3 end
    if plane == nil then plane = p3 end
  end
  if h then
    if plane and plane < h then h = math.max(h - 20, plane) end
    return h, 'near'
  end
  if c and c.lo then return c.lo, 'loose' end
  return nil
end
N.ground_height = height_at
-- where the segment (x1,y1,z1)-(x2,y2,z2) goes into the ground: the point and the confidence, or nil. Only a
-- real crossing counts: the first end over the ground and the second under it, after the line has been clearly
-- over the ground (0.3 m above a known height) somewhere before — a segment that starts under the guess (the
-- hand, in a cell the guess has too high) is no landing, and neither is one whose start is already under
-- (the crossing was earlier: inside the gate, or in a cell with no guess). (2.0.14, luka's first run: near him
-- the ring floated at hand height a metre or three away; far out it sat on the ground. His second: a ring on the
-- ground right at the gate's edge when the shot had landed well inside it — the a1 <= 0 case.)
local function ground_cross(x1, y1, z1, x2, y2, z2, st)
  local h1 = height_at(x1, y1)
  if h1 and z1 - h1 > 0.3 then st.clear = true end
  local h2, conf = height_at(x2, y2)
  if not h2 or z2 > h2 or not st.clear then return nil end
  h1 = h1 or h2
  local a1, a2 = z1 - h1, z2 - h2                     -- heights above the ground at the two ends
  if a1 <= 0 then return nil end
  local t = a1 / (a1 - a2)
  if t ~= t or t < 0 or t > 1 then t = 1 end
  local cx, cy = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
  -- (2.1.4: the confidence at the crossing itself, not at the segment's far end: a segment ending a cell past a
  -- walked one drew the ring faint)
  local _, cconf = height_at(cx, cy)
  return cx, cy, h1 + (h2 - h1) * t, cconf or conf
end
N.ground_cross = ground_cross
-- the landing of a line's segment, as the lines use it, with st the line's own state ({} per line: whether it
-- has been clearly over the ground yet; whether it has landed): nothing within from_m metres (horizontal) of the
-- thrower — the guess is worst right at your feet and the line is flattest there (20 m for a drop line, 7 m for
-- a throw or the Ultimatum's lob, luka's second run) — but a line that goes under sure ground (feet, props) in
-- there has landed: no ring past the gate either. Else ground_cross.
local function landing(x1, y1, z1, x2, y2, z2, px, py, st, from_m)
  if st.landed then return nil end
  from_m = from_m or 20
  if px and (x2 - px) ^ 2 + (y2 - py) ^ 2 < from_m * from_m then
    local h1 = height_at(x1, y1)
    if h1 and z1 - h1 > 0.3 then st.clear = true end
    if st.clear then
      local h2, conf = height_at(x2, y2)
      if h2 and z2 < h2 and (conf == 'feet' or conf == 'look' or conf == 'props') then st.landed = true end
    end
    return nil
  end
  return ground_cross(x1, y1, z1, x2, y2, z2, st)
end
N.ground_landing = landing

------------------------------------------------------------------------------------------ the feet
local function sample_feet(now)
  if not watch or not watch.items or not chef.unit_position then return end
  if now - gr.at < 0.25 then return end
  local dt = now - gr.at
  gr.at = now
  -- (2.4.3) where the vehicles are now (live, not the watch's list: an FRV covers 10 m in its second)
  local nv = 0
  if vwatch and vwatch.items then
    for _, it in ipairs(vwatch.items) do
      if chef.unit_alive(it.unit) then
        local vx, vy = chef.unit_position(it.unit)
        if vx then
          vpos[nv * 2 + 1], vpos[nv * 2 + 2] = vx, vy nv = nv + 1 vkind[nv] = it.kind
          if it.kind and not vsaid[it.kind] then vsaid[it.kind] = true log('research: ground: a vehicle in the world: %s', vname(it.kind)) end
        end
      end
    end
  end
  for _, it in ipairs(watch.items) do
    local u = it.unit
    if chef.unit_alive(u) then
      local x, y, z = chef.unit_position(u)
      if x and x == x and y == y and z == z then
        local last = gr.last[u]
        local riding = false
        for i = 0, nv - 1 do
          local ddx, ddy = x - vpos[i * 2 + 1], y - vpos[i * 2 + 2]
          if ddx * ddx + ddy * ddy < VEH_R * VEH_R then
            riding = true
            local k = 'at ' .. tostring(vkind[i + 1])
            if not vsaid[k] then vsaid[k] = true log('research: ground: a Helldiver at a %s (%.1f m across): no feet samples while there', vname(vkind[i + 1]), math.sqrt(ddx * ddx + ddy * ddy)) end
            break
          end
        end
        -- (a jump, a dive's fall, a jump pack's flight: the height moving over 3 m/s; the first sample after a
        -- gap can't tell, so it's skipped too; 2.4.3: and a Helldiver at a vehicle, riding it or beside it)
        if riding then gr.riding = (gr.riding or 0) + 1
        elseif last and dt < 1 and math.abs(z - last.z) / dt <= 3 then sample(x, y, z)
        else gr.skipped = gr.skipped + 1 end
        gr.last[u] = { z = z, at = now }
      end
    end
  end
  for u, l in pairs(gr.last) do if now - l.at > 5 then gr.last[u] = nil end end
end

-- (2.2.5) the look point: your Helldiver's af97ede7 (look_at_position: where the view's ray meets the world, ~1000 m
-- out on the sky; Blast & Trajectory Markers' finding, docs/RESEARCH.md), ten times a second whenever you're in a
-- mission, aiming or not. A cell keeps the lowest look point seen in it: the ground beside a rock rather than its
-- top, the ground under a bug rather than its back; a point more than BUMP m over sure ground known round it
-- (feet, look) isn't ground at all (a wall, a tree's side) and is left out. The sample is the last word for the cell
-- unless feet have been there
local LOOK_NAME = string.match(DATA.fieldnames or '', 'af97ede7 (%S+)')
local BUMP = 2.5
local lk = { at = -100, n = 0, out = 0, last = nil }
N.look_stats = lk
local function sample_look(now)
  if not LOOK_NAME or now - lk.at < 0.1 then return end
  local s, av = N.session_now, N.me.avatar
  if not (s and av) then return end
  lk.at = now
  if not N.alive(s, av, N.TYPES[2]) then return end   -- (a read of a gone object can end the game)
  local v = N.call('avatar.look', 'GameSession.game_object_field', s, av, LOOK_NAME)
  local x, y, z = N.xyz(v)
  if not (x and x == x and y == y and z == z) then lk.last = nil return end
  local cam = chef.camera()
  if cam and (x - cam.x) ^ 2 + (y - cam.y) ^ 2 + (z - cam.z) ^ 2 > 810000 then lk.last = nil return end   -- (the sky)
  lk.last = { x = x, y = y, z = z, at = now }
  local c = cell_of(x, y, true)
  if not c then return end
  -- (the bump rule: against the feet of this cell or the look points of the cells round it)
  local ref = nil
  if c.fn >= 2 then ref = c.fs / c.fn
  elseif c.lz then ref = c.lz
  else
    local cx, cy = math.floor(x / CELL), math.floor(y / CELL)
    for i = -1, 1 do for j = -1, 1 do
      local nc = gr.cells[(cx + i + 50000) * 100000 + (cy + j + 50000)]
      if nc and (nc.fn >= 2 or nc.lz) then
        local h = nc.fn >= 2 and nc.fs / nc.fn or nc.lz
        if ref == nil or h < ref then ref = h end
      end
    end end
  end
  if ref and z - ref > BUMP then lk.out = lk.out + 1 return end
  if c.lz == nil or z < c.lz then c.lz = z end
  c.ln = c.ln + 1
  lk.n = lk.n + 1
end
N.look_point = function() local l = lk.last return (l and chef.time() - l.at < 0.5) and l or nil end
------------------------------------------------------------------------------------------ the walk
local kind_cache = setmetatable({}, { __mode = 'k' })  -- unit handle -> kind id (false: unreadable)
-- (2.5.3, the frame time on busy maps: the "items" lap ran 0.12–0.17 ms with 14,000 units in the world against 0.05
-- on small maps, and the walk's three engine calls a unit were it) a unit's position from the last walk, and the
-- kinds that move. The map's props don't move: from the fourth walk on, a unit of a kind that stood still between
-- the second and third walks is sampled from its cached position without an engine call; a kind with any unit
-- that moved, a character or vehicle by name, a structure (destroyed ones must drop out) and a unit not seen
-- before are read as always. The ground learning sees the same samples either way
local pos_cache = setmetatable({}, { __mode = 'k' })   -- unit handle -> { x, y, z }
local moving = {}                                       -- kind id -> true: its units move
local function moving_kind(k)
  local v = moving[k]
  if v ~= nil then return v end
  local name = UNIT_NAMES[k]
  v = name and (string.find(name, 'fac_', 1, true) or string.find(name, '/vehicles/', 1, true) or string.find(name, '/cha_', 1, true)) and true or false
  moving[k] = v
  return v
end
local wk = { units = nil, i = 0, counts = nil, started = nil, spent = 0, fails = 0, dead = false, at = -100,
             stats = nil, nowhere = nil, cells = nil, gn = 0 }
local function vec_xyz(v)
  if v == nil then return nil end
  local x, y, z = call('ground.xyz', 'Vector3.to_elements', v)
  if type(x) == 'number' and type(y) == 'number' and type(z) == 'number' then return x, y, z end
  local a, b, c = string.match(tostring(v), '%(%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)')
  return tonumber(a), tonumber(b), tonumber(c)
end
local function skip_kind(k, count)
  if k == RUNTIME or k == AVATAR_RESOURCE then return true end
  local name = UNIT_NAMES[k]
  if name then
    if string.find(name, 'fac_helldivers/', 1, true) or string.find(name, '/equipment/', 1, true) or string.find(name, '/weapons/', 1, true) then return true end
    return false
  end
  -- (2.5.6: an unnamed structure kind — the warp ship, by hash — is never skipped, whatever its count)
  if N.struct_kind and N.struct_kind(k) then return false end
  return (count or 0) < 10
end
-- one frame's share of the walk
local function walk(now)
  if wk.units == nil then
    if now - wk.at < (gr.walks == 0 and 0 or 20) then return end
    wk.at = now
    local w = chef.world and chef.world()
    local units = w and call('ground.units', 'World.units', w)
    if type(units) ~= 'table' then
      if not wk.said then wk.said = true log('ground: World.units gives nothing (%s): the ground from the feet alone', tostring(units)) end
      wk.at = now + 60
      return
    end
    wk.units, wk.i, wk.counts, wk.started, wk.spent, wk.fails = units, 0, {}, now, 0, 0
    wk.stats, wk.nowhere, wk.gn, wk.structs, wk.unnamed, wk.still = {}, 0, 0, {}, {}, 0
    -- (the kinds' counts, for the 10-unit rule: from the last walk; the first walk counts as it goes and asks
    -- the unnamed kinds only from the second on)
    return
  end
  local t0 = clock()
  -- (a world's first walk only counts the kinds, 300 a frame, so the 10-unit rule has its counts; the second
  -- walk, straight after at 100 a frame, asks the positions; every walk after at 20 — the map doesn't move, the
  -- re-walks are for what streams in and the enemies, and 20 units are three engine calls each a frame)
  local first = gr.walks == 0
  local per = first and 300 or (gr.walks == 1 and 100 or 20)
  local last = math.min(#wk.units, wk.i + per)
  local counts = wk.counts
  for i = wk.i + 1, last do
    local u = wk.units[i]
    local k = kind_cache[u]
    if k == nil then
      local nm = call('ground.alive', 'Unit.alive', u) == true and call('ground.name', 'Unit.debug_name', u) or nil
      k = type(nm) == 'string' and string.match(nm, '#ID%[(%x+)%]')
      k = k and k:lower() or false
      kind_cache[u] = k
    end
    if k then
      counts[k] = (counts[k] or 0) + 1
      local pc = pos_cache[u]
      local struct = N.struct_kind and N.struct_kind(k)
      -- (2.5.3) a unit of a kind that doesn't move, seen before: its last position, no engine call
      local still = pc and gr.walks >= 3 and not struct and not moving_kind(k)
      if not first and not skip_kind(k, gr.counts and gr.counts[k]) and (still or call('ground.alive', 'Unit.alive', u) == true) then
        local x, y, z
        if still then
          x, y, z = pc[1], pc[2], pc[3]
          wk.still = (wk.still or 0) + 1
        else
          x, y, z = vec_xyz(call('ground.pos.' .. k, 'Unit.world_position', u, 1))
        end
        if x and x == x and y == y and z == z and math.abs(x) < 1e5 and math.abs(y) < 1e5 and math.abs(z) < 1e5 then
          if not still then
            if pc then
              -- (the third walk compares with the second: a unit that moved makes its kind a moving one)
              if gr.walks == 2 and not moving[k] and (x - pc[1]) ^ 2 + (y - pc[2]) ^ 2 + (z - pc[3]) ^ 2 > 0.0025 then moving[k] = true end
              pc[1], pc[2], pc[3] = x, y, z
            else
              pos_cache[u] = { x, y, z }
            end
          end
          unit_sample(k, x, y, z)
          if struct then N.struct_seen(wk.structs, u, k, x, y, z) end
          if cfg.research and not UNIT_NAMES[k] and #wk.unnamed < 4000 then wk.unnamed[#wk.unnamed + 1] = { k, x, y, z } end
          local st = wk.stats[k]
          if not st then st = { n = 0, nc = 0, cells = {} } wk.stats[k] = st end
          st.n = st.n + 1
          local ck = cell_key(x, y)
          if not st.cells[ck] then st.cells[ck] = true st.nc = st.nc + 1 end
        elseif x then
          wk.nowhere = wk.nowhere + 1
        end
      elseif not first and cfg.research and not UNIT_NAMES[k] and k ~= RUNTIME and k ~= AVATAR_RESOURCE and #wk.unnamed < 4000 then
        -- (2.5.2, research only) the rare unnamed kinds the walk skips (under 10 units), their positions for
        -- 12_struct's neighbours line: a structure whose named unit is only an anchor (the spore spewer's objective
        -- unit, a 0.3 m box) has its mesh in a kind filediver has no name for, and a warp ship may be one
        -- (2.5.3: from the cache too once the kind has stood still)
        if still then
          wk.unnamed[#wk.unnamed + 1] = { k, pc[1], pc[2], pc[3] }
        elseif call('ground.alive', 'Unit.alive', u) == true then
          local x, y, z = vec_xyz(call('ground.pos.' .. k, 'Unit.world_position', u, 1))
          if x and x == x and y == y and z == z and math.abs(x) < 1e5 and math.abs(y) < 1e5 and math.abs(z) < 1e5 then
            if pc then
              if gr.walks == 2 and not moving[k] and (x - pc[1]) ^ 2 + (y - pc[2]) ^ 2 + (z - pc[3]) ^ 2 > 0.0025 then moving[k] = true end
              pc[1], pc[2], pc[3] = x, y, z
            else
              pos_cache[u] = { x, y, z }
            end
            wk.unnamed[#wk.unnamed + 1] = { k, x, y, z }
          end
        end
      end
    else
      wk.fails = wk.fails + 1
    end
  end
  wk.i = last
  wk.spent = wk.spent + (clock() - t0)
  if wk.i < #wk.units then return end
  -- the walk is done
  gr.walks = gr.walks + 1
  gr.counts = counts
  if not first and N.struct_listed then N.struct_listed(wk.structs, wk.unnamed) end   -- (2.0.16: the structures the lines test)
  if cfg.research then
    local kinds, trusted, named = 0, 0, 0
    for k in pairs(counts) do kinds = kinds + 1 if UNIT_NAMES[k] then named = named + 1 end end
    for k, st in pairs(gr.kinds) do if kind_offset(st) then trusted = trusted + 1 end end
    local feet, props = 0, 0
    for _, c in pairs(gr.cells) do if c.fn >= 2 then feet = feet + 1 elseif c.us then props = props + 1 end end
    local mk = 0
    for _, v in pairs(moving) do if v then mk = mk + 1 end end
    log('research: ground walk %d: %d units of %d kinds (%d named, %d unreadable, %d nowhere; %d from the cache, %d moving kinds), %.1f ms over %d frames; %d trusted kinds; the grid %d cells: %d feet, %d props',
      gr.walks, #wk.units, kinds, named, wk.fails, wk.nowhere, wk.still or 0, mk, wk.spent * 1000, math.ceil(#wk.units / per), trusted, gr.n, feet, props)
    if cfg.census and (gr.walks == 2 or gr.walks % 5 == 0) then   -- (2.5.4: the census to its own log, with its own row)
      local rows = {}
      for k, st in pairs(wk.stats) do rows[#rows + 1] = { k, st } end
      table.sort(rows, function(a, b) return a[2].n > b[2].n or (a[2].n == b[2].n and a[1] < b[1]) end)
      local lines = {}
      for i, r in ipairs(rows) do
        local k, st = r[1], r[2]
        local name = UNIT_NAMES[k]
        if i <= 40 or name then
          local ks = gr.kinds[k]
          local off, sd = ks and kind_offset(ks)
          -- this session's own samples (the seed's share taken out, so a log can feed the seed without counting it twice)
          local d, d2, n = ks and ks.d - ks.d0, ks and ks.d2 - ks.d20, ks and ks.n - ks.n0
          local stat = ks and n > 0 and string.format(' dz %+.1f +-%.1f over %d%s', d / n, math.sqrt(math.max(0, d2 / n - (d / n) ^ 2)), n, off and ' trusted' or '') or (off and ' trusted' or '')
          lines[#lines + 1] = string.format('%s x%d in %d cells%s%s', k, st.n, st.nc, stat, name and (' ' .. string.gsub(name, '^content/', '')) or '')
        end
      end
      for i = 1, #lines, 4 do log('census: ground kinds: %s', table.concat(lines, '; ', i, math.min(i + 3, #lines))) end
    end
  end
  wk.units, wk.counts, wk.stats = nil, nil, nil
  if first then wk.at = -100 end                   -- (the positions: straight after the count)
end

local function ground_update(now)
  -- (2.4.7) none of the world's units read while you're dead, in the hellpod or just landed (12_vitals)
  local held = N.units_held and N.units_held(now)
  if not held then sample_feet(now) end
  sample_look(now)
  if N.struct_update and not held then N.struct_update(now) end
  -- (the walk in a fence: an error in it is logged once and ends the walk for the session, the feet grid and the
  -- HUD unharmed; Chef switches a mod off after 20 update errors)
  if not wk.dead and not held then
    local ok, err = pcall(walk, now)
    if not ok then wk.dead = true log('ground: the walk stopped: %s', tostring(err)) end
  end
  if cfg.research and now - gr.said >= 60 then
    gr.said = now
    log('research: ground grid: %d cells, %d feet samples, %d skipped, %d at a vehicle, %d look points (%d left out as bumps)%s', gr.n, gr.samples, gr.skipped, gr.riding or 0, lk.n, lk.out, gr.full and ' (full)' or '')
  end
end
N.ground_update = ground_update
-- (2.5.5, research: the warp ship hunt) the units within r metres of a point, from the walk's caches (every unit
-- walked, named or not), as "<name or kind> xN at d m" — for the MARK line: what stands where the reticle points
-- (2.5.12: within 40 m and 40 rows, not 15 m and 12 — the warp ship's hull never made the list: its furniture
-- filled the 12 rows within 12 m; and each kind's count on the whole map, and the nearest unit's height over the
-- point — a hull is one per ship, as many as the ships, its root maybe high up)
function N.units_near(x, y, r, z, rows_max)
  local by = {}
  for u, pc in pairs(pos_cache) do
    local dx, dy = pc[1] - x, pc[2] - y
    local d2 = dx * dx + dy * dy
    if d2 <= r * r then
      local k = kind_cache[u] or '?'
      local e = by[k]
      if not e then e = { n = 0, d = 1e9, dz = 0 } by[k] = e end
      e.n = e.n + 1
      if d2 < e.d then e.d, e.dz = d2, z and (pc[3] - z) or 0 end
    end
  end
  local rows = {}
  for k, e in pairs(by) do rows[#rows + 1] = { k = k, n = e.n, d = math.sqrt(e.d), dz = e.dz, all = gr.counts and gr.counts[k] or wk.counts and wk.counts[k] } end
  table.sort(rows, function(a, b) return a.d < b.d end)
  local out = {}
  for i = 1, math.min(#rows, rows_max or 40) do
    local r_ = rows[i]
    out[#out + 1] = string.format('%s x%d at %.1f m%s%s', string.gsub(UNIT_NAMES[r_.k] or (N.STRUCT_BY_ID and N.STRUCT_BY_ID[r_.k]) or (N.KIND_NAMES and N.KIND_NAMES[r_.k]) or r_.k, '^content/', ''), r_.n, r_.d,
      math.abs(r_.dz) >= 1 and string.format(' (%+.0f m up)', r_.dz) or '', r_.all and string.format(' [%d on the map]', r_.all) or '')
  end
  return out
end
-- (2.5.14) the nearest unit of each kind within r metres of a point, nearest kinds first: { k, u, d }
function N.units_near_handles(x, y, r)
  local by = {}
  for u, pc in pairs(pos_cache) do
    local dx, dy = pc[1] - x, pc[2] - y
    local d2 = dx * dx + dy * dy
    if d2 <= r * r then
      local k = kind_cache[u] or '?'
      local e = by[k]
      if not e or d2 < e.d2 then by[k] = { k = k, u = u, d2 = d2 } end
    end
  end
  local rows = {}
  for _, e in pairs(by) do rows[#rows + 1] = { k = e.k, u = e.u, d = math.sqrt(e.d2) } end
  table.sort(rows, function(a, b) return a.d < b.d end)
  return rows
end
-- a new world: the grid starts over; the kinds' offsets stay (they're the map's assets, not the map)
local function ground_reset()
  gr.cells, gr.n, gr.samples, gr.skipped, gr.last, gr.full, gr.walks, gr.counts = {}, 0, 0, 0, {}, false, 0, nil
  gr.riding, vsaid = 0, {}
  lk.n, lk.out, lk.last = 0, 0, nil
  for _, st in pairs(gr.kinds) do st.seen = {} end
  wk.units, wk.counts, wk.stats, wk.at = nil, nil, nil, -100
  kind_cache = setmetatable({}, { __mode = 'k' })
  pos_cache, moving = setmetatable({}, { __mode = 'k' }), {}   -- (2.5.3: a new world's units and kinds)
  if N.struct_reset then N.struct_reset() end
end
N.ground_reset = ground_reset

------------------------------------------------------------------------------------------ the mark
-- a ring on the ground at x, y, z (16 segments of radius r), a hair above it so the ground doesn't swallow it,
-- with an arrow pointing down at it; faint when the ground there is a guess ('near', 'loose'); color: the
-- structure hit's red (12_struct), else cream; px, py: the thrower, the arrow faces them
local ARROW_W, ARROW_H = 1.0, 1.6              -- the arrow over the mark: metres wide and tall
local function draw_mark(x, y, z, conf, color, px, py, blast, key)
  -- (2.4.8) painted on the ground (12_decal) unless Classic is chosen or the pictures can't be: then these lines
  if N.mark_painted and N.mark_painted(key or 'mark', x, y, z, conf, color, px, py, blast) then return end
  if not chef.line then return end
  local a = (conf == 'feet' or conf == 'look' or conf == 'props') and 200 or 90
  local c = N.wcol(color or N.CREAM, a)            -- (2.0.17: the world's tone curve)
  local k = cfg.mark_size or 1                     -- (2.0.20) Mark size, m: the whole mark scaled; 1 = the 2.0.16 size
  local r = 0.6 * k
  local n = 16
  local lx, ly = x + r, y
  for i = 1, n do
    local t = i / n * 2 * math.pi
    local nx, ny = x + r * math.cos(t), y + r * math.sin(t)
    chef.line(lx, ly, z + 0.08, nx, ny, z + 0.08, c)
    lx, ly = nx, ny
  end
  -- the dot: a short cross at the centre
  chef.line(x - r * 0.25, y, z + 0.08, x + r * 0.25, y, z + 0.08, c)
  chef.line(x, y - r * 0.25, z + 0.08, x, y + r * 0.25, z + 0.08, c)
  -- (2.0.15, luka) an arrow pointing down at the ring's centre, standing in the plane across the view, so the mark
  -- shows over grass: a triangle, its tip on the ring, ARROW_W wide and ARROW_H tall
  local dx, dy = px and (x - px) or 1, py and (y - py) or 0
  local dl = math.sqrt(dx * dx + dy * dy)
  if dl < 1e-4 then dx, dy, dl = 1, 0, 1 end
  local ax, ay = -dy / dl, dx / dl                  -- across the view
  local w, h = ARROW_W / 2 * k, ARROW_H * k
  local tz = z + 0.08
  local l1x, l1y, l2x, l2y = x - ax * w, y - ay * w, x + ax * w, y + ay * w
  chef.line(x, y, tz, l1x, l1y, tz + h, c)
  chef.line(x, y, tz, l2x, l2y, tz + h, c)
  chef.line(l1x, l1y, tz + h, l2x, l2y, tz + h, c)
  N.drop_lines = (N.drop_lines or 0) + n + 2 + 3
end
N.draw_ground_mark = draw_mark
