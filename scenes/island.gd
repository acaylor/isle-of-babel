extends Node3D
## The wizard's pocket-dimension island: procedural terrain in a vast lake
## ringed by forested mountains, with a dock, a rowboat, a stone path, a
## standing-stone circle, and the tower whose door leads to the library.

const PlayerScript := preload("res://player/player.gd")
const LIBRARY := "res://scenes/library.tscn"
const FOREST := "res://scenes/forest.tscn"
const BOAT_SPEED := 5.5

const ISLAND_RADIUS := 70.0
const TERRAIN_SIZE := 180.0
const TERRAIN_RES := 150
const WATER_LEVEL := 0.0

const TOWER_POS := Vector2(0.0, -12.0)
const PLATEAU_HEIGHT := 14.0
const TOWER_RADIUS := 5.6
const TOWER_HEIGHT := 22.0

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _t := 0.0
var _boat: Node3D
var _boat_base_y := 0.6
var _crystal: MeshInstance3D
var _crystal_base_y := 0.0
var _spawns := {}
var _menu_pivot: Node3D
var _voyage_points: Array[Vector3] = []
var _voyage_i := 0
var _voyage_done: Callable

func _ready() -> void:
	_noise.seed = 7041
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.02
	_noise.fractal_octaves = 4
	_detail.seed = 99
	_detail.frequency = 0.11

	_build_environment()
	_build_terrain()
	_build_water()
	_build_mountains()
	_build_trees()
	_build_rocks()
	_build_bushes()
	_build_grass()
	_build_path()
	_build_tower()
	_build_dock_and_boat()
	_build_stone_circle()
	_spawn_player()

func _process(delta: float) -> void:
	_t += delta
	if _boat:
		_boat.position.y = _boat_base_y + sin(_t * 1.1) * 0.06
		_boat.rotation.z = sin(_t * 0.9) * 0.03
		_boat.rotation.x = sin(_t * 0.7) * 0.02
		_voyage_step(delta)
	if _crystal:
		_crystal.rotation.y += delta * 0.6
		_crystal.position.y = _crystal_base_y + sin(_t * 1.4) * 0.12
	if _menu_pivot:
		_menu_pivot.rotation.y += delta * 0.035

# -- terrain ---------------------------------------------------------------

func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length() / ISLAND_RADIUS
	var shape := 1.0 - pow(d, 2.2)
	var smooth_h := shape * 8.0 - 1.8
	var tower_dist := (p - TOWER_POS).length()
	smooth_h += 7.5 * exp(-tower_dist * tower_dist / 260.0)
	var h := smooth_h
	h += _noise.get_noise_2d(x, z) * 5.0 * clampf(shape + 0.3, 0.0, 1.0)
	h += _detail.get_noise_2d(x, z) * 0.6 * clampf(shape, 0.0, 1.0)
	h += _detail.get_noise_2d(x * 3.0, z * 3.0) * 0.18 * clampf(shape, 0.0, 1.0)
	# Keep the walking route from the dock to the tower gentle.
	var corridor := smoothstep(5.0, 2.0, absf(x)) * smoothstep(62.0, 56.0, z) * smoothstep(-7.0, -2.0, z)
	h = lerpf(h, smooth_h, corridor * 0.85)
	# A steady ramp up the plateau's south side, so the path climbs to the
	# tower door instead of hitting a steep lip just before it.
	var ramp_h := lerpf(7.3, PLATEAU_HEIGHT, smoothstep(10.0, -5.0, z))
	var ramp_m := smoothstep(6.5, 3.0, absf(x)) * smoothstep(13.0, 10.0, z)
	h = lerpf(h, ramp_h, ramp_m)
	# Flatten a plateau for the tower to stand on.
	h = lerpf(h, PLATEAU_HEIGHT, smoothstep(12.0, 7.0, tower_dist))
	return h

func _normal_at(x: float, z: float) -> Vector3:
	var e := 0.9
	return Vector3(
		height_at(x - e, z) - height_at(x + e, z),
		2.0 * e,
		height_at(x, z - e) - height_at(x, z + e)
	).normalized()

