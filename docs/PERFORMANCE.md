# Rendering performance

Outdoor vegetation is grouped by mesh variant into 48 m XZ cells through
`Forge.scatter`. Godot culls each MultiMesh as a unit, so these cells allow
off-screen regions to skip submission. Bounds are padded by the mesh's own
`sway_amp` (`Forge.sway_padding` reads it off the sway material, and
`Flora._finish_sway` is the only thing that sets it), before instance scale
and rotation, so raising a wind amplitude widens the bounds instead of
culling cells whose canopies are still on screen. Static meshes pad by
nothing. Plants, colliders, seeds, and distant silhouettes are preserved.
Smaller cells increase draw calls; measure both ground-level and elevated
views before tuning the size.

Each batch is named `Scatter_<variant>_<cell x>_<cell z>` — the cell keys
repeat for every variant a scene scatters, so without the variant Godot
renames the collisions to `@Scatter_0_0@N` and the remote debugger loses the
one thing the name was for.

Flora indexes identical vertices at mesh completion. A comparison against
the previous generators with seed 11 (pine, broadleaf, bush, grass, fern,
log) counted 3,906 vertices before and 1,229 after, with equivalent expanded
positions, normals, colors, and triangle order. This is a geometry count,
not a measured frame-rate improvement; indexing also adds startup work.

Water filters ripple frequencies by screen-space derivatives and increases
roughness as detail becomes unresolved. This targets distant specular
shimmer. Verified on Forward+: the `CURRENT_RENDERER == RENDERER_COMPATIBILITY`
branch resolves as intended, and the shoreline foam band — which depends on
depth reconstruction — is pixel-identical to the previous shader (maximum
channel delta 1). Mid-water differs, which is the point of the change.

## Verification

```sh
godot --headless --path . --script res://tests/render_geometry.gd
godot --headless --path . res://tests/smoke.tscn
```

The geometry test covers negative cell coordinates, boundary positions,
scaled/rotated wind bounds, instance counts, empty input, per-variant batch
names, and that Flora's living meshes still carry a sway amplitude while its
static ones do not. It asserts the bounds against the amplitude on the
material rather than against a copy of the padding constant, so pinning the
pad back to a literal 0.1 m fails with `RENDER GEOMETRY FAIL: wind bounds
clipped`, and dropping the variant from the node name fails with `batch name
collided`. Headless Godot does not retain MultiMesh transform readback; the
test checks CPU-side cell counts and bounds rather than claiming GPU
validation. It also cannot read a shader's uniform defaults (the dummy
renderer never compiles them), which is why `Forge.sway_padding` asserts
that a sway material states its own `sway_amp`.

## Repeatable graphical measurements

Run from a graphical desktop, without movie recording or fixed FPS:

```sh
CAP_SCENE=res://scenes/island.tscn CAP_SPAWN=dock CAP_CAM="0,18,55" CAP_LOOK="0,14,-12" CAP_BENCH_FRAMES=600 \
  godot --path . res://tests/capture.tscn --disable-vsync

CAP_SCENE=res://scenes/forest.tscn CAP_CAM="-44,18,-68" CAP_LOOK="-58,11,-84" CAP_BENCH_FRAMES=600 \
  godot --path . res://tests/capture.tscn --disable-vsync
```

After 120 warmup frames the harness reports median and p95 wall frame time,
mean draw calls and primitives, renderer, and display driver, then exits.
Use identical camera, resolution, renderer, and hardware for comparisons.
Headless results only validate harness execution: its renderer is a dummy
and its timing is not a GPU benchmark. Also check the tower balcony and
boat crossing: more visible cells can trade fewer triangles for more draw
calls.

## Measured

Apple M5 Pro, Forward+, 400 frames per run after warmup, `--disable-vsync`,
Godot 4.7.2. "Before" is one MultiMesh per mesh variant per scene; "after"
is the 48 m cells.

| View | Draw calls | Primitives | Median frame |
| --- | --- | --- | --- |
| Forest `-44,18,-68` | 549 → 780 | 3.20M → 1.05M | 3.078 → 2.811 ms |
| Island dock | 295 → 655 | 1.529M → 1.302M | 2.70 → 2.72 ms |
| Island `0,70,70` | 205 → 491 | 1.066M → 0.975M | 2.775 → 2.766 ms |

Batch counts follow the same split: the forest scatters 490 cells where it
scattered 24 whole-variant MultiMeshes (7.2 instances per batch on average),
the island 139 where it scattered 19.

The forest is the real win — two thirds of its primitives were off-screen
trees. Both island views are a wash: its vegetation is dense and compact
enough that a 48 m cell buys a 9–15% primitive reduction for 2.2–2.4× the
draw calls, and the frame time does not move. A larger `cell_size` for
`island.gd` would keep the forest's gain without the island's draw-call
inflation; the parameter is per-call for exactly this reason.

Use the existing `--write-movie` capture workflow separately to inspect
shoreline foam, distant water, and wind at screen edges. Do not combine
movie capture with timing runs.

Reference: [Godot's MultiMesh optimization guidance](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).
