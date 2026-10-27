-- NarrowHUD, under: the Under layout, and which layout draws.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, learned, txt_width, txt, CREAM, WARN = N.cfg, N.learned, N.txt_width, N.txt, N.CREAM, N.WARN
local RED, col, empty_rect, solid_bar, txt_modes, MARK_COLORS = N.RED, N.col, N.empty_rect, N.solid_bar, N.txt_modes, N.MARK_COLORS
local heat_tone, draw_items, seg_max, draw_side, draw_custom = N.heat_tone, N.draw_items, N.seg_max, N.draw_side, N.draw_custom

local function draw(d, items)
  if cfg.custom then return draw_custom(d, items) end
  if cfg.right then return draw_side(d, items) end
  local w, h = chef.screen()
  if not w then return end
  local k = (h / 1440) * cfg.size
  local big = math.floor(28 * k + 0.5)                       -- the count's cap height
  local small = math.max(7, math.floor(16 * k + 0.5))        -- labels and the reserve
  local bw, bh = math.floor(260 * k), math.max(3, math.floor(14 * k))
  -- the bar's bottom (bottom-left origin) and left edge: under the crosshair, then the offsets; kept on the screen
  local y = math.floor(h / 2 - h * 0.09 + h * (cfg.off_y or 0) / 100)
  local x0 = math.floor(w / 2 - bw / 2 + w * (cfg.off_x or 0) / 100)
  y = math.max(math.floor(40 * k), math.min(y, h - math.floor(60 * k)))
  x0 = math.max(math.floor(160 * k), math.min(x0, w - bw - math.floor(130 * k)))
  local L = 905
  -- the mode labels, left of the bar
  local function label(str)
    txt_modes(x0 - math.floor(10 * k), y + math.floor((bh - small) / 2), str, small, 200, L, true)
  end

  if d and d.kind == 'none' then
    -- no ammo of its own: its modes on the left of where the bar would be, and the charge meter
    local left = d.mode or d.fmode
    if left then label(left) end
    if d.charge_frac then
      local ch = math.max(2, math.floor(bh * 0.3))
      chef.rect(x0, y, bw, ch, col(CREAM, 40), L)
      chef.rect(x0, y, math.floor(bw * math.min(1, d.charge_frac) + 0.5), ch, col(d.charge_frac >= 1 and WARN or CREAM, 230), L + 1)
    end
  elseif d then
    local frac = 0
    if d.top and d.top > 0 then frac = math.max(0, math.min(1, d.value / d.top)) end
    local tone = CREAM
    if d.kind == 'ammo' then
      if d.value == 0 then tone = RED elseif frac <= 0.25 then tone = WARN end
    else
      if d.overheated then tone = RED
      elseif d.heat_marks then tone = heat_tone(d, frac)
      elseif frac >= 0.75 and not learned.charge2[d.tid] then tone = WARN end
    end
    local alpha = d.reloading and 120 or 235

    if not cfg.show_bar then
      -- (no bar: the rest stays where it was)
    elseif d.kind == 'ammo' and d.top and d.top <= seg_max() and d.top >= 1 then
      local n = math.max(d.top, math.min(d.value, d.top + 3))  -- a tactical reload's chambered round: a tick more
      -- one tick a round, the gaps narrow (at most 4 px at 1440p): few rounds make long ticks, end to end over the bar
      local gap = math.max(1, math.min(bw / n * 0.45, 4 * k))
      local step = (bw + gap) / n
      for i = 0, n - 1 do
        local xa, xb = math.floor(x0 + i * step + 0.5), math.floor(x0 + i * step + step - gap + 0.5)
        if i < d.value then chef.rect(xa, y, math.max(1, xb - xa), bh, col(tone, alpha), L)
        else empty_rect(xa, y, math.max(1, xb - xa), bh, 55, L, math.max(1, math.floor(k * 0.8 + 0.5))) end
      end
    else
      solid_bar(x0, y, bw, bh, frac, col(tone, alpha), L, math.max(1, math.floor(k * 0.8 + 0.5)))
      if d.kind == 'heat' and not learned.charge2[d.tid] then
        for _, m in ipairs(d.heat_marks or { { 0.75, 3 } }) do
          chef.rect(x0 + math.floor(bw * m[1]), y - 2, math.max(2, math.floor(2 * k)), bh + 4, col(MARK_COLORS[m[2]], 220), L + 2)
        end
      end
    end

    -- the count, then | xN
    local str = d.kind == 'heat' and string.format('%d%%', math.floor(frac * (d.pct_top or 100) + 0.5)) or tostring(d.value)
    local nx = x0 + bw + math.floor(12 * k)
    local ny = y + math.floor((bh - big) / 2)
    local rx = nx
    if cfg.show_count then
      txt(nx, ny, str, big, col(tone, 245), L)
      rx = nx + txt_width(str, big) + math.floor(8 * k)
    end
    local ex = rx                                            -- where the line ends
    if d.reserve then
      chef.rect(rx, ny, math.max(1, math.floor(2 * k)), big, col(CREAM, 150), L)
      txt(rx + math.floor(7 * k), ny, 'x' .. tostring(d.reserve), small, col(CREAM, 220), L)
      ex = rx + math.floor(7 * k) + txt_width('x' .. tostring(d.reserve), small)
    end
    local left = (d.underbarrel and (cfg.show_mode and 'UB' or nil)) or (not d.underbarrel and d.mode) or nil
    if d.fmode and not d.underbarrel then left = left and (left .. '  ' .. d.fmode) or d.fmode end
    if d.kind == 'heat' and cfg.show_heat then left = left and ('HEAT  ' .. left) or 'HEAT' end
    if left then label(left) end
    -- a charge meter (the Railgun, the Epoch): a thin line over the bar while the trigger is held
    if d.charge_frac then
      local ch = math.max(2, math.floor(bh * 0.3))
      local cy = y + bh + math.max(2, math.floor(4 * k))
      local f = d.charge_frac
      local cc = d.locked and WARN or (f >= 0.95 and not d.t0.has.lock and not d.charge_safe and RED or (f >= (d.charge_mark or 2) and WARN or CREAM))
      chef.rect(x0, cy, bw, ch, col(CREAM, 40), L)
      chef.rect(x0, cy, math.floor(bw * math.min(1, f) + 0.5), ch, col(cc, 230), L + 1)
      if d.charge_mark then
        chef.rect(x0 + math.floor(bw * d.charge_mark), cy - 1, math.max(1, math.floor(2 * k)), ch + 2, col(WARN, 220), L + 2)
      end
    end
    if d.setting then                                        -- rate of fire, small, under the count
      local tiny = math.max(6, math.floor(12 * k + 0.5))
      txt(nx, ny - math.floor(7 * k) - tiny, d.setting, tiny, col(CREAM, 190), L)
    end
  end

  if items and (cfg.show_stims or cfg.show_grenades or cfg.pack) then draw_items(items, d, k, small, x0, y - math.floor(8 * k), x0 + bw, math.max(2, math.floor(bh * 0.5))) end
