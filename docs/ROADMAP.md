# NarrowHUD roadmap (from 1.1.0, planned 2026-10-27)

Everything here is read-only, as now: game object fields through Chef, Chef's drawing (`chef.rect`, `chef.triangle`,
`chef.line` for lines in the world, `chef.world_to_screen`), the camera (`chef.camera`) and Chef's unit watches. Each
feature has its own F9 row; new things you see are off until turned on, except the "hide while ..." rows (on: they
only take the HUD away where it's in the way). Each version gets a research-log part for what it's unsure of, and is
tested in game before the next one starts.

Out of scope: the mech and vehicle readout, stratagem cooldowns (no field carries them; the only way is reading the
screen with a separate program), pings, hit markers and the direction of a hit (nothing readable carries them).

Field names and numbers below are from docs/FIELDS.md.

## 1.2.0: quick ones and the stim timer

**1. Hide the HUD while the game needs the space** (effort 1). F9 "Hide while" rows, each on/off:
- the stratagem input: the stratagem key held (F9's key, Left Ctrl by default, and a controller's left shoulder). No
  field says it: 95c46304 is the weapon's stance (3 raised, 4 aiming), which 1.2.0 and 1.2.1 took for it and hid the
  HUD while aiming, firing from the hip and overheated;
- an emote: active_emote isn't -1 or 0;
- the map open: not in 1.2.0. cd889dbc follows what's in your hands (74, 88, 90 ...; 72 in a vehicle), not the map, and map_marker_type stayed 7 after the map was shut: no field tells the map yet.
Health and stamina stay (F9 choice: hide them too or not). Fades out over a quarter second, back at once.

**2. Low health and out of stims** (effort 1). The health bar pulses under 25 % (F9 on/off); with none left, the stim
count pulses red while you're under half health. Uses health and num_stims, read already.

**3. Reload progress** (effort 2). While reloading (reload_stage isn't 0) a thin line over the bar fills over the
reload's time. The time is learned per weapon type and kind of reload (tactical: stage 1 then 0; from empty: 4, 5, 7,
0 for the Liberator), saved in the learned table like magazine sizes, so the first reload of a weapon shows no line.
Stage numbers differ by weapon (shotguns load one shell at a time: each shell a step); the research log lists each
weapon's sequence the first time.

**4. Weapons that aren't in a hand** (done already: the field NarrowHUD reads as "carry" is the real enabled_mask; it goes from 0 to 1 or 2 when a weapon drops from your body, and such a weapon is already not "on you"). Was planned as: A carried weapon's position field reads (0, 0, 0); a dropped one (on
your body after a death, lying on the map) has a real position and is_moving / enabled_mask set. Such an object is
never picked as the weapon in your hand. Research first: whether a SEAF soldier's carried rifle also reads (0, 0, 0)
(if not, this settles most host takeovers too).

**5. Stim timer** (effort 2 to 3). A stim heals over a few seconds; some armour passives add 2 s (Med-Kit,
Adreno-Defibrillator: HD2Runtime's armour passive table names them, with a stim_duration row).
- When: num_stims goes down (your own stim). A teammate stimming you doesn't change your count: then health jumping
  up with the 70 field (below) counting up is the sign.
- How long: research first. Your Helldiver's a33df340 counted 0, 1, 2, 1, 0 while burning, poisoned and stimmed: if
  it's the number of effects on you and goes down the moment the stim ends, the timer is exact, armour included. If
  not: the base duration (Helldivers wiki / HD2Runtime) plus 2 s for those armours, told by your player object's
  armor_set, learned per armour set from what's measured.
- Shown as: a thin line under the stim icon (or over the health bar: F9 choice) shrinking to 0, with the seconds; a
  new Custom part `stim_timer` and the editor.

Research part of 1.2.0 (log only): the map signal (cd889dbc and the map pin fields with the map open and shut),
a33df340 with the time against each stim, burn and poison, the position field of every weapon object near you as
host (SEAF), and each weapon's reload_stage sequence.

## 1.3.0: markers in the world (done 2026-10-27, tested in game; on by default since 1.5.13)

**6. Your map pin on screen** (effort 2). map_marker_position (on the map z is 0: the height from the pin's own
object, map_marker_goid, which has a position; else drawn at your height), through chef.world_to_screen: a small pin
and its distance; off screen, an arrow at the edge. Gone when map_marker_type goes back to 0. F9 on/off.

**7. Death marker** (effort 2). Your position the frame health reached 0 (state 2): a mark and its distance, until you
are back within 2 m or 3 minutes pass. Only your last death. F9 on/off.

Both are drawn on the screen (not world lines), at a size that doesn't change with distance, under the HUD's layer.

**8. Research: the weapon model at your hand** — dropped (2026-10-27). 1.2.5 tells soldiers' guns from yours by a field
of the weapon object itself (the aim pitch, 6f3ab277: 0 on anything a Helldiver holds), which settled the host
takeovers without any unit lookup. The scoped rifles' third-person reticle, once planned here, is a standalone mod's.

## 1.4.0: drop line for weapons (done 2026-10-27, tested in game: hits dead on; every drop-prone weapon named; on while aiming by default since 1.5.13)

**9. Where the shot goes** (effort 4).
- Data: each weapon's projectile numbers from HD2Runtime (SkyeShade, its licence allows reuse with visible credit):
  speed (m/s), mass (g), diameter (mm), drag coefficient, gravity factor. The drag: k = pi/2 x r^2 x 1.2 x drag, the
  deceleration k v^2 / m (their spawn-code notes). Per fire mode or ammo type where a weapon has more than one (the
  Autocannon's, the grenade launchers', the underbarrel).
- Matching their weapon names to NarrowHUD's network types: a table made once (tools/make_ballistics.py), checked by
  hand for every weapon; the type names from FileDiver's entity table (BSD-3-Clause, credited) where they help.
- The flight: from the weapon toward the crosshair's line, stepped at 1/60 s (gravity 9.81 x the factor, the drag),
  for F9's length (default 150 m), as world lines (chef.line: the game hides them behind ground and walls, so the
  line goes into the ground where the shot lands), with a small mark at each 50 m.
- Shown while you aim (right mouse or the left trigger held) a weapon whose shot drops more than about half a metre
  over 100 m (rifles: nothing). Not in a magnified scope (the camera inside your Helldiver's head).
- Credit: "Uses research from HD2Runtime by SkyeShade" on the Nexus page, the README and in the mod manager text.
- Risks: chef.line's cost (a few hundred segments a frame; measured in the timing line), and where a third-person shot
  starts (it converges on the aim point; the start is approximated from your shoulder).

## 1.5.0: throw arcs (done 2026-10-27: the ball and C4 fitted from logged throws, the grenade still to be checked with a log; on by default since 1.5.13)

**10. Stratagem ball, C4 and grenades** (effort 4).
- The stratagem ball in your hand is a unit Chef can watch by its model id; the arc starts there. C4: its pose and
  mode as NarrowHUD reads them.
- The throw's speed and angle: measured by us (throws at marked distances, standing, walking, sprinting, diving), and
  checked against what Stratagem and C4 Trajectory measured (credited if we use their numbers).
- Your speed carried into the throw: your Helldiver's position over the last 0.15 s (that mod measured about 1.4 times
  your speed along where you aim, none of it sideways; diving and sprinting to be tested).
- Which grenade: learned from the first thrown grenade's type each mission (and remembered), as the grenade's flight
  differs; until then no arc for grenades.

## 1.6.0: attachments and the squad

**11. Weapon attachments** (effort 3). A weapon's 98b4aaf0 field holds a list of 64-bit ids (5 on a customized
Liberator): likely its attachments. They don't match HD2Runtime's attachment ids directly, so they're learned: the
research log shows them per weapon, and testers with the Scythe's heat sink attachments (60 / 150) tell which is
which. Then the overheat point is known at once, and a magazine attachment's size too.

