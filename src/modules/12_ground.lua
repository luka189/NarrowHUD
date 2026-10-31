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

local function cell_key(x, y)
  return (math.floor(x / CELL) + 50000) * 100000 + (math.floor(y / CELL) + 50000)
end
local function cell_of(x, y, make)
  local k = cell_key(x, y)
  local c = gr.cells[k]
  if c == nil and make then
    if gr.n >= MAX_CELLS then gr.full = true return nil, k end
    c = { fs = 0, fn = 0, us = nil, lo = nil }
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
-- a cell's own height and how sure: 'feet', 'props', or nil
local function cell_height(c)
  if c == nil then return nil end
  if c.fn >= 2 then return c.fs / c.fn, 'feet' end
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
  for _, reach in ipairs({ 1, 3 }) do
    local wsum, zsum = 0, 0
    for i = -reach, reach do
      for j = -reach, reach do
        if i ~= 0 or j ~= 0 then
          local nc = gr.cells[(cx + i + 50000) * 100000 + (cy + j + 50000)]
          local nh = cell_height(nc)
          if nh then
            local mx, my = (cx + i + 0.5) * CELL, (cy + j + 0.5) * CELL
            local d = math.sqrt((mx - x) ^ 2 + (my - y) ^ 2)
            local w = 1 / (1 + d)
            wsum, zsum = wsum + w, zsum + w * nh
          end
        end
      end
    end
    if wsum > 0 then return zsum / wsum, 'near' end
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
  return x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, h1 + (h2 - h1) * t, conf
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
      if h2 and z2 < h2 and (conf == 'feet' or conf == 'props') then st.landed = true end
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
  for _, it in ipairs(watch.items) do
    local u = it.unit
    if chef.unit_alive(u) then
      local x, y, z = chef.unit_position(u)
      if x and x == x and y == y and z == z then
        local last = gr.last[u]
        -- (a jump, a dive's fall, a jump pack's flight: the height moving over 3 m/s; the first sample after a
        -- gap can't tell, so it's skipped too)
        if last and dt < 1 and math.abs(z - last.z) / dt <= 3 then sample(x, y, z)
        else gr.skipped = gr.skipped + 1 end
        gr.last[u] = { z = z, at = now }
      end
    end
  end
  for u, l in pairs(gr.last) do if now - l.at > 5 then gr.last[u] = nil end end
end

------------------------------------------------------------------------------------------ the walk
local kind_cache = setmetatable({}, { __mode = 'k' })  -- unit handle -> kind id (false: unreadable)
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
    wk.stats, wk.nowhere, wk.gn, wk.structs = {}, 0, 0, {}
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
      if not first and not skip_kind(k, gr.counts and gr.counts[k]) and call('ground.alive', 'Unit.alive', u) == true then
        local x, y, z = vec_xyz(call('ground.pos.' .. k, 'Unit.world_position', u, 1))
        if x and x == x and y == y and z == z and math.abs(x) < 1e5 and math.abs(y) < 1e5 and math.abs(z) < 1e5 then
          unit_sample(k, x, y, z)
          if N.struct_kind and N.struct_kind(k) then N.struct_seen(wk.structs, u, k, x, y, z) end
          local st = wk.stats[k]
          if not st then st = { n = 0, nc = 0, cells = {} } wk.stats[k] = st end
          st.n = st.n + 1
          local ck = cell_key(x, y)
          if not st.cells[ck] then st.cells[ck] = true st.nc = st.nc + 1 end
        elseif x then
          wk.nowhere = wk.nowhere + 1
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
  if not first and N.struct_listed then N.struct_listed(wk.structs) end   -- (2.0.16: the structures the lines test)
  if cfg.research then
    local kinds, trusted, named = 0, 0, 0
    for k in pairs(counts) do kinds = kinds + 1 if UNIT_NAMES[k] then named = named + 1 end end
    for k, st in pairs(gr.kinds) do if kind_offset(st) then trusted = trusted + 1 end end
    local feet, props = 0, 0
    for _, c in pairs(gr.cells) do if c.fn >= 2 then feet = feet + 1 elseif c.us then props = props + 1 end end
    log('research: ground walk %d: %d units of %d kinds (%d named, %d unreadable, %d nowhere), %.1f ms over %d frames; %d trusted kinds; the grid %d cells: %d feet, %d props',
      gr.walks, #wk.units, kinds, named, wk.fails, wk.nowhere, wk.spent * 1000, math.ceil(#wk.units / per), trusted, gr.n, feet, props)
    if gr.walks == 2 or gr.walks % 5 == 0 then
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
      for i = 1, #lines, 4 do log('research: ground kinds: %s', table.concat(lines, '; ', i, math.min(i + 3, #lines))) end
    end
  end
  wk.units, wk.counts, wk.stats = nil, nil, nil
  if first then wk.at = -100 end                   -- (the positions: straight after the count)
end

local function ground_update(now)
  sample_feet(now)
  if N.struct_update then N.struct_update(now) end
  -- (the walk in a fence: an error in it is logged once and ends the walk for the session, the feet grid and the
  -- HUD unharmed; Chef switches a mod off after 20 update errors)
  if not wk.dead then
    local ok, err = pcall(walk, now)
    if not ok then wk.dead = true log('ground: the walk stopped: %s', tostring(err)) end
  end
  if cfg.research and now - gr.said >= 60 then
    gr.said = now
    log('research: ground grid: %d cells, %d feet samples, %d skipped%s', gr.n, gr.samples, gr.skipped, gr.full and ' (full)' or '')
  end
end
N.ground_update = ground_update
-- a new world: the grid starts over; the kinds' offsets stay (they're the map's assets, not the map)
local function ground_reset()
  gr.cells, gr.n, gr.samples, gr.skipped, gr.last, gr.full, gr.walks, gr.counts = {}, 0, 0, 0, {}, false, 0, nil
  for _, st in pairs(gr.kinds) do st.seen = {} end
  wk.units, wk.counts, wk.stats, wk.at = nil, nil, nil, -100
  kind_cache = setmetatable({}, { __mode = 'k' })
  if N.struct_reset then N.struct_reset() end
end
N.ground_reset = ground_reset

------------------------------------------------------------------------------------------ the mark
-- a ring on the ground at x, y, z (16 segments of radius r), a hair above it so the ground doesn't swallow it,
-- with an arrow pointing down at it; faint when the ground there is a guess ('near', 'loose'); color: the
-- structure hit's red (12_struct), else cream; px, py: the thrower, the arrow faces them
local ARROW_W, ARROW_H = 1.0, 1.6              -- the arrow over the mark: metres wide and tall
local function draw_mark(x, y, z, conf, color, px, py)
  if not chef.line then return end
  local a = (conf == 'feet' or conf == 'props') and 200 or 90
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
