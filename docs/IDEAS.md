# Ideas (2026-10-29)

Where NarrowHUD wants to sit: customizability, reliability and polish — a HUD you make your own and then forget
about — not the race to be the next HUD Plus (external helpers, screen reading, every feature). What we have: the
editor (nobody else has one), the look, first mover. In the order they stood out; all after the disconnect work and
the presets-vs-offsets fix, which both of the motion ideas need.

## 1. Motion (the clear first) — done 1.5.55 (docs/DEVLOG.md), the aiming state as a Spread change and an opacity

The hit trail on the health bar is the reference: it's what makes that bar look like the game's own. Apply the same
restraint everywhere — ease, don't animate; a thing moves once, with a reason — and never overdo it.

- A bar that eases to its value instead of jumping; a count that ticks; a warning that pulses once and settles,
  not a flash forever; a weapon swap that cross-fades rather than pops. Cheap in Lua, big in feel.
- **Aiming as a state.** We already know when you aim (the aim field, used for the drop line). Options on it:
  - show the HUD only while aiming (or fade it out when not);
  - two layouts, one for aiming and one for not, and the elements *slide* from their place in one to their place
    in the other as you raise or lower the weapon (closer in while aiming, further out at rest, or whatever the
    player draws). Two custom layout files, or two positions of the same preset, and a tween between them.
  - Needs the presets-vs-offsets rework first: a layout has to be a group of parts with relations, so a part can
    be moved between two places and keep what's pinned to it.

## 2. The game's typography

- **Square brackets around a gauge** — `[ ]` at the ends of a bar, the way the game draws its own health and
  stamina — as a third style next to the outline and the translucent background we have. Per gauge in the editor,
  a toggle in F9 for the built-in Positions.
- The rest of that direction: magazine ticks shaped like the game's, the backpack bar's ends, the game's own
  icons wherever they exist (the mode sprites are in; the stim and grenade are our own, drawn to match).

## Also from the same brainstorm (lower)

- Presets as a gallery of thumbnails rendered from their own files; share a layout as a short string pasted in a
  comment, "Import" in the editor; community layouts in the gallery with credit.
- The palette (and later per-part colours), in the layout file and in F9 through Chef 1.4's colour rows.
- Three curated defaults (Minimal / Narrow / Full) offered on first run with pictures; the knobs under them.
- Degrade, don't break: no single failure blanks the HUD; a one-line health row in F9 ("382 types, build matches,
  layout Curved pair, 0 errors"); the learned file shown as a feature.
- First-run card ("F9 to pick a layout, nothing else to configure"), then silence; a short top of the Nexus page.
- The HUD earns attention only when it has news (low ammo, heat, reload): dim-when-calm generalised.
- Not doing: external helpers, screen-read cooldowns, a compass with every objective, "everything HUD+ had".
  Teammates' health is the one HUD+ feature worth a look, and only if the panel can look like the game's.
