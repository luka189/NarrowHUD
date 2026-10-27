# Changelog

## 1.5.13

- **The F9 menu in topic blocks**, each row's label starting with its block (Chef's menu has no headings for a mod's
  rows; the prefix groups them to the eye and for the menu's / search): the layout (size, position, offsets,
  opacity), Show (the eleven parts), Bars (health, stamina, stim timer, warnings, reload, idle), Look (magazines,
  outlines, colours), World (markers, drop line, throw line, thickness), Keys (fire, swaps, wheel, weapon options,
  stratagem key and the two hide rows, the layout key), Testing (forget keys, log mark, research log, any build).
  Labels shortened; "a mark every 50 m" was long gone from the drop line's.
- **On by default**: the health and stamina bars (Always), your map pin and where you last died, the drop line while
  aiming, the throw line. Most players update through a mod manager and never open F9, so a feature shipped off was
  never seen. Everything can still be turned off there. (Rows at their old default aren't stored, so a player who
  never touched them gets the new default; one who turned a row off keeps it off.)
- **Position: Curved pair**, a fourth built-in layout: the ammo bar as a ) right of the crosshair with the charge
  meter outside it, the count and magazines above, modes and rate of fire under; the backpack as a ( on the left
  with stims and grenades under; health, stamina and the stim timer stacked over the crosshair (the numbers as a
  tester placed them in the editor). The editor's Curved
  pair preset is the same layout (its old arrangement, sides swapped, is "Curved pair, flipped"). F9's offsets move
  it like Under and Beside. In the list after Custom, so saved choices keep their meaning.
- The throw line's end mark is gone (the arc's height at your feet means nothing on the game's slopes).
- The texture test row is gone from the menu (the code stays, off; `M.debug_cfg` lets the tests reach it).

## 1.5.12

- **The layout editor: a screenshot of your game behind the parts.** "Use a screenshot" (or drop a picture on the
  screen, or paste one) puts it under the parts, so a layout can be placed around the game's own HUD; a slider fades
  it. The editor's screen takes the picture's shape (16:9, 21:9 ... or the picture's own when it's none of them). Read
  in the browser only: it's not sent anywhere, not kept in the draft, not in the layout file. No change to the mod.

## 1.5.11

- The texture test's log line says the screen size and the game's render resolution with the way that drew, and the
  research log counts the frames the texture was drawn and refused in, every 10 s. Still the test; no other change.

## 1.5.10

- The texture test as an F9 choice, to find which way draws right: the texture through its size ladder in the main
  world (as 1.5.9), the same at a top layer (Chef's top world, over the game's HUD), or one texture with no ladder;
  or the pixel sprite. The log says which way drew (`icons: the stim texture drawn, way N`).

## 1.5.9

- The stim texture shipped as Treasure Radar ships its icons: plain RGBA8, one mip level (a BC3 chain with mip
  levels showed as a white square in 1.5.4 and 1.5.8). Still the test: the stim only.

## 1.5.8

- The stratagem ball's line from ten more throws against the line as drawn while aiming, all three numbers fitted
  together: 20.3 m/s, 5.8 degrees above the camera, let go 0.9 m above the held ball (the far end of a long lob
  was a little long, the start a little low).
- The stim texture as a square (256, 128 and 64 px, powers of two) with the icon across its middle: the 96 x 40
  texture of 1.5.4 showed as a white square at times. Still a test.

## 1.5.7

- **The stratagem ball's line, corrected from a tester's screenshots:** the ball is let go about half a metre above
  where it's held while you aim (the arm swings up), a degree higher than 1.5.4 drew: up 0.5 m, lift 5.5 degrees.
  1.5.4's "from where it's held" came from comparing flights with the line at the moment of the throw, when the
  arm was already up, which is the wrong line to compare with; the research log now keeps the aim as drawn 0.4 s
  before a throw for each flight.
- The end mark is off by default: it marks where the arc reaches your feet's height, which is the landing on level
  ground only.

## 1.5.6

- **Throw line end mark** (F9, on): a small cross where the arc comes down to the height of your feet, a hand above
  the ground. The line itself is hidden by grass and ground cover for its last metre or so, which makes a throw seem
  to land past it: the 1.5.4 round's recorded ball flights follow the drawn line to within 10 cm over 25 m, while
  the balls looked to land 1-1.5 m beyond where the line vanished. On level ground the cross is the landing.

## 1.5.5

- Research: a grenade's flight is recorded until 2 s after it starts flying, not 2.5 s after its unit appears (a
  grenade is a unit from the moment it's taken in hand, seconds before the throw: the 1.5.3 log's grenade flights
  held four samples of flight each, too few to fit). The aim logged with a flight is the one at the throw.

