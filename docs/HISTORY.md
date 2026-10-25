# Development history (0.1 to 0.4)

The notes written during testing, newest first. Plain release notes: ../CHANGELOG.md.

## 0.4.23

- Game patches, smarter (Chef 1.0.x and 1.2+): on a game version NarrowHUD wasn't made for, it now asks the game for each type's
  declared fields (Network.object_info: on 1.2 it gives every field's id, the 2026-10-25 log) and checks its data
  against them: a type that's gone, or no longer declares a field NarrowHUD reads, is left out; the rest runs. Only if
  the player's or the Helldiver's fields moved, or Chef refuses object_info (1.1 only), does it stay off with
  the message. The research log reads only fields the game still declares.

## 0.4.22

- F9 menu: "Fire button (as bound in the game)" sits right above its key row, now "Fire on a keyboard key: which
  (only with 'A keyboard key' above)". The key row reads NONE unless you fire with a keyboard key; with a mouse
  button picked above it's not used.
- Research log: Network.object_info's field entries in full (the first four) and the count, on Chef 1.2.

## 0.4.21

- Fix: 0.4.20's swap-key bindings stopped NarrowHUD in a mission (Chef switched it off after 20 errors). Chef's
  key binding call gives the binding and its menu row; the last of the three in a table added the row as a fourth
  "binding". (The offline tests' stand-in gave only the binding; it now gives both, as Chef does.)
- Chef Shared Loader 1.2: NarrowHUD runs on it (checked on the loader's own code with a stand-in engine: no
  refusals, no errors). The research log notes once a session what Network.object_info gives for the player's type
  (allowed again from 1.2), to see whether it can check NarrowHUD's data against a patched game.

## 0.4.20

- Fire button and swap keys as bound in the game (NarrowHUD can't read the game's key settings): "Your fire button"
  (left, right, middle mouse, mouse buttons 4 and 5, or a keyboard key set below it), and three swap keys (primary,
  secondary, support; 1 / 2 / 3 by default). The controller's trigger and Y and the mouse wheel still count.
- Colours: Standard, or Colourblind (told apart by brightness as well as hue: white normal, sky blue for the first
  heat mark, yellow for low or hot, magenta for empty or overheated).
- Opacity (20 to 100 %), and "Fade out when full and not firing": down to a quarter after 4 s with a full magazine
  (or cool heat weapon), no shot and no swap; back at once.
- Toggles for the rate of fire, the fire mode and the weapon modes (UNGUIDED, APHET ...).
- Beside the crosshair: an up / down offset (% of the screen).

## 0.4.19

- Game patches: NarrowHUD reads the game's version (Application.build_identifier) and runs only on the version its
  data is from. On another one it stays off, says so for the first 25 s of each mission, and logs the version string;
  "Run on a game version it wasn't made for" in the F9 menu runs it anyway (a renamed field could crash the game).
  PATCHING.md has the steps for us after a patch.
- The learned file: saved with a version number; on reading, entries that don't fit (a damaged or hand-edited file)
  are dropped and counted in the log instead of being used, and a file that can't be read at all is logged and
  NarrowHUD starts from the shipped knowledge.
- Forgetting, two keys in the F9 menu (none set by default): forget what's learned about the weapon in hand (it's
  learned again on its next shot), and forget everything learned (press twice within 3 s). Both fall back to the
  shipped knowledge.
- Beside the crosshair: the spare-magazine squares run to the most magazines that weapon has carried (learned, so
  it holds across missions), the spent ones grey. New option "Beside: spare magazines as": Squares, or A number
  (| x6 after the count, like Under), which moves the mode text up.

## 0.4.18

- Beside the crosshair: the backpack bar sits a little higher over the count (8 px at 1440p instead of 5), so the
  space between the count and the lines around it is even.

## 0.4.17

- Double-Edge Sickle (corrected by the player): it hurts you from 50 % heat, more from 100 %, a lot from 180 %. The
  bar (to 200 %) has a yellow mark at 50, an orange one at 100 and a red one at 180, and the count takes the colour of
  the last mark passed.
- Research log: the "fields" line leaves out heat weapons' rate field (the Double-Edge Sickle's ramps 700 to 770 as
  it spins up, a line every 0.1 s).

## 0.4.16

- The Solo Silo's remote (held like a pistol, on key 3) has the Warrant's hand pose and isn't a weapon NarrowHUD
  knows, so key 3 showed the Warrant and taught that the Warrant is on key 3. Now when a key brings up the pose of a
  weapon learned on another key, something else is in hand: that weapon isn't shown (and no key is learned) until
  the pose changes, its own key is pressed, or it fires (then the key is its after all: a rebind). This replaces
  0.4.15's "seen twice on the new key".
