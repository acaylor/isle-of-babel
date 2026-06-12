class_name Flora
## Detailed procedural nature meshes: trees, rocks, bushes, grass, flowers,
## and mountains. Everything is triangle soup with hand-computed normals and
## per-vertex colors, so lighting never depends on winding order and no
## textures are needed.

# -- plumbing ----------------------------------------------------------------

static func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

static func _noise(seed_v: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	return n

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func _finish(st: SurfaceTool, rough := 1.0) -> ArrayMesh:
	var mesh := st.commit()
	var mat := Forge.vc_mat(rough)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh

static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.add_vertex(p)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_vert(st, a, na, ca)
	_vert(st, b, nb, cb)
	_vert(st, c, nc, cc)

## Tapered tube from p0 to p1. Normals are radial; color lerps c0 -> c1.
static func _tube(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, sectors: int, c0: Color, c1: Color) -> void:
	var axis := (p1 - p0).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var side2 := axis.cross(side).normalized()
	for j in sectors:
		var a0 := TAU * j / sectors
		var a1 := TAU * (j + 1) / sectors
		var d0 := side * cos(a0) + side2 * sin(a0)
		var d1 := side * cos(a1) + side2 * sin(a1)
		var v00 := p0 + d0 * r0
		var v01 := p0 + d1 * r0
		var v10 := p1 + d0 * r1
		var v11 := p1 + d1 * r1
		_tri(st, v00, v01, v11, d0, d1, d1, c0, c0, c1)
		_tri(st, v00, v11, v10, d0, d1, d0, c0, c1, c1)

## Irregular cone layer (for pines): a jittered ring fanned up to an apex.
static func _cone_layer(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, radius: float, height: float, base_c: Color, tip_c: Color, sectors := 10) -> void:
	var ring: Array[Vector3] = []
	for j in sectors:
		var a := TAU * j / sectors
		var r := radius * rng.randf_range(0.82, 1.15)
		var droop := rng.randf_range(-0.12, 0.04)
		ring.append(center + Vector3(cos(a) * r, droop * radius, sin(a) * r))
	var apex := center + Vector3(rng.randf_range(-0.06, 0.06) * radius, height, rng.randf_range(-0.06, 0.06) * radius)
	var slope := atan2(radius, height)
	for j in sectors:
		var p0 := ring[j]
		var p1 := ring[(j + 1) % sectors]
		var d0 := Vector3(p0.x - center.x, 0, p0.z - center.z).normalized()
		var d1 := Vector3(p1.x - center.x, 0, p1.z - center.z).normalized()
		var n0 := (d0 * cos(slope) + Vector3.UP * sin(slope)).normalized()
		var n1 := (d1 * cos(slope) + Vector3.UP * sin(slope)).normalized()
		_tri(st, apex, p0, p1, Vector3.UP, n0, n1, tip_c, base_c, base_c)

## Noise-displaced sphere (canopy blobs, bushes, rocks). The color callback
## receives (unit direction, displacement in 0..1) and returns the color.
static func _blob(st: SurfaceTool, noise: FastNoiseLite, center: Vector3, radius: float, squash: float, amp: float, color_cb: Callable, rings := 7, sectors := 10) -> void:
	var pts: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	var lump: Array[float] = []
	for i in rings + 1:
		var theta := PI * i / rings
		for j in sectors:
			var phi := TAU * j / sectors
			var dir := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			var n := noise.get_noise_3d(dir.x * 4.0 + center.x, dir.y * 4.0 + center.y, dir.z * 4.0 + center.z)
			var r := radius * (1.0 + amp * n)
			dirs.append(dir)
			lump.append(n * 0.5 + 0.5)
			pts.append(center + Vector3(dir.x * r, dir.y * r * squash, dir.z * r))
	for i in rings:
		for j in sectors:
			var j1 := (j + 1) % sectors
			var a := i * sectors + j
			var b := i * sectors + j1
			var c := (i + 1) * sectors + j1
			var d := (i + 1) * sectors + j
			var col_a: Color = color_cb.call(dirs[a], lump[a])
			var col_b: Color = color_cb.call(dirs[b], lump[b])
			var col_c: Color = color_cb.call(dirs[c], lump[c])
			var col_d: Color = color_cb.call(dirs[d], lump[d])
			_tri(st, pts[a], pts[b], pts[c], dirs[a], dirs[b], dirs[c], col_a, col_b, col_c)
			_tri(st, pts[a], pts[c], pts[d], dirs[a], dirs[c], dirs[d], col_a, col_c, col_d)

# -- trees -------------------------------------------------------------------

static func pine_mesh(seed_v: int) -> ArrayMesh:
	var rng := _rng(seed_v)
	var st := _begin()
	var bark0 := Color(0.26, 0.19, 0.12)
	var bark1 := Color(0.34, 0.26, 0.16)
	var bend := Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.14, 0.14))
	# Trunk in two segments with a slight lean.
	var mid := Vector3(0, 1.2, 0) + bend
	var top := Vector3(0, 2.6, 0) + bend * 1.8
	_tube(st, Vector3(0, -0.2, 0), mid, 0.24, 0.17, 8, bark0, bark1)
	_tube(st, mid, top, 0.17, 0.09, 8, bark1, bark1)
	# Canopy: stacked irregular cone layers, darker at the skirt.
	var deep := Color(0.11, 0.24, 0.11)
	var leaf := Color(0.17, 0.33, 0.14)
	var tip := Color(0.30, 0.48, 0.20)
	var hue := rng.randf_range(-0.02, 0.03)
	deep.g += hue; leaf.g += hue; tip.g += hue
	var layers := rng.randi_range(5, 7)
	var base_y := rng.randf_range(1.5, 1.9)
	var top_y := rng.randf_range(4.6, 5.6)
	for i in layers:
		var t := float(i) / float(layers - 1)
		var y := lerpf(base_y, top_y, t)
		var r := lerpf(rng.randf_range(1.35, 1.6), 0.35, pow(t, 0.85))
		var h := lerpf(1.5, 1.0, t)
		var c_base := deep.lerp(leaf, t)
		var c_tip := leaf.lerp(tip, t)
		var off := bend * lerpf(1.0, 2.0, t)
		_cone_layer(st, rng, Vector3(off.x, y, off.z), r, h, c_base, c_tip)
	return _finish(st)