func _terrain_color(x: float, z: float, h: float, normal_y: float) -> Color:
	var blotch := (_detail.get_noise_2d(x * 2.0, z * 2.0) + 1.0) * 0.5
	var c := Color(0.27, 0.45, 0.23).lerp(Color(0.45, 0.56, 0.28), blotch)
	var dirt := _detail.get_noise_2d(x * 0.45 + 510.0, z * 0.45 - 310.0)
	c = c.lerp(Color(0.42, 0.33, 0.22), smoothstep(0.30, 0.62, dirt) * 0.55)
	c = c.lerp(Color(0.78, 0.72, 0.54), smoothstep(1.7, 0.7, h))
	c = c.lerp(Color(0.55, 0.50, 0.40), smoothstep(0.55, 0.2, h))
	c = c.lerp(Color(0.47, 0.45, 0.43), smoothstep(0.18, 0.38, 1.0 - normal_y))
	c = c.lerp(Color(0.38, 0.42, 0.30), smoothstep(8.0, 13.0, h) * 0.4)
	return c

## Shared exclusion zones so scattered nature never blocks the path, the
## tower plateau, the stone circle, or the dock approach.
func _clear_of_landmarks(x: float, z: float) -> bool:
	if Vector2(x, z).distance_to(TOWER_POS) < 13.5:
		return false
	if absf(x) < 5.0 and z > -8.0 and z < 60.0:
		return false
	if Vector2(x, z).distance_to(Vector2(34, 18)) < 6.5:
		return false
	return true

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := TERRAIN_SIZE / TERRAIN_RES
	var half := TERRAIN_SIZE / 2.0
	for iz in TERRAIN_RES + 1:
		for ix in TERRAIN_RES + 1:
			var x := ix * step - half
			var z := iz * step - half
			var h := height_at(x, z)
			var n := _normal_at(x, z)
			st.set_color(_terrain_color(x, z, h, n.y))
			st.set_normal(n)
			st.add_vertex(Vector3(x, h, z))
	var w := TERRAIN_RES + 1
	for iz in TERRAIN_RES:
		for ix in TERRAIN_RES:
			var a := iz * w + ix
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + w)
			st.add_index(a + 1)
			st.add_index(a + w + 1)
			st.add_index(a + w)
	var mesh := st.commit()
	var mat := Forge.vc_mat(0.95)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1300, 1300)
	plane.subdivide_width = 140
	plane.subdivide_depth = 140
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	Forge.mesh(self, plane, mat, Vector3(0, WATER_LEVEL, 0))
	# Lakebed, so nothing transparent reveals the void below.
	Forge.cyl(self, 660, 660, 0.2, Forge.mat(Color(0.02, 0.09, 0.11)), Vector3(0, -3.0, 0), Vector3.ZERO, 48)

func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.23, 0.41, 0.62)
	sky_mat.sky_horizon_color = Color(0.74, 0.76, 0.70)
	sky_mat.ground_bottom_color = Color(0.12, 0.16, 0.18)
	sky_mat.ground_horizon_color = Color(0.66, 0.69, 0.64)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.78, 0.83)
	env.fog_density = 0.0004
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	sun.rotation_degrees = Vector3(-38, -125, 0)

func _build_mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Near ring: unique ridged mountains with forested slopes and snow caps.
	var count := 11
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.12, 0.12)
		var dist := rng.randf_range(385.0, 465.0)
		var height := rng.randf_range(90.0, 185.0)
		var radius := rng.randf_range(75.0, 125.0)
		var mi := MeshInstance3D.new()
		mi.mesh = Flora.mountain_mesh(9000 + i, radius, height, height > 150.0)
		add_child(mi)
		mi.position = Vector3(cos(angle) * dist, -8.0, sin(angle) * dist)
		mi.rotation.y = rng.randf() * TAU
	# Far ring: hazy simple cones for a second layer of depth.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 9
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	var far_count := 30
	mm.instance_count = far_count
	for i in far_count:
		var dist := rng.randf_range(530.0, 660.0)
		var angle := rng.randf() * TAU
		var height := rng.randf_range(110.0, 230.0)
		var radius := rng.randf_range(90.0, 160.0)
		var pos := Vector3(cos(angle) * dist, height / 2.0 - 10.0, sin(angle) * dist)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(radius, height, radius))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var shade := rng.randf_range(0.85, 1.05)
		var c := Color(0.24, 0.32, 0.36)
		mm.set_instance_color(i, Color(c.r * shade, c.g * shade, c.b * shade))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Forge.vc_mat(1.0)
	add_child(mmi)

