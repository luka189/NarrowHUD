# Changelog

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