- A weapon with no ammo of its own (the Arc Thrower, maybe the Solo Silo's remote) can now be learned on a pose
  another weapon of yours has, when that one's trigger field reads not held.

## 0.4.15

- Double-Edge Sickle: its heat runs to 200 and hurts you from 100 (the player). The bar now runs to 200, the % reads
  the heat as it is (up to 200 %), the red mark sits at 100 (half the bar), the count goes orange from 75 and red
  from 100. It was also once taken for a charge weapon; that's dropped and can't be learned again.
- Beside the crosshair: the backpack's bar (supply pack, ammo backpacks, warp and jump packs) sits over the count
  instead of after the grenades.
- Swap keys: a key isn't learned for a weapon that came out after two keys pressed in quick succession (it may be
  the first key's), and a weapon already learned on one key moves to another only when seen there twice (the log
  had the Warrant moved from key 2 to 3 once).

## 0.4.14

- Two of your weapons on one hand pose (the Arbitrator and a Bullet Storm on pose 10): swapping showed the other
  one's ammo until it fired. The one fired more (proven yours) was the only candidate kept, so the swap keys had
  nothing to choose between, and a key could be learned for the wrong weapon (the Arbitrator on key 3). Now only
  types someone else's has fired this session are narrowed to the proven one, a key is learned only where the pose
  is one weapon's, and a wrong key fixes itself: when the other weapon fires just after the key, the key is its.
- Beside the crosshair: the grenade and stim icons at the Small size's scale (the text as before), closer together;
  the charge meter (Railgun, Epoch, lock-on) is a thin vertical line just inside the bar, on the crosshair's side,
  filling from the bottom up.
- Charge weapons (Quasar, Nova): no high-heat mark or orange at 75 %; they fire once full.

## 0.4.13

- The start-of-mission backpack rule now covers the first 10 s instead of 20 s: a called backpack takes 10 s to call
  in after landing, plus the code and the landing, so nothing of yours can be worn before then (the 20 s could catch
  a fast pickup). The backpacks it catches aren't map loot (there is none to wear, apart from a few mission
  objectives): most likely a soldier's or an objective's, which as host you own.

## 0.4.12

- Backpacks lying on the map: a backpack's carry field reads 0 worn, 1 in its hellpod and 2 dropped, and one lying on
  the map reads 0 too. A backpack already at 0 in a mission's first 20 s (before any hellpod can land) is now taken
  for the map's: not shown until it's been moved (dropped and picked up) or went down with your reload or fire.
- The Helldiver's object fields don't hold the backpack after all (the log: your player, what you're looking at, two
  objects not yours): the 0.4.10 rule built on them is gone, and they're logged only with the research log on.
- Two weapons on one hand pose and neither fired yet (a mission's start: your Arbitrator and a Stalwart both on pose
  10): the one on the lowest swap key is shown, the primary first. Before, it could be the Stalwart's 249 + 1.
- Chef refusing the reads: the message now says NarrowHUD runs on Chef 1.0.x and 1.2 on (Th3chef will allow the
  three calls in 1.2).

## 0.4.11

- Position "Beside the crosshair (compact)" redone: a short vertical bar, the count right of it, the spare magazines
  as small squares under the count (dim ones for magazines used; more than 12 as xN), then the modes and rate of fire
  in small text, then the grenades and stims. Magazines of up to 10 rounds get a tick a round. Its own distance
  slider (default 3 % of the screen right of the crosshair); "Under" keeps its own.
- Under the crosshair: magazines are drawn a tick a round up to 25 rounds at Small, 33 at Medium, 42 at Large and 50
  at Huge (was 60); bigger ones are a solid bar.