# -- vegetation ------------------------------------------------------------

var _tree_spots: Array[Vector3] = []

func _multimesh_of(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var variants: Array[ArrayMesh] = [
		Flora.pine_mesh(11), Flora.pine_mesh(22), Flora.pine_mesh(33),
		Flora.broadleaf_mesh(44), Flora.broadleaf_mesh(55),
		Flora.broadleaf_mesh(66, true),  # an autumn-gold stray
	]
	var placements: Array = [[], [], [], [], [], []]
	var colliders := Node3D.new()
	add_child(colliders)
	var total := 0
	var attempts := 0
	while attempts < 2200 and total < 250:
		attempts += 1
		var x := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
		var z := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
		var h := height_at(x, z)
		if h < 1.6 or h > 11.5:
			continue
		if _normal_at(x, z).y < 0.82:
			continue
		if not _clear_of_landmarks(x, z):
			continue
		var v: int
		if rng.randf() < 0.6:
			v = rng.randi_range(0, 2)
		elif rng.randf() < 0.12:
			v = 5
		else:
			v = rng.randi_range(3, 4)
		var s := rng.randf_range(0.8, 1.5)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
		placements[v].append(Transform3D(basis, Vector3(x, h - 0.1, z)))
		_tree_spots.append(Vector3(x, h, z))
		total += 1
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.25 * s
		shape.height = 2.2
		cs.shape = shape
		body.add_child(cs)
		colliders.add_child(body)
		body.position = Vector3(x, h + 1.0, z)
	for v in variants.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(placements[v])
		_multimesh_of(variants[v], transforms)

func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var variants: Array[ArrayMesh] = [
		Flora.rock_mesh(1, 0.7), Flora.rock_mesh(2, 0.4),
		Flora.rock_mesh(3, 0.15), Flora.rock_mesh(4, 0.55),
	]
	var groups: Array = [[], [], [], []]
	var colliders := Node3D.new()
	add_child(colliders)
	# Large mossy boulders the player bumps into.
	var placed := 0
	var attempts := 0
	while attempts < 700 and placed < 26:
		attempts += 1
		var x := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
		var z := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
		var h := height_at(x, z)
		if h < 0.6 or h > 12.0 or not _clear_of_landmarks(x, z):
			continue
		var s := rng.randf_range(0.9, 2.3)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))).scaled(Vector3(s, s, s))
		var pos := Vector3(x, h + s * 0.2, z)
		groups[rng.randi_range(0, 3)].append(Transform3D(basis, pos))
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = s * 0.72
		cs.shape = shape
		body.add_child(cs)
		colliders.add_child(body)
		body.position = pos
		placed += 1
	# Mid-size rocks and shoreline pebbles, visual only.
	for spec in [[70, 0.35, 0.8, 0.8, 11.5], [170, 0.1, 0.32, 0.12, 1.5]]:
		placed = 0
		attempts = 0
		while attempts < spec[0] * 4 and placed < spec[0]:
			attempts += 1
			var x := rng.randf_range(-ISLAND_RADIUS - 4.0, ISLAND_RADIUS + 4.0)
			var z := rng.randf_range(-ISLAND_RADIUS - 4.0, ISLAND_RADIUS + 4.0)
			var h := height_at(x, z)
			if h < spec[3] or h > spec[4] or not _clear_of_landmarks(x, z):
				continue
			var s: float = rng.randf_range(spec[1], spec[2])
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3(s, s, s))
			groups[rng.randi_range(0, 3)].append(Transform3D(basis, Vector3(x, h + s * 0.2, z)))
			placed += 1
	for v in variants.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[v])
		_multimesh_of(variants[v], transforms)

func _build_bushes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6060
	var variants: Array[ArrayMesh] = [Flora.bush_mesh(7), Flora.bush_mesh(8)]
	var groups: Array = [[], []]
	if _tree_spots.is_empty():
		return
	var placed := 0
	var attempts := 0
	while attempts < 320 and placed < 80:
		attempts += 1
		var spot := _tree_spots[rng.randi() % _tree_spots.size()]
		var a := rng.randf() * TAU
		var x := spot.x + cos(a) * rng.randf_range(1.6, 3.6)
		var z := spot.z + sin(a) * rng.randf_range(1.6, 3.6)
		var h := height_at(x, z)
		if h < 1.4 or h > 11.5 or not _clear_of_landmarks(x, z):
			continue
		var s := rng.randf_range(0.8, 1.7)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.1), s))
		groups[rng.randi_range(0, 1)].append(Transform3D(basis, Vector3(x, h - 0.05, z)))
		placed += 1
	for v in variants.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[v])
		_multimesh_of(variants[v], transforms)

