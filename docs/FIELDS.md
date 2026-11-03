# What the game sends about your own objects (build 26088801; 26251122 moved nothing)

From the 1.0.9 and 1.0.10 research logs (2026-10-27, hosting, solo): `GameSession.game_object_field_batched` on your
Helldiver, your player object, your weapons and two objects your Helldiver points at, with `Network.object_info` for
each type's field list. Names marked `=name` are the field's real name (a word or word pair whose 32-bit hash matches;
health, max_health, stamina, booster, zone_health also match HUDdle's names). The rest are only ids; their meaning
below is what the logs showed and is marked as a guess where it is one.

**How the call answers:** a flat list in the type's field order, except for a type with more than 63 fields (the
Helldiver has 72, the mechs 76): its first 63 come as one list in place 64, then 65 on; field 64's own value isn't
given.

**Kinds (object_info's `type`):** 0 true / false, 1 whole number (min, max, bits), 2 decimal (min, max, bits,
tolerance), 3 a Vector3, 4 a rotation (Vector4), 9 a 64-bit id (a peer id, a hash), 10 a list, 11 unknown (field 64).

## Your Helldiver (type 5d9752f9, 72 fields)

| # | Field | Seen |
|---|---|---|
| 1 | 98b4aaf0 | a list of one 64-bit id (the same each life; HUDdle: "kit") |
| 2 | cd889dbc | a state number: 80 in the drop pod, 82 standing, 74 / 88 / 90 moving, 86 with the map open, 72 in a vehicle seat (guess: a locomotion state id) |
| 3 | 6ff0e58a | three 64-bit bit sets of action flags, read as hex strings. Known bits (2.1.x): word 1 bit 48 first-person view, word 1 bit 23 hover-pack flight; word 2 bit 18 aiming down the sights (a toggled aim counts, a knock-out ends it), word 2 bit 22 the weapon settings wheel open. The rest change with sprint, crouch, prone, throw, emote, vehicle, map |
| 4 | 5faee212 | 0 / 1 / 2 with the stance |
| 5 | **stamina** | 1 full, falls about 0.045 a second while sprinting |
| 6 | e3186939 | a rotation (changes all the time) |
| 7, 8 | af97ede7, bdc1cb8a | af97ede7 = **look_at_position** (its real name): where the view's ray meets the world, 998 m out on the sky, on the view at once; bdc1cb8a: the crosshair's hit point the rounds fly to, smoothed (~0.25 s behind the view). Both from Blast & Trajectory Markers 1.2.4's field study (docs/RESEARCH.md); NarrowHUD logs them beside the drop line since 2.2.4 (research) |
| 9 | **map_marker_position** | your map pin (your own position while none is placed). Whether its z is the terrain's height or 0 is still open: NarrowHUD draws a pin at your own height when the field's z is 0, and the 1.3.0 log's 20.8 / 23.2 could be either |
| 10 | **map_marker_type** | 0 none, 7 a placed pin (the 1.3.0 log: 7 the whole time a pin stood, back to 0 when removed; 1 not seen) |
| 11 | **map_marker_goid** | the pin's object (32767 none) |
| 12 | **spawn_time** | 5 or 4 when you land, then -1 |
| 13, 14 | 913af9a2, 0c09236b | two objects on you (types 67e52a93 and 4b3aa0ac, 15 fields each, nothing seen to change) |
| 15 | **terminal_interact** | a terminal object (32767 none) |
| 16 | **player_goid** | your player object |
| 17 | **ragdoll_position** | |
| 18 | **network_mask** | 0 in a vehicle, 1 on foot, 13 for a moment getting out |
| 20, 61 | a09ccd0a, 4441caf8 | true on foot, false in a vehicle (HUDdle: the same for a mech) |
| 23 | **position** | |
| 25 | 20efbed4 | the object you're next to or looking at (a backpack on the ground, a pin; Integrated HUD: your vehicle). An emplacement's seat (the HMG: its seat object; the AT: the gun itself) while you sit; not the FRV's turret (1.5.51) |
| 26, 27 | **motion_mode**, **motion_enabled** | motion_enabled false in the pod, in a vehicle, dead |
| 32 | **is_falling** | |
| 34 | 268ac291 | counts up by one at each vehicle exit and each emote (guess: an action counter) |
| 35 | **death_damage_type** | 10 from the start (not changed by the death seen) |
| 38 | **state** | 0 alive, 2 dead |
| 39 | cad5b537 | 0, then 699050 after the reinforcement landed |
| 40 | **max_health** | 125 |
| 42 | **health** | 125 full; 0 dead; a stim brought 29 to 125 within about a second |
| 43 | **zone_health** | -1 (a mech's per-part damage, HUDdle) |
| 45 | 8fd2d63e | -1, then 4095 after the first damage |
| 46 | **input** | 0 |
| 47 | **active_emote** | -1 none, an emote's hash while emoting |
| 48 | 95c46304 | the weapon's stance: 0 lowered, 3 raised (firing from the hip, overheated, a charge: the 1.2.2 log), 4 around a shot while aimed (for the shot's or charge's length only, not while you aim: the 1.4.5 log), 1 around a throw. Not the stratagem input (HUDdle reads 3 so) |
| 49 | **enabled_mask** | 5 alive, 7 while emoting, 0 dead |
| 56 | **num_throwables** | grenades |
| 57 | **num_stims** | stims |
| 58 | **stance** | 0 standing, 1 crouched, 2 prone |
| 59 | edbf0131 | -3.14 to 3.14: the way you face (radians) |
| 60 | 2932144a | 0 still, 1 walking, 1.2 sprinting, 0.65 crouched (guess: a speed step) |
| 67-69 | e4d00fe1, dae681f4, 6d976352 | 1, 100, 100 (never changed) |
| 70 | a33df340 | 0, 1, 2 at times; doesn't follow stims (the 1.2.2 log), unknown |

## Your player object (type 803159b3, 36 fields)

The avatar (2: your Helldiver's object, 32767 between lives), 3 (257 alive, 256 dead, 0 after the mission),
**loadout_state**, **index**, **body_type**, **helmet_set**, **cape_set**, **armor_set**, **booster**,
**voice_pack_set**, **customization_seed**, **player_title_index**, **avatar_flags** (5, then 7 after the first
reinforcement), a list of six 32-bit ids (26: the loadout?) and one of six 5s. Nothing changed when stratagems were
called or stims used: **no stratagem cooldowns here**, as HUDdle found.

## Weapons (23 to 27 fields)

What NarrowHUD reads (rounds_remaining, magazines_remaining, chamber_empty, fire_mode, options, rpm, heat,
is_overheated, is_charging, reload_stage, underbarrel_goid, original_owner), plus:
- **is_firing** (3132608f): what NarrowHUD calls "held".
- **position**, **rotation**, **is_moving**, **enabled_mask**: (0, 0, 0) while carried; a dropped weapon (on your
  body after a death) gets a position and is_moving true, enabled_mask 1 or 2.
- 98b4aaf0 (game name hpinuxg): the attachments, one 64-bit id per customization slot the weapon has (2.1.12, luka's
  differential missions: an attachment's id is the same on every weapon and after a restart; the reflex sight
  fa994cd576b2f912, the full choke 75713afac474d9c4, the Breaker's short / extended magazine 9992e382b80955cc /
  68b8d040421e8a49, its 1.5x tube red dot 490c9e167b3aaf8c). Not the hash of any known name or path; NarrowHUD
  learns per kit (06_kit). Not every weapon type has the field — reading it from one that doesn't (the HMG
  emplacement's gun fa6ddf17) crashes the game.
- c20428c6 / 6d1d5cfb: one-entry lists ({12} / {1}; the Railgun {10} / {1.1}); not the scope zoom (below).
- **The scope's zoom step is in options (31f86165), bits 16 and 32** (luka's 2026-10-30 marks: the R-40 Sightliner's
  options 80 → 96 → 64 → 80 and the AMW-20 Apex's 96 → 64 → 80 → 96, one zoom press each; nothing else on the
  weapon moved). `(options / 16) % 4`: 0 the lowest zoom, 1, 2 the highest; bit 64 stays set on both (the scope
  present, or its kind). The Helldiver's cd889dbc (#2 in the all-fields order; the same name hash as the weapons'
  reload_stage) goes 74 → 106 → 74 (+32) around each press, with the input bits in 6ff0e58a: the press itself.
