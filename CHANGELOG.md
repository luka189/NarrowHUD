# Changelog

## 1.5.26

**The game's own icons** (nothing of the game's art shipped)
- **The mode icons**: beside the stims (or wherever a layout puts them), the game's own icons for the fire mode
  (AUTO, SEMI, BURST, VOLLEY, SAFE / UNSAFE) and the weapon's mode (APHET / FLAK, HEAT / HE, FLECHETTE / STUN,
  GUIDED / UNGUIDED, LASER, DEPLOY / DETONATE, CLUSTER, BURST / ARTILLERY) and the underbarrel in hand (the One-Two's
  launcher, the Arbitrator's shotgun, the Stoker's flamer), drawn straight from the game's HUD sprite pages through
  the game's own icon shader, in the HUD's cream, or each in its mode's colour with "Modes in their own colours".
  A Show setting (on by default) and a part of the layout editor.
- **New stim and grenade icons**: the stim drawn by luka189, the grenade traced by dogo314 (used with his
  permission), as textures in the game's own icon layout, sharp at any size; the old pixel icons stay as the
  fallback.
- **The icon strobe is gone**: with Extended Pickup Icons Range's ammo markers on the screen, a texture drawn through
  Chef's bitmap call flickered to a white square (the loader keeps an engine temporary across the frame). NarrowHUD
  draws its textures through the loader's uv call now, which doesn't; the loader's author has the write-up.

**Weapons**
- A support weapon of yours **lying on the ground** (from an earlier life, say) is never taken for the weapon in your
  hand any more (it carries a link to its pickup while it lies there).
