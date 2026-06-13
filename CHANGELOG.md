# Changelog

All notable changes to Isle of Babel are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
releases are tagged on the `main` branch.

## [0.2.0-alpha] — Unreleased

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