func _build_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var variants: Array[ArrayMesh] = [
		Flora.grass_mesh(1), Flora.grass_mesh(2),
		Flora.grass_mesh(3, Color(0.92, 0.92, 0.96)),  # white blooms
		Flora.grass_mesh(4, Color(0.62, 0.40, 0.85)),  # violet
		Flora.grass_mesh(5, Color(0.95, 0.78, 0.25)),  # gold
	]
	var counts := [1500, 1300, 90, 90, 80]
	for v in variants.size():
		var transforms: Array[Transform3D] = []
		var attempts := 0
		while attempts < counts[v] * 3 and transforms.size() < counts[v]:
			attempts += 1
			var x := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
			var z := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
			var h := height_at(x, z)
			if h < 1.7 or h > 10.5 or not _clear_of_landmarks(x, z):
				continue
			var s := rng.randf_range(0.8, 1.5)
			var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s, s))
			transforms.append(Transform3D(basis, Vector3(x, h - 0.02, z)))
		_multimesh_of(variants[v], transforms)

func _build_path() -> void:
	var stone := CylinderMesh.new()
	stone.top_radius = 0.85
	stone.bottom_radius = 0.95
	stone.height = 0.18
	stone.radial_segments = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = stone
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var points: Array[Vector3] = []
	var z := 56.0
	while z > -4.6:
		var x := sin(z * 0.18) * 1.6 + rng.randf_range(-0.4, 0.4)
		points.append(Vector3(x, height_at(x, z) + 0.04, z))
		z -= 2.6
	mm.instance_count = points.size()
	for i in points.size():
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(rng.randf_range(0.8, 1.1), 1.0, rng.randf_range(0.8, 1.1)))
		mm.set_instance_transform(i, Transform3D(basis, points[i]))
		var v := rng.randf_range(0.85, 1.05)
		mm.set_instance_color(i, Color(0.52 * v, 0.51 * v, 0.49 * v))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Forge.vc_mat(1.0)
	add_child(mmi)

# -- structures ------------------------------------------------------------

