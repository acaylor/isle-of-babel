# Changelog

All notable changes to Isle of Babel are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
releases are tagged on the `main` branch.

## [0.5.0-alpha] — unreleased

The light on the water update.

### Added
- A visual fidelity roadmap (`docs/VISUAL_FIDELITY.md`): six planned
  rendering improvements, ranked by impact, all within the text-only and
  seeded-determinism rules.
- A procedural sky shader shared by the island and the forest: drifting
  fbm clouds lit against the sun, a sun disc with halo, horizon haze, and
  per-scene palettes (the old forest sits under heavier cover).

### Changed
- The lake learned depth: water color now fades shallow→deep by true
  water-column depth, a noise-broken foam line laps where water meets
  land (no more hard polygon shoreline), and fine ripples break the sun
  and sky reflections into glints.
- Distance fog no longer repaints the entire sky in fog color
  (`fog_sky_affect`), which had been flattening the heavens to a single
  pale wash; the horizon keeps its haze.

## [0.4.0-alpha] — 2026-07-06

The secrets update.

### Added
- The kept books: five books from the First Tower grew into living trees
  off the trail, each faintly glowing, each readable — a dictionary the
  roots kept revising, an atlas the moss corrected, a book of hours the
  seasons observe, a cookery book with unsettling margins, and a child's
  primer the forest finished. Returning all five words wakes the cold
  ring in the ruin: the wizard's last charm, a one-way door home to the
  jetty. (Progress is per-visit until save/load lands.)
- The spring glade: follow the stream the wrong way and it ends at its
  secret source — a waterfall down the boundary rock, a pool ringed in
  mossy stones, drifting motes of light, and the fifth kept book at the
  water's edge.
- The hermit's hollow: a great split tree someone has been living in.
  The fire is cold, the bedroll rolled, and the unsigned note on the
  root shelf did not arrive by boat.
- Natural boundaries: the forest cove is now walled by meandering rock
  cliffs too steep to climb, running into the lake as headlands, with a
  bare scree apron where the treeline breaks — no invisible walls, the
  world ends in stone and water.

### Changed
- Everything you can touch in the forest got a visual pass: the kept
  books breathe light through lips of bark, trailing tendrils, moss, and
  slow-orbiting loose pages; the boundary stone carries rows of worn
  carving, a chipped crown, and creeping moss; the wizard's journal lies
  open mid-entry on its lectern, ink lines and ribbon marker and all;
  the cold ring has shed shards beside a cracked dais circled with worn
  sigils, and wakes with breathing light and circling sparks; the
  hermit's camp gained a dead lantern, wax runs, spare books, and a
  washing line with one forgotten shirt; the rowboat carries a lit,
  gently pulsing bow lantern and moors to a proper post with a charmed
  knot. The spring's waterfall pours as a full column with white threads
  and mist, and every mote in the forest now drifts instead of hanging
  still.
- The stream now begins at the spring instead of running off the edge of
  the map.
- The smoke test collects all five kept books (asserting the ring wakes),
  validates every secret text, and marches the boundary with held input
  to prove the cliffs stop a walker.

## [0.3.0-alpha] — 2026-07-01

The voyage update.

### Added
- The rowboat sails. `E` at the dock seats you in it, the mooring knot
  unties itself, and the enchanted boat rows you across the lake — free to
  look around the whole way — before gliding up to a jetty on the far
  shore. The return trip watches the island grow out of the haze.
- The far shore: a new explorable area noticeably larger than the island.
  Old-growth forest (every tree bigger than the island's), ferns, mossy
  fallen logs with mushrooms, a winding stream, and a shoreline of coves
  beneath a fresh ring of mountains.
- A worn, cairn-marked trail from the jetty, across an arched footbridge,
  deep between the trees to the ruin of the First Tower: broken ring
  walls, spilled columns, a cracked dais, and a portal ring gone cold.
- The wizard's story, written rather than generated: a boundary stone
  carved in a worn hand, and the wizard's four-entry journal waiting on
  the lectern where he left it. `F` leafs through the journal's pages in
  order.
- `tests/capture.tscn`: an env-driven camera/spawn harness for
  movie-maker visual checks (documented in the README).

### Changed
- The dock prompt is now "Set out for the far shore"; the boat is no
  longer just scenery.
- The smoke test now crosses to the forest, validates the journal, and
  rides the boat's arrival leg end to end.

### Fixed
- Walking outdoors was clunky (playtest feedback): the player now walks
  slopes up to 55° instead of Godot's 45° default and snaps harder to
  bumpy ground; the plateau's south side is a steady ramp so the path
  climbs to the tower door instead of hitting a steep lip; and the
  footbridge banks rise into earthen abutments flush with the deck, so
  crossing no longer takes a jump. The smoke test now walks both routes
  with real held input — across the bridge (checking mid-crossing that
  the player is on the deck, not in the stream) and up to the tower door.
- Pressing `E` while reading closed the book but the same key press
  immediately took another book down from the shelf under the crosshair,
  so `E` appeared to flip pages just like `F`. The press that closes a
  book is now consumed. The smoke test opens and closes a book through
  real simulated key presses to keep this from regressing.

## [0.2.0-alpha] — 2026-06-12

The interactivity update.

### Added
- Main menu: the game now opens on a title screen floating over the live
  island, the camera slowly orbiting the tower. Begin starts at the dock;
  a version label sits in the corner.
- Open-book reading interface: taking a book down from a shelf now opens it
  across the screen — leather cover, two parchment pages, generated title,
  author, chapter heading, and page text that stays on the book's subject.
  `F` leafs to another page, `E`/`Esc` closes the book.
- Paper guide bird: press `Q` anywhere in the library and a loose page folds
  itself into a glowing bird that flies above the shelves toward the
  entrance portal, waiting when the reader falls behind and dissolving over
  the dais.
- Pause menu on `Esc` with Resume, Main Menu, and Quit.
- The standing-stone crystal now folds the world: touching it teleports you
  to the summit balcony.

### Fixed
- On-screen messages (arrival hints, the boat, falling in the lake) were
  positioned off-screen and never visible; they now appear above the bottom
  of the screen as intended.

### Changed
- `Esc` opens the pause menu instead of releasing the mouse.
- Shelf prompt is now "Take down a book".

## [0.1.0-alpha] — 2026-06-12

First playable alpha: the wizard's pocket dimension, explorable end to end.

### Added
- Explorable island in a vast lake ringed by forested mountains: noise-based
  terrain, animated water shader, wooden dock, stone path, standing-stone
  circle with a humming crystal, and the wizard's tower.
- Infinite library inside the tower: gallery cells stream in around the
  player and never end, each deterministically furnished from its grid
  coordinates — shelves of instanced books, reading tables, candles, rugs.
- Browsable shelves that produce generated book titles, authors, volume
  numbers, and excerpts.
- Portal loop: tower door ↔ library entrance, library portal ↔ summit
  balcony overlooking the island.
- Rowboat moored at the dock, reserved for a future voyage to the forest.
- Detailed procedural nature: sculpted pines and broadleaf trees (plus a
  rare autumn stray), mossy boulders in three size classes, grass tufts,
  wildflowers, bushes, and unique ridged mountains with forested slopes
  and snow caps.
- First-person controller (WASD / mouse / Shift / Space / E), fade
  transitions with spawn-point routing, lake-fall rescue back to the dock.
- Headless smoke test covering the island → library → summit loop.

### Notes
- Everything is generated procedurally at runtime; the repository is 100%
  text. Future binary assets are pre-routed through Git LFS.