static func broadleaf_mesh(seed_v: int, autumn := false) -> ArrayMesh:
	var rng := _rng(seed_v)
	var noise := _noise(seed_v, 0.9)
	var st := _begin()
	var bark0 := Color(0.28, 0.21, 0.14)
	var bark1 := Color(0.38, 0.30, 0.20)
	var bend := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
	var fork := Vector3(0, rng.randf_range(1.4, 1.8), 0) + bend
	_tube(st, Vector3(0, -0.2, 0), fork, 0.28, 0.18, 8, bark0, bark1)
	# Branches reach out to the canopy blobs.
	var deep: Color
	var bright: Color
	if autumn:
		deep = Color(0.30, 0.20, 0.06)
		bright = Color(0.55, 0.40, 0.10)
	else:
		deep = Color(0.15, 0.30, 0.11)
		bright = Color(0.40, 0.54, 0.20)
	var blob_count := rng.randi_range(4, 6)
	var centers: Array[Vector3] = []
	for i in blob_count:
		var a := TAU * i / blob_count + rng.randf_range(-0.4, 0.4)
		var spread := rng.randf_range(0.3, 1.0)
		var c := Vector3(cos(a) * spread, rng.randf_range(2.4, 3.4), sin(a) * spread) + bend * 1.5
		centers.append(c)
		_tube(st, fork, c, 0.12, 0.05, 6, bark1, bark1)
	for i in blob_count:
		var center := centers[i]
		var radius := rng.randf_range(0.8, 1.25)
		var jitter := rng.randf_range(-0.05, 0.05)
		var color_cb := func(dir: Vector3, l: float) -> Color:
			var c := deep.lerp(bright, clampf(dir.y * 0.5 + 0.35 + l * 0.5 + jitter, 0.0, 1.0))
			return c
		_blob(st, noise, center, radius, rng.randf_range(0.78, 0.95), 0.22, color_cb)
	return _finish(st)