func _build_tower() -> void:
	var base := Vector3(TOWER_POS.x, PLATEAU_HEIGHT, TOWER_POS.y)
	var tower := Node3D.new()
	add_child(tower)
	tower.position = base

	var stone := Forge.mat(Color(0.52, 0.50, 0.52), 0.9)
	var stone_dark := Forge.mat(Color(0.40, 0.38, 0.42), 0.9)
	var roof_mat := Forge.mat(Color(0.30, 0.18, 0.42), 0.7)
	var wood := Forge.mat(Color(0.32, 0.22, 0.13), 0.9)
	var glow := Forge.mat(Color(1.0, 0.85, 0.5), 0.4, Color(1.0, 0.8, 0.4), 2.2)

	# Body: slightly tapered cylinder with trim rings.
	Forge.cyl(tower, 5.0, TOWER_RADIUS, TOWER_HEIGHT, stone, Vector3(0, TOWER_HEIGHT / 2.0, 0), Vector3.ZERO, 28)
	for y in [6.0, 12.0, 18.0]:
		var r: float = lerpf(TOWER_RADIUS, 5.0, y / TOWER_HEIGHT) + 0.25
		Forge.cyl(tower, r, r, 0.45, stone_dark, Vector3(0, y, 0), Vector3.ZERO, 28)
	Forge.collider_cyl(tower, TOWER_RADIUS, TOWER_HEIGHT, Vector3(0, TOWER_HEIGHT / 2.0, 0))

	# Windows, glowing warm from the library inside.
	for i in 4:
		var wy := 6.0 + i * 4.0
		var angle := PI * 0.25 + i * PI * 0.55
		var r := lerpf(TOWER_RADIUS, 5.0, wy / TOWER_HEIGHT)
		var pos := Vector3(cos(angle) * (r - 0.05), wy, sin(angle) * (r - 0.05))
		Forge.box(tower, Vector3(0.55, 1.3, 0.25), glow, pos, Vector3(0, -angle + PI / 2.0, 0))

	# Door on the south face, with stone frame and steps.
	var door_z := TOWER_RADIUS - 0.1
	Forge.box(tower, Vector3(0.5, 3.2, 0.7), stone_dark, Vector3(-1.25, 1.6, door_z))
	Forge.box(tower, Vector3(0.5, 3.2, 0.7), stone_dark, Vector3(1.25, 1.6, door_z))
	Forge.box(tower, Vector3(3.0, 0.55, 0.7), stone_dark, Vector3(0, 3.4, door_z))
	Forge.box(tower, Vector3(2.0, 2.9, 0.22), wood, Vector3(0, 1.45, door_z + 0.1))
	Forge.sphere(tower, 0.09, Forge.mat(Color(0.8, 0.65, 0.2), 0.3), Vector3(0.6, 1.4, door_z + 0.25))
	Forge.box(tower, Vector3(3.2, 0.3, 1.6), stone_dark, Vector3(0, 0.05, door_z + 1.0))
	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(2.2, 3.0, 0.5)
	tower.add_child(Interactable.make(door_shape, "Enter the tower", func(_p: Node) -> void:
		Game.travel(LIBRARY, "entrance"),
		Transform3D(Basis.IDENTITY, Vector3(0, 1.5, door_z + 0.2))))

	# Summit balcony with railing, central spire, and the return portal.
	var deck_y := TOWER_HEIGHT + 0.25
	Forge.cyl(tower, 7.0, 6.4, 0.5, stone_dark, Vector3(0, deck_y, 0), Vector3.ZERO, 28)
	Forge.collider_cyl(tower, 7.0, 0.5, Vector3(0, deck_y, 0))
	for i in 20:
		var a := TAU * i / 20.0
		Forge.cyl(tower, 0.07, 0.07, 1.1, stone, Vector3(cos(a) * 6.7, deck_y + 0.8, sin(a) * 6.7), Vector3.ZERO, 6)
	Forge.torus(tower, 6.58, 6.82, stone, Vector3(0, deck_y + 1.4, 0))
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		Forge.collider_box(tower, Vector3(3.6, 1.5, 0.25), Vector3(cos(a) * 6.7, deck_y + 1.0, sin(a) * 6.7), Vector3(0, -a + PI / 2.0, 0))

	Forge.cyl(tower, 2.1, 2.4, 4.5, stone, Vector3(0, deck_y + 2.5, 0), Vector3.ZERO, 20)
	Forge.collider_cyl(tower, 2.4, 4.5, Vector3(0, deck_y + 2.5, 0))
	Forge.cyl(tower, 0.0, 3.3, 3.8, roof_mat, Vector3(0, deck_y + 6.6, 0), Vector3.ZERO, 20)
	Forge.cyl(tower, 0.04, 0.04, 2.2, stone_dark, Vector3(0, deck_y + 9.4, 0), Vector3.ZERO, 6)
	Forge.sphere(tower, 0.22, Forge.mat(Color(0.9, 0.75, 0.3), 0.2, Color(1.0, 0.8, 0.3), 1.5), Vector3(0, deck_y + 10.5, 0))
	Forge.box(tower, Vector3(0.55, 1.0, 0.2), glow, Vector3(0, deck_y + 3.0, 2.3))

	var portal := Forge.portal(tower, Vector3(-4.2, deck_y + 0.25, 0), "Step through the portal", func(_p: Node) -> void:
		Game.travel(LIBRARY, "portal"))
	portal.rotation.y = PI / 2.0

