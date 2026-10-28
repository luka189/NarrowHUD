-- HD2-Addon: mods/luka189/narrowhud
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
local M = { version = '1.5.14' }
if type(chef.own_log) == 'function' then chef.own_log('narrowhud') end
local log = function(fmt, ...) chef.log(fmt, ...) end
-- (research log only: the game's GameSession table as Chef gives it to this mod, for game_object_field_batched, which
-- Chef wraps in its own guard (it answers only for an object that exists, and a crash in it turns the call off))
local ENGINE_GS = type(stingray) == 'table' and type(stingray.GameSession) == 'table' and stingray.GameSession or nil
-- the modules (src/modules, in order) go here, then: return M
