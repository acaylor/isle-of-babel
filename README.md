# Isle of Babel

A small, Myst-flavored first-person exploration game built with Godot 4.

You arrive on a wizard's pocket dimension: a green island adrift in the
middle of a vast lake, ringed on every horizon by forested mountains. A
stone path climbs from a wooden dock to the wizard's tower. The tower is
larger inside than out — its interior is an endless library containing
every book ever written, and a portal in the entrance hall carries you to
the summit balcony, where you can look down over the whole island.

A rowboat waits at the dock. It isn't going anywhere. Yet.

## Running it

Requires [Godot 4.6+](https://godotengine.org/download). No other
dependencies and no assets to download — every mesh, material and book in
the game is generated procedurally at runtime.

```sh
# from the repo root
godot --path .
# or open the project in the Godot editor and press Play
```

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` | Walk |
| Mouse | Look |
| `Shift` | Run |
| `Space` | Jump |
| `E` | Interact (doors, portals, shelves, boat, …) |
| `F` | While reading: leaf to another page |
| `Q` | In the library: summon a paper guide bird that leads you home |
| `Esc` | Pause menu (Resume / Quit) — also closes an open book |

## Things to do

- Follow the stone path from the dock up to the tower and press `E` at the door.
- Take a book down from any shelf and actually read it — leaf further with `F`.
- Walk in any direction inside the library. Keep walking. It does not end.
- Wander too deep, then whistle (`Q`) and follow the paper bird home.
- Take the portal in the entrance hall to the summit balcony and look down.
- Find the standing stones on the east side of the island and touch the crystal.
- Examine the rowboat at the dock.

## Project layout

```
autoload/game.gd     Input map, fade transitions, spawn-point routing
player/player.gd     First-person controller + HUD (builds itself in code)
scenes/island.gd     Procedural island: terrain, lake, mountains, trees,
                     dock, boat, stone circle, tower + summit balcony
scenes/library.gd    Endless streamed library cells, deterministic per cell
scripts/forge.gd     Static helpers for procedural geometry
scripts/flora.gd     Detailed nature meshes: trees, rocks, bushes, grass,
                     flowers, ridged mountains (hand-computed normals,
                     per-vertex color)
scripts/interactable.gd  Raycast-targetable object with prompt + action
scripts/book_lore.gd Generated titles/authors/excerpts for the shelves
shaders/water.gdshader   The lake
```

## Testing

The repo ships a headless smoke test that plays through the whole loop —
island, into the library (opens a generated book, summons the guide bird),
through the portal to the summit, then back out to the title screen —
asserting at each step. Run it from the repo root:

```sh
godot --headless --path . res://tests/smoke.tscn
```

It prints `SMOKE OK` and exits `0` on success, or `SMOKE FAIL: <reason>`
and exits `1`. The stages live in `tests/observer.gd` (time-based, because
the scene transitions fade in real time).

For visual checks without playing, Godot's movie-maker mode renders real
frames to disk:

```sh
# 25 frames of the title screen / island at 10 simulated fps
godot --path . --write-movie /tmp/shots/f.png --fixed-fps 10 --quit-after 25

# same, but for a specific scene
godot --path . res://scenes/library.tscn --write-movie /tmp/shots/f.png --fixed-fps 10 --quit-after 25
```

(macOS note: the Homebrew cask — `brew install --cask godot` — doesn't put
`godot` on PATH; either symlink it,
`ln -s /Applications/Godot.app/Contents/MacOS/Godot /opt/homebrew/bin/godot`,
or use the full path.)

## Asset policy

The repo is intentionally 100% text: scripts, two one-node scenes, a
shader, and an SVG icon. `.gitattributes` already routes future binary
formats (models, textures, audio) through Git LFS, so when handcrafted
assets arrive they won't bloat history.

## Roadmap

- **The forest** — the rowboat becomes usable and carries you across the
  lake to a forest level beneath the mountains.
- Ambient audio (lake, wind, the particular quiet of infinite shelves).
- More to find in the library: rare glowing volumes, deeper structure.
- Save/load (remember where the wanderer left off).
