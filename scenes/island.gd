extends Node3D
## The wizard's pocket-dimension island: procedural terrain in a vast lake
## ringed by forested mountains, with a dock, a rowboat, a stone path, a
## standing-stone circle, and the tower whose door leads to the library.

const PlayerScript := preload("res://player/player.gd")
const LIBRARY := "res://scenes/library.tscn"

const ISLAND_RADIUS := 70.0
const TERRAIN_SIZE := 180.0
const TERRAIN_RES := 110
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
	if _crystal:
		_crystal.rotation.y += delta * 0.6
		_crystal.position.y = _crystal_base_y + sin(_t * 1.4) * 0.12

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
	# Keep the walking route from the dock to the tower gentle.
	var corridor := smoothstep(5.0, 2.0, absf(x)) * smoothstep(62.0, 56.0, z) * smoothstep(-7.0, -2.0, z)
	h = lerpf(h, smooth_h, corridor * 0.85)
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
	var c := Color(0.30, 0.47, 0.26).lerp(Color(0.43, 0.55, 0.30), blotch)
	c = c.lerp(Color(0.78, 0.72, 0.54), smoothstep(1.7, 0.7, h))
	c = c.lerp(Color(0.47, 0.45, 0.43), smoothstep(0.18, 0.38, 1.0 - normal_y))
	c = c.lerp(Color(0.38, 0.42, 0.30), smoothstep(8.0, 13.0, h) * 0.4)
	return c

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
	env.fog_light_color = Color(0.70, 0.75, 0.78)
	env.fog_density = 0.0016
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
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 9
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var count := 64
	mm.instance_count = count
	for i in count:
		var ring := 0 if i < 40 else 1
		var dist := rng.randf_range(380.0, 470.0) if ring == 0 else rng.randf_range(490.0, 580.0)
		var angle := rng.randf() * TAU
		var height := rng.randf_range(70.0, 150.0) * (1.0 if ring == 0 else 1.4)
		var radius := rng.randf_range(60.0, 115.0) * (1.0 if ring == 0 else 1.3)
		var pos := Vector3(cos(angle) * dist, height / 2.0 - 10.0, sin(angle) * dist)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(radius, height, radius))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var shade := rng.randf_range(0.75, 1.0)
		var c := Color(0.13, 0.24, 0.18).lerp(Color(0.20, 0.30, 0.34), float(ring))
		mm.set_instance_color(i, Color(c.r * shade, c.g * shade, c.b * shade))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := Forge.vc_mat(1.0)
	mmi.material_override = mat
	add_child(mmi)

# -- vegetation ------------------------------------------------------------

func _tree_mesh(kind: int) -> ArrayMesh:
	var bark := Forge.mat(Color(0.34, 0.25, 0.18), 1.0)
	bark.vertex_color_use_as_albedo = true
	bark.vertex_color_is_srgb = true
	var leaf := Forge.mat(Color(0.18, 0.34, 0.16) if kind == 0 else Color(0.28, 0.42, 0.18), 1.0)
	leaf.vertex_color_use_as_albedo = true
	leaf.vertex_color_is_srgb = true

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.22
	trunk.height = 1.8
	trunk.radial_segments = 7
	st.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)))
	var mesh := st.commit()

	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == 0:
		# Pine: stacked cones.
		var sizes := [Vector2(1.25, 1.7), Vector2(0.95, 1.5), Vector2(0.6, 1.3)]
		var ys := [2.2, 3.3, 4.3]
		for i in 3:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = sizes[i].x
			cone.height = sizes[i].y
			cone.radial_segments = 8
			st2.append_from(cone, 0, Transform3D(Basis.IDENTITY, Vector3(0, ys[i], 0)))
	else:
		# Broadleaf: a couple of squashed spheres.
		for offset in [Vector3(0, 2.5, 0), Vector3(0.5, 2.1, 0.3), Vector3(-0.45, 2.2, -0.25)]:
			var ball := SphereMesh.new()
			ball.radius = 1.0
			ball.height = 1.7
			ball.radial_segments = 9
			ball.rings = 5
			st2.append_from(ball, 0, Transform3D(Basis.IDENTITY, offset))
	st2.commit(mesh)
	mesh.surface_set_material(0, bark)
	mesh.surface_set_material(1, leaf)
	return mesh

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var placements: Array[Array] = [[], []]  # per kind: list of Transform3D
	var colliders := Node3D.new()
	add_child(colliders)
	var attempts := 0
	while attempts < 1600 and placements[0].size() + placements[1].size() < 240:
		attempts += 1
		var x := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
		var z := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
		var h := height_at(x, z)
		if h < 1.6 or h > 11.5:
			continue
		if _normal_at(x, z).y < 0.82:
			continue
		if Vector2(x, z).distance_to(TOWER_POS) < 15.0:
			continue
		if absf(x) < 5.0 and z > -8.0 and z < 60.0:
			continue  # keep the path clear
		if Vector2(x, z).distance_to(Vector2(34, 18)) < 7.0:
			continue  # keep the stone circle clear
		var kind := 0 if rng.randf() < 0.62 else 1
		var s := rng.randf_range(0.8, 1.5)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		placements[kind].append(Transform3D(basis, Vector3(x, h - 0.15, z)))
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.25 * s
		shape.height = 2.2
		cs.shape = shape
		body.add_child(cs)
		colliders.add_child(body)
		body.position = Vector3(x, h + 1.0, z)
	for kind in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _tree_mesh(kind)
		mm.instance_count = placements[kind].size()
		for i in placements[kind].size():
			mm.set_instance_transform(i, placements[kind][i])
			var v := rng.randf_range(0.82, 1.1)
			mm.set_instance_color(i, Color(v, v, v))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)

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
	while z > -3.0:
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
	_boat.add_child(Interactable.make(boat_shape, "Examine the boat", func(p: Node) -> void:
		p.show_message("The rowboat tugs gently at its mooring. Across the water, the forested shore waits beneath the mountains.\n\n(A voyage for another day.)"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0))))

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
		p.show_message("The crystal thrums with a voice that is not quite a voice:\n\n“The shelves remember every word ever written. The lake remembers everything else.”"),
		Transform3D(Basis.IDENTITY, Vector3(center.x, ch + 1.7, center.y))))

# -- player ----------------------------------------------------------------

func _spawn_player() -> void:
	var deck_y := PLATEAU_HEIGHT + TOWER_HEIGHT + 0.6
	var spawns := {
		"dock": Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 63.0)),
		"tower_door": Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(0, PLATEAU_HEIGHT + 0.3, -4.2)),
		"tower_top": Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(-3.3, deck_y, -12.0)),
	}
	var player := PlayerScript.new()
	add_child(player)
	var t: Transform3D = spawns.get(Game.spawn_point, spawns["dock"])
	player.global_transform = t
	player.home_transform = spawns["dock"]
	player.fall_reset_y = -2.2
	player.fall_message = "The lake returns you, politely, to the dock."
	if Game.spawn_point == "dock":
		player.show_message("You arrive in the wizard's pocket dimension.\n\nWASD — walk · Mouse — look · Shift — run\nSpace — jump · E — interact · Esc — release mouse", 12.0)
