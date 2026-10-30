-- NarrowHUD, weapon: a weapon's state as shown (d): fire and weapon modes, rate of fire, charge, magazine size, spare magazines.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local TYPES, NO_OBJECT, blocked, field, learned, HEAT_RANGE = N.TYPES, N.NO_OBJECT, N.blocked, N.field, N.learned, N.HEAT_RANGE
local learn, objs, read_weapon, pack_ammo, planet = N.learn, N.objs, N.read_weapon, N.pack_ammo, N.planet

local MODE_NAMES = { [1] = 'AUTO', [2] = 'SEMI', [3] = 'BURST', [4] = 'VOLLEY', [5] = 'SAFE', [6] = 'UNSAFE', [7] = 'TOTAL' }
-- (1.5.18) the game's own HUD icons: sprites on its texture-atlas pages (docs/ICONS.md; the records read from the
-- installed game by tools/atlas_sprites.py, 2026-10-28: a sprite is named by the murmur64 of its path, e.g.
-- content/ui/mission/hud/weapon_function/firemode_single is 3efff09cd12fb89a). Each entry: the page texture's id
-- and the sprite's uv rectangle on it; drawn with chef.bitmap_uv, nothing shipped. The rectangles move when
-- Arrowhead repacks an atlas: rerun the tool after a patch and compare.
N.ATLAS = {
  -- weapon_function/* (128 px) on the mission atlas page f9a3f2 (4096x2048 BC1, 13 mips), the page 10a081
  -- (2048x1024 BC1, 4 mips) and 7b1eef (256x256); the sixth value is the sprite's id (the path's murmur64), which
  -- also names the game's own icon material for it (the mask shader: black is empty, R and G the icon's white, B
  -- its shadow; HD2Runtime's finding). Drawn in game 2026-10-28: every one of these, through that material.
  AUTO     = { 'f9a3f22a93eedcbd', 0.223388671875, 0.2265625, 0.254638671875, 0.2890625, '6115051c9558c50e' },
  SEMI     = { 'f9a3f22a93eedcbd', 0.943115234375, 0.1640625, 0.974365234375, 0.2265625, '3efff09cd12fb89a' },
  BURST    = { 'f9a3f22a93eedcbd', 0.786865234375, 0.1640625, 0.818115234375, 0.2265625, '131742904d846798' },
  VOLLEY   = { 'f9a3f22a93eedcbd', 0.634521484375, 0.0078125, 0.665771484375, 0.0703125, '16413ee2e6725687' },
  UNDERBARREL = { 'f9a3f22a93eedcbd', 0.301513671875, 0.2265625, 0.332763671875, 0.2890625, 'b019df1ca8b6d4a2' },
  UNDERBARREL_SHOTGUN = { 'f9a3f22a93eedcbd', 0.947021484375, 0.0859375, 0.978271484375, 0.1484375, '067bb0962f896bbb' },
  UNDERBARREL_FLAMER = { 'f9a3f22a93eedcbd', 0.340576171875, 0.2265625, 0.371826171875, 0.2890625, 'cd87fdddec2a6bfc' },
  APHET    = { 'f9a3f22a93eedcbd', 0.379638671875, 0.1484375, 0.410888671875, 0.2109375, 'f8ede5f922c05cb6' },
  FLAK     = { 'f9a3f22a93eedcbd', 0.457763671875, 0.1484375, 0.489013671875, 0.2109375, '9dcc0312a14e11e6' },
  FRAG     = { 'f9a3f22a93eedcbd', 0.496826171875, 0.1484375, 0.528076171875, 0.2109375, '8dc0ec9ce217ab7f' },
  HEAT     = { 'f9a3f22a93eedcbd', 0.630615234375, 0.1640625, 0.661865234375, 0.2265625, '4b867645db9f364e' },
  HE       = { 'f9a3f22a93eedcbd', 0.535888671875, 0.1484375, 0.567138671875, 0.2109375, '081dcaf42dc2ecbb' },
  FLECHETTE = { 'f9a3f22a93eedcbd', 0.712646484375, 0.0859375, 0.743896484375, 0.1484375, '3b975896bc689499' },
  STUN     = { 'f9a3f22a93eedcbd', 0.708740234375, 0.1640625, 0.739990234375, 0.2265625, '2d9268907fb9420e' },
  LASER    = { 'f9a3f22a93eedcbd', 0.829833984375, 0.0078125, 0.861083984375, 0.0703125, 'c1028550c62fc4fa' },
  NO_LASER = { 'f9a3f22a93eedcbd', 0.790771484375, 0.0078125, 0.822021484375, 0.0703125, 'a9f9bf81827c51e5' },
  GUIDED   = { '10a0814c0fad8650', 0.6328125, 0.578125, 0.6953125, 0.703125, '7db70e669d8034c9' },
  UNGUIDED = { '10a0814c0fad8650', 0.7109375, 0.578125, 0.7734375, 0.703125, 'bc7975e05284cf57' },
  DEPLOY   = { '10a0814c0fad8650', 0.8671875, 0.578125, 0.9296875, 0.703125, '38adabc6a32af014' },
  DETONATE = { '10a0814c0fad8650', 0.7890625, 0.578125, 0.8515625, 0.703125, '55374383474193f8' },
  AIRSTRIKE = { '10a0814c0fad8650', 0.2421875, 0.578125, 0.3046875, 0.703125, 'f83f6f461ed94e4b' },
  BURST_FIRE = { '7b1eef337fc5f1bf', 0.0625, 0.0625, 0.5625, 0.5625, '62d0512daebb0be0' },
  -- (1.5.47) a scope's zeroing step (weapon_function/zeroing_low, _medium, _high on the mission HUD page)
  ZEROING_LOW    = { 'f9a3f22a93eedcbd', 0.223388671875, 0.1484375, 0.254638671875, 0.2109375, '6be28cced767bb52' },
  ZEROING_MEDIUM = { 'f9a3f22a93eedcbd', 0.262451171875, 0.1484375, 0.293701171875, 0.2109375, '46271d0b4ce4136c' },
  ZEROING_HIGH   = { 'f9a3f22a93eedcbd', 0.591552734375, 0.09375, 0.622802734375, 0.15625, 'a2ab43e85546f79a' },
  -- unnamed sprites that look like the HUD's stim, stims and grenade icons (the stim page isn't loaded in a mission)
  stim     = { '18edbed388a3d706', 0.155517578125, 0.89208984375, 0.171142578125, 0.92333984375, 'a0e91aa5aab7b94d' },   -- 64 px
  stims    = { '1667261d881bd08a', 0.94921875, 0.4169921875, 0.98046875, 0.4482421875, '55decfa1c7de5d20' },             -- 128 px
  grenade  = { 'f9a3f22a93eedcbd', 0.095947265625, 0.76171875, 0.111572265625, 0.79296875, 'e1ebfa9b2ca0963c' },         -- 64 px
}
-- the words of what's shown -> the sprite the game's HUD uses for them (the fire modes; the weapon's own modes: the
-- WASP's BURST is burst_fire, its ARTILLERY the airstrike, the Airburst's CLUSTER the frag; the Railgun's SAFE the
-- single, UNSAFE the burst; seen against the HUD 2026-10-28)
local FIRE_SPRITES = { AUTO = 'AUTO', SEMI = 'SEMI', BURST = 'BURST', VOLLEY = 'VOLLEY', SAFE = 'SEMI', UNSAFE = 'BURST' }
local OPTION_SPRITES = { APHET = 'APHET', FLAK = 'FLAK', HEAT = 'HEAT', HE = 'HE', FLECHETTE = 'FLECHETTE', STUN = 'STUN',
  LASER = 'LASER', ['NO LASER'] = 'NO_LASER', GUIDED = 'GUIDED', UNGUIDED = 'UNGUIDED', DEPLOY = 'DEPLOY', DETONATE = 'DETONATE',
  CLUSTER = 'FRAG', ARTILLERY = 'AIRSTRIKE', BURST = 'BURST_FIRE' }
-- the underbarrel selected, by its type: the grenade launcher's icon, the shotgun's, the flamer's (the Arbitrator's
-- shotgun: to be learned from the research log, "underbarrel type")
-- (luka's logs, 2026-10-28: the One-Two's launcher 16425925, the Arbitrator's shotgun da0f356e, the Stoker's flamer 2166c7a1)
local UNDERBARREL_SPRITES = { ['16425925'] = 'UNDERBARREL', da0f356e = 'UNDERBARREL_SHOTGUN', ['2166c7a1'] = 'UNDERBARREL_FLAMER' }
local ub_said = {}
-- a sprite entry with the word it stands for (the icon takes the word's colour, as the text does); made once per
-- sprite and word
local worded = {}
local function with_word(e, word)
  local key = e[6] .. word
  local w = worded[key]
  if not w then
    w = { e[1], e[2], e[3], e[4], e[5], e[6], word = word }
    worded[key] = w
  end
  return w
end
N.FIRE_WORD = function(word) return word == 'ZOOM' or FIRE_SPRITES[word] ~= nil end   -- (1.5.57: the icons apart)
N.mode_icons = function()
  local d = N.shown_d
  if not d then return nil end
  local out = {}
  if d.mode then
    local rest = d.mode
    while rest and rest ~= '' do
      local word, more = string.match(rest, '^(.-)  (.*)$')
      word = word or rest
      rest = more
      local e = OPTION_SPRITES[word] and N.ATLAS[OPTION_SPRITES[word]]
      if e then out[#out + 1] = with_word(e, word) end
    end
  end
  -- (1.5.47) the scope's zeroing step, for a weapon learned to have one: the game's low / medium / high icon
  if d.zoom then
    local name = ({ [0] = 'ZEROING_LOW', 'ZEROING_MEDIUM', 'ZEROING_HIGH' })[d.zoom]
    if name then out[#out + 1] = with_word(N.ATLAS[name], 'ZOOM') end
  end
  if d.underbarrel then
    local name = UNDERBARREL_SPRITES[d.tid]
    if not name and not ub_said[d.tid] then ub_said[d.tid] = true log('research: underbarrel type %s: no sprite known for it (the generic underbarrel icon)', tostring(d.tid)) end
    out[#out + 1] = with_word(N.ATLAS[name or 'UNDERBARREL'], d.ub_label or 'UB')
  else
    -- (a weapon with an underbarrel shows its fire mode's icon even with one mode: the switch is to the underbarrel,
    -- as the game's HUD shows it; the text keeps its two-modes rule)
    local fm = d.fmode or d.fmode_ub
    if fm and FIRE_SPRITES[fm] then out[#out + 1] = with_word(N.ATLAS[FIRE_SPRITES[fm]], fm) end
  end
  return out[1] and out or nil
end
-- (seen against the game's own display, 2026-10-24: Pummeler, Autocannon, Bushwhacker, Railgun)
local function seen(kind, id, value)
  local list = learned[kind][id] or ''
  local key = ',' .. tostring(value) .. ','
  if not string.find(',' .. list .. ',', key, 1, true) then
    list = list == '' and tostring(value) or (list .. ',' .. tostring(value))
    learn(kind, id, list)
  end
  return string.find(list, ',', 1, true) ~= nil      -- two or more seen
end
-- the fire mode (on the left of the bar, with the weapon's own mode)
local function fire_mode_label(t, w)
  local fm = tonumber(w.fire_mode)
  if fm and math.floor(fm / 8) % 2 == 0 and seen('modes', t.id, fm % 8) then
    return MODE_NAMES[fm % 8] or ('MODE ' .. (fm % 8))
  end
  return nil
end
-- the rate of fire (small, under the count)
-- The rate field is the rate in effect: Extreme Cold lowers every weapon's by 10 % (the Helldivers 2 wiki), while the
-- game's menu shows the setting. So the setting is shown: each weapon's settings are learned (not while it's cold), a
-- reading 0.9 of a known setting is that setting and means it's cold (for every weapon, until a reading matches a
-- setting again), and the planet's measured cooling (x1.5) says so too.
local cold = { wid = nil, on = false }
local function is_cold()
  local wid = chef.world_id and chef.world_id()
  if wid ~= cold.wid then cold.wid, cold.on = wid, false end
  return cold.on or planet.factor == 1.5
end
local function in_list(list, v)
  for x in string.gmatch(list or '', '[^,]+') do
    local n = tonumber(x)
    if n and math.abs(n - v) <= 1.5 then return n end
  end
  return nil
end
local function rpm_setting(id, v)
  local base = learned.rpmbase[id]
  local exact = in_list(base, v)
  if exact then cold.on = false return exact end
  local warm = in_list(base, v / 0.9)
  if warm then cold.on = true return warm end
  if is_cold() then return math.floor(v / 0.9 + 0.5) end
  learn('rpmbase', id, base and (base .. ',' .. v) or tostring(v))
  return v
end
local rpm_last = {}
local function setting_label(t, w)
  local parts = {}
  local rpm = tonumber(w.rpm)
  if rpm and rpm > 0 and not t.has.heat then                  -- (heat weapons: the field isn't a rate of fire)
    -- (another rate in the same fire mode: a rate of fire setting. Not across missions, and not one 0.9 of the other:
    -- Extreme Cold's 10 %, the Sightliner's 40 and 36 on two planets taught it a setting it doesn't have)
    local wid = chef.world_id and chef.world_id()
    local last = rpm_last[t.id]
    if last and last.wid ~= wid then last = nil end
    local cold_pair = last and (math.abs(rpm - last.rpm * 0.9) <= 1.5 or math.abs(last.rpm - rpm * 0.9) <= 1.5)
    if last and last.fm == w.fire_mode and last.rpm ~= rpm and last.rpm > 0 and not cold_pair and not learned.rpmadj[t.id] then
      log('learned: type %s has a rate of fire setting', t.id)
      learn('rpmadj', t.id, true)
    end
    rpm_last[t.id] = { fm = w.fire_mode, rpm = rpm, wid = wid }
    if learned.rpmadj[t.id] then parts[#parts + 1] = rpm_setting(t.id, math.floor(rpm + 0.5)) .. ' RPM' end
  end
  return #parts > 0 and table.concat(parts, '  ') or nil
end

-- A weapon's own mode is in its options field, two bits per setting (seen in the research log, 2026-10-24): the bits at
-- 4 are the ammo type or guidance (the Warrant 80 / 84, the Autocannon, Recoilless, Airburst and missile pistol the
-- same), the bits at 256 the C4's deploy / detonate (80 / 336), the bits at 4096 the fire mode (shown under the count
-- instead), the rest fixed. Named weapons show their mode at once; others show OPT <n> once the bits at 4 have been
-- seen with two values.
local OPTION_NAMES = {
  c920c2d3 = { at = 4, [0] = 'GUIDED', [1] = 'UNGUIDED' },     -- the Warrant
  fd585726 = { at = 4, [0] = 'GUIDED', [1] = 'UNGUIDED' },     -- the missile pistol
  ['7bfb2e06'] = { at = 4, [0] = 'APHET', [1] = 'FLAK' },      -- the Autocannon
  b2bfd847 = { at = 4, [0] = 'HEAT', [1] = 'HE' },             -- the Recoilless Rifle
  ['8a3c6fee'] = { at = 4, [0] = 'FLAK', [1] = 'CLUSTER' },    -- the Airburst Rocket Launcher
  ['6b2c3bed'] = { at = 256, [0] = 'DEPLOY', [1] = 'DETONATE' }, -- the C4
  ['656d507b'] = { at = 4, [0] = 'BURST', [1] = 'ARTILLERY' },  -- the WASP
}
-- Weapons with two loaded ammo types, chosen by the selected field (slot0 / slot1): the Halt's flechette and stun rounds
-- (a player's log, 2026-10-26: selected 0 on flechette, 1 on stun)
local SELECTED_NAMES = { ['9c06f074'] = { [0] = 'FLECHETTE', [1] = 'STUN' } }
-- (the game's HUD names for a weapon's two fires; luka, 2026-10-28)
local UB_NAMES = {
  cd0e4b4a = { main = '12MM', ub = 'FLAME' },          -- the Stoker
  ['8fcdd35c'] = { main = '4MM', ub = '10G' },         -- the Arbitrator (its underbarrel shotgun)
  ['3244dc49'] = { main = '8MM', ub = '40MM HE' },     -- the One-Two (its underbarrel launcher)
}
local function option_mode(t, w)
  local v = tonumber(w.options)
  if not v then return nil end
  local names = OPTION_NAMES[t.id]
  if names then return names[math.floor(v / names.at) % 4] end
  local m = math.floor(v / 4) % 4
  if not seen('options1', t.id, m) then return nil end
  return 'OPT ' .. m
end

-- charge meters (seconds to the end of the meter, and a mark), from the Helldivers 2 wiki
local CHARGE_METER = {
  ['26acc614'] = { secs = 3, mark = 2.5 },      -- RS-422 Railgun (unsafe: 90 % at 2.5 s, explodes at 3 s)
  ['314a1bf5'] = { secs = 3.25, mark = 2.6 },   -- PLAS-45 Epoch (full charge at 2.6 s, explodes at 3.25 s)
}

-- what to show for a weapon state
local function shown(s, goid, t, w, o)
  local d = { kind = nil }
  d.setting = setting_label(t, w)
  d.fmode = fire_mode_label(t, w)
  -- (most weapon types declare the underbarrel field; one is fitted only when it holds an object)
  local ub_bit = type(w.fire_mode) == 'number' and math.floor(w.fire_mode / 8) % 2 == 1
  local ub = t.has.underbarrel and (N.REF_READS or ub_bit) and field(s, goid, t, 'underbarrel')
  d.has_ub = type(ub) == 'number' and ub ~= NO_OBJECT
  if not d.fmode and d.has_ub and type(w.fire_mode) == 'number' and math.floor(w.fire_mode / 8) % 2 == 0 then
    d.fmode_ub = MODE_NAMES[w.fire_mode % 8]
  end
  -- the names the game's HUD gives a weapon's two fires (the Stoker: 12MM and FLAME; luka, 2026-10-28)
  local un = UB_NAMES[t.id]
  if un then d.ub_label = un.ub end
  d.t0, d.goid0 = t, goid                                        -- (the weapon itself, for its charge meter)
  -- (1.5.47) the scope's zeroing step (0 the lowest, 2 the highest) for a weapon learned to have one
  if learned.zoom[t.id] and type(w.options) == 'number' then d.zoom = math.floor(w.options / 16) % 4 end
  -- (1.5.54) the zeroing as text, an F9 row: 50 / 100 / 200 m for the low / medium / high step
  if d.zoom then d.zoom_word = ({ [0] = '50 M', '100 M', '200 M' })[d.zoom] end   -- (the layouts' zoom part shows it)
  d.mode = option_mode(t, w)
  if un and un.main and not d.mode then d.mode = un.main end
  local sn = SELECTED_NAMES[t.id]
  if sn and t.has.selected then
    local m = sn[tonumber(w.selected) or 0]
    if m then d.mode = d.mode and (m .. '  ' .. d.mode) or m end
  end
  -- laser guidance on / off (the Commando: a field of its own, seen in the research log 2026-10-24)
  if t.has.guide and w.guide ~= nil then
    local g = w.guide == true and 'LASER' or 'NO LASER'
    d.mode = d.mode and (d.mode .. '  ' .. g) or g
  end
  -- the underbarrel, when the fire mode selects it
  if d.has_ub and type(w.fire_mode) == 'number' and math.floor(w.fire_mode / 8) % 2 == 1 then
    local o = objs[ub]
    local ut = o and o.t and TYPES[o.t]
    if ut then
      t, w, goid = ut, read_weapon(s, ub, ut), ub
      d.underbarrel = true
    end
  end
  d.tid = t.id                                                   -- (the weapon shown: the underbarrel when selected)
  if t.has.heat and not t.has.rounds then
    d.kind = 'heat'
    local h = tonumber(w.heat) or 0
    -- Where it overheats: per weapon object, as attachments change it (the LAS-5 Scythe: 60, 100 or 150 with its heat
    -- sinks, a player's report). The type keeps the last one seen, for the next mission's start. While overheated:
    -- the highest heat read is the point (a read can land a moment after it, a little lower: within 8 % below the
    -- one known, that one stays). Heat past the known point means it's higher.
    -- The heat can read 0 already in the first overheated read (the Scythe, a 2026-10-26 log: "overheats at 0"), so
    -- the heat just before counts too, and a point under 30 never does (no weapon overheats that low). A lower point is
    -- taken only from an overheat seen starting (not one already under way when the weapon was first shown: its heat
    -- had cooled some).
    local top = learned.heat[t.id] or 100
    local ho = (not d.underbarrel) and o or nil
    local now = chef.time()
    if ho and type(w.heat) == 'number' then
      top = ho.heat_top or top
      if w.overheated == true then
        if ho.oh_peak == nil then
          ho.oh_seen = ho.h_before_t ~= nil and now - ho.h_before_t <= 0.5
          ho.oh_peak = ho.oh_seen and ho.h_before or 0
        end
        if h > ho.oh_peak then ho.oh_peak, ho.oh_read = h, true end
        local p = math.floor(ho.oh_peak + 0.5)
        -- (a value read while overheated is the heat at its top. The one from just before has the field's dead band
        -- (12_heat) over it: the heat went on up to anywhere within the band of that value before overheating, so
        -- the known point stays when it's within that, and a lower one is the band's top; the 1.2.7 log read the
        -- Talon's 84.8 just before and took its point for 85)
        local tol = ho.oh_read and 0 or (N.heat_tol and N.heat_tol(t) or 15.6)
        local lower = ho.oh_seen and p + tol < top * 0.92
        if lower then p = math.floor(p + tol + 0.5) end
        if p >= 30 and (p > top or lower) then ho.heat_top, top = p, p end
      else
        if ho.oh_peak then
          ho.oh_peak, ho.oh_read = nil, nil
          local k = learned.heat[t.id]
          if top >= 30 and (k == nil or top > k or top < k * 0.92) then
            if k then log('learned: type %s overheats at %d (was %d: an attachment?)', t.id, top, k) end
            learn('heat', t.id, top)
          end
        end
        ho.h_before, ho.h_before_t = h, now
      end
      if h > top then ho.heat_top, top = math.ceil(h), math.ceil(h) end
    elseif w.overheated == true and h > top and h >= 30 then
      learn('heat', t.id, math.floor(h + 0.5))
      top = math.floor(h + 0.5)
    end
    local range = HEAT_RANGE[t.id]
    if range then top = range.top end
    local rest = learned.rest2[t.id] or 0
    -- a charge weapon while charging: the heat field stays put until the shot, so the bar rises over the charge time
    local secs = learned.charge2[t.id]
    if secs and w.charging == true and o and o.charge_t0 then
      d.charge_anim, d.charge_secs, d.charge_from = true, secs, h   -- (run every frame, below)
      h = h + (top - h) * math.min(1, (chef.time() - o.charge_t0) / secs)
    end
    d.top_raw, d.tid, d.t, d.goid = top, t.id, t, goid
    d.top = top - rest
    d.value = math.max(0, h - rest)
    d.overheated, d.charging = w.overheated == true, w.charging == true
    d.rest, d.o = rest, o
    -- (past 100: the bar runs to its top, the % reads the heat as it is, the mark where it starts to hurt)
    if range then
      d.heat_marks, d.pct_top = {}, top
      for _, m in ipairs(range.marks) do d.heat_marks[#d.heat_marks + 1] = { (m[1] - rest) / (top - rest), m[2] } end
    end
  elseif t.has.rounds then
    d.kind = 'ammo'
    local n = tonumber(w.rounds) or 0
    d.mag = n                                                     -- the magazine alone (its size is learned from it)
    if t.has.chamber and w.chamber == false then n = n + 1 end   -- a round in the chamber
    d.value = n
  elseif t.has.slot0 then
    d.kind = 'ammo'
    local sel = tonumber(w.selected) or 0
    local n = tonumber(sel == 1 and w.slot1 or w.slot0) or 0
    if t.has.chamber and w.chamber == false then n = n + 1 end   -- a shell in the chamber (single-shot launchers)
    d.value, d.mag = n, n                                         -- (the chamber is part of what it holds)
  elseif t.noammo then
    d.kind = 'none'                                               -- (only its modes and charge meter)
  elseif t.fed then
    local r, pg = pack_ammo(s)
    if r == nil then return d end                                -- no pack on you: nothing to show
    d.kind, d.value, d.mag, d.fed = 'ammo', r, r, true
    -- (its bar is the pack's: the most that pack type was seen holding, not the weapon's: the Maxigun's and the
    -- Cremator's share a hand pose)
    local pt = TYPES[objs[pg].t]
    if r > (learned.pack[pt.id] or 0) then learn('pack', pt.id, r) end
    d.pack_top = learned.pack[pt.id]
  end
  if d.kind == 'ammo' then
    -- the bar is the magazine: a tactical reload's extra round in the chamber shows in the count, not as a bigger
    -- magazine
    if d.pack_top then
      d.top = d.pack_top
    else
      if d.mag > (learned.mag[t.id] or 0) then learn('mag', t.id, d.mag) end
      -- The magazine's size is this weapon's in this mission: attachments change it (the Liberator Penetrator's
      -- shortened magazine: 30 instead of 45), and they're set for the whole mission. The most this object has held
      -- is its size, once it's known to have been full: it was there in the mission's first 30 s (you drop with
      -- full magazines), held as much as the most learned, or was reloaded. Until then, the most learned.
      local top = learned.mag[t.id] or d.mag
      local o = objs[goid]                                         -- (the underbarrel's own object when it's selected)
      -- (two loaded ammo types, the Halt's: each its own magazine, kept apart, so a switch isn't taken for a reload)
      if o and t.has.slot1 and t.has.selected and SELECTED_NAMES[t.id] then
        local sel = tonumber(w.selected) or 0
        o.per_sel = o.per_sel or {}
        o.per_sel[sel] = o.per_sel[sel] or {}
        o = o.per_sel[sel]
      end
      if o then
        if o.mag_max == nil then
          o.mag_max = d.mag
          o.mag_full = (blocked.since ~= nil and chef.time() - blocked.since < 30) or d.mag >= (learned.mag[t.id] or 0)
        elseif d.mag > o.mag_max then
          o.mag_max, o.mag_full = d.mag, true
        elseif o.mag_prev and d.mag > o.mag_prev then
          o.mag_full = true
        end
        o.mag_prev = d.mag
        if o.mag_full then top = o.mag_max end
      end
      d.top = math.max(1, top)                                     -- (a single-shot weapon's magazine is always 0)
    end
  end
  d.reloading = (tonumber(w.reload_stage) or 0) ~= 0 and d.kind == 'ammo'
  d.reload_stage = tonumber(w.reload_stage)
  -- the reserve: magazines, else spare rounds, else your backpack's
  if learned.packres[t.id] then
    d.reserve = pack_ammo(s)                                    -- (reloads from its backpack: the C4's charges ...)
  elseif d.fed then
    -- (the pack is the ammo)
  -- (a heat weapon's magazines are heat sinks: shown once it has carried some, 0 too when they're used up; a charge
  -- weapon's field never means anything)
  elseif t.has.magazines and tonumber(w.magazines) and (not t.has.heat or (not N.CHARGE_WEAPONS[t.id]
         and (w.magazines > 0 or (learned.resmax[t.id] or 0) > 0)))
         and not (N.seat and N.seat.gun == goid and w.magazines == 0) then
    d.reserve = w.magazines
    if t.has.heat and w.magazines > (learned.resmax[t.id] or 0) then learn('resmax', t.id, w.magazines) end
  elseif t.has.spare then d.reserve = tonumber(w.spare)
  elseif d.kind == 'ammo' and N.seat and N.seat.gun == goid then
    -- (1.5.51: a mounted gun with no magazines (the emplacements' belts) shows its rounds alone, not "x0")
  elseif d.kind == 'ammo' then
    -- (not for a heat weapon: the Nova and the Scythe showed the Guard Dog's magazines as theirs)
    for pgoid, o in pairs(objs) do
      local pt = o.t and TYPES[o.t]
      if pt and pt.pack and o.on and pt.has.remaining then
        local r = field(s, pgoid, pt, 'remaining')
        if type(r) == 'number' then d.reserve = r break end
      end
    end
  end
  return d
end


N.CHARGE_METER, N.shown = CHARGE_METER, shown
