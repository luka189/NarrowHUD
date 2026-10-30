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
local SNIPERS = { b697955d = 'APW-1 Anti-Materiel Rifle', ['30294946'] = 'R-40 Sightliner', a4eff4fa = 'AMW-20 Apex' }
local rt = { on = false, said = nil }
local function first_person()
  local cam = chef.camera()
  local u = N.my_unit and N.my_unit()
  if not (cam and u and chef.unit_position) then return false end
  local x, y = chef.unit_position(u)
  if not x then return false end
  local dx, dy = cam.x - x, cam.y - y
  return dx * dx + dy * dy < 0.25                   -- (half a metre across: the camera at your head, not behind you)
end
-- d: the weapon shown (its tid); drawn while aimed (the aim button, or the stance field at 4) in third person
local function draw_reticle(d, now)
  if not cfg.reticle or not d or not SNIPERS[d.tid] then rt.on = false return end
  local st8 = N.state8
  local aimed = input.aiming or (st8 and st8.aim == 4)
  local on = aimed and not first_person()
  if on ~= rt.on then
    rt.on = on
    if cfg.research then log('research: sniper crosshair %s (%s; aim button %s, stance %s)', on and 'shown' or 'hidden', SNIPERS[d.tid], tostring(input.aiming), tostring(st8 and st8.aim)) end
  end
  if not on then return end
  local w, h = chef.screen()
  if not w then return end
  local sx, sy = math.floor(w / 2 + 0.5), math.floor(h / 2 + 0.5)
  local L = N.L0 + 895
  local c, back = N.col(N.CREAM, 240), N.col({ 0, 0, 0 }, 150)
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
    drawn = N.icon_texture('reticle', x0, y0, S, N.CREAM, 1.09, L)
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
