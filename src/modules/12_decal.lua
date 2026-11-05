-- NarrowHUD, the lines' look (2.4.8): the drop and throw lines as dashes, and where they land painted on the ground —
-- the landing pin, and for an explosive round or a grenade its blast zone (the full-damage radius) and the outer
-- radius it still reaches (red while you stand within it). luka: "an area of effect marker the way they and trajectory markers do, with the ground
-- decal; and improve how our line and ending markers look". The old look stays an F9 choice (Classic).
-- Painting on the ground (docs/RESEARCH.md, Blast Radius Markers 1.0.2): copies of the game's projected-decal unit
-- 1b798f4f99a0b8c8, spawned with chef.spawn (local: nobody else sees them), each with our own picture on its
-- material's color_map (tools/decal_art.py, shipped in our patch in the game's texture layout) and its opacity on
-- alpha_multiplier; turned to project straight down and scaled to (diameter, depth, diameter), 1 m a unit. It paints
-- whatever lies in its box: the ground, a rock, a slope, a step. Kept in a pool, parked 5 km down when unused; Chef
-- removes them at a world change. Anything missing (the unit, a picture, the calls): the Classic lines instead.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, call = N.cfg, N.call

------------------------------------------------------------------------------------------------ the decals
local DECAL_UNIT = '1b798f4f99a0b8c8'
local PARK_Z, CAP = -5000, 8
-- (the game stops drawing decals ~82 m out at Medium Object Detail; 2.4.9: times its LOD multiplier, read from the
-- game's settings once a world — High about 1.5, luka's zone stopped at ~80 m)
local reach = { wid = nil, m = 80 }
local function REACH()
  local wid = chef.world_id and chef.world_id() or 0
  if reach.wid ~= wid then
    reach.wid = wid
    local v = chef.setting and chef.setting('render_settings.lod_selection_multiplier')
    reach.m = 80 * ((type(v) == 'number' and v >= 0.25 and v <= 4) and v or 1)
    if cfg.research then log('research: ground pictures drawn to %.0f m (Object Detail LOD multiplier %s)', reach.m, tostring(v)) end
  end
  return reach.m
end
local K = math.sqrt(0.5)
local PIC = {}
for _, n in ipairs({ 'zone_cream', 'zone_red', 'ring_cream', 'ring_red', 'pin_cream', 'pin_red' }) do
  local t = TEXTURES and TEXTURES['decal_' .. n .. '_game']
  PIC[n] = t and t[1] and t[1][3] or nil
