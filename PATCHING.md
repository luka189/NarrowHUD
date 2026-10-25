# After a Helldivers 2 patch

NarrowHUD reads game objects by hashed type and field names taken from one game build's network config. A patch can
rename, add or move fields, and reading a field a type doesn't declare can end the game. So on a game version it doesn't
know (`BUILDS` in `src/narrowhud.lua`), NarrowHUD checks its data first: with Chef 1.2 and later, `Network.object_info`
gives each type's declared fields, and a type that's gone or no longer declares a field NarrowHUD reads is left out
(the log: "game version check: done: N types as NarrowHUD's data, M left out"). Only when the player's or the
Helldiver's fields moved, or on Chef 1.1 (which refuses object_info), it stays off and says so for the first 25 s of each
mission, unless the player turns on "Run on a game version it wasn't made for" in the F9 menu.

So after most patches NarrowHUD keeps working. Still do the steps below: weapons left out need the data remade, and
new weapons need it too.

## 1. Find the new version string

Run the game once with NarrowHUD installed. The log (`narrowhud.log` next to `chef_loader.log`, in
`%APPDATA%\Arrowhead\Helldivers2`) has a line:

    game version: stingray:NNNNN <hash>, not the one NarrowHUD's data is from (Steam build 26088801): off unless ...

Note the string and the Steam build number (SteamDB, or the game's properties in Steam).

## 2. Check whether the network config changed

1. `filediver.exe -T network_config -o extracted` ([filediver](https://github.com/xypwn/filediver)) gives
   `generated.network_config.main`.
2. `python3 tools/parse_netcfg.py generated.network_config.main types.json`
3. Compare with the last `types.json` (kept outside the repo). If the types NarrowHUD uses (the player, the
   Helldiver, the weapons and backpacks in `src/data_generated.lua`) have the same fields in the same order, only the
   version string is new: add it to `BUILDS` with the new Steam build and go to step 5.

## 3. Remake the data (the config changed)

1. `python3 tools/make_data.py types.json - --ids-only > ids.txt`
2. `cc -O3 -fopenmp -o crack_thin tools/crack_thin.c && ./crack_thin - < ids.txt > cracked_new.txt` (only new ids
   need cracking: pass the old cracked files first, comma-separated, and crack what's missing)
3. `python3 tools/make_data.py types.json cracked.txt,cracked_new.txt src/data_generated.lua --build <steam build>`
4. Add the new version string to `BUILDS`, mapped to the new Steam build. Remove the old one: its data no longer
   matches.

## 4. Check what moved

- Role fields (`ROLES` in `tools/make_data.py`): a renamed field drops out of every type that had it. Diff
  `src/data_generated.lua` against the previous one; a weapon that lost its `r` (rounds) or `h` (heat) letter needs
  a look in a research-log mission.
- The avatar's grenades and stims, the player's avatar field: `AVATAR_FIELDS`, `PLAYER_FIELDS`.
- Special packs (`SPECIAL` in `src/narrowhud.lua`): their field ids by hand.
- New weapons: they're learned on their first shot; ship them in the next seed (`tools/make_seed.py`).

## 5. Build, test, release

1. `python3 tools/build.py`
2. `python3 tests/run_tests.py` (0 failed)
3. One mission with the research log on: the log shows "game version: ... as NarrowHUD's data", "objects sorted",
   your weapons and backpack.
4. Bump the version, write the changelog, upload.