- **spread_seed**: a new random number each reload.
- 31182caf: bits that empty over the last 4 rounds of a magazine.
- **6f3ab277** (-0.5 to 1.58, 7 bits, radians): the aim's pitch of a weapon that aims by itself. 0 on every weapon
  a Helldiver holds (your own, ten missions); changes all the time on SEAF soldiers' rifles, turrets, a Guard Dog's
  gun, tanks', emplacements. A support weapon out of its hellpod kept a stray 0.012 (one quantum off 0) in it while
  held (a 1.2.7 log). NarrowHUD 1.2.8 tells soldiers' guns from yours by it moving.
- reload_stage: a tactical reload 0, 1, 0; from empty 0, 4, 5, 7, 0 (the Liberator).
- **heat** (a5023836): a dead-banded value (object_info tolerance 15.62): the game sends it once the heat has moved
  by that from the last value sent, so falls come in steps of 15.7 and a shot of less than the band can hide inside
  it. The last value before an overheat is a lower bound of the overheat point (the Talon's 84.8 for 100). The
  Talon's rises read about 12 a shot (the wiki: 15) in a 1.2.7 log.

## Backpacks with a model of their own (2.1.x; 02_settings `SPECIAL`)

- **Hover pack efb4a22e**: one flag f8d23bd2, true in flight (it stays on about a second past touchdown). No fuel
  field: the fuel is modelled — burnt for the whole time the flag is on (the bar's tank 8.1 s; a drop down a slope
  lends a little that directional input spends, so a flag-on time of 10.9 s still lands at zero), refilled at
  1.15 x the flag's time from touchdown. Fitted from luka's marked flights (two sessions).
- **Shield backpack b0b9f710**: 1ad6d70f = charge (its real name), 150 full, sent only when moved by its tolerance
  39; 6fee6b03 true while broken; 24cf7e78 true while regenerating; b19ad128 = active goes false when it breaks.
- **Directional shield d3e4682e** (20 fields, max_health 400, a raised / lowered flag 7f7d11f7) and **ballistic
  shield 2b651283** (26 fields, max_health 1000, state 0 > 2 stowed): no health field; their damage isn't networked.
- Jump pack 3a9a3ab0 and warp pack c89adf0c: a recharge / heat field each (1.5.x).
