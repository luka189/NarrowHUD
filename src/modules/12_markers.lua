-- NarrowHUD, markers (1.3.0): your map pin and the spot of your last death, drawn on the screen where they are in the
-- world (through chef.world_to_screen); an arrow at the screen's edge when one is out of view.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES, call, alive, cfg, me = N.TYPES, N.call, N.alive, N.cfg, N.me

-- the three numbers of an engine vector (Vector3.to_elements; from its text when that call isn't given)
local function xyz(v)
  if v == nil then return nil end
  local x, y, z = call('xyz', 'Vector3.to_elements', v)
  if type(x) == 'number' and type(y) == 'number' and type(z) == 'number' then return x, y, z end
  local a, b, c = string.match(tostring(v), '%(%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)%s*,%s*([-%d%.e]+)')
  return tonumber(a), tonumber(b), tonumber(c)
end

-- Your Helldiver's fields, every 0.1 s: position; map_marker_type (0 none, 7 one being placed, 1 placed), with
-- map_marker_position (its z is 0 on the map: the pin is drawn at your own height then); health, for the moment it
-- reaches 0 (the 1.0.10 research log for all of these).
local mk = { at = -100, goid = nil, pos = nil, hp = nil, pin = nil, death = nil, pin_said = nil }
local function read_markers(s, now)
  if now - mk.at < 0.1 then return end
  mk.at = now
  local want_pin, want_death = cfg.map_pin, cfg.death_mark
  if not want_pin and not want_death then mk.pin = nil return end
  local av = me.avatar
  if not av or not alive(s, av, TYPES[2]) then mk.pin, mk.hp, mk.pos = nil, nil, nil return end
  if mk.goid ~= av then mk.goid, mk.hp, mk.pin = av, nil, nil end
  local x, y, z = xyz(call('avatar.position', 'GameSession.game_object_field', s, av, 'position'))
  if x then mk.pos = { x = x, y = y, z = z } end
  if want_death then
    local hp = tonumber((call('avatar.health', 'GameSession.game_object_field', s, av, 'health')))
    if hp and mk.hp and mk.hp > 0 and hp <= 0 and mk.pos then
      mk.death = { x = mk.pos.x, y = mk.pos.y, z = mk.pos.z, at = now, goid = av }
      if cfg.research then log('research: died at (%.1f, %.1f, %.1f)', mk.pos.x, mk.pos.y, mk.pos.z) end
    end
    if hp then mk.hp = hp end
    -- gone: after 3 minutes, or once you're back within 2 m of it (after a new life, or having been 5 m away)
    local d = mk.death
    if d and mk.pos then
      local d2 = (mk.pos.x - d.x) ^ 2 + (mk.pos.y - d.y) ^ 2
      if d.goid ~= av or d2 > 25 then d.away = true end
      if now - d.at > 180 or (d.away and d2 <= 4) then mk.death = nil end
    elseif d and now - d.at > 180 then
      mk.death = nil
    end
  else
    mk.hp = nil
  end
  if want_pin then
    local mt = tonumber((call('avatar.pin_type', 'GameSession.game_object_field', s, av, 'map_marker_type'))) or 0
    if mt ~= 0 then
      local px, py, pz = xyz(call('avatar.pin_pos', 'GameSession.game_object_field', s, av, 'map_marker_position'))
      if px and mk.pos then
        if math.abs(pz) < 0.01 then pz = mk.pos.z end
        mk.pin = { x = px, y = py, z = pz, type = mt }
      end
    else
      mk.pin = nil
    end
    if cfg.research and (mt ~= (mk.pin_said or 0)) then
      mk.pin_said = mt
      local g = call('avatar.pin_goid', 'GameSession.game_object_field', s, av, 'map_marker_goid')
      local o = type(g) == 'number' and N.objs[g]
      log('research: map pin type %s at %s, its object %s (%s)', tostring(mt), mk.pin and string.format('(%.1f, %.1f, %.1f)', mk.pin.x, mk.pin.y, mk.pin.z) or 'none',
        tostring(g), o and (o.t and TYPES[o.t] and TYPES[o.t].id or 'a type NarrowHUD doesn\'t know') or 'not among your objects')
    end
  else
    mk.pin = nil
  end
end

-- where a world point goes on the screen: x, y and true when it's in view (inside a margin); else a point on the
-- screen's edge toward it, false, and the direction (right, up) of the arrow there
local function place(x, y, z, w, h, m)
  local sx, sy = chef.world_to_screen(x, y, z)
  if sx and sx >= m and sx <= w - m and sy >= m and sy <= h - m then return sx, sy, true end
  local cam = chef.camera()
  if not cam then return nil end
  local ang = math.atan2(x - cam.x, y - cam.y) - (cam.yaw or 0)       -- 0 ahead, positive to the right
  local ux, uy = math.sin(ang), math.cos(ang)
  local cx, cy = w / 2, h / 2
  local t = math.min((w / 2 - m) / math.max(1e-6, math.abs(ux)), (h / 2 - m) / math.max(1e-6, math.abs(uy)))
  return cx + ux * t, cy + uy * t, false, ux, uy
end
local function tri(x1, y1, x2, y2, x3, y3, c, L)
  chef.triangle(x1, y1, x2, y2, x3, y3, c, L)
end
-- a marker: in view, its shape at the point with the distance under it; out of view, an arrow at the edge with
-- the distance inside it
local function draw_marker(p, shape, color, w, h, k, L)
  if not mk.pos then return end
  local dist = math.sqrt((p.x - mk.pos.x) ^ 2 + (p.y - mk.pos.y) ^ 2)
  local str = string.format('%d m', math.floor(dist + 0.5))
  local cap = math.max(7, math.floor(13 * k + 0.5))
  local m = math.floor(36 * k)
  local sx, sy, seen, ux, uy = place(p.x, p.y, p.z, w, h, m)
  if not sx then return end
  local c = N.col(color, 230)
  local s = 9 * k
  if seen then
    if shape == 'pin' then
      -- a pin: a triangle pointing down at the spot, a square head over it
      tri(sx, sy, sx - s, sy + 2.2 * s, sx + s, sy + 2.2 * s, c, L)
      chef.rect(sx - s, sy + 2.2 * s, 2 * s, 0.9 * s, c, L)
    else
      -- a diamond
      tri(sx, sy + 1.6 * s, sx - 1.1 * s, sy, sx + 1.1 * s, sy, c, L)
      tri(sx, sy - 1.6 * s, sx - 1.1 * s, sy, sx + 1.1 * s, sy, c, L)
    end
    N.txt(sx - N.txt_width(str, cap) / 2, sy - 0.6 * s - cap - 1.4 * s, str, cap, c, L)
  else
    -- the arrow: its tip at the edge, pointing out
    local px, py = -uy, ux
    local len, half = 2.6 * s, 1.3 * s
    tri(sx, sy, sx - ux * len + px * half, sy - uy * len + py * half, sx - ux * len - px * half, sy - uy * len - py * half, c, L)
    -- the distance just inside it, and the shape's mark beside the distance
    local tx, ty = sx - ux * (len + 1.2 * s), sy - uy * (len + 1.2 * s)
    local tw = N.txt_width(str, cap)
    tx = math.max(m * 0.3, math.min(w - m * 0.3 - tw, tx - tw / 2))
    ty = math.max(m * 0.3, math.min(h - m * 0.3 - cap, ty - cap / 2))
    N.txt(tx, ty, str, cap, c, L)
    if shape ~= 'pin' then
      local dx, dy = tx - 1.6 * s, ty + cap / 2
      tri(dx, dy + 0.9 * s, dx - 0.6 * s, dy, dx + 0.6 * s, dy, c, L)
      tri(dx, dy - 0.9 * s, dx - 0.6 * s, dy, dx + 0.6 * s, dy, c, L)
    end
  end
end
local function draw_markers()
  if not mk.pin and not mk.death then return end
  local w, h = chef.screen()
  if not w or not chef.world_to_screen then return end
  local k = (h / 1440) * (cfg.size or 1)
  local L = N.L0 + 890                                       -- (under the HUD's 905)
  if mk.death and cfg.death_mark then draw_marker(mk.death, 'diamond', N.RED, w, h, k, L) end
  if mk.pin and cfg.map_pin then draw_marker(mk.pin, 'pin', N.CREAM, w, h, k, L) end
end
local function markers_reset() mk.pin, mk.death, mk.hp, mk.pos, mk.goid, mk.pin_said = nil, nil, nil, nil, nil, nil end
N.read_markers, N.draw_markers, N.markers_reset, N.markers_state = read_markers, draw_markers, markers_reset, mk
