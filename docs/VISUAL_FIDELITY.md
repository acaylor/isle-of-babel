# Visual fidelity roadmap

A checklist of rendering improvements, ranked by impact per effort. All of
them respect the hard rules: text-only assets (shaders and generators, no
textures on disk), seeded determinism, and the quiet low-poly aesthetic —
the goal is polish and atmosphere, not realism.

Verify every item by rendering captures (`tests/capture.tscn`) and looking
at them; include before/after screenshots in the PR.

## Checklist

- [x] **1. Water shader upgrade.** Water fills half of nearly every
  outdoor frame. Blend shallow→deep color by real depth (depth texture),
  draw a soft foam line where water meets terrain (kills the hard polygon
  shore edge), and perturb normals with scrolling procedural waves so sun
  glints and the sky reflection break up instead of banding.
- [x] **2. Procedural sky.** Replace the flat two-color
  `ProceduralSkyMaterial` with a custom sky shader: fbm-noise drifting
  clouds, a sun disc with halo, horizon haze. Per-scene palettes stay
  (island vs. forest).
- [ ] **3. Volumetric fog in the forest.** Forward+ volumetric fog plus
  sun `light_volumetric_fog_energy` for god-rays through the canopy and a
  glowing haze around the portal clearing. Keep cheap exponential fog for
  the island's far haze.
- [ ] **4. Global illumination and tonemapping.** Switch Filmic → AgX
  tonemapper. Try `sdfgi_enabled` on outdoor scenes (runtime-only, no
  baking — capture-and-compare the GPU cost; fallback is `ssil_enabled`
  next to the existing SSAO). Soften the sun: `shadow_blur ≈ 1.5–2.0`,
  `directional_shadow_blend_splits = true`.
- [ ] **5. Cliff and mountain surfaces.** The boundary cliffs read as
  untextured gray planes from the lake. Add horizontal strata banding and
  a top-down snow/scree gradient — either a small triplanar shader or
  vertex-color banding in the mesh generator (the pattern `Flora` already
  uses).
- [ ] **6. Motion.** World-position sine sway in a vertex shader on
  canopies and grass; sparse GPUParticles pollen motes drifting through
  the forest light shafts. Route cheap ambient animation through the
  scenes' FX registries.