## 1.5.4

- **Test: the stim icon as a texture** (F9 › Textured icons, on): a syringe drawn from art/icons/stim.svg, shipped
  in the patch in three sizes (tools/make_textures.py; Chef picks the one nearest the size drawn) and drawn through
  chef.bitmap, tinted like the sprite. When Chef can't draw it (the log says why), the pixel sprite is drawn as
  before. The grenade stays a sprite for now: this is to see whether textures load on this build and how they look.

- The stratagem ball's line starts where the ball is held, not 0.4 m above it, and lifts 4.5 degrees above the
  camera, not 7.5: every ball flight in the 1.5.3 log started 0.42 m under the line and fell 1 m more over 20 m.
- C4's line shows whenever C4 is in hand in DEPLOY, aimed or not.
- A quick grenade throw (the aim button not held) drawn 0.4 % faster (a tester's 0.2 m over 25 m).
- Nine more grenade unit ids guessed at (thermite, stun, seeker ...): a grenade whose flight the research log never
  records is one whose unit isn't known yet. tools/fit_throws.py prints each flight against the line drawn.

## 1.5.3

- The stratagem ball's line shows all the while the ball is in hand: it's thrown by a press, not let go from a hold
  (the 1.5.2 log read fire up the whole time), so 1.5.2's "while fire is held" never came.
- Throw numbers from 35 fitted throws: the ball 21 m/s at 7.5 degrees above the camera, C4 22.5 m/s at 5 degrees,
  grenades 21 m/s at 8 degrees. Throws into the ground too short to fit are left out of the fit.

## 1.5.2

- The stratagem ball's line shows while you aim: its hand pose (40; a grenade's is 41, the 1.5.1 log) with fire
  held, from the ball's unit when one is found in reach, else from your hand. 1.5.1 only drew it from a found ball,
  and never found one in the hand (research line `ball pose:` says what it sees now).
- A throw line that goes (the grenade put away, the ball thrown) no longer stays in the world.
- First numbers of our own, from 20 throws in the 1.5.1 log: C4 22.6 m/s and 6.5 degrees above the camera (the other
  mod's 4.4), grenades 22 m/s and 8 degrees, the stratagem ball 21 m/s (its lift still that mod's 7.8 degrees: no
  aimed ball throw recorded yet). The flight lines now carry the aim's release point, for a better fit.

## 1.5.0

- The drop line's "While aiming" didn't hold: the weapon stance field (95c46304) reads 4 only around a shot, not
  while you aim (the 1.4.5 log), so the line flashed with each shot. It now reads the aim button itself: the right
  mouse button, or a controller's left trigger. C4's throw line uses the same.

- **Throw line** (F9 › Throw line, off until turned on): where a stratagem ball, a grenade or a C4 charge will fly
  while you aim it, as a line in the world from your hand, ending where it enters the ground. A stratagem ball: the
  ball in your hand while fire is held; a grenade: while it's out (its key held); C4: in DEPLOY while aiming. Your
  own speed along the aim is carried into the throw. Drawn with the drop line's thickness.
- The throw numbers are first guesses: the stratagem ball's and C4's as Stratagem and C4 Trajectory (Nexus 17945)
  fitted them from its throws, the grenade's the ball's. With the research log on, each thrown thing's flight is
  recorded (`research: throw flight: ...`), and tools/fit_throws.py fits NarrowHUD's own numbers from them.
- The thrown things are found as units: the grenades' and C4's ids from their resource paths in filediver's hash
  list, the stratagem ball's as that mod found it.

## 1.4.5

- The drop line starts 10 m out (3 m for the Ultimatum, whose whole curve is in the first metres).
- Named from a tester's run: the Scorcher, the Purifier, the Dominator. Every weapon with a visible drop now has its
  numbers.

## 1.4.4

- The drop line starts 15 m out from the weapon (5 m for the Ultimatum and the Leveller): the first metres are of no
  use and any mismatch with the muzzle shows there. Its start sits a hand's width left of the hand node.
- The flight stepped 120 times a second, plainly, as the game seems to step it (a 60-a-second step ran 2.5 % short
  of the rounds, an exact flight as much long).
- Thickness: Thin, Medium and Thick are one, two and three lines side by side.
- Named from a tester's run: the Eruptor, the Expendable Napalm.

