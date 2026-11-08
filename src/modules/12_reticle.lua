-- NarrowHUD, reticle: a crosshair at the screen's middle for the sniper rifles aimed in third person. The game draws
-- none for them there (the APW-1 Anti-Materiel Rifle, the R-40 Sightliner, the AMW-20 Apex), and a third-person shot
-- goes from the muzzle to the point under the screen's middle (the drop line's CONVERGE, the 1.4.x logs), so the
-- middle is where the shot lands. The game's own default crosshair, a ring and a dot, as a texture luka189 traced (1.5.68; a cross where the texture can't be drawn), dark-backed, in the HUD's colour. Not in first
-- person (the game's own scope is up): the camera within half a metre across of your Helldiver's feet. An idea
-- NarrowHUD's users asked for since "3rd Person Sniper Reticle" (Nexus 17918, which turns the game's own on by
-- patching its weapon data) broke; HUDdle 0.6.0 draws one the same way (docs/RESEARCH.md); this is ours.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, input = N.cfg, N.input
-- (2.6.7, luka) the crosshairs keep the game's own cream whatever the Colours tab says: the game draws the other
-- weapons' crosshairs, and one sniper's in a colour of its own looked off
local INK = { 236, 229, 206 }
local SNIPERS = { b697955d = 'APW-1 Anti-Materiel Rifle', ['30294946'] = 'R-40 Sightliner', a4eff4fa = 'AMW-20 Apex' }
-- (2.0.1, a Nexus request) weapons the game gives no crosshair in first person: the ring and dot there, always.
-- (2.0.11, luka's five marks, 2026-10-31: the flamethrowers, under their own row, off by default — a flamethrower is
-- aimed by its stream; one user asked. luka's names: 104184f7 the Torcher, 0fe87029 the Crisper, def25ee4 the
-- Flamethrower, 2ddd091d the Sterilizer, 15f1a9f0 the Cremator)
local FIRST_PERSON = { b3246bb7 = { 'Maxigun', 'reticle_fp' } }
for id, name in string.gmatch('15f1a9f0=Cremator def25ee4=Flamethrower 2ddd091d=Sterilizer 104184f7=Torcher 0fe87029=Crisper', '(%x+)=(%a+)') do FIRST_PERSON[id] = { name, 'reticle_flame' } end
local rt = { on = false, said = nil }
local BLEND = 0.25                                   -- (2.5.9) the crosshair's hand-over between the reticle and the centre, s
local function first_person()
  local cam = chef.camera()
  local u = N.my_unit and N.my_unit()
  if not (cam and u and chef.unit_position) then return false end
  local x, y = chef.unit_position(u)
  if not x then return false end
  local dx, dy = cam.x - x, cam.y - y
  return dx * dx + dy * dy < 0.25                   -- (half a metre across: the camera at your head, not behind you)
