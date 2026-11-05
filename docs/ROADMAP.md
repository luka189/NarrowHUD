# NarrowHUD roadmap

Rewritten 2026-11-02, after 2.2.0. Everything is read-only, as now: game object fields through Chef, Chef's drawing,
the camera and Chef's unit watches. Each feature gets its own F9 row (new things off by default, except the "hide
while" rows), a research-log part for what it's unsure of, and an in-game test before the next one starts. What was
done, and how, is in docs/DEVLOG.md (every build) and docs/HISTORY.md; the per-version plans that used to be here
(1.2.0–1.6.0, 2.0) are all done or closed and were cut.

## Where it stands (2.4.0, public 2026-11-04)

Done since 2.3.2 (2.4.0): the shell flash (luka's "flash per bullet", built as a shell thrown from the bar), the
hit trail in chunks, Warning pulses' Flash once, the Hatched shade (straight and curved), the reload line to the
gun's readiness (the chamber from empty; the Apex's late rounds), the SG-451 Cookout's two tubes, shots with F9 open
not counted against a weapon, the ground seed at 230 kinds.

2.3.2 (the same evening): the death crash of 2.3.0 fixed — the one read of your Helldiver's object without the
exists check (2.2.3's position read); every single-field read audited.

Done since 2.2.0 (2.3.0): the weapon model at the hand, the game's look point for the ground and the line's aim,
the slope carried downhill, hide at a terminal, side up / down, the hide in step, the own-Helldiver-by-position
fix, kit sizes never shrinking, on_stop for Chef 1.5.
Done since 1.0: five layouts and the web editor (pins, rules, motion, snapping, share links); hide while a
stratagem / emote / the weapon settings wheel; low-health and no-stim warnings; reload progress; the stim timer; the
map pin and the death mark; the drop line (HD2Runtime's catalogue, the wiki's numbers; a start where the shot has
dropped N cm); throw lines for the ball, C4 and every grenade kind seen; the ground model with the landing mark, red
on structures; the sniper crosshair; emplacement guns; the Maxigun's and flamethrowers' first-person crosshair; the
scope's zeroing; the jump, warp, hover and shield packs on the backpack bar; attachments learned per kit; the count's
fixed digits; the disconnects fixed (the host's objects never read); the game-patch check.

## luka's list (2026-11-03), with a feasibility rating each

- **Squad members' pins** (effort 2–3; the risk is the point): three fields on each teammate's Helldiver, which are
  *their* objects — found by listing another peer's objects, the class of read that dropped clients in 1.5.x, at a
  far smaller volume (one list per teammate every ten seconds, three fields twice a second). HUDdle has read the
  host's health once a second since 0.6.8 "where players report no drops". The plan when wanted: an F9 row off by
  default, each pin in its player's colour as yours is drawn, a research line per read, luka's long client mission
  before any public build. Parked.
- **A 3D "virtual panel"** — the HUD placed in the world and moving with your Helldiver, as HUD+ had. Two
  different things: (a) *the layout anchored to a world point* (a spot ahead of your chest, say) and projected to
  the screen each frame with `chef.world_to_screen`, eased, so it sways and lags with you as you move and turn —
  **feasible, effort 2**: a layout-level anchor "world" with an offset, the editor showing it at rest, no new
  engine calls (one projection a frame); (b) *a panel tilted in perspective* — **not feasible**: Chef draws screen
  rects and text only, there is no world-space GUI for a mod, and the icon GUI is a screen GUI too. Worth doing (a)
  only if the sway is the point; it fights "a HUD you forget about".
- **More bar shapes: a horizontal curve and a donut** (effort 2). The arc code (`arc_geom`, curved_left / right)
  takes a start and end angle already; a curve bulging up or down is the same arc rotated, a donut a 360° arc with
  the fill running round. The ticks mode on a ring and where the count goes are the design questions. Feasible.
- ~~**A flash per bullet fired**~~ — done in 2.4.0 as the shell flash. (Was: effort 1, like the health bar's hit chunk: the tick that just emptied stays lit a
  moment and fades, or a short bright run at the fill's edge. Cheap in 08_motion (the bar knows the value's drop);
  off by default, a motion option. May read as noise on fast weapons — try it on a dev build and look.)

## Open points

0. ~~**Two crash reports (Nexus, 2026-11-04):**~~ found from a player's logs and fixed in 2.4.1: shriekers matched
   the structure pattern 'shrieker', and Unit.box on one destroyed ended the game (DEVLOG 2.4.1). Was: (a) "crash mid-op often when I
   have the ring line enabled (the one that circles the ground) … three missions, crashed about halfway through, all
   when the stratagem list is open; disabled, no crash"; (b) "I'm getting this CTD as well, I'll try disabling the
   landing mark." The "ring" is likely the landing mark (12_drop / 12_throw's circle on the ground), and the
   stratagem list is the stratagem input (hide on stratagem: the HUD hides, but do the world lines?). To look at:
   what the landing mark and the throw line read and draw while the stratagem list is up (the ball's unit, the
   ground model's unit walk, `Unit.box` of structures), whether anything there runs on a unit that can be gone;
   then a reproduction attempt (luka: stratagem list open with the landing mark on, a long mission). Chef's trace
   names a call only on its first use per launch: an unguarded read that ran before won't show there.
   luka's lead (2026-11-04 evening): the ground distance now reads the game's aim fields (the look point and the
   crosshair point, af97ede7 / bdc1cb8a, since 2.2.4 / 2.2.5: 12_ground `sample_look`, 12_drop's aim), and opening
   the stratagem list draws the landing mark if nothing else — start there.

1. **Per-part colours** (effort 3–4). Today: four named tables (CREAM, YELLOW, WARN, RED) and the two mode tones,
   swapped whole by the colourblind palette (`N.apply_palette`; the editor has the same PALETTES). Two steps:
   - a palette of your own: the same swap fed from the layout file (`colors = { cream = {r,g,b}, ... }`) and, for
     the built-in layouts, Chef 1.4's `type='color'` rows in F9; the editor gets colour inputs and draws from the
     same tokens (effort 1–2);
   - a colour per part: every EL_DRAW takes its colour through `col()`, so an element's `color` has to be threaded
     into each draw function while the warning states (orange, red) stay semantic on top (effort 3).
   luka's first "Next" item after 2.1.0.
2. **The heat simulation, fine-tuned.** First the bug: holding the fire button while a heat weapon cools makes the
   readout odd for a moment (luka, 2026-10-31). A research log with the moment marked would show whether it's the
   shot detection, the cooling rate or the mode read. Then the Nova / Quasar charge-and-cool model against marked
   runs.
3. **Alignment by ink** (a Nexus comment, 2026-11-01; effort 2–3). Place text and icon parts by their visible
   bounds (`Gui.text_extents` for glyphs, the icons' real bounds) rather than their layout boxes, so parts at one x
   share a visible left edge. The boxes are the pin chain, so the offset has to be applied at draw time only.
4. **A pixel nudge in the editor** (the same comment; effort 1, editor only). Arrow keys move the selected part by
   1 px at the chosen resolution, x / y shown in pixels beside the %; or a snap grid in pixels.
5. **Attachments, named** (effort 1 of play, 1 of code). The kit ids are learned, not decoded. Two more one-change
   missions (the foregrip off; another paint) would pin the Breaker's 1st / 3rd / 6th positions and let the
   research log say "optic / muzzle / magazine" beside each id. Only worth it if a tester's question needs it.
6. ~~The thrown grenade's kind, remembered across missions~~ — moot: the grenade is a unit in the hand before the
   throw and 12_throw reads its kind there (1.5.56), so a new mission knows it the moment one is raised.
7. ~~The weapon model at the hand~~ — done in 2.2.2 (dev; 05_model, `tools/make_weapon_units.py` from filediver's
   embedded entity table — no game files needed): shared poses settled, a weapon shown before its first shot. Left
   for later: the drop line from the real muzzle node (the model's `attach_muzzle`), and learning a pose from the
   model instead of the first shot once the distances prove reliable in luka's logs.
7b. **Lines stop on rocks, walls and trunks** (effort 2): `chef.ray_box` against the walked units' boxes (not only
   the structure list), with hysteresis against the gun's sway, so the drop line ends on the boulder in front of
   you instead of passing into it. HUDdle 0.6.5's idea.
8. **Blast radius** on the landing mark (effort 1–2). A faint disc at 70 % of the full-damage radius per grenade
   and launcher, from HD2Runtime's explosion data; a timed grenade's line ending where its fuse runs out (the Stun's
   fuse still unseen in the flight data).
9. **Structure kinds still to name** for the red mark: detector towers, jammers, gunship factories (they need a log
   with one in view; `STRUCT_PAT` in 12_struct).
10. **The editor's gallery**: presets as thumbnails rendered from their own files; "Import" of a layout pasted as a
    string; community layouts with credit. Three curated defaults (Minimal / Narrow / Full) offered on first run.
11. **For Th3chef** (asks that would simplify ours): a material argument on `bitmap_uv` so the loader owns the icon
    GUI; whether reading a single host object your own seat field points at is safe (the emplacement case).

## Ideas going forward (not planned; in the order they seem worth it)

- **Small ones from HUDdle 0.7.0** (RESEARCH.md): a low-ammo threshold slider (ours is a fixed quarter); a text
  outline for bright planets; a short glow on the count after a resupply; F9 settings saved to a file and loaded
  back; hidden while the game is paused.

- **Degrade, don't break**: a one-line health row in F9 ("382 types, build matches, layout Arcs, 0 errors"), so a
  bug report starts from the right place; the learned file shown as a feature (what's known of your weapons).
- **First-run card** ("F9 to pick a layout, nothing else to configure"), then silence.
- **The HUD earns attention only when it has news**: dim-when-calm generalised across parts; a weapon swap that
  cross-fades rather than pops.
- **Teammates' health** (effort 3): each other player's Helldiver's health and max_health, one field each a few
  times a second — but their Helldivers are the host's objects, and reading the host's objects is what dropped
  clients (RESEARCH.md, "The disconnects"). A single field read a few times a second is not the 700-object listing
  that did it, but it's a host read all the same: its own research run before anything ships. HUDdle reads the
  host's health once a second since 0.6.8 "where players report no drops" — evidence, not proof. The one HUD+ feature
  worth a look, and only if the panel can look like the game's.
- **Emplacement guns called in by others**: the same host-read question (the seat field b2205a6e points at the gun).
- **The game's own HUD behind the editor's parts** (effort 2): the vanilla HUD's pieces as outlined boxes at the
  game's HUD scale and edge offset, measured from screenshots at 16:9 / 21:9 / 32:9, so a layout is placed around
  them. Nice, not asked for.
- **Status effects** (burning, poisoned, stimmed): no field found that tells them apart (a33df340 doesn't follow
  stims); only if a field turns up.
- **Compass strip with teammates and objectives**: bigger than the rest of the HUD; their positions are host objects.
  Only if asked for, and after the host-read question.

## Closed: out of scope or not doable

- **Stratagem cooldowns**: no field carries them (the player and Helldiver types checked; likely names hashed
  against the whole network config); the stratagem types a02f5da5 / 089913db were never probed because the user
  took cooldowns out of scope — no bundled screen reader, ever. The Stratagem Deck plugin does it outside the game.
- **Mech / vehicle readout, pings, hit markers, the direction of a hit**: nothing readable carries them.
- **The map being open**: no field says it (cd889dbc follows what's in your hands; map_marker_type stays).
- **The directional and ballistic shields**: no health field; their damage isn't networked (2.1.6 research).
- **A world raycast**: the game has had none for Lua since 7.2.0; `chef.ray_box` meets a ray with a unit's box.
  The ground model and the structure boxes are the answer, and they're in.
- **Decoding the attachment ids**: not murmur64 of any name or path filediver knows; learned per kit instead.
- **Reading the host's objects on a client** (listing, sorting, reading them each second): drops the client after
  a quarter hour. Never again as a list; a single pointed-at object is an open question (above).
- **The quit-to-desktop crash notice**: the loader trace shows a clean shutdown after every mod's shutdown; the
  game's own. Our textures were trimmed anyway (2.1.8).
- **The never-held rule from HUDdle** (a weapon that never reads held isn't yours): unsafe at a 0.1 s read.
- **Chef.bitmap's white-square strobe** (docs/chef_bitmap_issue.md): fixed in Chef 1.4.0.
- **Boot Mod Loader support**: not planned (docs/BOOT_MOD_LOADER.md says what it would take).