- The Helldiver's six object fields are logged even with the research log off, until the backpack's field is learned
  (it wasn't, in the missions since 0.4.10; the log will say why).
- A backpack gone between two reads no longer stops the backpack bar's update with an error.
- Shipped knowledge refreshed: 95 weapons with a hand pose (from the full weapon run), swap keys included.

## 0.4.10

- A backpack lying on the map (one you never had) could show as yours: its carry field reads as worn. The Helldiver
  has six fields that hold other objects' ids; the one that holds your backpack is learned the first time it holds a
  backpack proven yours (it went down with your reload or fire), and from then on only the backpack it holds is
  yours. The research log shows what each of the six fields holds, to see what the other five are (the weapons in
  your slots, maybe the one in hand).

## 0.4.9

- Research log: each backpack's carry value, ammo and owner as they change, the carry value in the session line, and
  when the backpack bar starts and stops showing (and for which object), to find what was taken for a worn backpack.

## 0.4.8

- Controllers: a gamepad's right trigger counts as your fire button (before, only the left mouse button did, so on a
  controller every shot looked like someone else's and nothing was learned). A controller's Y (weapon swap) works
  like the mouse wheel behind a shield.
- New option, Position: under the crosshair (as before) or right of it. Right of it, the bar is level with the
  crosshair and the mode labels come after the count. The distance slider is now "Distance from the crosshair" and
  sets both.
- When Chef refuses the reads NarrowHUD needs (Chef 1.1), it says so on screen for the first 25 s of each mission and
  once in the log, instead of silently drawing nothing.
- The research log is off by default (F9 menu: "Research log", takes effect from the next start).
- A heat weapon's HEAT label and its mode name no longer draw over each other.

## 0.4.7

- With a shield, the hand pose is the shield's (30, 36) whichever one-handed weapon is out, so swapping between two of
  them didn't change the readout until the other one fired. The swap keys now say which came out: 1, 2 and 3 (the
  game's default binds) and the mouse wheel. Which key each weapon is on is learned when you swap without the shield
  (where the pose tells them apart); until then a key or the wheel switches to the other weapon. A shot still decides
  if the guess is wrong.

## 0.4.6

- The missions where nothing showed: each new world (each mission) starts its object ids over, and NarrowHUD kept
  what it knew about each id from the last one. An id that had been nothing of ours was never looked at again, so
  when it was one of your weapons in the next mission, that weapon went unseen all mission (the log: "0 weapons on
  you", the objects sorted at once). Everything about objects is now forgotten on a new world. Reproduced in the
  offline tests before the fix.
- Shipped knowledge refreshed: 74 weapons.

## 0.4.5

- Rate of fire: the setting, as the game's menu shows it. Extreme Cold lowers every weapon's rate in effect by 10 %
  (the Helldivers 2 wiki), which is what the field holds. Each weapon's settings are learned (not while it's cold); a
  reading 0.9 of a known setting is that setting and means it's cold, for every weapon, until a reading matches a
  setting again; the planet's measured cooling (x1.5) says so too. Shipped settings: Stalwart 700 / 850 / 1150, MG
  630 / 760 / 900, HMG 450 / 600 / 750, belt-fed grenade launcher 160 / 240 / 320, Variable 300 / 550 / 750.

## 0.4.4

- Rate of fire shown as the field has it, with no scaling: the belt-fed grenade launcher's field read 144 / 216 / 288
  in one session and 160 / 240 / 320 (the game's numbers) in the next, so the 1 / 0.9 for it and the Variable made it
  178 / 267 / 356. The field seems to be the rate in effect, which something in a mission can lower.

## 0.4.3

- Backpack bar: 0.4.2's "proven by use" rule is gone (the supply pack has no use animation to prove it by). Instead a
  pack counts as yours when its owner field (where it can be read) is your peer id, so other players' and soldiers'
  packs aren't picked; with several left, the one that went down with your reload or fire.
- Backpack-fed weapons: the bar runs to the most the pack type was seen holding, not the weapon type (the Maxigun's
  1000 stayed on the Cremator, which shares its hand pose).
- Shipped: the Apex reloads from its backpack (seen in the log).
- The session line lists the packs on you.

## 0.4.2

- Backpack bar only for a pack type proven to mean something to you: it went down with your reload, while you fired a
  weapon fed from it, or while you threw something (a supply box). A guard dog's pack never does, so it isn't shown
  (in a joined game the bar tracked something else entirely). Learned per pack type.
- Rate of fire only for weapons whose rate can be set: seen changing while the fire mode stayed the same (the Senator
  showed one: its field reads differently at first). Shipped: Stalwart, MG, HMG, belt-fed grenade launcher, Variable.
- Confirmed in a joined game: your weapons learn and show; a weapon's owner field holds your peer id as text.

## 0.4.1

- Sorting your objects by type in three passes: first what's likely yours (the player and Helldiver, weapons with a
  known hand pose, backpacks and special packs), then the other weapons, then (research log) the other carried things.
  As host you own every soldier's and enemy's objects, and each one that's none of ours was tried against all 775
  types before the next: in a big mission that took longer than the mission (the last one of the test session showed
  nothing). With 3,000 such objects a known weapon now shows in about 4 s (it took over 20 s). 1,000 tests a frame
  (was 600). The log says when sorting is done ("objects sorted: N of yours ...").

## 0.4.0

- Someone else's game: the host may own your weapons, so the host's objects are looked at too, and kept only where the
  weapon's owner field reads your peer id (still being checked in game: a weapon's owner field and the session are
  logged once a mission, 8 s in). In the last mission of the test session nothing of yours was seen at all.
