-- NarrowHUD, research: the research log's field watching.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local ROLE, call, norm_id, alive, KNOWN_FIELDS = N.ROLE, N.call, N.norm_id, N.alive, N.KNOWN_FIELDS

------------------------------------------------------------------------------------------------ research
-- Every field the weapon in hand's type declares (from the game's network config, all of them safe to read), read
-- every 0.1 s, and each change logged: to find what a toggle (the Commando's laser ...) or a mode changes. The fields
-- NarrowHUD already reads are left out, and so is one that changes all the time (logged once as noisy).
local RF = nil
local function research_fields(tid)
  if RF == nil then
    RF = { types = {}, names = {} }
    for line in string.gmatch(DATA.fieldnames or '', '[^\n]+') do
      local id, name = string.match(line, '^(%x+) (%S+)$')
      if id then RF.names[id] = name end
    end
    for _, r in pairs(ROLE) do RF.names[r.id] = nil end   -- (the fields NarrowHUD already reads: logged elsewhere)
    for f in pairs(KNOWN_FIELDS) do RF.names[f] = nil end
    for line in string.gmatch(DATA.fields or '', '[^\n]+') do
      local id, rest = string.match(line, '^(%x+) ?(.*)$')
      if id then RF.types[id] = rest end
    end
  end
  local l = RF.types[tid]
  if type(l) == 'string' then
    local list = {}
    for f in string.gmatch(l, '%x+') do if RF.names[f] then list[#list + 1] = f end end
    RF.types[tid] = list
    l = list
  end
  return l or {}
end
local rws, noisy = {}, {}
N.research_watch = function(s, goid, t)
  local rw = rws[goid]
  if rw == nil or rw.t ~= t then rw = { t = t, vals = {}, counts = {}, started = chef.time(), noisy = noisy } rws[goid] = rw end
  if not alive(s, goid, t) then rws[goid] = nil return end
  local changes = {}
  for _, f in ipairs(research_fields(t.id)) do
    if not rw.noisy[f] and not (t.live and not t.live[norm_id(f)]) then
      local v = call(t.id .. '.' .. f, 'GameSession.game_object_field', s, goid, RF.names[f])
      local sv
      if type(v) == 'table' then
        local parts, n = {}, 0
        for k, x in pairs(v) do
          n = n + 1
          if n <= 8 then parts[#parts + 1] = tostring(k) .. '=' .. tostring(x) end
        end
        table.sort(parts)
        sv = '{' .. table.concat(parts, ' ') .. (n > 8 and ' ...' or '') .. '}'
      else
        sv = tostring(v)
      end
      if string.find(sv, '^Vector') or string.find(sv, '^Quaternion') or string.find(sv, '^Matrix') then
        rw.noisy[f] = true                                -- (a position or rotation: changes as you move)
      end
      if rw.noisy[f] then
        -- (left out)
      elseif rw.vals[f] ~= nil and rw.vals[f] ~= sv then
        rw.counts[f] = (rw.counts[f] or 0) + 1
        if rw.counts[f] > 150 and chef.time() - rw.started < 30 then
          rw.noisy[f] = true
          log('research %s: field %s changes all the time, left out', t.id, f)
        else
          changes[#changes + 1] = string.format('%s %s>%s', f, rw.vals[f], sv)
        end
      end
      rw.vals[f] = sv
    end
  end
  if #changes > 0 then log('research %s: %s', t.id, table.concat(changes, ', ')) end
end

------------------------------------------------------------------------------------------------ each frame

N.rws = rws