## 1.4.3

- The drop line no longer stays in the world when you swap to a weapon without one (Chef keeps showing the last
  lines dispatched until a frame draws some again: a line of nothing for a few frames takes it away).
- Thicker: F9 › Drop line thickness (Thin, Medium, Thick; Medium by default): the line drawn again beside itself,
  the same width on the screen at any distance. The 50 m marks are gone.
- A steep lob's first metres drawn with more points (a point every 4 m, or sooner once the flight has turned 3°).
- The flight computed at 240 steps a second with midpoint steps (at 60 a grenade came out about 1.5 % short), from
  half a metre on from the hand (the muzzle).
- Named from a tester's run: the Evictor, the Speargun, the Leveller, the Airburst.

## 1.4.2

- **The drop line starts at the weapon**: your Helldiver's right hand (the unit's attach_hand_r node), and runs to
  where the crosshair looks (the point 100 m along the camera's line, as the game converges a shot on its aim
  point). From the camera (1.4.1) the line was one thin vertical stroke with the round flying in from the left of
  it. When the hand can't be asked, the line comes from the view as before.
- Named from a tester's run: the Exploding Crossbow, the Grenade Pistol, the De-Escalator, the EAT-17.

## 1.4.1

- The drop line starts about 8 m out, past your Helldiver, not at the camera (its start jumped about the screen).
- Named from a tester's run: the Punisher Plasma, the Ultimatum; the GL-21 and the belt-fed grenade launcher confirmed.

## 1.4.0

- **Drop line** (F9 › Drop line, off until turned on: while aiming down the sights, or whenever the weapon is in
  hand): the shot's flight drawn as a line in the world from your view along the crosshair, bending down as the
  projectile drops, with a mark every 50 m, for F9's length (150 m). The game hides the line behind the ground and
  walls, so it ends where the shot would land. Only for weapons whose shot drops half a metre or more over 100 m
  (grenade launchers, the Recoilless, the Epoch, the Verdict ...); rifles and lasers get none. The numbers are the
  Helldivers 2 wiki's (speed, mass, drag and gravity factors) with the projectile's diameter from HD2Runtime's
  catalogue; the flight as the game's spawn code has it. The shot is taken to start at your view: in third person the
  muzzle is off to the side and the shot converges on the aim point, so the line is off up close and right at range.