end
N.first_person = first_person
-- d: the weapon shown (its tid). A sniper rifle: drawn in third person while aimed (the aim button, or the stance
-- field at 4), or whenever it's in hand ("Sniper crosshair: Always", 2.0.1, a Nexus request). A FIRST_PERSON weapon:
-- drawn in first person, where the game draws none for it.
local function draw_reticle(d, now)
  local sn, fpe = d and SNIPERS[d.tid], d and FIRST_PERSON[d.tid]
  local fp = fpe and cfg[fpe[2]] and fpe[1] or nil          -- (the weapon's row on: its name)
  if not d or not ((sn and cfg.reticle) or fp) then rt.on = false return end
  local st8 = N.state8
  -- (2.0.1: the game's own aim and view bits where they read — a toggled aim counts; the button and the camera
  -- where they don't)
  local aimed = (st8 and st8.ads ~= nil) and st8.ads == 1 or ((not st8 or st8.ads == nil) and (input.aiming or (st8 and st8.aim == 4)))
  local first = (st8 and st8.view ~= nil) and st8.view == 1 or ((not st8 or st8.view == nil) and first_person())
  local on
  if first then on = fp and true or false
  else on = (sn and cfg.reticle) and (aimed or cfg.reticle_always) or false end
  if on ~= rt.on then
    rt.on = on
    if cfg.research then log('research: crosshair %s (%s; %s person, aim bit %s, aim button %s, stance %s)', on and 'shown' or 'hidden', sn or fp, first and 'first' or 'third', tostring(st8 and st8.ads), tostring(input.aiming), tostring(st8 and st8.aim)) end
  end
  if not on then return end
  local w, h = chef.screen()
  if not w then return end
  local sx, sy = math.floor(w / 2 + 0.5), math.floor(h / 2 + 0.5)
  local L = N.L0 + 895
  local c, back = N.col(INK, 240), N.col({ 0, 0, 0 }, 150)
  -- (2.5.1, luka) the ring and dot follow the game's own aim (the reticle point 12_drop reads for the drop line,
  -- led the same two frames, projected to the screen), as the game's reticle would if it drew one: it lags the view
  -- in a turn and sways with the sight. A larger, thinner ring stays at the screen's middle, so the crosshair comes
  -- to rest inside it as the aim settles. F9 "Crosshair at": The reticle, or The centre (the static crosshair).
  local ring = false
  if (cfg.reticle_at or 2) == 2 and N.reticle_point and chef.world_to_screen then
    ring = true
    local cam = chef.camera()
    local rp, why = nil, 'no camera'
    if cam then rp, why = N.reticle_point(cam, true) end
    local px, py
    if rp then px, py = chef.world_to_screen(rp.x, rp.y, rp.z) end   -- (not `rp and f()`: that keeps one value)
    -- (2.5.9, luka: the crosshair "teleports to the centre too often" — his log: 20 falls to the centre in a
    -- minute, all "off the screen": the reticle point lags a fast turn by up to 35 deg, and the projection has
    -- nothing for a point outside the view, mostly up or down on a wide screen) a hand-over between the two
    -- places is eased over BLEND seconds from where the crosshair was, while plain tracking stays live
    local tx, ty = sx, sy
    if px and py then tx, ty = px, py end
    local on_point = (px and py) and true or false
    if rt.on_point ~= nil and rt.on_point ~= on_point and rt.cx then rt.blend_t, rt.bx, rt.by = now, rt.cx, rt.cy end
    rt.on_point = on_point
    if rt.blend_t then
      local f = (now - rt.blend_t) / BLEND
      if f >= 1 then rt.blend_t = nil
      else
        f = 1 - (1 - f) ^ 3
        tx, ty = rt.bx + (tx - rt.bx) * f, rt.by + (ty - rt.by) * f
      end
    end
    rt.cx, rt.cy = tx, ty
    sx, sy = math.floor(tx + 0.5), math.floor(ty + 0.5)
    if cfg.research then   -- (where the crosshair sits and why, on change, at most once a second)
      local what = (px and py) and 'the reticle' or ('the centre: ' .. tostring(rp and 'off the screen' or why))
      if rt.at ~= what and now - (rt.at_t or -100) >= 1 then rt.at, rt.at_t = what, now log('research: the crosshair on %s', what) end
    end
  end
  -- (1.5.68, luka: the game's own default crosshair, traced by him — art/icons/reticle.svg, a ring and a dot — as a
  -- texture, like the stim and grenade icons. Its size is the screen's, not F9's Size (the game's crosshair doesn't
  -- scale either): "World: crosshair size" pixels across at 1440p. A dark copy a pixel off in four directions
  -- behind it is the backing. Where the texture can't be drawn (Chef says why in its log): the cross of 1.5.43)
  local ks = h / 1440
  local D = (cfg.reticle_px or 17) * ks                -- the ring's outer diameter on the screen
  local S = math.floor(D / 0.875 + 0.5)                -- (the icon fills 14/16 of its square: make_textures' margin)
  local iw = math.floor(S * 0.875 + 0.5)
  local drawn = false
  if N.icon_texture then
    local x0, y0 = sx - math.floor(iw / 2), sy - math.floor(S / 2)
    for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      N.icon_texture('reticle', x0 + o[1], y0 + o[2], S, { 0, 0, 0 }, 0.7, L - 1)
    end
    drawn = N.icon_texture('reticle', x0, y0, S, INK, 1.09, L)
    if ring and drawn then
      -- the centre ring: 1.6 times the crosshair, at the screen's middle, a little dimmer
      local S2 = math.floor(S * 1.6 + 0.5)
      local iw2 = math.floor(S2 * 0.875 + 0.5)
      local cx, cy = math.floor(w / 2 + 0.5), math.floor(h / 2 + 0.5)
      local x1, y1 = cx - math.floor(iw2 / 2), cy - math.floor(S2 / 2)
      for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        N.icon_texture('ring', x1 + o[1], y1 + o[2], S2, { 0, 0, 0 }, 0.6, L - 1)
      end
      N.icon_texture('ring', x1, y1, S2, INK, 0.85, L)
    end
  end
  if drawn then return end
  local k = ks * (cfg.size or 1)
  local gap, len, th = math.floor(4 * k + 0.5), math.floor(6 * k + 0.5), math.max(1, math.floor(1.5 * k + 0.5))
  local function bar(x, y, bw, bh)
    chef.rect(x - 1, y - 1, bw + 2, bh + 2, back, L - 1)
    chef.rect(x, y, bw, bh, c, L)
  end
  local half = math.floor(th / 2)
  bar(sx + gap, sy - half, len, th)                 -- right
  bar(sx - gap - len, sy - half, len, th)           -- left
  bar(sx - half, sy + gap, th, len)                 -- down
  bar(sx - half, sy - gap - len, th, len)           -- up
  bar(sx - half, sy - half, th, th)                 -- the dot
end
N.draw_reticle, N.SNIPERS = draw_reticle, SNIPERS