- Jump pack recharge 13.2 s (the flag comes 1.8 s after the jump; 15 s from the press). Hover pack recharge removed (it
  depends on the keys held while landing).
- Shipped knowledge updated from the latest learned file: 69 weapons.

## 0.3.9

- Shipped starting knowledge (src/learned_seed.lua): what NarrowHUD learned in luka189's play, so 54 weapons show
  before their first shot (with their magazine sizes, heat rates, modes and backpack reloads). A player's own learning
  wins. Cleaned of the SEAF troops' rifles, guard dog weapons and other wrong entries; the Scythe's and Laser Cannon's
  overheat point set to the wiki's 100; the Verdict's poses with a shield. tools/make_seed.py remakes it from a
  learned file.

## 0.3.8

- SEAF troops, take three: they fire all the time, so some of their shots land within 0.4 s of yours. A shot now only
  teaches a pose when its object never fired without your fire button; once an object of some type has (someone
  else's), objects of that type must have fired with it twice and more often than without. "Fires on its own" is no
  longer learned per type (SEAF rifles had been, and a type can be yours too); it's per object, per session.
- Hand poses per weapon are a set: with a shield in the other hand the pose changes (the Verdict at 1, 30 and 36), and
  a weapon no longer has to be fired again each time it switches.
- Backpacks: as host you own the SEAF troops' backpacks too. Yours is the one that went down with your reload or while
  you fired, else the only one there is; with several and none proven, none is shown.
- Reloads only count for the weapon in your hand.
- Removed: a guard dog's ammo in the backpack bar (it picked up SEAF rifles).

## 0.3.7

- Yours, take two: 0.3.5's distance check used the weapons' position field, which isn't where a carried weapon is (your
  own Arbitrator read as 231 m away, so it was never shown, nor the Verdict). Removed. Instead a shot counts as yours
  only within 0.4 s of your fire button (the left mouse button, read every frame); an object that fires three times
  more without it than with it is someone else's (a SEAF soldier's) for the rest of the session, and objects fired
  with it are preferred. If the mouse button can't be read, shots aren't checked (logged).

## 0.3.6

- Hover pack: the bar drains over its 6 s flight (it can't be cut short; the research log had the flag on for 5.9 and
  6.0 s), stays empty through the landing assist, then recharges over 8 s from landing.

## 0.3.5

- Yours only: as host you own every SEAF soldier's (and machine's) objects too, and their rifles were learned at your
  Arbitrator's pose. A weapon or pack now counts as on you only within 6 m of your Helldiver (its position field).
- Jump pack and hover pack: their recharge in the backpack bar (the jump pack 15 s from a jump, the hover pack 8 s
  from landing; the times from the player, the moments from their fields, found with the research log).
- Warp pack: the bar runs to 78, the most its heat can reach (a warp adds 33, one over 45 kills).
- Removed: counting a grenade back while it's in your hand (a grenade thrown from the hand took two off the count).
- Research log: the fields NarrowHUD now reads from packs are left out.

## 0.3.4

- Warp pack: its heat gauge (a field of its own, found with the research log: 33 a warp, then cooling) in the backpack
  bar, with marks at 15 and 45 (the Helldivers 2 wiki: a warp over 15 hurts a limb, over 45 kills); cream, orange,
  red.
- Research log: a field is only left out as noisy after 150 changes in its first 30 s (the warp pack's heat was cut off
  after 3 s of cooling).

## 0.3.3

- Research log: every other carried thing (393 more types: jump, hover and warp packs and the like) is recognised
  while the research log is on, and its fields watched; it's never shown. Jump, hover and warp packs aren't ammo
  backpacks, so 0.3.2's backpack watch never saw them.
- Where heat comes to rest is only ever lowered (the Talon learned 10.4 from a pause).

## 0.3.2

- Guard dog and drone weapons: a weapon that fires while your hands hold something else (another weapon, a grenade,
  nothing) three times is learned as firing on its own; it's never taken for the weapon in hand (a pose learned for it
  is forgotten), and its ammo shows in the backpack bar. A weapon whose trigger was never seen held can't take the
  hands from one whose trigger has been. The Hot Dog's weapons had been learned at the Talon's and Sickle's poses.
