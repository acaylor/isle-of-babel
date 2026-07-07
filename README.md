# Isle of Babel

A small, Myst-flavored first-person exploration game built with Godot 4.

You arrive on a wizard's pocket dimension: a green island adrift in the
middle of a vast lake, ringed on every horizon by forested mountains. A
stone path climbs from a wooden dock to the wizard's tower. The tower is
larger inside than out — its interior is an endless library containing
every book ever written, and a portal in the entrance hall carries you to
the summit balcony, where you can look down over the whole island.

A rowboat waits at the dock. Sit in it, and it rows itself across the lake
to the far shore: an old-growth forest, noticeably larger than the island,
where a worn trail leads over a stream and deep between the trees to the
mossy ruin of the First Tower — the wizard's failed first library, and the
reason the island exists. The wizard left his journal on the lectern there.

## Running it

Requires [Godot 4.7+](https://godotengine.org/download). No other
dependencies and no assets to download — every mesh, material and book in
the game is generated procedurally at runtime.

```sh
# from the repo root — first run only: build Godot's import cache
# (running the game directly on a fresh checkout fails with a wall of
#  "Identifier not declared" / "Could not find type" parse errors,
#  because the global script-class cache in .godot/ doesn't exist yet)
godot --headless --path . --import

godot --path .
# or open the project in the Godot editor and press Play
# (opening the editor once also builds the cache)
```

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` | Walk |
| Mouse | Look |
| `Shift` | Run |
| `Space` | Jump |
| `E` | Interact (doors, portals, shelves, boat, …) |
| `F` | While reading: leaf to another page (in order, for the journal) |
| `Q` | In the library: summon a paper guide bird that leads you home |
| `Esc` | Pause menu (Resume / Quit) — also closes an open book |

## Things to do

- Follow the stone path from the dock up to the tower and press `E` at the door.
- Take a book down from any shelf and actually read it — leaf further with `F`.
- Walk in any direction inside the library. Keep walking. It does not end.
- Wander too deep, then whistle (`Q`) and follow the paper bird home.
- Take the portal in the entrance hall to the summit balcony and look down.
- Find the standing stones on the east side of the island and touch the crystal.
- Sit in the rowboat at the dock and let it carry you to the far shore.
- Follow the cairn-marked trail over the footbridge to the ruin of the
  First Tower, read the boundary stone, and leaf through the wizard's
  journal (`F` turns its pages in order).
- Leave the trail. Five books glow faintly where the forest keeps them —
  return all five words and listen for what wakes in the ruin.
- Follow the stream the wrong way.
- Someone else has been living in the forest. Find their camp, and don't
  tell the wizard.
- Sail home and watch the island grow out of the haze.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the game is put
  together: the one-node scene pattern, scene routing, the procedural
  toolkit, terrain, the streamed library, and the testing tools.
- [docs/VISION.md](docs/VISION.md) — what this game is trying to be, the
  story so far, every feature shipped per release, and the parts box of
  future ideas.
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — how to contribute,
  assuming no Godot experience: setup, just-enough-Godot, recipes, and the
  testing house rules.

## Project layout

```
autoload/game.gd     Input map, fade transitions, spawn-point routing
player/player.gd     First-person controller + HUD (builds itself in code)
scenes/island.gd     Procedural island: terrain, lake, mountains, trees,
                     dock, boat, stone circle, tower + summit balcony
scenes/library.gd    Endless streamed library cells, deterministic per cell
scenes/forest.gd     The far shore: old-growth forest, stream + footbridge,
                     trail, jetty, and the ruin of the First Tower
scripts/forge.gd     Static helpers for procedural geometry
scripts/flora.gd     Detailed nature meshes: trees, rocks, bushes, grass,
                     flowers, ferns, fallen logs, ridged mountains
                     (hand-computed normals, per-vertex color)
scripts/interactable.gd  Raycast-targetable object with prompt + action
scripts/book_lore.gd Generated titles/authors/excerpts for the shelves
shaders/water.gdshader   The lake
```

## Testing

The repo ships a headless smoke test that plays through the whole loop —
island, into the library (opens a generated book with simulated key
presses, summons the guide bird), through the portal to the summit, out to
the title screen, then across to the forest (reads the wizard's journal
and rides the boat's arrival leg to the jetty) — asserting at each step.
Run it from the repo root:

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

# tests/capture.tscn adds an env-driven free camera / spawn point:
#   CAP_SCENE  scene to load (default the forest)
#   CAP_SPAWN  spawn point ("jetty", "voyage", "dock", ...)
#   CAP_CAM    "x,y,z" fixed camera (omit for the player's view)
#   CAP_LOOK   "x,y,z" the fixed camera's target
CAP_CAM="-44,18,-68" CAP_LOOK="-58,11,-84" \
  godot --path . res://tests/capture.tscn --write-movie /tmp/shots/f.png --fixed-fps 10 --quit-after 12
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

- Ambient audio (lake, wind, the particular quiet of infinite shelves).
- More to find in the library: rare glowing volumes, deeper structure.
- Save/load (remember where the wanderer left off — and which words the
  forest has already given back).
- The stranger: who leaves a fire cold that long?
