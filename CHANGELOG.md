# Changelog

## 3.1.0

- **NEW: lines stop on the world.** The drop and throw lines end on what they would hit — a boulder, a cliff, a
  wall, a building, a wreck — with the landing mark there, instead of passing into it and marking the ground
  beyond. 878 kinds of scenery from the game's own models, each looked over by eye: rocks and cliffs on every kind
  of planet, city and colony buildings and their ruins, cars and wrecks, the Super Earth base walls, platforms,
  containers and pipes, the Automaton factories, fortifications and dropship wrecks, the Terminid caves, bones and
  webs, the Illuminate ruins, labs and crashed ships, roots, ice and coral. The shapes sit a little inside the
  surface, so a line never stops where the round would get through; a ruined building or a car counts as one
  block; what barely rises above the ground (under half a metre) stops nothing. Bug holes, fabricators, nests,
  towers and turrets keep their red mark. Off with "Lines stop on rocks" under Lines and marks. Not known yet: the
  newer, intact city towers (a line passes through them as before).
- **NEW: the rate-of-fire icon**: the game's own low / medium / high icon for a weapon's rate-of-fire setting,
  beside the number in every built-in layout and in the editor (the `rpmicon` part, with a rule of its own under
  Parts). With "Modes in colour" it and the zeroing icon take their step's colour, as the mode words and icons do.
- **Icons by their ink** (Look, on): the mode, fire-mode, zeroing and rate-of-fire icons take up only what they
  draw — the game's sprites come with padding about half their square — so they sit against other parts and line
  up by the picture. The built-in layouts keep their look. A custom layout tuned to the old squares will see its
  icons move by about 14 px at Medium: retune the gaps, or switch the row off.
- **Centre ring opacity** (Crosshairs, under "Crosshair at"): 0 to 100 for the larger ring that marks the screen's
  middle with "The reticle" chosen; 0 hides it.
