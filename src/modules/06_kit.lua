-- NarrowHUD, kit: a weapon's attachments, as the game lists them, and what NarrowHUD learns per kit.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)
local call, norm_id, cfg, alive = N.call, N.norm_id, N.cfg, N.alive

-- A weapon's 98b4aaf0 field (the game's name hpinuxg; the Helldiver has one too) is a list of 64-bit ids, one per
-- customization slot the weapon has. luka's 2026-11-01 missions, the Breaker and the Sweeper:
--   Breaker, 1.5x tube red dot, vertical foregrip, full choke, short magazine:
--     {f9df21c8e52cac95 490c9e167b3aaf8c 1683585f8aef3ea2 75713afac474d9c4 9992e382b80955cc 344e58664bde2872}
--   the magazine extended: the 5th id 9992e382b80955cc > 68b8d040421e8a49
--   the optic a reflex sight: the 2nd id 490c9e167b3aaf8c > fa994cd576b2f912
--   Sweeper, reflex sight, full choke: {f40dea68b213b005 fa994cd576b2f912 a57694699f3ffd97 75713afac474d9c4}
-- So: an attachment has one id on every weapon (the reflex sight fa994cd576b2f912 and the full choke 75713afac474d9c4
-- on both), the ids are the same after a restart (two runs an hour apart), and a weapon with nothing fitted still has
-- one id (the Verdict's 309f7e645a8d2b56: the piece itself, or its paint). The ids are not the hash of any name or
-- path filediver knows, so nothing is decoded: NarrowHUD learns per kit instead — the magazine's size and the
-- overheat point seen with this exact list on this weapon type (learned.kitmag / kitheat, keyed
-- "<type>:<id>+<id>+...") are known from the first frame the next time the same kit comes out, in place of the type's
-- last seen. The paint slot is in the key too (an unknown position), so a repaint learns again: cheap.
local KIT_NAME = string.match(DATA.fieldnames or '', '98b4aaf0 (%S+)')
-- (2.1.11: only a type that has the field. 2.1.10 read it from every weapon on you, and luka's HMG emplacement
-- (fa6ddf17: rounds, no owner, so counted as yours) has no 98b4aaf0: game_object_field of a field the type
-- doesn't have crashed the game on the spot, the last line of the loader trace. The type's own list from
-- Network.object_info decides, the build's data when that gives nothing)
local KIT_OK = {}
local function kit_ok(t)
  local v = KIT_OK[t.id]
  if v ~= nil then return v end
  v = false
  local ok, info = pcall(call, 'objinfo', 'Network.object_info', t.name)
  if ok and type(info) == 'table' and type(info.fields) == 'table' then
    for _, f in ipairs(info.fields) do
      if type(f) == 'table' and norm_id(f.id) == '98b4aaf0' then v = true end
    end
  else
    local line = string.match('\n' .. (DATA.fields or ''), '\n' .. t.id .. ' ([^\n]*)')
    v = line ~= nil and string.find(line, '98b4aaf0', 1, true) ~= nil
  end
  KIT_OK[t.id] = v
  return v
end
-- the list as read: a table of id strings, or nil (no such field, or nothing came)
local function kit_read(s, goid, t)
  if not (KIT_NAME and goid and t and kit_ok(t)) then return nil end
  if not alive(s, goid, t) then return nil end   -- (2.3.2: the object asked about first, as every read; cached a frame)
  local v = call(t.id .. '.kit', 'GameSession.game_object_field', s, goid, KIT_NAME)
  if type(v) ~= 'table' then return nil end
  local ids = {}
  for i = 1, math.min(#v, 12) do ids[i] = tostring(v[i]) end
  return ids
end
-- the research log's text for a weapon's list
function N.kit_text(s, goid, t)
  if not (KIT_NAME and goid and t) then return '?' end
  if not kit_ok(t) then return 'no such field on this type' end
  local ids = kit_read(s, goid, t)
  return ids and ('{' .. table.concat(ids, ' ') .. '}') or 'nil'
end
-- the learned key of an object's kit, read once an object (o: its entry in objs; o.kit false when it has none)
function N.kit_key(s, goid, t, o)
  if not o then return nil end
  if o.kit == nil then
    local ids = kit_read(s, goid, t)
    o.kit = (ids and #ids > 0) and (t.id .. ':' .. table.concat(ids, '+')) or false
    if o.kit and cfg.research then log('research: kit of %s (object %s): %s', t.id, tostring(goid), o.kit) end
  end
  return o.kit or nil
end
