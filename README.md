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
| `Esc` | Release the mouse (click to recapture) |

## Things to do

- Follow the stone path from the dock up to the tower and press `E` at the door.
- Browse the shelves — the library will hand you a book. It has plenty.
- Walk in any direction inside the library. Keep walking. It does not end.
- Take the portal in the entrance hall to the summit balcony and look down.
- Find the standing stones on the east side of the island.
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