- A weapon's shot only counts as yours when its trigger was seen held within 0.6 s (for weapons whose trigger field
  has ever been seen held).
- Weapons with no ammo of their own (the Arc Thrower): learned when their trigger is held at a pose no weapon has; shown
  as their modes and a charge meter (1 s, the Helldivers 2 wiki).
- Commando: laser guidance from its own field (seen in the research log), LASER / NO LASER on the left.
- Named: TOTAL (fire mode 7, the Variable), the WASP's BURST / ARTILLERY. The Variable's rate of fire shown as the game
  shows it (the field holds 0.9 of it).
- Research log: your backpack's fields too (jump and hover pack charge), and while nothing is shown, the weapons on you
  not learned yet.

## 0.3.1

- Lock-on (Spear, WASP and other lock-on launchers): the lock progress as a thin line over the bar, orange once
  locked. Found with the research log: a lock progress field (0 to 1) and a locked flag.
- Charge weapons (Quasar, Nova): the charge-up runs every frame (it went in tenths of a second).
- No rate of fire for heat weapons (the Quasar's field isn't one); the belt-fed grenade launcher's rate shown as the
  game shows it (160 / 240 / 320; the field holds 0.9 of that).
- Backpack-fed weapons need a reload stage: the types without one ride along with other equipment and kept the
  Cremator from being learned (three candidates instead of one).
- Research log: table values shown by their contents, positions and rotations left out at once, a noisy field left out
  for every weapon.

## 0.3.0