end
local P = { ok = nil, why = nil, wid = nil, pool = {}, used = {}, frame = -1, said = {} }
local function id64(hex) return call('decal.id', 'IdString64.from_hex', hex) end
local function decal_ok()
  local wid = chef.world_id and chef.world_id()
  if wid ~= P.wid then P.wid, P.pool, P.used, P.ok, P.why = wid, {}, {}, nil, nil end   -- (Chef took the old world's)
  if P.ok ~= nil then return P.ok end
  local why
  if not chef.spawn then why = 'this Chef has no chef.spawn'
  else
    for n, hex in pairs(PIC) do
      if not hex then why = 'our picture ' .. n .. ' isn\'t in the build' break end
      local id = id64(hex)
      if not id or call('decal.can', 'Application.can_get', 'texture', id) ~= true then why = 'our picture ' .. n .. ' isn\'t loaded' break end
    end
    if not why and call('decal.q', 'Quaternion.from_elements', 0, 0, 0, 1) == nil then why = 'no Quaternion.from_elements' end
  end
  P.ok, P.why = why == nil, why
  log('ground pictures: %s', P.ok and 'painted on the ground (the game\'s decal unit, our pictures)' or ('the Classic lines instead: ' .. why))
  return P.ok
end
N.decal_ok = decal_ok
local function v3(x, y, z) return call('decal.v3', 'Vector3', x, y, z) end
-- its material: the picture and the opacity (Mesh.refresh_instance_hash so the change takes)
local function dress(d, pic, a)
  a = math.floor(a * 20 + 0.5) / 20                -- (in steps of 5 %: the HUD's fades don't re-dress it every frame)
  if d.pic == pic and d.a == a then return true end
  local m = call('decal.mesh', 'Unit.mesh', d.u, 1)
  local mat = m ~= nil and call('decal.mat', 'Mesh.material', m, 1) or nil
  if mat == nil then return false end
  if d.pic ~= pic then
    local id = id64(PIC[pic])
    if id then call('decal.tex', 'Material.set_texture', mat, 'color_map', id) d.pic = pic end
  end
  if d.a ~= a then call('decal.alpha', 'Material.set_scalar', mat, 'alpha_multiplier', a) d.a = a end
  call('decal.hash', 'Mesh.refresh_instance_hash', m)
  return true
end
local function take(x, y, z)
  for _, d in ipairs(P.pool) do
    if not d.key and chef.unit_alive(d.u) then return d end
  end
  if #P.pool >= CAP then return nil end
  local u, err = chef.spawn(DECAL_UNIT, x, y, z)
  if not u then
    if not P.said.spawn then P.said.spawn = true log('ground pictures: the decal didn\'t spawn (%s): the Classic lines instead', tostring(err)) end
    P.ok = false
    return nil
  end
  local d = { u = u }
  P.pool[#P.pool + 1] = d
  return d
end
-- one picture on the ground this frame: centred at x, y, z, `size` across, its box `depth` tall (it paints what lies
-- within half of it above and below), at opacity a; true when painted
local function paint(key, pic, x, y, z, size, depth, a)
  if not decal_ok() then return false end
  local d = P.used[key]
  if d and not chef.unit_alive(d.u) then P.used[key], d = nil, nil end
  if not d then
    d = take(x, y, z)
    if not d then return false end
    d.key, P.used[key] = key, d
    d.x = nil
  end
  d.frame = N.frame
  if not (d.x and math.abs(d.x - x) + math.abs(d.y - y) + math.abs(d.z - z) < 0.02 and d.s == size and d.dp == depth) then
    local p, q, sc = v3(x, y, z), call('decal.q', 'Quaternion.from_elements', -K, 0, 0, K), v3(size, depth, size)
    if p then call('decal.pos', 'Unit.set_local_position', d.u, 1, p) end
    if q and not d.turned then call('decal.rot', 'Unit.set_local_rotation', d.u, 1, q) d.turned = true end
    if sc then call('decal.scale', 'Unit.set_local_scale', d.u, 1, sc) end
    d.x, d.y, d.z, d.s, d.dp = x, y, z, size, depth
  end
  return dress(d, pic, a)
end
-- once a frame, after the lines: the pictures not painted this frame parked (kept for the next)
function N.decal_sweep()
  for key, d in pairs(P.used) do
    if d.frame ~= N.frame then
      P.used[key], d.key, d.x = nil, nil, nil
      if chef.unit_alive(d.u) then
        local p = v3(0, 0, PARK_Z)
        if p then call('decal.pos', 'Unit.set_local_position', d.u, 1, p) end
      end
    end
  end
end

------------------------------------------------------------------------------------------------ the mark
-- (2.4.8) The landing mark on the ground: the pin where the line lands (a ring, four ticks, a dot), red where it hits
-- an enemy structure; for an explosive round or a grenade the blast zone under it, its full-damage radius filled
-- faintly with a bright rim, and the outer radius a dashed ring; the zone red while you stand inside it. Faint
-- where the ground is a guess. The upright chevron over it, so it shows over grass. -> true when painted (false:
-- the Classic ring instead)
local ARROW_W, ARROW_H = 0.8, 1.2
local chev = {}                                   -- (the chevron's point last frame)
local clock = os and os.clock or function() return 0 end
local function mark_painted(key, x, y, z, conf, color, px, py, blast)
  if (cfg.mark_look or 2) ~= 2 or not chef.camera then return false end
  local cam = chef.camera()
  if not cam or not cam.x or (x - cam.x) ^ 2 + (y - cam.y) ^ 2 + (z - cam.z) ^ 2 > REACH() ^ 2 then return false end
  local sure = conf == 'feet' or conf == 'look' or conf == 'props'
  -- (2.4.18, luka: on guessed ground only the chevron is dimmed; the pin and the zone at full strength, since the
  -- half-strength zone was hard to see on day maps)
  local a = math.min(1, (cfg.line_alpha or 0.3) / 0.3) * (N.alpha_k or 1)
  local k = cfg.mark_size or 0.5
  local hit = color == N.RED
  if not paint(key .. '.pin', hit and 'pin_red' or 'pin_cream', x, y, z, 1.6 * k, 6, math.min(1, a)) then return false end
  if blast and cfg.blast_zone ~= false then
    local inner, outer = blast[1] or 0, blast[2] or 0
    -- (you inside it: your Helldiver within a radius, a few metres up or down: the outer ring red inside the outer
    -- radius — the blast still hurts there — and the zone too inside the full-damage one)
    local in_inner, in_outer = false, false
    local u = N.my_unit and N.my_unit()
    if u and chef.unit_alive(u) then
      local ux, uy, uz = chef.unit_position(u)
      if ux and math.abs(uz - z) < 4 then
        local d2 = (ux - x) ^ 2 + (uy - y) ^ 2
        in_inner, in_outer = d2 <= inner * inner, d2 <= outer * outer
      end
    end
    local function depth(r) return r > 10 and math.min(24, 2 * r) or math.min(12, math.max(6, 2 * r)) end
    if inner > 0.3 then paint(key .. '.zone', in_inner and 'zone_red' or 'zone_cream', x, y, z, 2 * inner, depth(inner), math.min(1, a * 0.9)) end
    if outer > inner + 0.5 then paint(key .. '.ring', in_outer and 'ring_red' or 'ring_cream', x, y, z, 2 * outer, depth(outer), math.min(1, a * 0.7)) end
  end
  -- (2.4.9, luka) the chevron as a screen icon over the landing point (our chevron texture, luka's sketch: a wide V
  -- with a triangle in it), drawn in cream (red on a structure hit) at a size that follows Mark size: it always faces
  -- you and keeps its size, and costs one bitmap. Its bottom point sits a little over the pin
  if chef.world_to_screen and N.icon_texture then
    -- (2.4.11, luka: the chevron didn't lag as the line and the pictures do, so a swing looked disjointed: the engine
    -- shows a moved decal a frame later, so the chevron takes last frame's landing point)
    local lx, ly, lz = chev.x or x, chev.y or y, chev.z or z
    if chev.frame ~= N.frame - 1 then lx, ly, lz = x, y, z end   -- (a gap: no stale point)
    chev.x, chev.y, chev.z, chev.frame = x, y, z, N.frame
    local sx, sy = chef.world_to_screen(lx, ly, lz + 0.1)
    if sx then
      local sw, sh = chef.screen()
      local S = math.max(12, math.floor((sh or 1440) / 1440 * 34 * (k / 0.7) + 0.5))
      N.alpha_k = (N.alpha_k or 1)
      local cc = hit and N.RED or N.CREAM
      -- (the screen's y runs up from the bottom, as the HUD's parts are placed: the icon's bottom a little over the pin;
      -- 2.4.9 subtracted and drew it under the pin, luka's screenshot)
      local ok = N.icon_texture('chevron', math.floor(sx - S / 2 + 0.5), math.floor(sy + S * 0.15 + 0.5), S, cc, sure and 0.95 or 0.5, N.L0 + 905)
      if not ok and chef.line then
        -- (no texture: the old standing V in lines)
        local dx, dy = px and (x - px) or 1, py and (y - py) or 0
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl < 1e-4 then dx, dy, dl = 1, 0, 1 end
        local ax, ay = -dy / dl, dx / dl
        local w, h = ARROW_W / 2 * k / 0.7, ARROW_H * k / 0.7
        local tz = z + 0.35 * k / 0.7
        local c2 = N.wcol(cc, sure and 210 or 110)
        chef.line(x, y, tz, x - ax * w, y - ay * w, tz + h, c2)
        chef.line(x, y, tz, x + ax * w, y + ay * w, tz + h, c2)
        N.drop_lines = (N.drop_lines or 0) + 2
      end
    end
  end
  return true
end

-- (2.4.11) timed: its share of the frame in the research timing line (N.decal_time, 13_main)
function N.mark_painted(...)
  local t0 = clock()
  local ok = mark_painted(...)
  N.decal_time = (N.decal_time or 0) + (clock() - t0)
  return ok
end
------------------------------------------------------------------------------------------------ the line
-- (2.4.8) A line as dashes the same size on the screen near and far (a dash every PERIOD of the view's angle, on for
-- DUTY of it), fading in over its first metre and a half, its strands side by side with a dark one along each edge
-- so it reads over snow and sky. "Flowing" moves the dashes along toward where it lands. The Classic look: one
-- solid line, as before. st: { u, path } along the line, from 0 at its start; the strands' colours given.
local PERIOD, DUTY, FADE_M, FLOW = 0.055, 0.6, 1.5, 1.4
-- (2.4.9) the looks: 1 Classic (the strands as before), 2 Solid (one line with dark edges, fading in: the default —
-- luka: the dashes cost a fifth of the frame, not worth it), 3 Dashes, 4 Flowing dashes
function N.line_state(now)
  local look = cfg.line_look or 2
  return { u = 0, path = 0, look = look, flow = look == 4 and ((now or 0) * FLOW) % 1 or 0 }
end
-- draw the line's piece from (x1, y1, z1) to (x2, y2, z2): the strands across the view (ax, ay, az), `lines` of them;
-- c the colour, dk the edge's; -> the lines drawn
-- (2.4.11, the frame time) two savings that change nothing on screen: pieces under MERGE_ANG of the view are run
-- together (a 4 m piece past 80 m: the chord's sag on a 100 m/s round is millimetres; a slow round's pieces are near
-- and never merge), and the dark edges stop past EDGE_FAR metres, where a line is a pixel wide against its own
-- shadow. luka's log: the lines at 0.3–0.6 ms a frame on 100–180 engine line calls, so each call is the cost
local MERGE_ANG, EDGE_FAR = 0.05, 80
-- (2.4.12) the line's end: a piece still pending (merged, waiting for the next) is drawn out to its end. Without
-- this the line stopped a piece short, at a point that moved with the aim (the flight's points sit at different
-- paths at different pitches), so its end jumped every half degree
function N.line_end(st, cam, lines, c, dk, cfun)
  if not st.px then return 0 end
  st.flush = true
  local n = N.line_piece(st, cam, st.px, st.py, st.pz, st.ex, st.ey, st.ez, st.ax, st.ay, st.az, lines, c, dk, cfun)
  st.flush, st.px = nil, nil
  return n
end
function N.line_piece(st, cam, x1, y1, z1, x2, y2, z2, ax, ay, az, lines, c, dk, cfun)
  local cx, cy, cz = cam.x, cam.y, cam.z
  if st.look <= 2 then
    -- a pending start: this piece's start is where the merged piece began
    if st.px then x1, y1, z1 = st.px, st.py, st.pz end
    local dd = math.sqrt((x2 - cx) ^ 2 + (y2 - cy) ^ 2 + (z2 - cz) ^ 2)
    local ll = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
    if dd > 1 and ll / dd < MERGE_ANG and not st.flush then
      if not st.px then st.px, st.py, st.pz = x1, y1, z1 end   -- (st.path stays at the merged piece's start: the
      st.ex, st.ey, st.ez, st.ax, st.ay, st.az = x2, y2, z2, ax, ay, az   -- fade is over in the first 1.5 m, never merged)
      return 0
    end
    st.px = nil
  end
  local sx, sy, sz = x2 - x1, y2 - y1, z2 - z1
  local len = math.sqrt(sx * sx + sy * sy + sz * sz)
  if len < 1e-5 then return 0 end
  local d1 = math.sqrt((x1 - cx) ^ 2 + (y1 - cy) ^ 2 + (z1 - cz) ^ 2)
  local d2 = math.sqrt((x2 - cx) ^ 2 + (y2 - cy) ^ 2 + (z2 - cz) ^ 2)
  if dk and d1 > EDGE_FAR then dk = nil end
  local n = 0
  -- (2.4.9, luka's try) three strands as a triangle: two across the view, the third over them (along the view's up
  -- for this piece: across the line's direction and the across vector), so the line has a body at a glancing angle
  local ux, uy, uz = 0, 0, 0
  if lines == 3 and cfg.line_tri ~= false then
    local nx, ny, nz = sy * az - sz * ay, sz * ax - sx * az, sx * ay - sy * ax
    local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
    if nl > 1e-6 then ux, uy, uz = nx / nl, ny / nl, nz / nl if uz < 0 then ux, uy, uz = -ux, -uy, -uz end end
  end
  local tri = ux ~= 0 or uy ~= 0 or uz ~= 0
  local function strands(t1, t2)
    local px1, py1, pz1 = x1 + sx * t1, y1 + sy * t1, z1 + sz * t1
    local px2, py2, pz2 = x1 + sx * t2, y1 + sy * t2, z1 + sz * t2
    local e1, e2 = (d1 + (d2 - d1) * t1) * 0.0012, (d1 + (d2 - d1) * t2) * 0.0012
    local col, dcol = c, dk
    if cfun then
      local f = math.min(1, (st.path + len * t1) / FADE_M)
      if f < 1 then col, dcol = cfun(f) end
    end
    if tri then
      for _, o in ipairs({ -0.5, 0.5 }) do
        chef.line(px1 + ax * e1 * o, py1 + ay * e1 * o, pz1 + az * e1 * o, px2 + ax * e2 * o, py2 + ay * e2 * o, pz2 + az * e2 * o, col)
      end
      chef.line(px1 + ux * e1 * 0.87, py1 + uy * e1 * 0.87, pz1 + uz * e1 * 0.87, px2 + ux * e2 * 0.87, py2 + uy * e2 * 0.87, pz2 + uz * e2 * 0.87, col)
    else
      for k = 1, lines do
        local o = k - (lines + 1) / 2
        chef.line(px1 + ax * e1 * o, py1 + ay * e1 * o, pz1 + az * e1 * o, px2 + ax * e2 * o, py2 + ay * e2 * o, pz2 + az * e2 * o, col)
      end
    end
    n = n + lines
    if dcol and st.look ~= 1 then
      local o = (lines + 1) / 2
      for _, sgn in ipairs({ -1, 1 }) do
        chef.line(px1 + ax * e1 * o * sgn, py1 + ay * e1 * o * sgn, pz1 + az * e1 * o * sgn, px2 + ax * e2 * o * sgn, py2 + ay * e2 * o * sgn, pz2 + az * e2 * o * sgn, dcol)
      end
      n = n + 2
    end
  end
  if st.look <= 2 then
    strands(0, 1)
  else
    local du = len / math.max(0.5, (d1 + d2) / 2)
    local u0, u1 = st.u, st.u + du
    local a = u0
    local guard = 0
    while a < u1 and guard < 64 do
      guard = guard + 1
      local q = a / PERIOD + st.flow
      local f = q - math.floor(q)
      local on = f < DUTY
      local b = math.min(u1, a + ((on and (DUTY - f)) or (1 - f)) * PERIOD)
      if on and b > a then strands((a - u0) / du, (b - u0) / du) end
      a = b + 1e-7
    end
    st.u = u1
  end
  st.path = st.path + len
  return n
end