- A weapon taken from a crate or a crashed flier on the map shows on the HUD (a user's report): it was taken for
  one still lying on the ground.
- A backpack-fed weapon (the M-1000 Maximum) could vanish from the HUD for the mission when a SEAF soldier's rifle
  fired on its hand pose. The pose goes back to the weapon it was taken from.
- The Nova's charge on the bar begins when the gun can charge, not at the press: held through an overheat it
  charges again as the gun has cooled; pressed while cooling, it finishes cooling first.
- A part pinned to a hidden icon sits at the icon's middle instead of climbing into its neighbour; a part switched
  Off in F9 gives up its place at once.
- A weapon with no magazines of its own took the first worn backpack found as its reserve, which could be another
  player's or a soldier's: your own now.
- **Nothing is asked of a unit in its first 3 seconds** (a precaution from another mod author's crash reports with
  freshly called-in equipment). What you may notice: after a reinforce, and for the first 3 seconds of a mission
  or on the ship, the weapon in hand is not read and the drop and throw lines are not drawn.
- Safer reads: your armour (for the stim timer) is checked to exist before it is read, as everything else is; the
  hand pose is asked for afresh each time; what was remembered of one mission's scenery can't be taken for the
  next's.
- A Stoker's underbarrel flamer no longer has its hand pose learned and forgotten every session; two F9 hints that
  were shown cut off fit again.
- **Crash trace** (F9 > Testing, off): for a game that crashes or hangs with the mod on. Each call the mod makes
  into the game is named in `narrowhud_lastcall.txt` just before it is made, and the next start says in
  `narrowhud.log` whether the last launch ended inside one of them. It costs frame time: on for a test session,
  send both files after a crash, off again.
- Testing > "Draw structure boxes" also draws a box round each thing a line stops on, the nearest 60.

## 3.0.1

- Shell-by-shell weapons (the Evictor, the Sweeper, the shotguns) dropped into missions one round over what they
  hold since 3.0.0; fixed, and the sizes 3.0.0 saved for them are dropped once so they learn again at the next drop.

## 3.0.0

- **NEW: your own colours.** The Colours tab in F9: Text, Bars, Low, Empty, the two mode colours, Lines and Stamina
  are each a colour row (Left and Right step through the swatches), with Standard and Colourblind presets that set
  them all. The layout editor goes further: a colour per part (a picker, the hex and the swatches), and the same
  roles saved in the layout file, where they win over the tab. Low and Empty colour every part the same way, so a
  low magazine always reads as one. The lines are drawn in the world, where each planet's light shifts a colour,
  so their list is the pure colours only; the crosshairs keep the game's own cream.
- **NEW: the Cake layout** (Layout: Cake, and the editor's fifth preset): five rings on one centre right of the
  crosshair with a slice open at the top — the backpack and the stim timer sharing the innermost, then stamina,
  health, the ammo bar and the charge meter — the count and the magazines in the middle.
- **NEW: two more bar shapes**: a curve bulging up and one bulging down, on every bar, and a curve can close into a
  full circle now (300 degrees was the most).
- **NEW: Duds** (Lines and marks, on): a launcher round that lands closer than it arms bounces, so the drop line is
  grey up to the arming distance (GL-21, Grenadier Battlement and Evictor 7 m; GL-28 5 m; GP-31, De-Escalator and
  the One-Two's underbarrel 4 m), and a landing inside it gets a grey pin and chevron and no blast zone.
- **NEW: rounds carry your movement**: the GP-20 Ultimatum's and the CB-9 Exploding Crossbow's chevrons move with
  you — the round leaves with your own velocity added. Testing > "Rounds carry movement: all" tries it on every
  weapon.
- **NEW: Text outline** (Look, off): a dark outline round the count and the words, for bright planets.
- The magazine's size is what the game counts: the rounds you have after a reload from empty, or at the drop (the
  bolt pistol 6, the Crossbow 5, the Liberator 45). The bar is full at that and a tactical reload shows as one over
  it on every weapon; a weapon with no attachments keeps its size between missions too. Before, these started every
  mission one short until a tactical reload.
- The Railgun's reload line ends as its round is back (it stayed a few seconds).
- The editor: every pinned part has its X field; loading a file names the values that didn't fit, colours included.
- Needs Chef Shared Loader 1.4.0 or newer now (the colour rows).

## 2.6.0

- **NEW: the red mark knows the structures' real shapes.** It turns red only where the shot would go in — a bug
  hole's shaft and mouth, not its mound; the shrieker nest's and the spore spewer's trunk and cap; the warp ship's
  hull; the tesla tower and the Illuminate turret; the Automaton fabricator and the big factory; the Automaton
  emplacements' guns (mortar, anti-air, cannon, autocannon), whichever way they turn. The shapes come from the
  structures' own models. Testing > "Draw structure boxes" draws them in the world. A Custom layout file can set
  its own shapes (`struct_parts`, docs/LAYOUT.md).
- **NEW: Hide in a vehicle** (Visibility, on): the HUD, health and stamina away while you drive the FRV or a tank,
  pilot an exosuit or man a tank's gun; they stay as a passenger and on the FRV's turret, where you can be shot.
- **NEW: a key that hides the HUD** (Keys > "Hide the HUD"): everything of NarrowHUD's away until pressed again.
  Set it to the game's own hide-HUD key and both go together.
- **NEW: the Range part**, the metres to the landing chevron while a line is up, else to where the reticle points
  ("-" on the sky). Placed in the four built-in layouts; Off / While aiming / Always. And the distance beside the
  chevron itself ("Distance by the chevron", on): the Range part never shows the number twice.
- **The sniper crosshair follows the aim**: the ring and dot sit where the game aims, lagging the view in a turn
  and swaying as the reticle does, with a larger ring marking the centre (Crosshairs > "Crosshair at": The reticle,
  or The centre as before).
- **F9 regrouped** into Layout, Motion, Parts, Visibility, Look, Crosshairs, Lines and marks, Keys and Testing.
  Every setting keeps its value.
- The drop line and the crosshair no longer flick to the centre when the aim crosses from a near surface to a far
  one; the drop line's end no longer jumps as you aim.
- The red mark on bug holes and nests sits right on every one of them (it was off on all but the first met in a
  mission); the Illuminate warp ship's and the spore spewer's red marks (a Nexus report).
- The ground census (for the ground model) has a log and a Testing row of its own.

## 2.5.0

- **NEW: a blast zone on the ground.** For explosive rounds and grenades, the area the blast reaches is painted on the
  ground where the line lands: the full-damage radius filled faintly with a bright rim, the outer radius as a dashed
  ring, red while you stand within reach. Radii per weapon and grenade from the game's own data (the Recoilless and
  the EAT get no zone or mark: their blast hardly matters and the mark got in the way of the aim).
- **The drop line follows the reticle.** It's aimed where the game's own reticle points, so it lags the view in a
  turn and sways with the sight as the reticle does (F9 "Line aimed at": The reticle, or The view as before).
- **The lines and marks look new.** Solid lines with dark edges that fade in at your hand (Line look: Solid; Dashes
  and Flowing dashes keep their size near and far; Classic is the old line). The landing mark is painted on the
  ground, lying on rocks, slopes and steps, with a chevron icon over it that always faces you (red on a structure
  hit); Classic keeps the old ring. The marks reach farther on higher Object Detail settings. Where the ground is a
  guess only the chevron is dimmed; the mark and the zone stay at full strength.
- The drop line starts 3 m from your hand for every weapon and moves smoothly as you aim (it used to step in half
  degrees); the Crossbow's zone shows from close in. No drop line for the Verdict or the Re-Educator; no throw line
  for the Seekers (they fly on their own). Blast zones for the Grenadier Battlement and the One-Two's underbarrel.
- The drop line hides where it can't apply: in a vehicle seat, in the hellpod, while the Recoilless, Epoch or
  Airburst reload kneeling, and while you sprint. The throw line hides in a seat and in the hellpod.
- New F9 setting "Low ammo at, %": how much of a magazine is left when the ammo bar and count turn orange (and flash
  once); 25 by default, as before. An ammo backpack follows it too.
- Rounds loaded one at a time (the Cookout, the Punisher, a launcher's rocket) flick into the ammo bar; a resupply
  lights the magazine squares in order; the ammo bar flashes once as it turns orange; the charge mark brightens as
  the charge crosses it and the bar is red from there; mode words and icons fade over to the new one. Shell loading
  has its own F9 rows, on / off and its length.
- The Aim spread's move is quick off the mark and settles over its last few frames, every part on the same frame.
- Less frame time: the HUD's layout is worked out only when something changes, the lines cost less, the hatched
  shade is drawn as one texture (F9 "Hatch drawn as" keeps the stripe-by-stripe way).
- Fixes: a weapon with few rounds a magazine (the Epoch) no longer disappears as "not yours" after reloads with
  rounds left; the log no longer fills with a line about the mode icons; the ground learning no longer counts a
  Helldiver in an exosuit, the FRV or the tank as standing on the ground.
- New defaults: Lines Thin, Mark size 0.5 m.
- A crash precaution: nothing in the world around you is looked at while you're dead, in your hellpod, or in the
  first 10 seconds after it lands.

## 2.4.1

- Fixes a crash to desktop with the drop or throw line on near a shrieker nest (most often as the stratagem list
  opened): the shriekers themselves were taken for structures the line could hit.

## 2.4.0

- NEW, worth a look: Hatched shade (F9 > Look > Shade behind bars > Hatched; not the default). Diagonal stripes on a
  dark ground behind a bar's empty part, as the game's own health bar has, on straight and curved bars alike (a
  layout can set it per bar).
- Shell flash (F9 > Layout, under Motion; on by default): each round fired flicks out of the ammo bar in the bar's
  colour, square to it and away from the crosshair, and is gone. Shell flash length sets how far it gets.
- Hit trail (F9 > Visibility): what each hit took stays red a moment, then drains away, each hit on its own (or as
  one piece, or off). On a red (low) health bar only your health shows. Hit trail held sets how long it stays
  (0.4 s).
- Warning pulses (F9 > Visibility) has a third choice, Flash once: the health bar flashes as it turns red, then
  simply stays red.
- The reload line runs until the gun is ready: on a reload from empty it waits for the round to be chambered, and it
  works for weapons whose rounds show a moment after the reload (the AMW-20 Apex, the AMR and others).
- The SG-451 Cookout shows all it holds: both tubes and the chambered shell, on a bar of 16 (it showed one tube at a
  time).
- Firing or holding the trigger while Chef's F9 menu is open no longer hides your weapon for the rest of the
  mission.
- The landing mark knows more of the map's ground kinds (230).

## 2.3.2

- Fixes a crash to desktop after a death (2.3.0 and 2.3.1: the game closed a few seconds after you died, before the
  reinforce).

## 2.3.0

- The weapon in your hand is found by its model at your hand: shown the moment you draw it, before any shot, and two
  weapons on one hand pose (the Nova and the Breacher, a pistol and a rifle on a controller) are told apart without
  a key press.
- The drop line's landing mark uses the game's own aim point: the ground wherever you have looked is known, the
  line aims where the crosshair really points, and a guess for ground you haven't looked at follows the slope.
- Hide at a terminal (F9 > Visibility): the HUD, health and stamina step aside while you work one.
- Layouts: a part's Side can be Up or Down, so the Spread and the Aim spread move it vertically — the horizontal
  layout now moves down as a whole while you aim (its Spread moves it the same way; 0 for none).
- The HUD hides at once (80 ms) for the stratagem key, an emote, the game's menu, the weapon wheel and a terminal,
  and health and stamina go with it in step.
- Your own Helldiver is found by position, not by the camera: an ally passing behind you no longer takes over your
  hand pose or the drop line for a moment.
- The Medium and Thick lines keep their width whichever way they run.
- The magazine size remembered for a set of attachments never shrinks (a weapon with a chambered round starts a
  mission with one fewer in the magazine).
- Switching NarrowHUD off and on in Chef's F9 menu takes effect at once (Chef Shared Loader 1.5).

## 2.2.0

- Drop line start (F9 > World > Line from a drop of, cm): the line begins where the shot has fallen that far below a
  straight aim, so a flat-shooting gun's line starts far out; never closer than 7 m. Default 10 cm, 0 for the old
  start.
- Hide on weapon settings (F9 > Visibility): the HUD, health and stamina go out of the way while the weapon
  settings wheel is open.
- The hover pack: the backpack bar shows its fuel — draining in flight, back in a little over the flight's time on
  the ground.
- The shield backpack: the backpack bar shows its strength — orange when low, red when broken.
- Attachments: the magazine size and the overheat point are remembered per set of attachments, so they're right
  from the first shot the next time the same set comes out.
- The count no longer slides as it falls: it sits right-aligned in a box as wide as the full magazine, so the
  parts after it stay put (F9 > Look > Count digits: Tight for the old way; a layout's Count part can set its own).
- The Nova's and the Quasar's heat no longer climbs while the trigger is held through an overheat.

## 2.1.0

- Landing mark: a ring and an arrow on the ground where the drop line or the throw line lands. The ground's
  heights come from the map's own rocks, trees and props, calibrated by where you and your teammates walk, and
  are remembered per planet across missions; the mark is faint where the ground is a guess. Never within 20 m of
  you (7 m for throws and the Ultimatum). F9 > World > Landing mark, Mark size (0.3–1 m).
- Structure hits: the mark turns red where the shot or throw would hit a bug hole, a fabricator, a warp ship or
  an Illuminate tower before the ground. F9 > World > Structure hits.
- Line opacity (F9 > World) for the drop and throw lines and the mark.
- Aiming is read from the game's own state, not the aim button: a toggled aim counts, and being knocked out of
  it ends it. The sniper crosshair, "while aiming" rules, the aim Spread and opacity all follow. First vs third
  person is read from the game too.
- Sniper crosshair: "Shown" — While aiming (as before) or Always, with the rifle out in third person.
- The Maxigun gets the crosshair in first person, where the game draws none (on by default); the flamethrowers
  can (F9 > World > Flamethrower crosshair, off by default).
- The Variable's TOTAL fire mode gets an icon.
- The F9 menu regrouped: Layout (with the aim Spread and Motion), Visibility (every part's rule, the aim
  opacity, idle dimming, the stim timer, warning pulses and reload line), Look, World, Keys, Testing.
- Fixed: five Visibility rows (the ammo bar, the count, the spare magazines, the charge meter and the backpack
  bar) and their heading were missing from the F9 menu in 2.0.0. Fixed: the Torcher, Sterilizer and a few other
  weapons could be taken for an emplacement gun when picked up.

## 2.0.0

Your settings carry over but the layout choice. The F9 menu is regrouped, with short labels. Old Custom layout
files still load.

- Four new layouts (the horizontal stack, the arcs, the vertical pair, the block) that hold together: parts pin to
  each other, so hiding or resizing one keeps the rest in order. A Spread slider opens or closes the pair around
  the crosshair. The old Under / Beside / Corner / Curved pair are gone: pick your layout in F9 (Custom users:
  Custom layout again; the file is untouched).
- The layout editor: pins, snapping, a grid, a Share link for your layout, a Help page.
- A Show rule for every part: always, while not full, on a change, while aiming, or a mix.
- Motion: parts slide, bars ease, and short flashes mark a bar at zero, the last magazine, an overheat, a stim or
  grenade used, stamina empty or full. Off, Quick or Normal.
- Colours now look as they are meant to, on every planet. The opacity slider works across its whole range.
- Emplacement guns: the HMG, Anti-Tank and Grenadier emplacements show their rounds while you're seated.
- A throw line for every grenade kind.
- Bar edges (none, outline, or the game's brackets), the shade behind the bars, the weapon mode and fire mode as
  separate parts with their icons, the scope's zeroing as text or icon, a tick per use on the backpack bar.
- A crosshair for the sniper rifles aimed in third person.
- Fixed: the overheat flash looked purple; the vertical backpack bar emptied from the wrong end; a wrong grenade
  line for a moment after a throw.
- Needs Chef Shared Loader 1.2.3 or newer, as before.

## 1.5.41

- Two logs: narrowhud.log keeps the plain lines; the research rows' field dumps go to narrowhud_research.log. The
  loader starts a log afresh once it passes 1 MB, and a long research session was pushing the plain log over it.
- Fixed: "Drop line length" past about 220 m did nothing for grenade launchers and the grenade pistols. The line
  now goes the full length set.
- The guard dogs' guns are never taken for the weapon in your hand.

## 1.5.38

- The disconnects: when you played in someone else's game, NarrowHUD listed, sorted and read the host's objects
  once a second to find any weapon of yours the host might own, and the client lost its host 12 to 17 minutes
  into every mission. 1.5.38 never touches the host's objects. Nothing you see changes.

## 1.5.36 (interim, for the disconnect reports)

- Two reads are off in this build: a support weapon's "lying on the ground" field is never read, and a weapon's
  underbarrel field only while the fire mode selects it — as 1.5.13 read them. They are the one difference on the
  reading side between 1.5.13 (one disconnect report in three days) and 1.5.26 (many), so this build tests
  whether they matter. What you lose for now: a support weapon of yours lying on the ground can be taken for the
  one in your hand at drop-in until its first shot (the 1.5.26 fix), and the underbarrel's icon shows only while
  it's selected. Everything else is 1.5.35.
- The logs say more (1.5.27–1.5.35): if you get dropped, post narrowhud.log and chef_loader.log with the clock time.

## 1.5.35

- "Testing: reads" level 6: no floor / underbarrel reads — the one read-side difference between 1.5.13 and 1.5.26
  (docs/DEVLOG.md), for the disconnect bisection.

## 1.5.34

- "Testing: reads" (F9, with the research log), for the disconnect bisection within the reads: 2 no host objects,
  3 no field reads, 4 no object reads at all, 5 no Unit calls; one mission a level, said in the log.
- A refused engine read answering a reason no longer trips a number conversion (five places; latent).

## 1.5.33

- The freeze lines say "(you're dead)" when you are, and a mission's end line says when you were last dead: a
  world that stands still while you're dead isn't the freeze before a drop.

## 1.5.32

- Made for game patch 7.2.2 (Steam build 26251122, 2026-10-29): the network config has one new type and not one
  field moved, so the data is the same with the new build number; the version check knows both builds.

## 1.5.31

- On Chef Shared Loader 1.4.0 or newer: the stim and grenade textures go through the plain bitmap call again (the uv
  call was the workaround for 1.3's strobe, which 1.4.0 fixed), the drop line needs no line of nothing after it
  (1.4.0 clears them itself), and the loader's players event is logged (someone joining, in, or leaving) with the
  player count in a mission's end line, for the disconnect reports. On 1.3 nothing changes.

## 1.5.30

- The freeze before a drop seen directly: the host's Helldiver (its input, stamina, health and aim fields) and the
  teammates' positions, once a second; "still for 3 s" and "moving again" lines, and the mission's end line says how
  long before it each last changed. (The object churn of 1.5.29 alone was too weak: a healthy mission had 20 s with
  nothing coming or going.)
- The per-object type cache is pruned as objects go (it grew by a few hundred entries a minute in a long mission).

## 1.5.29

- **For the disconnect reports**, a second line a minute in a mission: the worst frame and the frames over 50 and
  100 ms, the objects of yours and the host's and how many came or went, the fields read, the engine objects made
  (GUIs, material copies), any table of the mod's that grew, and the ping to the host if the engine answers for it;
  a line when no object came or went for 5 s (the freeze the reports describe) and when they move again; and at a
  mission's end, how long before it the last object moved. Nothing to turn on.
- Two research builds for the reporters, made with `tools/build.py --research`: **R0** reads nothing and draws
  nothing (the loader's hook and the vitals only), **R1** reads everything and draws nothing. One mission with each
  tells whether a drop needs the mod's reads, its drawing, or only the loader being there.
- The icon material's copy is asked of the engine once a world, not once a frame an icon.

## 1.5.28

- Fixed: a weapon fed from the backpack sharing a hand pose with a weapon of its own ammo was learned and forgotten
  again every tenth of a second while the pack went down (a dog firing from it, say): 800 log lines a mission and the
  learned file rewritten every 5 s. Forgotten once, it stays forgotten for the session.
- The first reporter's logs read (1.5.27, a client, four missions): the Lua heap flat at 4–6 MB, no frame stalled a
  quarter second, nothing before the drop. Whatever drops clients, it isn't visible from inside the mod; still open.

## 1.5.27

- For the **disconnect reports** (clients dropped from a host's mission): every narrowhud.log now has a line a minute
  with the game's Lua heap and any frames where the whole game stalled, and a summary when a mission ends. Nothing to
  turn on. If you get dropped, post your narrowhud.log and chef_loader.log with the clock time of the drop.

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