- Research log: every field the weapon in hand declares (all of them from the game's network config) is watched and
  each change logged by field id, leaving out the ones NarrowHUD already reads and any that change all the time; and
  when the backpack goes down at a hand pose with no weapon learned for it, the backpack-fed candidates on you.
  The data now carries every field id and stand-in name of the weapon and backpack types.
- Where heat comes to rest: learned only after the heat sat still for 4.5 s (0.6 s caught pauses between the game's
  updates mid-cooldown: one pistol learned 11.7); the old values are dropped.
- Backpack-fed weapons: the backpack bar beside the icons is hidden (the ammo bar already is the backpack).

## 0.2.9

- Fire modes moved to the left of the bar, next to the weapon's own mode; the rate of fire stays under the count.
  Named from the research log: VOLLEY (Bushwhacker, 4), SAFE / UNSAFE (Railgun, 5 / 6).
- Charge meter: a thin line over the bar while the trigger is held, for the Railgun (3 s, mark at 2.5 s: unsafe mode
  explodes at 3 s) and the Epoch (3.25 s, mark at full charge, 2.6 s); timings from the Helldivers 2 wiki.
- Heat keeps running between the game's updates while overheated, and cooling rates are learned then too: the Quasar's
  and Nova's cooldown went in about six steps.
- A grenade taken in hand still counts until it's thrown (the game takes it off the count when you draw it).

## 0.2.8

- Weapon modes named from the research log: the missile pistol GUIDED / UNGUIDED, the Recoilless HEAT / HE, the Airburst
  FLAK / CLUSTER, and the C4's DEPLOY / DETONATE (another setting in the options field, the bits at 256). Named weapons
  show their mode at once instead of after the first switch (the Autocannon's).
- Single-shot launchers (missile pistol, Recoilless, Airburst: their magazine is always 0, the round sits in the
  chamber) show one full tick in the normal color instead of an empty red one.

## 0.2.7

- Named from our own research log: fire modes AUTO / SEMI / BURST (the fire mode field's 1 / 2 / 3); the weapon mode is
  the options field's two bits at 4 (the field also carries the fire mode at 4096): the Warrant's GUIDED / UNGUIDED,
  the Autocannon's APHET / FLAK. Other weapons show OPT <n> until named.
- Rate of fire confirmed against the game (Stalwart 700 / 850 / 1150, the MG 630 / 760 / 900).
- A backpack going down within a second of a reload is that reload: learns the weapon as reloading from the backpack,
  and is never taken for a backpack-fed weapon firing. A fed weapon that had been learned on the same hand pose as a
  weapon of its own ammo (the Autocannon's partner object) has that pose forgotten. The Autocannon's backpack count
  vanished after a reload because of it.
- Research log: the ammo fields of the weapon in hand after each reload.

## 0.2.6

- Heat rates of the LAS-5 Scythe (12.5 up / 8.5 down per second) and LAS-98 Laser Cannon (8 / 5) from the Helldivers 2
  wiki; other heat weapons learn theirs.
- Planet temperature: measured each mission from a weapon with a known rate (snapped to the wiki's x0.75 hot, x1, x1.5
  cold) and applied to every heat weapon's cooling; learned cooling rates are kept neutral. Logged as
  `planet cooling x1.50 (cold)`.
- Weapons that reload from their backpack are learned: a reload that adds to the weapon as the backpack goes down.
- Fire modes and weapon modes show as `MODE <n>` / `OPT <value>` until named from our own testing.
- Research log (F9, on for now): the weapon in hand's fire mode, options, rate of fire and selected slot on each change.

## 0.2.5

- Heat is run every frame: up at the weapon's rate while the trigger is held (the trigger-held field, read every
  frame), down at its cooling rate otherwise; a new value from the game is folded in over a quarter second. Before, the
  bar restarted from the game's last value (seconds old) on each press or release and jumped by up to 20 %.
- The C4 and other weapons with spare ammo in their backpack: what's loaded, then the backpack's count.
- A chambered round leaving the weapon counts as a shot (learns the C4 on its first throw).

## 0.2.4

- Heat rates up (trigger held) and down learned per weapon; the bar runs on between the game's updates (about every
  3 s for the Laser Cannon).
- A charge weapon is one whose heat stays flat while the trigger is held and then jumps near its overheat point; the
  Laser Cannon (heats while firing) showed a charge-up. Charge times stored under a new key, so a wrong one is gone.
- Weapon modes from the options field on the left of the bar (the Warrant's guided / unguided).
- Shell weapons: the chambered shell is part of the capacity, so a single-shot underbarrel launcher shows one full tick
  in the normal color (was empty and red).
- The stim and grenade line shows whenever something is in your hand (the C4 hid everything).

## 0.2.3

- Underbarrel objects (the Stoker's flamethrower, the Arbitrator's shotgun) are found through their rifle every scan
  and never taken for the weapon in hand; a hand pose learned for one is forgotten. The shown weapon had flipped between
  the Stoker and its flamethrower.
- Fire mode and rate of fire, small under the count, once a weapon has been seen with two of them.
- Ticks with narrow gaps (at most 4 px at 1440p): a few rounds make long ticks across the bar.
- Stims left, grenades right; a thin backpack bar next to them.
- The game font at every Render Scale again, for now, to judge its look.

## 0.2.2

- Weapons fed straight from a backpack (no ammo of their own) added to the data; learned when the backpack's ammo goes
  down while you fire, then shown with the backpack's ammo.
- Shell weapons, underbarrel launchers included, count a shell in the chamber.
- A tactical reload's chambered round gets its own tick, gone with the first shot.
- Below native Render Scale on Chef 1.0.x: the pixel font (Chef draws in the UI world there, and a GUI in the game's
  world gets upscaled and color-graded: orange came out red with yellow edges).

## 0.2.1

- Before any object is read: it still exists and is still that type, checked once a frame; a gone one is forgotten.
  The expendable napalm, destroyed when used up, crashed the game when read afterwards.
- Magazine size learned from the magazine alone, so a tactical reload no longer makes it one too big.
- Heat runs on between the game's updates at the measured cooling rate (the Quasar's cooldown was choppy).
- Text: the font's runtime copy with the game's runtime-font material (the development material had yellow edges);
  on Chef 1.1 and newer, Chef's own text.

## 0.2.0

- No bar while a stratagem or grenade is held (hand poses 40 and 41); a weapon not learned yet shows from its first
  shot instead of being guessed (a 150-round bar had shown with a stratagem in hand).
- Rounds: +1 whenever the chamber holds one (the support grenade launcher showed 0 with one left).
- Heat runs from where the weapon cools down to (the Nova's ~5) to its overheat point, and rises over the charge time
  while charging (the Nova's 1.6 s built in, others learned).
- The game's HUD font, with Chef's pixel font as the fallback; F9 toggle.
- Grenade and syringe icons instead of G and S.
- The `HD2-Keep-On-Crash` header kept within the first 400 characters, where Chef looks for it.

## 0.1.0

- First version: ammo (a tick per round), heat, reserve, underbarrel and grenades / stims as a narrow bar under the
  crosshair, in the style of Reticle Ammo HUD's "Bar" setting.
- Weapons read as network game objects you own, by stand-in names with the same 32-bit hashes as the game's.
- The weapon in hand found from your Helldiver's hand pose, learned per weapon on its first shot.
