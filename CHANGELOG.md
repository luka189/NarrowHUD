# Changelog

## 1.0.6

**New: Custom position and the layout editor**
- F9 > NarrowHUD > Position: **Custom** places every part of the HUD on its own: the bar, the charge meter, the count,
  the magazines, the modes, the rate of fire, stims, grenades and the backpack bar, each placed, sized, faded and
  styled on its own (bars horizontal, vertical, curved "(" or curved ")", ticks or solid; magazines as a number or
  squares; modes in a line or stacked). A part can follow another (the magazines follow the count, so "100%" never
  runs over them).
- **The layout editor**, https://luka189.github.io/NarrowHUD/editor/ : drag the parts around a game screen, see each
  weapon type as it will look, then copy (or download) the file. Starting points: Under, Beside, and a curved pair.
- The first time you pick Custom, NarrowHUD writes a layout file with Under's look to start from. A new key in F9
  reads the file again without restarting. A file with a typo is never written over: Under's look until it's fixed,
  and the key says so on screen. F9's offsets move a Custom layout only when its file says so (the editor has a box
  for it). The format is in docs/LAYOUT.md.

**Hosting with SEAF** (from full-mission logs, thanks!)
- A soldier's gun firing while you fired could still take the HUD over and teach NarrowHUD wrong things. Now a gun
  whose trigger is held while you aren't firing is someone else's at once, as is one that fires without your fire
  button three times and a quarter of its shots. What such a gun taught NarrowHUD in that mission is taken back, and
  while you charge the Nova, the Quasar or a Railgun, a gun firing on the same hand pose isn't learned as yours.
- Lighter as host: guns proven someone else's aren't read any more, and the others only for what shows a shot.

**Fixes**
- No more blinking off for a moment: walking, vaulting, a stim or a swap's first moments pass through hand poses with
  no weapon, and the HUD went off for 0.1 to 1 s each time. The weapon shown now stays up to 2 s there. Grenades and
  stratagems still hide it at once.
- Swapping to your support weapon could show another weapon for a moment (a Stalwart lying on the map, as host, held
  like your primary). NarrowHUD now waits for the hand pose to settle after a key.
- The mouse wheel while holding the weapon options key (R) changes a scope's zoom or the flashlight, not the weapon:
  no longer taken for a swap (switching the AMR's scope showed the wrong ammo). Moved weapon options off R in the
  game? Set the same key in F9 ("Weapon options key, held").
- New setting "Mouse wheel swaps weapons (as in the game)": up and down, up only, down only, or no.
- The Railgun showed the Guard Dog's magazines instead of its own spare rounds (a reload just as the dog reloaded was
  taken for a backpack reload). A weapon whose own magazines go down on a reload is never taken for one, and one
  learned so before is put right on its next reload.
- Heat weapons with a backpack on (the Nova, the Scythe ...) showed the backpack's count as magazines. Not any more.
- The LAS-5 Scythe's heat sink attachments (overheating at 60 or 150) showed the wrong top of the heat bar. Each
  weapon's overheat point is now taken from its own overheats, and the last one is kept for the next mission.
- A weapon with no rate of fire setting could show one (the Sightliner's 40 RPM, from 40 on one planet and 36 on an
  Extreme Cold one). Fixed, and what was learned that way is dropped.