func _build_dock_and_boat() -> void:
	var wood := Forge.mat(Color(0.42, 0.30, 0.18), 0.95)
	var wood_dark := Forge.mat(Color(0.30, 0.21, 0.13), 0.95)
	var dock := Node3D.new()
	add_child(dock)
	# Planks from the beach out over the water.
	for i in 9:
		var z := 57.0 + i * 1.12
		Forge.box(dock, Vector3(2.3, 0.12, 1.04), wood, Vector3(0, 1.12, z))
	for side in [-1.0, 1.0]:
		for i in 4:
			var z := 58.0 + i * 2.6
			Forge.cyl(dock, 0.11, 0.13, 3.6, wood_dark, Vector3(side * 1.05, -0.4, z), Vector3.ZERO, 8)
	Forge.collider_box(dock, Vector3(2.4, 0.25, 10.4), Vector3(0, 1.1, 61.8))

	_boat = Node3D.new()
	add_child(_boat)
	_boat.position = Vector3(2.7, _boat_base_y, 64.0)
	Forge.box(_boat, Vector3(1.1, 0.16, 2.9), wood_dark, Vector3(0, 0.0, 0))
	Forge.box(_boat, Vector3(0.13, 0.5, 3.0), wood, Vector3(-0.58, 0.28, 0), Vector3(0, 0, 0.18))
	Forge.box(_boat, Vector3(0.13, 0.5, 3.0), wood, Vector3(0.58, 0.28, 0), Vector3(0, 0, -0.18))
	Forge.box(_boat, Vector3(1.25, 0.5, 0.13), wood, Vector3(0, 0.28, -1.48), Vector3(-0.2, 0, 0))
	Forge.box(_boat, Vector3(1.25, 0.5, 0.13), wood, Vector3(0, 0.28, 1.48), Vector3(0.2, 0, 0))
	Forge.box(_boat, Vector3(1.05, 0.07, 0.42), wood, Vector3(0, 0.34, 0.2))
	Forge.cyl(_boat, 0.035, 0.035, 2.1, wood_dark, Vector3(-0.2, 0.5, -0.5), Vector3(0.3, 0.4, 1.2), 6)
	Forge.cyl(_boat, 0.035, 0.035, 2.1, wood_dark, Vector3(0.25, 0.5, -0.3), Vector3(0.3, -0.5, -1.2), 6)
	var boat_shape := BoxShape3D.new()
	boat_shape.size = Vector3(1.5, 1.1, 3.2)
	_boat.add_child(Interactable.make(boat_shape, "Set out for the far shore", func(p: Node) -> void:
		_start_voyage(p as Player),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0))))

# -- the voyage ----------------------------------------------------------------
# The enchanted rowboat: sit in it and it rows itself. The outbound leg
# glides away from the dock and fades into the forest scene, whose own
# arrival leg finishes the crossing; the reverse trip mirrors it.

func _boat_seat() -> Node3D:
	var seat: Node3D = _boat.get_node_or_null("Seat")
	if seat == null:
		seat = Node3D.new()
		seat.name = "Seat"
		_boat.add_child(seat)
		seat.position = Vector3(0, 0.45, 0.2)
	return seat

func _start_voyage(player: Player) -> void:
	if not _voyage_points.is_empty():
		return
	player.sit(_boat_seat())
	player.show_message("The mooring knot unties itself. Across the water, the old forest waits beneath the mountains.", 6.0)
	_voyage_points = [Vector3(6.0, 0, 80.0), Vector3(2.0, 0, 106.0), Vector3(-2.0, 0, 132.0)]
	_voyage_i = 0
	_voyage_done = func() -> void:
		Game.travel(FOREST, "voyage")

func _arrive_by_boat(player: Player) -> void:
	_boat.position = Vector3(-2.0, _boat_base_y, 132.0)
	player.sit(_boat_seat())
	_voyage_points = [Vector3(4.5, 0, 92.0), Vector3(2.7, 0, 64.0)]
	_voyage_i = 0
	_voyage_done = func() -> void:
		player.stand()
		player.global_transform = _spawns["dock"]
		player.velocity = Vector3.ZERO
		player.show_message("Home water. The dock creaks its familiar greeting.", 6.0)

func _voyage_step(delta: float) -> void:
	if _voyage_points.is_empty():
		return
	var target := _voyage_points[_voyage_i]
	var pos := _boat.position
	var to := Vector3(target.x - pos.x, 0, target.z - pos.z)
	var dist := to.length()
	if dist < 1.0:
		_voyage_i += 1
		if _voyage_i >= _voyage_points.size():
			_voyage_points = []
			_voyage_done.call()
		return
	var dir := to / dist
	_boat.position.x += dir.x * BOAT_SPEED * delta
	_boat.position.z += dir.z * BOAT_SPEED * delta
	_boat.rotation.y = lerp_angle(_boat.rotation.y, atan2(dir.x, dir.z), delta * 1.6)