**12. Teammates' health** (effort 3). Each other player's Helldiver object: health and max_health with
game_object_field (one field each; the all-fields call has crashed the game on other players' objects and isn't used
for them), a few times a second. A Custom part `squad` (and a place in Under and Beside): a thin bar per teammate in
their colour, a mark when one is down. Research first: whether a joined game reads the others' health live.

## The layout editor (no mod version needed; can go out any time)

**E1. The game's own HUD behind the parts** (effort 2). An option in the editor's preview row: the vanilla HUD's
pieces drawn where the game puts them (the weapon panel, health and stamina, stims and grenades, the stratagem list,
the compass, the squad, the objective, the reticle), as plain outlined boxes and lines with their names, not the
game's art. A **HUD scale** slider and an **edge offset** slider
(the game's two HUD settings that move them), each piece shrinking or growing from its own screen corner as the game
does, so a layout can be placed around them. Their sizes and places measured from screenshots at 16:9, 21:9 and 32:9
and two or three HUD scales (testers' screenshots, or the user's).

**E2. A screenshot behind it** (effort 1; done in 1.5.12). "Use a screenshot" loads a picture from your computer as the background
(read in the browser, never sent anywhere; kept only for the session, not in the draft). Fitted to the editor's
screen; a picture of another aspect ratio switches the editor's screen to it (or says it doesn't match). An opacity
slider for it, so the parts stay easy to see. The anchors and the crosshair marker stay on top.

Both only change the preview: nothing of them goes into the layout file.

## To do

- Weapons added with the Evictor: the P-34 Breacher is named (1.5.15, from logs); any other new weapon shows up as
  `weapon <id>: no projectile numbers known` in a log and needs a name.

## Later

**13. Compass with teammates and objectives** (effort 4): their positions as objects (HUDdle does it); a strip above or
under the crosshair. Bigger than the rest of the HUD; only if wanted after 1.6.0.

**14. Status effects** (burning, poisoned, stimmed) (effort 2): only if the research of 1.2.0 shows which field says
which; one counter alone can't tell them apart.
