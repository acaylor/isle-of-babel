# Contributing

This guide assumes you've **never used Godot**. That's fine — this project
uses Godot unusually (everything is built by code, the editor is optional),
so general Godot experience matters less here than in most Godot projects.
If you can read a Python-ish language and run a terminal, you can contribute.

## 1. Setup (10 minutes)

1. **Install Godot 4.7+** (the standard build, not .NET):
   - macOS: `brew install --cask godot` — note the cask does *not* put
     `godot` on your PATH. Either use the full path
     `/Applications/Godot.app/Contents/MacOS/Godot` or symlink it:
     `ln -s /Applications/Godot.app/Contents/MacOS/Godot /opt/homebrew/bin/godot`
   - Linux/Windows: grab the binary from [godotengine.org](https://godotengine.org/download);
     it's a single executable, no installer.
2. **Clone the repo.** There are no assets to download — the repository is
   100% text and the whole game is generated at runtime.
3. **Build the import cache (first run only):**

   ```sh
   godot --headless --path . --import
   ```

   Skipping this on a fresh checkout gets you a wall of
   `Identifier "Forge" not declared` parse errors — Godot resolves the
   project's global classes through a cache in the untracked `.godot/`
   directory, and only an import pass (or opening the editor once) builds it.
4. **Run the game:** `godot --path .` — you should land on the title screen.
5. **Run the test:** `godot --headless --path . res://tests/smoke.tscn` —
   it plays through the whole game in about a minute and prints `SMOKE OK`.

If all five steps worked, you have everything.

## 2. Just enough Godot

Godot concepts you'll actually encounter here, in one table:

| Term | What it means in this repo |
|---|---|
| **Node / scene tree** | Everything in a running game is a tree of nodes (like a DOM). `Node3D` is a thing with a transform; `MeshInstance3D` displays a mesh; `StaticBody3D` + `CollisionShape3D` is a wall you can't walk through. Our code creates these with `Thing.new()` and `add_child()`. |
| **Scene (`.tscn`)** | Normally a big editor-authored file. Ours are ~6 lines: one root node with a script. **You will probably never edit a `.tscn`.** |
| **Script (`.gd`)** | GDScript, attached to a node. `_ready()` runs once when the node enters the tree (we build the whole world there), `_process(delta)` runs every frame, `_physics_process(delta)` runs every physics tick. |
| **`class_name`** | Makes a script a global type — that's why code can just say `Forge.box(...)` or `Interactable.make(...)` with no imports. |
| **Autoload** | A script Godot instantiates once and keeps alive across scene changes. Ours is `Game` (see below). It's registered in `project.godot`. |
| **Signal** | Godot's event system (`button.pressed.connect(func)`); we use them only for UI buttons and timers. |

GDScript in sixty seconds: it looks like Python. `var x := 5` declares with
inferred static typing (we type everything). `func name(arg: Type) -> Ret:`
defines functions. Indentation is **tabs**. Lambdas look like
`func(p: Node) -> void: ...` and capture variables by value. `$` and
`get_node()` fetch child nodes, but you'll rarely need them — we hold direct
references instead.

## 3. The map of the codebase

```
autoload/game.gd     Scene travel + fades, spawn routing, pause menu, input map, VERSION
player/player.gd     The first-person controller; builds its own camera/HUD/book UI
scenes/island.gd     The island: terrain, tower, dock, boat voyage (out/home legs)
scenes/library.gd    The infinite library: streamed cells, shelves, the guide bird
scenes/forest.gd     The far shore: terrain, trail, ruin, secrets, boundary cliffs
scripts/forge.gd     Static geometry helpers (box/cyl/sphere/collider/light/portal)
scripts/flora.gd     Nature meshes (trees, rocks, ferns, logs, grass, mountains)
scripts/interactable.gd  The E-to-interact building block
scripts/book_lore.gd Generated book text + all fixed/written lore
shaders/water.gdshader   The lake
tests/observer.gd    The smoke test's staged script
tests/capture.gd     Env-driven camera rig for rendering screenshots
docs/                You are here
```

Read [ARCHITECTURE.md](ARCHITECTURE.md) for how these fit together. The
three most important house rules:

1. **`height_at(x, z)` is the single source of terrain truth** in each
   outdoor scene. Never place something at a hardcoded height — ask
   `height_at()`.
2. **All randomness is seeded.** Every generator makes its own
   `RandomNumberGenerator` with a fixed seed. If your feature uses
   randomness, seed it — the world must be identical on every launch.
3. **Vertex colors are sRGB.** Use `Forge.vc_mat()` for anything with
   per-vertex color, or your feature will render washed-out and pale.

## 4. Recipes

### Add an interactable prop

Everything the player can press E on is an `Interactable` — a shape, a
prompt, and a closure:

```gdscript
var shape := BoxShape3D.new()
shape.size = Vector3(1.0, 1.2, 1.0)
root.add_child(Interactable.make(shape, "Ring the bell", func(p: Node) -> void:
    (p as Player).show_message("Somewhere, far away, nothing answers.", 6.0),
    Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0))))
```

Build its visuals next to it with `Forge` calls. Look at the boat or the
boundary stone in `forest.gd` for complete examples.

### Add a readable text

Fixed texts live in `scripts/book_lore.gd` as functions returning a
Dictionary with `title`, `author`, `volume`, `chapter`, `body`, `page`.
Open one with `(p as Player).open_book(BookLore.my_text())`, or pass an
array of pages as the second argument to make `F` leaf through them in
order (see the wizard's journal).

### Change terrain

Edit the scene's `height_at()` / `_base_height()`. Features are additive
noise/`smoothstep`/`lerpf` terms. Keep slopes the player must walk under
~45° (the controller tolerates 55°); make barriers steeper than 60°. If
vegetation should stay off your feature, add an exclusion to
`_clear_of_landmarks()`.

### Add a new area/scene

Copy the 6-line `.tscn` pattern with a new script. Give it `height_at()`,
a `_spawns` dictionary, and a `_spawn_player()` that reads
`Game.spawn_point`. Wire an `Interactable` (door/portal/boat) in an
existing scene to `Game.travel("res://scenes/yours.tscn", "spawn_name")`.
Then add an observer stage (below).

## 5. Testing your change — this part is not optional

### The smoke test

```sh
godot --headless --path . res://tests/smoke.tscn
```

`tests/observer.gd` is a staged, time-based script that plays the game:
travels between scenes, opens books with *real simulated key events*, and
literally walks routes with held input (across the footbridge, up the tower
ramp, into the boundary cliffs) asserting the world behaves. If your change
adds a mechanic, add a stage; if it fixes a bug, add an assertion that fails
without your fix.

House rule — **prove your test can fail**: temporarily reintroduce the bug
(or stub out your feature), run the smoke test, confirm it fails with your
message, then restore. Quote the failing output in your PR description.
Tip: copy the file to a backup before hacking it up — a `git checkout --`
restore will eat your uncommitted fix along with the experiment.

### Seeing your change

Godot's movie-maker mode renders real frames headlessly-ish (it needs a
display but no interaction). `tests/capture.tscn` gives you a positionable
camera via environment variables:

```sh
# Free camera at x,y,z looking at x,y,z — 8 frames into /tmp/shots/
CAP_SCENE=res://scenes/forest.tscn CAP_CAM="-44,18,-68" CAP_LOOK="-58,11,-84" \
  godot --path . res://tests/capture.tscn \
  --write-movie /tmp/shots/f.png --fixed-fps 10 --quit-after 8

# Or the player's view at a spawn point (omit CAP_CAM)
CAP_SCENE=res://scenes/forest.tscn CAP_SPAWN=voyage \
  godot --path . res://tests/capture.tscn \
  --write-movie /tmp/shots/f.png --fixed-fps 10 --quit-after 150
```

Look at the frames. Visual features get merged on the strength of their
screenshots — include one or two in your PR.

## 6. Conventions and PR flow

- **Style:** tabs; typed GDScript (`var x := ...`, typed args and returns);
  match the surrounding code. Comments state *constraints the code can't
  show* ("the terrain mesh is coarser than these samples and would poke
  through"), not what the next line does.
- **Asset policy:** the repo is 100% text. Do not commit binaries.
  `.gitattributes` pre-routes binary formats through Git LFS for the day
  we deliberately add some (probably audio) — that day arrives via
  discussion, not a PR.
- **Tone:** the game is quiet, literate, and gently melancholy. In-game
  prose gets the same review attention as code — read the existing lore in
  `book_lore.gd` before writing any.
- **Branch → PR → merge = release point.** Add your changes to the
  `Unreleased` section of `CHANGELOG.md`. Version tags (`vX.Y.Z-alpha`)
  are cut on `main` after merge; `Game.VERSION` is bumped in the PR that
  starts a new version's work.
- A PR should have: green smoke test, a changelog entry, screenshots for
  anything visible, and (for bug fixes) the quoted negative-repro output.

## 7. Getting unstuck

- Wall of `Identifier not declared / Could not find type` errors → you
  skipped the `--import` step (see Setup #3).
- Your mesh is invisible from one side → you built raw `SurfaceTool`
  geometry without `cull_mode = CULL_DISABLED`; use `Flora._finish()` or
  `Forge.vc_mat()`.
- Your colors look pale and washed out → sRGB flag; use `Forge.vc_mat()`.
- Something floats above the terrain → you placed it before terrain
  planning ran, or at a hardcoded height; ask `height_at()` (and see
  "plan before terrain" in ARCHITECTURE.md).
- The player can't walk somewhere they should → slope over 55°, or a
  collider where you didn't expect one; the walk-test pattern in
  `observer.gd` is the fastest way to prove it either way.
