# After a game patch

What to do when Helldivers 2 updates (the log says `game version: stingray:NNNNN …, not the one NarrowHUD's data is
from`). Written 2026-10-29 for 7.2.2 (stingray:46805 437a3d445f9df7662b60086ac8ae3c65b5c95da6, after 7.2.1's
stingray:46659 e176252a3ac4eb5436b25e7cef665a8c71afa243 / Steam build 26088801).

## 1. The game's network config (on the PC with the game)

    filediver.exe -T network_config -o extracted

gives `extracted/…/generated.network_config.main`. Send that file (and the new Steam build id: Steam's
`steamapps/appmanifest_553850.acf`, the `buildid` line, or SteamDB).

## 2. The types and their fields

    python3 tools/parse_netcfg.py generated.network_config.main types.json

Compare with the previous build's `types.json` (the scratchpad keeps the last: `netcfg/`): new types, types gone,
fields added or removed on the types we read (the player 803159b3, the Helldiver 5d9752f9, the weapons and packs).
A field that moved on a type we read is what the version check exists for.

## 3. Names for new ids only

    python3 tools/make_data.py types.json - --ids-only > ids.txt      # every id that needs a name
    # keep only the ids not in cracked.txt, cracked2.txt, cracked3.txt (the previous builds' names still hold)
    cc -O3 -fopenmp -o crack_thin tools/crack_thin.c && ./crack_thin - < new_ids.txt > cracked4.txt

(7 letters is ~78 billion strings an id; a handful of new ids is minutes with OpenMP, hundreds is hours.)

## 4. The data file and the build table

    python3 tools/make_data.py types.json cracked.txt,cracked2.txt,cracked3.txt,cracked4.txt src/data_generated.lua --build <steam build id>

Then `BUILDS` in `src/modules/01_core.lua`: add the new engine string → Steam build id line (keep the old). The
ballistics (`src/ballistics_generated.lua`) only change when HD2Runtime's catalog does. The seed
(`src/learned_seed.lua`) keeps: it's keyed by type id, and a type that vanished is simply never seen.

## 5. Build and check

    python3 tools/build.py && python3 tests/run_tests.py && python3 tools/lint_globals.py
    python3 tools/build.py --research R0 && python3 tools/build.py --research R1     # while the disconnect work is on

Bump the version first (one version a build). Then one mission in game: the log's `game version:` line says
"as NarrowHUD's data"; the HUD shows a weapon from its first shot; F9's rows; anything the changelog touched.

## 6. Ship

CHANGELOG.md, docs/nexus_page.txt (the changelog tab), docs/DEVLOG.md; `python3 tools/publish.py --yes`; the tag and
the zip on GitHub; the Nexus upload.