- **The AR/GL-21 One-Two** is named; its launcher has a drop line (the grenade pistol's round). The Stoker's two
  fires read 12MM and FLAME, the Arbitrator's 4MM and 10G, the One-Two's 8MM and 40MM HE, as the game names them.
- The Breacher's drop line drops a fifth more, as its shots do.
- The throw line knows the **throw-range armours**: Servo-Assisted (SA-25, SA-12, SA-32, FS-61, SC-37, TR-62, CW-36)
  and Desert Stormer (DS-10, DS-42, DS-191) throw farther, and the line with them (first numbers from Stratagem and
  C4 Trajectory's measurements; to be fitted from our own throws).

**Layouts**
- **Preview 1 to 4** in Position: four new built-in layouts (a horizontal stack under the crosshair, a compact block
  beside it, a curved pair with every arc centred on the crosshair, a vertical pair), designed by luka189 and
  aligned to the pixel. Previews while the way F9's offsets move a preset is being redone; the five Positions you
  have stay as they were.
- The layout editor: the **mode icons** as a part (in a line or stacked), the new stim and grenade icons in the
  preview, the four previews as presets, and a click on empty screen deselects everything.

**Testing rows** (with the research log on): the stim texture's ways and the mode icons' ways, with short names, since
the F9 menu shows about twelve characters of a choice.

## 1.5.15

- The layout editor: **undo and redo** (Ctrl+Z, Ctrl+Y or Ctrl+Shift+Z, and two buttons in the screen bar); a slider
  run or a run of arrow-key nudges counts as one step.
- **The P-34 Breacher has its drop line**: named from two players' logs (the only weapon at 20 rpm, one round, a
  pistol's hand pose), with the wiki's numbers (10 g, 150 m/s, drag 200 %).
- **The Halt vanished after a shot and a few mode switches** (the same player's report, with the research log): the
  Halt swaps its two slots' counts when its ammo is switched (slot0 6>7 and slot1 8>7 going to stun, back on the way
  back), and each swap read as a round fired. Fired three times with no fire button pressed, the Halt was "someone
  else's" for the session. Before the first shot the same switches made NarrowHUD give up checking the fire button
  instead, which is why switching first "worked". A slot change while the ammo, fire mode or options just changed
  (1.5 s) is no longer a shot.
- **The Liberator Legacy showed no ammo** (a player's report with his logs): it's new, with a hand pose NarrowHUD
  had never seen (90), and 1.0.6 learned it right, then learned three wrong poses for it during quick swaps (the
  grenade pistol's among them, within a second). Four poses tripped the "not one weapon's set, never shown" guard,
  and that verdict sat in his learned file through every update since. Now: the Legacy ships in the seed (pose 90),
  and a type caught by that guard has its poses forgotten and is learned again from the next shot, instead of being
  hidden for good (whether a gun is yours is the aim field's and the trigger's call since 1.2.5). Anyone with an old
  learned file that hid a weapon this way gets it back on the next shot.

## 1.5.14

The layout editor only; the mod is unchanged.
- The settings rail scrolls on its own beside the preview, so the preview stays in view while you edit; drag the
  divider between them to give either side room (double-click puts it back), and a wide rail shows two columns
  (presets and parts left, the picked part's fields right) unless "One column" is on.
- A part's fields in three groups: Look (style first), Place, Size; hints behind ? buttons (hover or click); the
  parts list in two columns where there's room; "ticks up to" beside the fill.
- Several parts picked together show the fields they all have, with ≠ where they differ; a change sets every one.
- A screenshot of your game behind the parts (picked, dropped or pasted; read in the browser only).

## 1.5.13

The 1.0.7 to 1.5.13 builds, as released together.

**Lines in the world**
- **Drop line** (F9 › World: drop line; while aiming down the sights by default, or whenever the weapon is in hand,
  or off; its length, 150 m by default): where the shot goes, for every weapon whose shot drops half a metre or more
  over 100 m (grenade launchers, the Recoilless, the Epoch, the crossbow, the plasma weapons, the Verdict ...). Drawn
  from your Helldiver's right hand to where the crosshair looks, bending down with the projectile's drop, hidden by
  the game where it enters the ground. The numbers are the Helldivers 2 wiki's (speed, mass, drag and gravity
  factors) with each projectile's diameter from HD2Runtime's catalogue, flown as the game flies them; testers' rounds
  land on the line. Thin, Medium or Thick (one, two or three lines side by side).
- **Throw line** (F9 › World: throw line, on): where a stratagem ball, a grenade or a C4 charge goes while you aim
  it, from your hand to where it lands; your own run along the aim is carried into the throw. The stratagem ball's
  and C4's numbers are fitted from recorded throws (the ball: 20.3 m/s, 5.8° above the camera, let go 0.9 m above
  where it's held); grenades' are the first fit and may be a little off.
- The weapon in hand is now found by its unit: the drop line starts at the weapon, not the camera. The stance field
  the first "while aiming" used only flashes around a shot, so aiming is read from the aim button (right mouse, or a
  controller's left trigger).

**Markers in the world** (F9 › World, on)
- **Your map pin** on the screen where it is in the world, with its distance; out of view, an arrow at the screen's
  edge pointing to it. Gone when the pin is.
- **Where you last died**: a red diamond at the spot, with its distance, for 3 minutes or until you're back there.

**Health, stamina and the rest** (1.1.0, 1.2.0)
- **Health bar** (Off, Always, When hurt) and **Stamina bar** (Off, Always, While not full), both Always now:
  health cream, orange from half, red from a quarter, a hit's loss shown in red for a moment; stamina blue, orange
  when nearly out. Under the crosshair they sit over the ammo bar; beside it, left of the crosshair as two thin bars;
  Custom has them as parts `health` and `stamina`.
- **Stim timer** (off): a green line shrinking over a stim's effect, 4 s or 6 s with the Med-Kit or
  Adreno-Defibrillator armour (Auto knows those armours from HD2Runtime's list).
- **Warnings** (off): the health bar pulses under 25 %, the stim count pulses when you have none and are hurt.
- **Reload progress** (off): a line over the bar fills over the reload, from a weapon's second reload on.
- The HUD fades out while the stratagem key is held and while you emote (both on). The stratagem key has no default:
  set yours in F9 (Left Ctrl, the game's default, is many players' crouch key; a controller's left shoulder button
  counts without setting anything).

**Layouts and the editor**
- **Position: Curved pair**, a fourth built-in layout: the ammo bar as a ) right of the crosshair with the charge
  meter outside it, the count and magazines under it, modes and rate of fire above; the backpack as a ( on the
  left with stims and grenades under; health, stamina and the stim timer over the crosshair. The editor has it as
  a preset ("Curved pair, flipped" is the same the other way round).
- The layout editor can show **a screenshot of your game** behind the parts (picked, dropped on the screen or
  pasted; read in the browser only, never sent anywhere), and takes the picture's shape.
- Custom layouts harder to get wrong: a layout pasted into the learned file is moved to the layout file and said on
  screen; the "Read the layout file again" key says when Position isn't Custom; the editor's steps name the file.

**The F9 menu**
- In topic blocks, each row's label starting with its block: the layout, Show (the eleven parts), Bars, Look,
  World, Keys, Testing. Labels shortened. A key to put a numbered mark in the log, for bug reports.

**Fixes**
- Shot lasers (the Talon, the Sickles, the Sai): the heat bar follows each shot (a press adds the shot's heat at
  once, an automatic one keeps adding while fire is held) and cools between; the Talon no longer runs too high. The
  Scythe's bar is no longer wrong for the rest of the mission after it overheated at a heat read of 0.
- As host, SEAF soldiers' guns no longer take the HUD: a weapon whose aim moves by itself (a soldier's rifle, a
  turret, a Guard Dog, a tank) is someone else's. A gun firing while your charge or beam was going doesn't count as
  yours either.
- Your Helldiver is found from your own avatar, not as the Helldiver nearest the camera.
- A weapon you pick up (from its hellpod or the ground) shows at once, also when it's held like another of yours.
- The Halt (and any weapon whose trigger reads held for a moment) no longer vanishes after a few quick ammo switches.
- A jump pack lying on the map no longer shows a recharge bar; a new mission's stim count no longer starts the stim
  timer; the Railgun in SAFE stops at 60 %, orange, never red; used-up heat sinks show 0.
- The HUD no longer blinks off while running, and is hidden at once for a grenade or a stratagem ball.
- Needs Chef Shared Loader 1.2.3 or newer (said so everywhere).

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
