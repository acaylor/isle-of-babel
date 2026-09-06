# Rendering performance

Outdoor vegetation is grouped by mesh variant into 48 m XZ cells through
`Forge.scatter`. Godot culls each MultiMesh as a unit, so these cells allow
off-screen regions to skip submission. Bounds include 0.1 m of mesh-local
wind displacement before instance scale and rotation. Plants, colliders,
seeds, and distant silhouettes are preserved. Smaller cells increase draw
calls; measure both ground-level and elevated views before tuning the size.

Flora indexes identical vertices at mesh completion. A comparison against
the previous generators with seed 11 (pine, broadleaf, bush, grass, fern,
log) counted 3,906 vertices before and 1,229 after, with equivalent expanded
positions, normals, colors, and triangle order. This is a geometry count,
not a measured frame-rate improvement; indexing also adds startup work.

Water filters ripple frequencies by screen-space derivatives and increases
roughness as detail becomes unresolved. This targets distant specular
shimmer. The shader changes still need graphical verification: the current
agent session could run headless tests but could not authenticate to X11.

## Verification

```sh
godot --headless --path . --script res://tests/render_geometry.gd
godot --headless --path . res://tests/smoke.tscn
```

The geometry test covers negative cell coordinates, boundary positions,
scaled/rotated wind bounds, instance counts, and empty input. Removing the
wind padding makes it fail with `RENDER GEOMETRY FAIL: wind bounds clipped`.
Headless Godot does not retain MultiMesh transform readback; the test checks
CPU-side cell counts and bounds rather than claiming GPU validation.

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
calls. No FPS improvement has been measured yet.

Use the existing `--write-movie` capture workflow separately to inspect
shoreline foam, distant water, and wind at screen edges. Do not combine
movie capture with timing runs.

Reference: [Godot's MultiMesh optimization guidance](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).