func _build_stone_circle() -> void:
	var center := Vector2(34.0, 18.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var stone_mat := Forge.mat(Color(0.45, 0.44, 0.47), 0.95)
	var root := Node3D.new()
	add_child(root)
	for i in 7:
		var a := TAU * i / 7.0
		var x := center.x + cos(a) * 3.6
		var z := center.y + sin(a) * 3.6
		var h := rng.randf_range(1.3, 2.3)
		Forge.box(root, Vector3(0.75, h, 0.55), stone_mat,
			Vector3(x, height_at(x, z) + h / 2.0 - 0.15, z),
			Vector3(rng.randf_range(-0.07, 0.07), rng.randf() * TAU, rng.randf_range(-0.07, 0.07)))
	var ch := height_at(center.x, center.y)
	_crystal_base_y = ch + 1.7
	var crystal_mat := Forge.mat(Color(0.55, 0.35, 0.9), 0.2, Color(0.6, 0.35, 1.0), 2.6)
	_crystal = Forge.box(root, Vector3(0.5, 0.8, 0.5), crystal_mat, Vector3(center.x, _crystal_base_y, center.y), Vector3(PI / 4.0, 0, PI / 4.0))
	Forge.omni(root, Color(0.6, 0.35, 1.0), 1.4, 9.0, Vector3(center.x, ch + 2.2, center.y))
	var shape := CylinderShape3D.new()
	shape.radius = 1.2
	shape.height = 3.0
	root.add_child(Interactable.make(shape, "Touch the crystal", func(p: Node) -> void:
		var pl := p as Player
		Game.blink(func() -> void:
			pl.global_transform = _spawns["tower_top"]
			pl.velocity = Vector3.ZERO
			pl.show_message("The crystal hums — the world folds, and the summit unfolds beneath your feet.", 7.0)),
		Transform3D(Basis.IDENTITY, Vector3(center.x, ch + 1.7, center.y))))

# -- player ----------------------------------------------------------------

func _spawn_player() -> void:
	var deck_y := PLATEAU_HEIGHT + TOWER_HEIGHT + 0.6
	_spawns = {
		"dock": Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 63.0)),
		"tower_door": Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(0, PLATEAU_HEIGHT + 0.3, -4.2)),
		"tower_top": Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(-3.3, deck_y, -12.0)),
	}
	if Game.spawn_point == "menu":
		_build_main_menu()
		return
	var player := PlayerScript.new()
	add_child(player)
	player.home_transform = _spawns["dock"]
	player.fall_reset_y = -2.2
	player.fall_message = "The lake returns you, politely, to the dock."
	if Game.spawn_point == "voyage":
		_arrive_by_boat(player)
		return
	var t: Transform3D = _spawns.get(Game.spawn_point, _spawns["dock"])
	player.global_transform = t
	if Game.spawn_point == "dock":
		player.show_message("You arrive in the wizard's pocket dimension.\n\nWASD — walk · Mouse — look · Shift — run\nSpace — jump · E — interact · Esc — pause", 12.0)

## The title screen: the live island under a slowly orbiting camera, with
## the menu floating over it.
func _build_main_menu() -> void:
	set_meta("main_menu", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_menu_pivot = Node3D.new()
	add_child(_menu_pivot)
	_menu_pivot.position = Vector3(TOWER_POS.x, 0, TOWER_POS.y)
	var cam := Camera3D.new()
	cam.far = 1600.0
	_menu_pivot.add_child(cam)
	cam.position = Vector3(48, 34, 78)
	cam.look_at(Vector3(TOWER_POS.x, 24.0, TOWER_POS.y))
	cam.current = true

	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "ISLE  OF  BABEL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color(0.93, 0.87, 0.68))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	layer.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position.y += 90

	var subtitle := Label.new()
	subtitle.text = "a pocket dimension"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 0.85))
	subtitle.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03, 0.8))
	subtitle.add_theme_constant_override("outline_size", 6)
	layer.add_child(subtitle)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	subtitle.position.y += 178

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	layer.add_child(buttons)
	var begin := Game.menu_button("Begin")
	begin.pressed.connect(func() -> void:
		Game.travel("res://scenes/island.tscn", "dock"))
	buttons.add_child(begin)
	var quit := Game.menu_button("Quit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.position.y -= 220
	begin.grab_focus()

	var version := Label.new()
	version.text = "v%s" % Game.VERSION
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	version.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	version.add_theme_constant_override("outline_size", 4)
	layer.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position += Vector2(-14, -10)
