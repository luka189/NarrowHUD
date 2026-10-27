-- NarrowHUD, beside: the Beside and Corner layouts.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local cfg, learned, learn, txt_width, txt, CREAM = N.cfg, N.learned, N.learn, N.txt_width, N.txt, N.CREAM
local WARN, RED, col, empty_rect, solid_bar, txt_modes = N.WARN, N.RED, N.col, N.empty_rect, N.solid_bar, N.txt_modes
local MARK_COLORS, heat_tone, draw_items = N.MARK_COLORS, N.heat_tone, N.draw_items

local function draw_side(d, items)
  local w, h = chef.screen()
  if not w then return end
  local k = (h / 1440) * (cfg.side_size or 1.25)
  local big = math.floor(28 * k + 0.5)
  local small = math.max(7, math.floor(16 * k + 0.5))
  local tiny = math.max(6, math.floor(12 * k + 0.5))
  local vw, vh = math.max(2, math.floor(4 * k + 0.5)), math.floor(big * 1.7 + 0.5)
  -- the bar's left edge and bottom (bottom-left origin): just right of the crosshair, or (the corner) by the game's
  -- weapon panel, bottom left; then the offsets; kept on the screen
  local x0, yb
  if cfg.corner then x0, yb = w * 0.02, h * 0.16
  else x0, yb = w / 2 + h * 0.03, h / 2 - vh / 2 end
  x0 = math.floor(x0 + w * (cfg.off_x or 0) / 100)
  yb = math.floor(yb + h * (cfg.off_y or 0) / 100)
  x0 = math.max(0, math.min(x0, w - math.floor(140 * k)))
  yb = math.max(math.floor(30 * k), math.min(yb, h - vh))
  local nx = cfg.show_bar and (x0 + vw + math.floor(8 * k)) or x0
  local ny = yb + vh - big                                   -- the count's baseline: its top level with the bar's
  local L = 905
  local below = ny                                           -- where the next line goes (top of it)
  local lw = math.max(1, math.floor(k * 0.8 + 0.5))           -- (an outline's width)

  local function vbar(frac, tone, alpha, n)
    if not cfg.show_bar then return end
    if n then
      local gap = math.max(1, math.min(vh / n * 0.3, 3 * k))
      local step = (vh + gap) / n
      for i = 0, n - 1 do
        local ya, yz = math.floor(yb + i * step + 0.5), math.floor(yb + i * step + step - gap + 0.5)
        if i < frac then chef.rect(x0, ya, vw, math.max(1, yz - ya), col(tone, alpha), L)
        else empty_rect(x0, ya, vw, math.max(1, yz - ya), 55, L, lw) end
      end
    else
      solid_bar(x0, yb, vw, vh, frac, col(tone, alpha), L, lw, true)
    end
  end

  local labels = {}
  local count_w = nil
  if d and d.kind == 'none' then
    local f = d.charge_frac or 0
    vbar(math.min(1, f), f >= 1 and WARN or CREAM, 230)
    local left = d.mode or d.fmode
    if left then txt_modes(nx, ny, left, small, 200, L) end
    below = ny
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
    if d.kind == 'ammo' and d.top and d.top <= 10 and d.top >= 1 then
      local n = math.max(d.top, math.min(d.value, d.top + 3))
      vbar(d.value, tone, alpha, n)
    else
      vbar(frac, tone, alpha)
      if d.kind == 'heat' and not learned.charge2[d.tid] and cfg.show_bar then
        for _, m in ipairs(d.heat_marks or { { 0.75, 3 } }) do
          chef.rect(x0 - 2, yb + math.floor(vh * m[1]), vw + 4, math.max(1, math.floor(2 * k)), col(MARK_COLORS[m[2]], 220), L + 2)
        end
      end
    end
    local str = d.kind == 'heat' and string.format('%d%%', math.floor(frac * (d.pct_top or 100) + 0.5)) or tostring(d.value)
    count_w = 0
    if cfg.show_count then
      txt(nx, ny, str, big, col(tone, 245), L)
      count_w = txt_width(str, big)
    end
    -- a charge meter (the Railgun, the Epoch, a lock-on): a thin vertical line just inside the bar (on the
    -- crosshair's side), filling from the bottom up
    if d.charge_frac then
      local cwid = math.max(1, math.floor(2 * k + 0.5))
      local cx0 = x0 - math.max(1, math.floor(2 * k + 0.5)) - cwid
      local f = d.charge_frac
      local cc = d.locked and WARN or (f >= 0.95 and not d.t0.has.lock and not d.charge_safe and RED or (f >= (d.charge_mark or 2) and WARN or CREAM))
      chef.rect(cx0, yb, cwid, vh, col(CREAM, 40), L)
      chef.rect(cx0, yb, cwid, math.floor(vh * math.min(1, f) + 0.5), col(cc, 230), L + 1)
      if d.charge_mark then
        chef.rect(cx0 - 1, yb + math.floor(vh * d.charge_mark), cwid + 2, math.max(1, math.floor(2 * k)), col(WARN, 220), L + 2)
      end
    end
    -- the spare magazines: a square each, grey ones up to the most this weapon has carried (learned; more than 12:
    -- xN), or (the option) a number after the count, like Under: | xN
    if d.reserve then
      local o = d.o or {}
      if d.reserve > (o.res_top or 0) then o.res_top = d.reserve end
      local id = not d.underbarrel and d.t0 and d.t0.id
      if id and d.reserve > (learned.resmax[id] or 0) then learn('resmax', id, d.reserve) end
      local top = math.max(d.reserve, o.res_top or 0, id and learned.resmax[id] or 0)
      if cfg.mags_number then
        local rx = nx + (count_w > 0 and count_w + math.floor(8 * k) or 0)
        chef.rect(rx, ny, math.max(1, math.floor(2 * k)), big, col(CREAM, 150), L)
        txt(rx + math.floor(7 * k), ny, 'x' .. tostring(d.reserve), small, col(CREAM, 220), L)
      else
        local ps, pg = math.max(2, math.floor(6 * k + 0.5)), math.max(1, math.floor(3 * k + 0.5))
        local py = ny - math.floor(7 * k) - ps
        if cfg.mags_hide then top = d.reserve end
        if top <= 12 then
          for i = 0, top - 1 do
            local x = nx + i * (ps + pg)
            if i < d.reserve then chef.rect(x, py, ps, ps, col(CREAM, 220), L)
            elseif cfg.outline then empty_rect(x, py, ps, ps, 55, L, lw)
            else chef.rect(x, py, ps, ps, col({ 150, 150, 150 }, 120), L) end
          end
          below = py
        else
          txt(nx, ny - math.floor(7 * k) - tiny, 'x' .. tostring(d.reserve), tiny, col(CREAM, 220), L)
          below = ny - math.floor(7 * k) - tiny
        end
      end
    end
    if d.underbarrel then
      if cfg.show_mode then labels[#labels + 1] = 'UB' end
    elseif d.mode then labels[#labels + 1] = d.mode end
    if d.fmode and not d.underbarrel then labels[#labels + 1] = d.fmode end
    if d.kind == 'heat' and cfg.show_heat then table.insert(labels, 1, 'HEAT') end
    if d.setting then labels[#labels + 1] = d.setting end
  end
  if #labels > 0 then
    below = below - math.floor(6 * k) - tiny
    txt_modes(nx, below, table.concat(labels, '  '), tiny, 190, L)
  end
  if items and (cfg.show_stims or cfg.show_grenades or cfg.pack) then
    -- (the icons at the Small size's scale, the text as is; closer together)
    -- (the backpack's bar over the count, as wide as the count's line)
    local ph = math.max(2, math.floor(4 * k))
    local bar = { x = nx, y = yb + vh + math.max(3, math.floor(8 * k)), w = math.max(math.floor(60 * k), count_w or 0) }
    draw_items(items, d, k, tiny, nx, below - math.floor(8 * k), nx + math.floor(120 * k), ph, k * 0.8, math.floor(10 * k), bar)
  end
end


N.draw_side = draw_side