- The game knows a weapon only by a hash, so the drop line needs each weapon's name once: the log says `weapon <id>:
  no projectile numbers known (for the drop line, tell which weapon this is ...)` the first time such a weapon is in
  hand. Known so far: the weapons testers have named (17), plus the GL-21 and the belt-fed grenade launcher matched
  by their magazines, to be confirmed.

## 1.3.0

- **Your map pin on the screen** (F9 › Your map pin, off until turned on): a small pin where you put it on the map,
  with its distance under it; out of view, an arrow at the screen's edge pointing to it, the distance beside. Gone
  when the pin is. The map gives the pin no height, so it's drawn at yours.
- **Where you last died** (F9 › Where you last died, off until turned on): a red diamond at the spot your health
  reached 0, with its distance, for 3 minutes or until you're back within 2 m of it. Only your last death.
- Both are drawn under the HUD's layer, at a size that doesn't change with the distance, and hide with the HUD while
  the stratagem key is held. Research log: each pin's type and object, each death's position.

## 1.2.8

- **A support weapon out of its hellpod wasn't shown** (a 1.2.7 log): its aim-pitch field held a stray 0.012 as you
  held it, and two reads off 0 made it "someone else's" (1.2.5). The field must now move (two changes between
  values off 0): a soldier's rifle or a turret's gun does every read or two; a weapon in your hands never.
- **A jump pack lying on the map showed a recharge bar** with no pack on your back. The backpack rule applies to the
  jump and warp packs too: one that reads "worn" in a mission's first 10 s is the map's until it's used.
- **The Talon's bar ran too high.** Three causes: the wiki's 15 heat a shot is about 12 by every rise the field sent
  (the wiki's number is now the start, refined from the field's rises as the other shot lasers are); the planet's
  cooling was measured from the field's falls with shots hidden inside the dead band (one such fall read x0.52, and
  the bar cooled at half speed for half a minute: a shot laser's fall counts only with no press of fire in it); and
  the overheat point was taken for 85 from the last value before an overheat (the heat went on up within the band:
  the known point stays when it's within reach).

## 1.2.7

- **Lasers that fire shots** (the Talon, the Sickles, the Sai): the heat bar follows your shots. Each press of fire adds
  the shot's heat at once (the Talon: 15, from the Helldivers wiki, so it overheats on the seventh), an automatic
  one keeps adding at its rate while fire is held, a burst three; it cools between shots (the Talon 10 a second). The
  heat a shot of the other shot lasers is learned from the field's rises over the shots counted. Before, their bars
  heated by the time the trigger was held, which for a semi-automatic laser is a blink a shot.
- The heat field moves in steps (15.6 a step) and lands a read late: a new value no longer pulls the bar back by a
  step, and the bar never runs further from the last value than a step without a new one.
- Research log: each heat value against the bar's, to see where the model is off.

## 1.2.6

- The HUD hid while you crouched: the stratagem key's default, Left Ctrl, is many players' crouch key. The key has no
  default now: set F9 › Stratagem key to yours, and the HUD hides while it's held (a controller's left shoulder button
  counts without setting anything).
- A new mission's stim count no longer starts the stim timer.
- Tidied: the 1.0.7 unit synchronizer research (it answered nil in every game) and the per-field research watch
  (the all-fields reader covers it) are gone; the research log's load is a little lower.

## 1.2.5

- **SEAF soldiers' guns taking the HUD as host, the main cause found.** Weapon objects carry a field that holds the
  aim's pitch for a weapon that aims by itself: a soldier's rifle, a turret, a Guard Dog, a tank. On every weapon a
  Helldiver holds it reads 0 (ten logged missions), on soldiers' rifles it moves all the time. A weapon read off 0
  twice is someone else's for the rest of the session: never learned for a hand pose or a swap key, never shown. What
  its type had learned of poses and keys (from earlier sessions) is forgotten, unless one of your own of that type is
  proven yours.
- A soldier's gun firing while your Scythe's beam or a charge was going no longer counts as "a shot with your fire
  button" (two of those made it "proven yours").
- The half-second wait after a swap to the Scythe came from a soldier's rifle sharing its hand pose: gone with it.

## 1.2.4

- The HUD hid while you aimed, fired from the hip, charged the Nova or held fire on an overheated Scythe (1.2.1
  hid it for a field that turned out to be the weapon's stance, not the stratagem input). Hiding for stratagems now
  follows the stratagem key itself: F9 › **Stratagem key** (Left Ctrl, the game's default) and a controller's left
  shoulder button.
- **Stim timer:** 6 s with the Med-Kit or Adreno-Defibrillator armour now comes from a list of those armours
  (HD2Runtime's armour catalog; the CM-09 Bonesnapper's id matched it in game). 1.2.2 tried to learn it from a field
  that turned out not to follow stims, so it stayed at 4 s.
- A gun firing just after you let go of a Nova charge before it fired, or between rapid clicks with the Scythe, was
  learned as yours and took the HUD for a moment (as host, a SEAF soldier's). Your weapon counts as busy for 0.6 s
  after it last read charging (the Scythe reads charging while its beam fires).
- Reload progress: a reload with rounds left was taken for one from empty (the game empties the magazine as a reload
  starts), so both kinds shared one time. Told apart by the magazine before the reload now.

## 1.2.3

- The Halt vanished from the HUD after switching its ammo a few times with the quick weapon wheel (a player's report;
  any weapon whose trigger reads held for a moment like that). Each switch counted toward the "holds its trigger with
  no fire button: someone else's gun" rule, added up across the mission. Now only a hold of 0.8 s or more without a
  break counts, and never right after a fire mode, ammo or option change or during a reload.

## 1.2.2

- The weapon is hidden at once again for a grenade or a stratagem ball (1.0.7 waited half a second, against blinks
  while running; it made the HUD feel slow). The blinks are to be found with the mark key instead.
- New F9 key (no key until you set one): **Put a numbered mark in the log**. Each press writes "==== MARK 3 ====" with
  what's shown, and says it on screen, so a tester can note what happened at each mark.

## 1.2.1

- 1.2.0 hid the HUD while you aimed down the sights: the field it took for the stratagem key reads 4 while aiming.
  It hides now only for typing a stratagem's code (3).
- Custom layouts, harder to get wrong (a player pasted the layout into the wrong file):
  - a layout pasted into the learned file (chef_data_luka189_2fnarrowhud__learned.lua, which NarrowHUD rewrites as it
    learns) is moved to the layout file, and said on screen;
  - the "Read the layout file again" key says when Position isn't Custom (the file is read, but only Custom uses it);
  - the layout editor's steps: a button that copies the file's name, which of the two files it is, and Notepad's
    ".lua.txt" trap.

## 1.2.0

- **Stim timer** (F9 › Stim timer, off until you turn it on): a green line that shrinks over a stim's effect, from the
  moment one of yours is used. 4 s, or 6 s with the Med-Kit or Adreno-Defibrillator armour: F9 › Stim duration says
  which, or Auto learns it for each armour set the first time it can tell (until then 4 s). Under and Beside: with the
  health and stamina bars; Custom: a new part, `stim`.
- **Hidden while calling in a stratagem and while emoting** (two F9 rows, on): the HUD fades out while the stratagem
  key is held (health, stamina and the stim timer stay) and while you emote (all of it).
- **Warnings** (F9, off): the health bar pulses under 25 %, and the stim count pulses when you have none left and are
  under half health.
- **Reload progress** (F9, off): a line over the bar (where the charge meter goes) fills over the reload. Each weapon's
  reload time is learned from its first reload (one from empty and one with rounds left apart), so the line shows from
  the second on.
- Research log: each weapon's reload stages and time, the stim and the effects counter.

## 1.1.0

**New: health and stamina bars**
- F9 › NarrowHUD › **Health bar** (Off, Always, When hurt) and **Stamina bar** (Off, Always, While not full), both off
  until you turn them on. Health is cream, orange from half, red from a quarter, and a hit's loss shows in red for a
  moment before it shrinks away. Stamina is blue, orange when nearly out. "When hurt" / "While not full" fade out
  2 s after the bar is full again. Both dim with the rest of the HUD when nothing changes, never while you're hurt or
  out of breath, and show without a weapon in hand too. Hidden while you're dead.
- Under the crosshair: over the ammo bar, as long as it. Beside the crosshair: two thin bars mirroring the weapon's,
  left of the crosshair (the screen corner: left of the weapon's bar). Custom: two new parts, `health` and `stamina`
  (any bar style, curved too), in the layout editor and its three starting points.
- Read from your Helldiver's own health, max_health and stamina fields (found with the research log).

## 1.0.10 (research build)

- Research log, every field: the Helldiver's fields read one by one. The game gives a type with more than 63 fields
  its first 63 as one list (1.0.9 logged it as one field, left out as "changes all the time" after 10 s, so health
  and the rest never showed). Fields with a known real name show it (health, stamina, num_stims, is_firing ...:
  names found by trying words against the game's hashes), and objects of yours your Helldiver's fields point at are
  read too.

## 1.0.9 (research build)

- Research log: every field the game sends about your own objects (your Helldiver, your player, the weapon in hand,
  the weapons learned for a hand pose, your backpack), with Chef's `GameSession.game_object_field_batched`: each
  type's field list (kind and range) once, each object's values once, then every change, twice a second. A field
  that changes at almost every read (a position) is left out after 10 s, said once. At most 6000 lines a session.

## 1.0.8

- The Scythe's heat bar was wrong for the rest of the mission (and the next ones) after its heat read 0 as it
  overheated: that was taken as where it overheats. Not any more, and a point under 30 already learned is dropped.
- As host: a SEAF soldier's gun firing while your Scythe was overheated, or your Nova cooling from its shot, was
  learned as your weapon for that pose and took the HUD over a moment later. Your weapon counts as busy then, and a
  heat weapon's held trigger counts too.

## 1.0.7 (research build)

- Your Helldiver is now found from your own avatar object (the game's unit synchronizer), not as the Helldiver nearest
  the camera, which could be a teammate standing close by. Until the game gives it (a moment after the drop), the old
  way.
- A weapon you pick up (from its hellpod or the ground) is the one shown at once, also when it's held like another
  weapon of yours.
- While the Nova or the Quasar cools after its shot, or a weapon is overheated, holding fire no longer lets another
  gun take the HUD over (as host: a soldier's).
- The Railgun in SAFE mode: the charge meter fills to 60 % (where SAFE stops) in about 1.7 s and stays there, orange,
  never red (it can't blow up).
- The weapon is hidden for a grenade or a stratagem ball only after half a second in that pose: the game passes
  through it for a moment while you run, which made the ammo bar blink.
- A heat weapon's heat sinks show 0 when they're used up (they disappeared).
- Needs Chef Shared Loader 1.2.3 or newer (said so everywhere now).
- Research log: a "hand check" once a second: for each weapon of yours, whether the game gives it a unit (its model),
  and how far that is from your Helldiver's right hand. If it works, the weapon in your hand can be told for sure.

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
