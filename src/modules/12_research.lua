-- NarrowHUD, research: the research log's field watching.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local ROLE, call, norm_id, alive = N.ROLE, N.call, N.norm_id, N.alive
local TYPES, HANDHELD, objs = N.TYPES, N.HANDHELD, N.objs

------------------------------------------------------------------------------------------------ research
-- (1.2.6: the per-field watch of the weapon in hand (1.0.x) and the 1.0.7 hand check through the unit synchronizer
-- are gone: the all-fields reader below covers the first, and the synchronizer answered nil in every game)

-- (research, 1.0.9: everything the game sends about your own objects. GameSession.game_object_field_batched (Chef
-- 1.2.2 and newer) gives every field of an object at once, in its type's order; Network.object_info gives that order
-- with each field's id, kind and range. Your Helldiver, your player and the weapons and backpack on you (never another
-- player's object: the call has ended the game on those; Chef checks the object exists, and after a crash in it skips
-- that call (Chef 1.3: the mod stays on; before, it was turned off until updated)). Each object: all its fields once, then the changes, read every half second, one object a frame. A
-- field that changes at almost every read (a position, an aim) is left out after 20 reads, said once. 6000 lines.)
local BR = { lines = 0, next = 0, queue = {}, types = {}, objs = {}, wid = nil, said = {} }
local ROLE_OF = {}
for k, r in pairs(ROLE) do ROLE_OF[norm_id(r.id)] = k end
-- (1.0.10) the real names of fields seen in the 1.0.9 log, found by trying words and word pairs against the 32-bit
-- hashes (a match of a plain word or a sensible pair is near certain; logged with "=" so a guess isn't taken as fact)
local REAL_NAMES = {}
for id, name in string.gmatch([[
cb0453ea=health 9ddf0683=max_health 7870bb31=stamina 8bbeb160=position 20605662=rotation 82830aed=state
8d874f55=stance b19ad128=active 2bbcabe5=input c336a25c=key 3b12bd49=booster 9d550ad3=zone_health
5f8eb478=num_stims d92082f9=num_throwables 1510fa6a=is_falling 2d27198c=is_moving 3132608f=is_firing
88b7cf6d=is_charging f6275c53=is_overheated 4a893e74=chamber_empty 49c250a6=fire_mode d7a5d63e=rounds_remaining
ec64918b=magazines_remaining 67526982=underbarrel_goid 3ccffa7f=original_owner 7030c54e=spread_seed
248ff28e=spawn_time cf55c86e=player_goid a5f83fa0=ragdoll_position d1930672=active_emote d6a4a959=motion_mode
d49efb40=motion_enabled dab52fe8=death_damage_type eef04e89=terminal_interact 27c07e3e=map_marker_goid
b463e168=map_marker_type 4b7fae39=map_marker_position bd5b4583=avatar_flags 9256767e=network_mask
788b9753=enabled_mask 86c3722=loadout_state b03b8bce=index e0a22d09=body_type e46a6928=helmet_set
b7d3a2ec=armor_set ff071a32=cape_set 9a54379a=voice_pack_set 31ea730a=customization_seed 1d7272d6=player_title_index
]], '(%x+)=(%S+)') do REAL_NAMES[id] = name end
local function br_log(fmt, ...)
  if BR.lines >= 6000 then return end
  BR.lines = BR.lines + 1
  log(fmt, ...)
  if BR.lines == 6000 then log('research: all fields: 6000 lines written, no more this session') end
end
local function br_val(v, depth)
  local tv = type(v)
  if tv == 'number' then
    if v == math.floor(v) and math.abs(v) < 1e15 then return string.format('%d', v) end
    return string.format('%.4g', v)
  elseif tv == 'table' then
    if depth >= 2 then return '{...}' end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if type(a) == type(b) and (type(a) == 'number' or type(a) == 'string') then return a < b end
      return type(a) < type(b)
    end)
    local parts, n = {}, #v
    for i = 1, math.min(#keys, 24) do
      local k = keys[i]
      local plain = type(k) == 'number' and k >= 1 and k <= n and k == math.floor(k)
      parts[i] = (plain and '' or (tostring(k) .. '=')) .. br_val(v[k], depth + 1)
    end
    return '{' .. table.concat(parts, ' ') .. (#keys > 24 and (' ... ' .. #keys .. ' in all') or '') .. '}'
  end
  return tostring(v)
end
-- a type's field list, once: [i] = { id, label }, and logged (8 a line) with each field's kind and range
local function br_type(t)
  local ti = BR.types[t.id]
  if ti ~= nil then return ti or nil end
  local ok, info = pcall(call, 'objinfo', 'Network.object_info', t.name)
  if not (ok and type(info) == 'table' and type(info.fields) == 'table') then
    BR.types[t.id] = false
    br_log('research: all fields: Network.object_info gives nothing for type %s', t.id)
    return nil
  end
  ti = {}
  local line = {}
  for i, f in ipairs(info.fields) do
    local id = type(f) == 'table' and norm_id(f.id) or '?'
    local role = (HANDHELD[t.id] or t.pack) and ROLE_OF[id]        -- (NarrowHUD's names: weapons and backpacks only)
    local real = REAL_NAMES[id]
    ti[i] = { id = id, label = id .. (real and ('=' .. real) or '') .. (role and not real and (' ' .. role) or '') }
    local range = ''
    if type(f) == 'table' and f.bits then
      range = string.format(' %s..%s %sb', br_val(f.min, 1), br_val(f.max, 1), tostring(f.bits))
      if f.tolerance and f.tolerance ~= 0 then range = range .. ' ~' .. br_val(f.tolerance, 1) end
    end
    line[#line + 1] = string.format('#%d %s (kind %s%s)', i, ti[i].label, type(f) == 'table' and tostring(f.type) or '?', range)
    if #line == 8 or i == #info.fields then
      br_log('research: all fields: type %s: %s', t.id, table.concat(line, ', '))
      line = {}
    end
  end
  BR.types[t.id] = ti
  return ti
end
local function br_read(s, goid, t, label, now)
  local ti = br_type(t)
  if not ti then return end
  local fn = ENGINE_GS and ENGINE_GS.game_object_field_batched
  if type(fn) ~= 'function' then
    if not BR.said.absent then BR.said.absent = true br_log('research: all fields: GameSession.game_object_field_batched not offered (Chef 1.2.2 or newer has it)') end
    return
  end
  if not alive(s, goid, t) then return end
  local ok, vals = pcall(fn, s, goid, {})
  if not ok or type(vals) ~= 'table' then
    local why = ok and ('it gave ' .. type(vals)) or tostring(vals)
    if not BR.said[why] then BR.said[why] = true br_log('research: all fields: %s %s (object %s): %s', label, t.id, tostring(goid), why) end
    return
  end
  -- (a type of more than 63 fields, the Helldiver's 72: the game gives the first 63 as a list in place 64, then 65 on;
  -- field 64's own value isn't given (the 1.0.9 log, and Integrated HUD reads the vehicle from avatar[64][25] too))
  local packed = false
  if #ti > 63 and vals[1] == nil and type(vals[64]) == 'table' then
    local f, inner = {}, vals[64]
    for i = 1, 63 do f[i] = inner[i] end
    for i = 65, #ti do f[i] = vals[i] end
    vals, packed = f, true
  end
  -- (an object of yours another field points at: read too, from the next round on; the Helldiver's 913af9a2 and
  -- 0c09236b hold two objects on you of types NarrowHUD doesn't know)
  if t.avatar then
    BR.refs = {}
    for i = 1, #ti do
      local v = vals[i]
      local o = type(v) == 'number' and v ~= 32767 and objs[v]
      local rt = o and o.t and TYPES[o.t]
      if rt and not rt.avatar and not rt.player and #BR.refs < 4 then BR.refs[#BR.refs + 1] = { v, rt, 'object in your Helldiver\'s ' .. ti[i].label } end
    end
  end
  local ob = BR.objs[goid]
  if ob == nil or ob.tid ~= t.id then
    ob = { tid = t.id, vals = {}, changes = {}, reads = 0, noisy = {} }
    BR.objs[goid] = ob
    local parts = {}
    local n = math.max(#ti, #vals)
    for i = 1, n do
      local sv = br_val(vals[i], 0)
      ob.vals[i] = sv
      parts[#parts + 1] = string.format('#%d %s=%s', i, ti[i] and ti[i].label or '?', sv)
      if #parts == 10 or i == n then
        br_log('research: all fields: %s %s (object %s): %s', label, t.id, tostring(goid), table.concat(parts, ', '))
        parts = {}
      end
    end
    if packed then br_log('research: all fields: %s %s: the first 63 fields come as a list in place 64 (field 64 itself not given)', label, t.id)
    elseif #vals ~= #ti then br_log('research: all fields: %s %s gives %d values, its type declares %d fields', label, t.id, #vals, #ti) end
    return
  end
  ob.reads = ob.reads + 1
  local ch = {}
  for i = 1, math.max(#ti, #vals) do
    if not ob.noisy[i] then
      local sv = br_val(vals[i], 0)
      if sv ~= ob.vals[i] then
        ob.changes[i] = (ob.changes[i] or 0) + 1
        if string.find(sv, '^Vector') or string.find(sv, '^Quaternion') or string.find(sv, '^Matrix')
           or (ob.reads >= 20 and ob.changes[i] >= ob.reads * 0.8) then
          ob.noisy[i] = true
          br_log('research: all fields: %s %s: #%d %s changes all the time, left out (now %s)', label, t.id, i,
            ti[i] and ti[i].label or '?', string.sub(sv, 1, 120))
        else
          ch[#ch + 1] = string.format('#%d %s %s>%s', i, ti[i] and ti[i].label or '?', string.sub(ob.vals[i] or 'nil', 1, 120), string.sub(sv, 1, 120))
        end
        ob.vals[i] = sv
      end
    end
  end
  if #ch > 0 then br_log('research: all fields: %s %s: %s', label, t.id, table.concat(ch, ', ')) end
end
N.batched_research = function(s, now, shown_goid, grip)
  if BR.lines >= 6000 then return end
  local wid = chef.world_id and chef.world_id()
  if BR.wid ~= wid then BR.wid, BR.objs, BR.queue, BR.next, BR.refs = wid, {}, {}, now + 2, nil end
  if #BR.queue == 0 then
    if now < BR.next then return end
    BR.next = now + 0.5
    local me = N.me
    if me.avatar then BR.queue[#BR.queue + 1] = { me.avatar, TYPES[2], 'your Helldiver' } end
    if me.player then BR.queue[#BR.queue + 1] = { me.player, TYPES[1], 'your player' } end
    -- (the weapon in hand, the weapons learned for a hand pose (as host a SEAF squad's guns are yours too: not those),
    -- and up to two backpacks on you)
    local nw, np = 0, 0
    local poses = N.learned.poses
    for goid, o in pairs(objs) do
      local t = o.t and TYPES[o.t]
      if t and o.on and not o.notmine and not t.other and not t.player and not t.avatar then
        if goid == shown_goid then
          table.insert(BR.queue, 1, { goid, t, 'weapon in hand' })
        elseif t.pack or t.special or t.other then
          if np < 3 then np = np + 1 BR.queue[#BR.queue + 1] = { goid, t, t.pack and 'backpack' or 'carried' } end
        elseif HANDHELD[t.id] and nw < 4 and (poses[t.id] or (grip and grip ~= 0 and N.learned.grip[t.id] == nil and not o.ub)) then
          -- (the weapons learned for a pose, and while one is in your hand, those not learned yet: what an Arc
          -- Thrower changes when fired)
          nw = nw + 1
          BR.queue[#BR.queue + 1] = { goid, t, 'weapon' }
        end
      end
    end
    local queued = {}
    for _, e in ipairs(BR.queue) do queued[e[1]] = true end
    for _, r in ipairs(BR.refs or {}) do
      local o = objs[r[1]]
      if o and o.t and TYPES[o.t] == r[2] and not queued[r[1]] then queued[r[1]] = true BR.queue[#BR.queue + 1] = r end
    end
    return
  end
  local e = table.remove(BR.queue, 1)
  br_read(s, e[1], e[2], e[3], now)
end
