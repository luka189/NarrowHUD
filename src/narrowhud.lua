-- HD2-Addon: mods/luka189/narrowhud
-- HD2-Requires: chef-shared-loader >= 1.2.3
-- HD2-Keep-On-Crash: yes
-- NarrowHUD (luka189): your weapon's ammo, heat and reserve as a narrow bar under the crosshair, plus grenades and
-- stims. A Chef Shared Loader addon: plain Lua 5.1, read only, every engine call through chef.call_kind (crash
-- guarded). How it knows what you hold:
--   * your weapons are network game objects you own; their types and fields come from the game's network config
--     (DATA, made by tools/make_data.py), read by stand-in names with the same 32-bit hashes as the real ones;
--   * the game says nothing about which one is in your hand, so NarrowHUD reads your Helldiver's hand pose (the
--     animation value weapon_selected) and learns which weapon goes with which pose the first time you fire it
--     (its rounds, shells or heat change while that pose is up), and remembers it (narrowhud learned table);
--   * magazine sizes, overheat points, where heat comes to rest, how long a charge takes, how fast heat rises and
--     falls, and which weapons reload from the backpack are learned too.
-- Keep-On-Crash: if one of the engine calls below ever ends the game, Chef skips only that call from then on (the
-- game font is the likely one: then the pixel font is used).
-- DATA is put in front of this file by tools/build.py.
local chef = ...
local M = { version = '2.0.0' }
-- Two logs of its own (1.5.41): narrowhud.log for what anyone reads (a few hundred lines a session), and
-- narrowhud_research.log for the research rows' field dumps (a megabyte an hour). The loader starts a fresh file
-- for a log once it passes 1 MB at the next launch, so one log for both lost two sessions' plain lines to the
-- research lines on 2026-10-29. A MARK goes to both. chef.own_log rebinds chef.log each time it's called, so each
-- writer is taken right after its call; the main one last, so chef.log_file names it.
local log_main, log_research = chef.log, nil
if type(chef.own_log) == 'function' then
  if chef.own_log('narrowhud_research') then log_research = chef.log end
  if chef.own_log('narrowhud') then log_main = chef.log end
end
log_research = log_research or log_main
local log = function(fmt, ...)
  local ok, s = pcall(string.format, fmt, ...)
  if not ok then s = tostring(fmt) end
  local h7 = string.sub(s, 1, 7)
  if h7 == 'researc' or h7 == 'fields ' or h7 == 'time a ' then return log_research('%s', s) end
  if string.sub(s, 1, 8) == '==== MAR' then log_research('%s', s) end
  return log_main('%s', s)
end
-- (research log only: the game's GameSession table as Chef gives it to this mod, for game_object_field_batched, which
-- Chef wraps in its own guard (it answers only for an object that exists, and a crash in it turns the call off))
local ENGINE_GS = type(stingray) == 'table' and type(stingray.GameSession) == 'table' and stingray.GameSession or nil
-- the modules (src/modules, in order) go here, then: return M