- The Halt: its two rounds are shown by name, FLECHETTE and STUN, each with its own count and magazine size.
- Research log: a timing line once a minute (where NarrowHUD's time goes), and it reads less as host.
- Under the hood: the mod is split into modules.

## 1.0.5

- Joining someone else's game: your grenades and stims could show the host's counts instead, flicking between theirs
  and yours. NarrowHUD sometimes took the host's player for yours; now it always takes your own.

## 1.0.4

- Hosting with SEAF: a soldier's gun of the same kind as yours, firing as you fired, could take the HUD over. Now
  the weapon in your hand keeps it while it's firing; another one on the same hand pose takes over only after a swap
  (keys, the wheel, a pose change), when the shown one is gone, or when it keeps firing with your fire button while
  the shown one does nothing.
- SEAF, from a host's log (thanks!): five kinds of SEAF gun had been learned as "your" weapon for up to 7 hand
  poses each. Now a gun that fires at the same moment as the weapon in your hand isn't learned for that pose; a kind
  learned for 4 or more poses that didn't ship with NarrowHUD is never shown (every real weapon has 1 to 3), which
  also clears what older versions learned wrongly; and once your fire button has been seen, a gun shown firing on
  its own no longer switches the fire-button check off (1.0.2's controller fallback was set off that way).
- Research log: more for the SEAF case (each switch between two objects on one pose, with both objects' fields;
  weapons that turn up later in a mission; each time a soldier's gun was kept out).
- New setting "Fire and weapon modes in their own colours" (off by default): each mode always in the same colour
  (cream, sky blue or green, the same in both palettes), and a weapon's modes never share one, so a switch is easy
  to see. SEMI, SAFE, APHET, HEAT, GUIDED, DEPLOY: cream; AUTO, UNSAFE, FLAK, HE, UNGUIDED, DETONATE, ARTILLERY,
  LASER: blue; BURST, VOLLEY, TOTAL, CLUSTER: green.
- "Fade out when full and not firing" is now "When nothing changes for a while": Shown, Dimmed (a quarter) or
  Hidden, after a number of seconds you set (2 to 15, 4 by default). Any change wakes it at once: the count, heat
  (cooling too), a reload, the magazines, a mode, swapping or picking up a weapon, stims, grenades, the backpack, or
  just pressing fire. It's a new row, so it starts at Shown once.

## 1.0.3

**The settings, reorganised.** Your position and distance settings go back to the default once (they're new rows);
everything else is kept.

- Every part can be shown or hidden on its own: the ammo / heat bar, the count, the spare magazines, the HEAT label,
  weapon modes, the fire mode, the rate of fire, the charge and lock-on meter, stims, grenades, the backpack bar.
  With all of them off, nothing is shown. (Stims and grenades used to be one setting.)
- One offset, left / right and down / up (% of the screen, -50 to +50), moves any position anywhere. It replaces
  Under's distance, Beside's distance and up / down, and the corner's two sliders.
- New position "Screen corner": by the game's own weapon panel (bottom left, just above it). Best with the bar,
  stims, grenades and backpack turned off, and the magazines as a number: the game's panel shows those already.
- The menu in order: placement, what's shown (in the order it's on the screen), the look, then the keys.
- New setting "Empty parts as outlines": what's empty in the ammo bar (the ticks and the solid bar), the magazine
  squares and the backpack bar is drawn as an outline instead of faint. The faint squares were hard to tell from the
  full ones. Off by default. A solid bar keeps its outline in place around the whole bar and fills inside it, so a
  weapon cooling down from overheated only changes the inside.
- New setting "Beside and corner: empty magazine squares": shown (as before) or hidden.

## 1.0.2

**Fixes**
- Controllers: the HUD could disappear after a few shots. When NarrowHUD couldn't see the trigger, your shots looked
  like someone else's and your weapon was hidden. Now every connected controller is read, not only the first, by the
  button names the pad gives itself (R2 and triangle on a PlayStation pad). And if the weapon in your hand keeps
  firing with no fire button or trigger seen at all, NarrowHUD stops checking your shots for the rest of the session
  (it says so in narrowhud.log) instead of hiding the weapon. Checked on an Xbox-style pad; PlayStation pads untested.
- Hosting: two kinds of object a host owns (not weapons you carry) could be learned as your rifle when they fired as
  you fired, and then shown instead of it. Only real hand-held weapon types can be the weapon in your hand now;
  anything already learned wrongly is ignored, no reset needed.
- Magazine attachments: the bar's size is now the weapon's own magazine in this mission, not the largest ever seen for
  its type. A Liberator Penetrator with the shortened magazine (30 instead of 45) read 2/3 full when full. A weapon
  you drop in with is known at once; one picked up later, after its first reload.

**Changes**
- Beside the crosshair is bigger at every size (it was small even at Huge): Small is the old Medium, Medium the old
  Large, Large the old Huge, and Huge is new (about a quarter bigger again). Under the crosshair is unchanged.
- The research log also notes your grenade and stim counts as they change (for bug reports).
- License: "no monetary gain" made plain: no selling and no paywalls (Patreon and the like); donations and Donation
  Points are fine.

## 1.0.1

- The Dagger (and any other laser) could be taken for a charge weapon like the Nova, which hid its heat marks. Only
  the Nova and the Quasar are charge weapons now; a charge learned for anything else is dropped.
- New setting "Backpack bar (and the warp and jump packs)": "Grenades and stims" no longer turns the backpack bar off
  too.
- "Game font (off: pixel font)" is shown on Chef 1.0.x only. From Chef 1.1 on, every mod's text is Chef's own, and
  Chef's "Game font" setting (F9 > Chef Shared Loader) switches all of it to the pixel font.

## 1.0.0

The first release.

- Ammo and heat by your crosshair: a narrow bar (a tick per round for smaller magazines), the count and your spare
  magazines, under the crosshair or beside it in a compact layout.
- Heat weapons with their marks (75 %; the Double-Edge Sickle's 50 / 100 / 180 %), charge weapons filling as they
  charge, cooling that follows the planet.
- Backpack weapons and backpack-fed weapons, underbarrels, fire modes, weapon modes, rate-of-fire settings, lock-on
  and charge meters.
- Stims, grenades, the backpack's fill, the warp pack's heat and the jump pack's recharge.
- Ships knowing 95 weapons; others are learned on their first shot. Tells weapons held the same way apart by your
  swap keys (a shield, the Solo Silo's remote).
- Settings in F9: size, layout and distances, magazines as squares or a number, opacity and fade, a colourblind
  palette, which texts to show, your fire button and swap keys, forgetting what was learned, a research log.
- Reads only, never writes. Checks its data against a patched game and leaves out what moved, or stays off with a
  message when it can't check.
- Runs on Chef Shared Loader 1.0.x and 1.2 and newer.

The notes from development (0.1 to 0.4.23) are in docs/HISTORY.md.
