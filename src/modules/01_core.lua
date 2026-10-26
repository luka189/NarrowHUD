-- NarrowHUD, core: game data (types, roles), guarded engine reads, the game version check.
-- (tools/build.py puts src/narrowhud.lua and these modules together, each module in a function of its own; N holds
-- what they share: imported as locals below when set once, used as N.x when it changes later)

------------------------------------------------------------------------------------------------ game data
local ROLE = {}            -- role -> { letter, id, name }
for role, r in pairs(DATA.roles) do ROLE[role] = r end
local LETTER = {}          -- letter -> role
for role, r in pairs(ROLE) do LETTER[r.letter] = role end

local TYPES = {}           -- list of { id, name, has = { role = true }, pack = bool }
local function add_types(text, pack)
  for line in string.gmatch(text, '[^\n]+') do
    local id, name, letters = string.match(line, '^(%x+) (%S+) ?(%a*)$')
    if id then
      local has = {}
      for c in string.gmatch(letters, '.') do if LETTER[c] then has[LETTER[c]] = true end end
      -- fed: a weapon with no ammo of its own (it fires straight from its backpack)
      -- (and a reload stage: the types without one ride along with other equipment, seen 2026-10-24)
      local fed = not pack and not (has.rounds or has.slot0 or has.heat) and has.reload_stage == true
      local noammo = not pack and not (has.rounds or has.slot0 or has.heat) and not fed and has.held == true
      TYPES[#TYPES + 1] = { id = id, name = name, has = has, pack = pack, fed = fed, noammo = noammo }
    end
  end
end
-- the player and avatar first (one of each), then backpacks, then weapons
TYPES[1] = { id = DATA.player.id, name = DATA.player.name, has = {}, player = true }
TYPES[2] = { id = DATA.avatar.id, name = DATA.avatar.name, has = {}, avatar = true }
add_types(DATA.backpacks, true)
add_types(DATA.weapons, false)
-- In a hand: only types with an owner field. Every weapon learned in testing has one (59 types); a player's log as host
-- (1.0.1) had two without it (e45066e4, b747653b: objects a host owns, fired as the player fired) learned to the
-- rifles' pose and shown in place of the player's own weapon.
local HANDHELD = {}
for _, t in ipairs(TYPES) do if t.has.owner then HANDHELD[t.id] = true end end
log('NarrowHUD %s: %d types (game build %s)', M.version, #TYPES, tostring(DATA.build))

local AVATAR_RESOURCE = '4d1c334d294dfa97'   -- the third-person Helldiver unit
local GRIP_VARIABLE = 'weapon_selected'      -- the avatar's hand pose (0: nothing in hand)
local NO_OBJECT = 32767
local THROWABLE = { [40] = true, [41] = true }

------------------------------------------------------------------------------------------------ engine reads
local function call(kind, name, ...) return chef.call_kind(name, kind, ...) end
-- a field or type id as lower-case hex without leading zeros (Network.object_info's ids come without them)
local function norm_id(id)
  if type(id) == 'number' then id = string.format('%x', id) end
  if type(id) ~= 'string' then id = id ~= nil and tostring(id) or nil end
  return id and (string.gsub(string.lower(id), '^0+', '')) or nil
end
local function live_fields(name)
  local ok, info = pcall(call, 'objinfo', 'Network.object_info', name)
  if not ok or type(info) ~= 'table' or type(info.fields) ~= 'table' then return nil end
  local set = {}
  for _, f in ipairs(info.fields) do
    local id = type(f) == 'table' and norm_id(f.id)
    if id then set[id] = true end
  end
  return set
end
-- Chef 1.1 refuses the calls NarrowHUD reads your weapons with: said on screen for the first 25 s of a mission
local blocked = { n = 0, said = false, since = nil }
-- An object can go between two reads (an expendable weapon is dropped and destroyed the moment it's used, and its id
-- can come back as another type); reading a gone object's field can end the game. So before an object's fields are
-- read, once a frame: it still exists and is still that type. A gone one is forgotten until the next scan.
N.frame, N.checked = 0, {}
N.forget = nil                                   -- set below (the objects list)
local function alive(s, goid, t)
  local c = N.checked[goid]
  if c and c.frame == N.frame and c.t == t then return c.ok end
  local ok = call('exists', 'GameSession.game_object_exists', s, goid) == true
  if ok and t then ok = call(t.id, 'GameSession.game_object_is_type', s, goid, t.name) == true end
  N.checked[goid] = { frame = N.frame, t = t, ok = ok }
  if not ok and N.forget then N.forget(goid) end
  return ok
end
local function field(s, goid, t, role)
  if not (t and t.has[role]) then return nil end
  if not alive(s, goid, t) then return nil end
  return call(t.id .. '.' .. role, 'GameSession.game_object_field', s, goid, ROLE[role].name)
end

------------------------------------------------------------------------------------------------ the game's version
-- NarrowHUD's data (types and fields, by hash) is taken from one game build's network config. A patch can rename or
-- move fields, and reading a field a type doesn't declare can end the game, so on a game version NarrowHUD wasn't
-- made for it stays off (with a message) unless the player turns on "Run on a game version it wasn't made for".
-- Application.build_identifier per Steam build (the engine's own string):
local BUILDS = {
  ['stingray:46659 e176252a3ac4eb5436b25e7cef665a8c71afa243'] = '26088801',   -- 2026-10-22
}
local game_build = { id = nil, known = nil }
do
  local id = chef.call and chef.call('Application.build_identifier')
  game_build.id = type(id) == 'string' and id or nil
  if game_build.id == nil then
    game_build.known = nil
    log('game version: unknown (no build identifier): running')
  elseif BUILDS[game_build.id] == DATA.build then
    game_build.known = true
    log('game version: %s (Steam build %s, as NarrowHUD\'s data)', game_build.id, DATA.build)
  else
    game_build.known = false
    log('game version: %s, not the one NarrowHUD\'s data is from (Steam build %s): off unless "Run on a game version it wasn\'t made for" is on', game_build.id, DATA.build)
  end
end


N.ROLE, N.TYPES, N.HANDHELD, N.AVATAR_RESOURCE, N.GRIP_VARIABLE, N.NO_OBJECT = ROLE, TYPES, HANDHELD, AVATAR_RESOURCE, GRIP_VARIABLE, NO_OBJECT
N.THROWABLE, N.call, N.norm_id, N.live_fields, N.blocked, N.alive = THROWABLE, call, norm_id, live_fields, blocked, alive
N.field, N.game_build = field, game_build