static func bush_mesh(seed_v: int) -> ArrayMesh:
	var rng := _rng(seed_v)
	var noise := _noise(seed_v + 17, 1.1)
	var st := _begin()
	var deep := Color(0.13, 0.26, 0.11)
	var bright := Color(0.32, 0.46, 0.18)
	var color_cb := func(dir: Vector3, l: float) -> Color:
		return deep.lerp(bright, clampf(dir.y * 0.6 + 0.3 + l * 0.4, 0.0, 1.0))
	for i in rng.randi_range(2, 3):
		var c := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.25, 0.45), rng.randf_range(-0.3, 0.3))
		_blob(st, noise, c, rng.randf_range(0.4, 0.65), 0.75, 0.3, color_cb, 6, 8)
	return _finish(st)

# -- rocks -------------------------------------------------------------------

## A lumpy boulder around unit radius; scale per instance. `mossy` in 0..1
## controls how much green creeps over the upper faces.
static func rock_mesh(seed_v: int, mossy: float) -> ArrayMesh:
	var rng := _rng(seed_v)
	var noise := _noise(seed_v + 31, 1.0)
	var st := _begin()
	var base := Color(0.40, 0.39, 0.38).lerp(Color(0.46, 0.43, 0.38), rng.randf())
	var crevice := base * 0.62
	var moss := Color(0.22, 0.34, 0.15)
	var color_cb := func(dir: Vector3, l: float) -> Color:
		var c := crevice.lerp(base, clampf(l * 1.4 - 0.1, 0.0, 1.0))
		var moss_t := clampf((dir.y - 0.25) * 1.6, 0.0, 1.0) * clampf(l * 2.0 - 0.55, 0.0, 1.0) * mossy
		return c.lerp(moss, moss_t)
	_blob(st, noise, Vector3.ZERO, 1.0, rng.randf_range(0.62, 0.8), 0.34, color_cb, 8, 11)
	return _finish(st)

# -- grass and flowers -------------------------------------------------------

## A tuft of bent grass blades; normals point up so the lawn lights evenly.
## Pass a flower color with alpha > 0 to top one stem with a small bloom.
static func grass_mesh(seed_v: int, flower := Color(0, 0, 0, 0)) -> ArrayMesh:
	var rng := _rng(seed_v)
	var st := _begin()
	var root := Color(0.14, 0.26, 0.11)
	var tip := Color(0.42, 0.52, 0.22)
	var blades := rng.randi_range(5, 7)
	for i in blades:
		var a := TAU * i / blades + rng.randf_range(-0.3, 0.3)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.08, 0.22)
		var h := rng.randf_range(0.22, 0.42)
		var across := Vector3(-sin(a), 0, cos(a))
		var w0 := 0.035
		var base_p := Vector3(cos(a) * 0.05, 0, sin(a) * 0.05)
		var mid_p := base_p + Vector3(0, h * 0.6, 0) + lean * 0.5
		var tip_p := base_p + Vector3(0, h, 0) + lean * 1.3
		var c_mid := root.lerp(tip, 0.6)
		_tri(st, base_p - across * w0, base_p + across * w0, mid_p + across * w0 * 0.5, Vector3.UP, Vector3.UP, Vector3.UP, root, root, c_mid)
		_tri(st, base_p - across * w0, mid_p + across * w0 * 0.5, mid_p - across * w0 * 0.5, Vector3.UP, Vector3.UP, Vector3.UP, root, c_mid, c_mid)
		_tri(st, mid_p - across * w0 * 0.5, mid_p + across * w0 * 0.5, tip_p, Vector3.UP, Vector3.UP, Vector3.UP, c_mid, c_mid, tip)
	if flower.a > 0.0:
		var a := rng.randf() * TAU
		var stem_top := Vector3(cos(a) * 0.06, rng.randf_range(0.4, 0.55), sin(a) * 0.06)
		var stem_base := Vector3(stem_top.x, 0, stem_top.z)
		_tube(st, stem_base, stem_top, 0.012, 0.008, 4, root, tip)
		var s := 0.075
		var heart := Color(0.95, 0.85, 0.3)
		for q in 4:
			var qa := TAU * q / 4.0
			var qb := TAU * (q + 1) / 4.0
			_tri(st, stem_top + Vector3(0, 0.015, 0),
				stem_top + Vector3(cos(qa) * s, 0, sin(qa) * s),
				stem_top + Vector3(cos(qb) * s, 0, sin(qb) * s),
				Vector3.UP, Vector3.UP, Vector3.UP, heart, flower, flower)
	return _finish(st)