end

-- Health and stamina (vit, from 13_main), drawn every frame on their own: Custom places them from the layout file;
-- Under: over the bar (above the charge meter), the bar's length; Beside: two thin bars mirroring the weapon's on
-- the other side of the crosshair (the corner: left of the weapon's)
local VH_UNDER = { style = 'horizontal', length = 260, thickness = 5 }
local VS_UNDER = { style = 'horizontal', length = 260, thickness = 3 }
local VT_UNDER = { style = 'horizontal', length = 260, thickness = 3 }
local VH_SIDE = { style = 'vertical', length = 48, thickness = 4 }
local VS_SIDE = { style = 'vertical', length = 48, thickness = 3 }
local VT_SIDE = { style = 'vertical', length = 48, thickness = 3 }
local function draw_vitals(vit)
  if cfg.custom then return draw_custom(nil, nil, vit) end
  local w, h = chef.screen()
  if not w then return end
  local E = N.EL_DRAW
  -- (stacked: health, then stamina, then the stim timer, each only where F9 has it on: one off leaves no gap)
  local parts = {}
  if (cfg.health or 1) > 1 then parts[#parts + 1] = { E.health, VH_UNDER, VH_SIDE } end
  if (cfg.stamina or 1) > 1 then parts[#parts + 1] = { E.stamina, VS_UNDER, VS_SIDE } end
  if cfg.stim_timer then parts[#parts + 1] = { E.stim, VT_UNDER, VT_SIDE } end
  if cfg.right then
    local k = (h / 1440) * (cfg.side_size or 1.25)
    local big = math.floor(28 * k + 0.5)
    local vh = math.floor(big * 1.7 + 0.5)
    local x0, yb
    if cfg.corner then x0, yb = w * 0.02, h * 0.16
    else x0, yb = w / 2 + h * 0.03, h / 2 - vh / 2 end
    x0 = math.floor(x0 + w * (cfg.off_x or 0) / 100)
    yb = math.floor(yb + h * (cfg.off_y or 0) / 100)
    x0 = math.max(0, math.min(x0, w - math.floor(140 * k)))
    yb = math.max(math.floor(30 * k), math.min(yb, h - vh))
    local gap = math.max(2, math.floor(4 * k))
    -- (nearest the crosshair first: mirrored, the first one's right edge as far left of the middle as the weapon's
    -- left edge is right of it; the corner: left of the weapon's bar)
    local xr = cfg.corner and (x0 - gap) or math.floor(w - x0)
    for _, p in ipairs(parts) do
      local e = p[3]
      e.length = vh / k
      local th = math.max(1, math.floor(e.thickness * k + 0.5))
      local x = math.max(0, xr - th)
      p[1](e, k, nil, x, yb, false, nil, vit)
      xr = x - gap
    end
    return
  end
  local k = (h / 1440) * cfg.size
  local bw, bh = math.floor(260 * k), math.max(3, math.floor(14 * k))
  local y = math.floor(h / 2 - h * 0.09 + h * (cfg.off_y or 0) / 100)
  local x0 = math.floor(w / 2 - bw / 2 + w * (cfg.off_x or 0) / 100)
  y = math.max(math.floor(40 * k), math.min(y, h - math.floor(60 * k)))
  x0 = math.max(math.floor(160 * k), math.min(x0, w - bw - math.floor(130 * k)))
  local yy = y + bh + math.floor(10 * k)
  for _, p in ipairs(parts) do
    local e = p[2]
    e.length = bw / k
    p[1](e, k, nil, x0, yy, false, nil, vit)
    yy = yy + math.max(1, math.floor(e.thickness * k + 0.5)) + math.max(2, math.floor(3 * k))
  end
end

N.draw, N.draw_vitals = draw, draw_vitals