# -- mountains ---------------------------------------------------------------

## A ridged mountain with a lobed footprint, forest-mottled lower slopes,
## rocky shoulders, and an optional snow cap. Built at full size.
static func mountain_mesh(seed_v: int, base_radius: float, height: float, snowy: bool) -> ArrayMesh:
	var rng := _rng(seed_v)
	var lobes := _noise(seed_v + 7, 1.0)
	var ridges := _noise(seed_v + 13, 1.0)
	var mottle := _noise(seed_v + 23, 0.05)
	var rings := 15
	var sectors := 44
	var peak_off := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1)) * base_radius

	var pts: Array[Vector3] = []
	for i in rings + 1:
		var t := float(i) / rings
		for j in sectors:
			var phi := TAU * j / sectors
			var cp := cos(phi)
			var sp := sin(phi)
			var lobe := 1.0 + 0.45 * lobes.get_noise_2d(cp * 1.8, sp * 1.8)
			var ridge := 1.0 - absf(ridges.get_noise_2d(cp * 3.2, sp * 3.2))
			var r := base_radius * lobe * pow(t, 0.85) * (1.0 + ridge * 0.30 * t)
			var y := height * pow(1.0 - t, 1.5)
			# Shoulder sub-peaks and craggy slope jitter.
			y += height * 0.18 * ridge * t * (1.0 - t)
			y += height * 0.07 * lobes.get_noise_2d(cp * 4.0 + t * 5.0, sp * 4.0 - t * 5.0) * t * (1.0 - t) * 2.0
			var p := Vector3(cp * r, y, sp * r) + peak_off * (1.0 - t)
			pts.append(p)

	var idx := func(i: int, j: int) -> int:
		return clampi(i, 0, rings) * sectors + posmod(j, sectors)
	var normal_at := func(i: int, j: int) -> Vector3:
		var d_phi: Vector3 = pts[idx.call(i, j + 1)] - pts[idx.call(i, j - 1)]
		var d_t: Vector3 = pts[idx.call(mini(i + 1, rings), j)] - pts[idx.call(maxi(i - 1, 0), j)]
		var n := d_t.cross(d_phi).normalized()
		var p: Vector3 = pts[idx.call(i, j)]
		var out := (Vector3(p.x, 0, p.z).normalized() + Vector3.UP).normalized()
		if n.dot(out) < 0.0:
			n = -n
		return n

	var forest_a := Color(0.16, 0.33, 0.16)
	var forest_b := Color(0.26, 0.44, 0.20)
	var rock_c := Color(0.40, 0.38, 0.37)
	var snow_c := Color(0.91, 0.93, 0.96)
	var color_at := func(i: int, j: int) -> Color:
		var p: Vector3 = pts[idx.call(i, j)]
		var up_t := p.y / height
		var m := mottle.get_noise_3d(p.x, p.y * 2.0, p.z)
		var c := forest_a.lerp(forest_b, clampf(m * 1.4 + 0.5, 0.0, 1.0))
		c = c.lerp(rock_c, smoothstep(0.62, 0.85, up_t + m * 0.18))
		if snowy:
			c = c.lerp(snow_c, smoothstep(0.74, 0.86, up_t + m * 0.12))
		return c

	var st := _begin()
	for i in rings:
		for j in sectors:
			var a: int = idx.call(i, j)
			var b: int = idx.call(i, j + 1)
			var c: int = idx.call(i + 1, j + 1)
			var d: int = idx.call(i + 1, j)
			var na: Vector3 = normal_at.call(i, j)
			var nb: Vector3 = normal_at.call(i, j + 1)
			var nc: Vector3 = normal_at.call(i + 1, j + 1)
			var nd: Vector3 = normal_at.call(i + 1, j)
			var ca: Color = color_at.call(i, j)
			var cb: Color = color_at.call(i, j + 1)
			var cc: Color = color_at.call(i + 1, j + 1)
			var cd: Color = color_at.call(i + 1, j)
			_tri(st, pts[a], pts[b], pts[c], na, nb, nc, ca, cb, cc)
			_tri(st, pts[a], pts[c], pts[d], na, nc, nd, ca, cc, cd)
	return _finish(st)
