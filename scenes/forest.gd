extends Node3D
## The far shore: an old-growth forest noticeably larger than the island,
## reached by the enchanted rowboat. A winding trail leads from the jetty,
## over a stream, and deep between the trees to the ruin of the First Tower —
## the wizard's failed first library, and the reason the island exists.

const PlayerScript := preload("res://player/player.gd")
const ISLAND := "res://scenes/island.tscn"

const WATER_LEVEL := 0.0
const X_MIN := -165.0
const X_MAX := 165.0
const Z_MIN := -165.0
const Z_MAX := 95.0
const RES_X := 165
const RES_Z := 130

const RUIN_POS := Vector2(-58.0, -84.0)
const RUIN_HEIGHT := 10.0
const BRIDGE_Z := 56.0
const BOAT_SPEED := 5.5

## Secrets. Four kept books hide in the open woods; the fifth waits at the
## spring. The hollow is the stranger's camp.
const KEPT_POSITIONS := [
	Vector2(-105.0, -40.0), Vector2(78.0, 20.0),
	Vector2(-20.0, -110.0), Vector2(30.0, -70.0),
]
const HOLLOW_POS := Vector2(-88.0, -20.0)
const POOL_Z := -118.0

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _t := 0.0
var _player: Player
var _boat: Node3D
var _boat_base_y := 0.6
var _voyage_points: Array[Vector3] = []
var _voyage_i := 0
var _voyage_done: Callable
var _trail: Array[Vector2] = []
var _spawns := {}
var _pool_pos := Vector2.ZERO
var _kept_found := {}
var _ring_body: Interactable
var _ring_root: Node3D
var _bridge_yaw := 0.0
var _bridge_base := 0.0
var _abutment_a := Vector2.ZERO
var _abutment_b := Vector2.ZERO
var _abutment_h := -1e9  # sentinel: abutments off until computed

func _ready() -> void:
	_noise.seed = 8083
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.016
	_noise.fractal_octaves = 4
	_detail.seed = 141
	_detail.frequency = 0.10
	_pool_pos = Vector2(_stream_x(POOL_Z), POOL_Z)
	_make_trail()
	_plan_bridge()

	_build_environment()
	_build_terrain()
	_build_water()
	_build_stream()
	_build_glade()
	_build_mountains()
	_build_island_silhouette()
	_build_jetty_and_boat()
	_build_trail()
	_build_bridge()
	_build_ruin()
	_build_kept_books()
	_build_hollow()
	_build_trees()
	_build_ferns()
	_build_logs()
	_build_rocks()
	_build_bushes_and_grass()
	_spawn_player()

func _process(delta: float) -> void:
	_t += delta
	if _boat:
		_boat.position.y = _boat_base_y + sin(_t * 1.1) * 0.06
		_boat.rotation.z = sin(_t * 0.9) * 0.03
		_boat.rotation.x = sin(_t * 0.7) * 0.02
		_voyage_step(delta)

# -- terrain -----------------------------------------------------------------

func _stream_x(z: float) -> float:
	return 36.0 - z * 0.16 + sin(z * 0.05) * 7.0

## Terrain before the stream carves its channel; the stream's own water
## surface is placed relative to this so it always sits below the banks.
func _base_height(x: float, z: float) -> float:
	var coast := smoothstep(88.0, 50.0, z)
	var h := -3.2 + coast * 7.0
	h += clampf((20.0 - z) * 0.055, 0.0, 11.0)
	# Boundary cliffs: the cove is walled in rock too steep to climb
	# (~70°, past the player's 55° limit), and the walls run out into the
	# lake as headlands, so the world ends in stone and water, not air.
	# The wall line meanders and the crest varies, so from above it reads
	# as the foot of a mountain range rather than a built rampart.
	var wob_x := _detail.get_noise_2d(z * 0.22, 314.0) * 8.0
	var wob_z := _detail.get_noise_2d(x * 0.22, -314.0) * 8.0
	var wall := clampf(
		smoothstep(124.0, 141.0, absf(x) + wob_x) + smoothstep(-124.0, -141.0, z + wob_z),
		0.0, 1.35)
	h += wall * 46.0 * (1.0 + 0.22 * _detail.get_noise_2d(x * 0.1, z * 0.1))
	# Past the crest the rock keeps climbing toward the mountains proper.
	h += smoothstep(142.0, 165.0, maxf(absf(x), -z)) * 30.0
	h += _noise.get_noise_2d(x, z) * 4.5 * coast
	h += _detail.get_noise_2d(x, z) * 0.5 * coast
	h += _detail.get_noise_2d(x * 3.0, z * 3.0) * 0.16 * coast
	# A level clearing for the ruin to stand in.
	h = lerpf(h, RUIN_HEIGHT, smoothstep(22.0, 13.0, Vector2(x, z).distance_to(RUIN_POS)))
	# Earthen abutments rise to meet the footbridge ends, so the deck sits
	# flush with the banks and the trail walks straight onto it.
	if _abutment_h > -1e8:
		var da := Vector2(x, z).distance_to(_abutment_a)
		var db := Vector2(x, z).distance_to(_abutment_b)
		h = lerpf(h, _abutment_h, smoothstep(4.5, 1.6, minf(da, db)))
	return h

func height_at(x: float, z: float) -> float:
	var h := _base_height(x, z)
	if z < 86.0:
		var ds := absf(x - _stream_x(z))
		# The channel begins at the spring; above it the cliff is unbroken.
		h -= 2.2 * smoothstep(3.4, 0.9, ds) * smoothstep(POOL_Z - 5.0, POOL_Z + 5.0, z)
	# The spring pool, carved into the cliff's foot.
	h -= 1.7 * smoothstep(5.5, 2.0, Vector2(x, z).distance_to(_pool_pos))
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
	# Forest floor: darker and loamier than the island's open turf.
	var c := Color(0.20, 0.33, 0.17).lerp(Color(0.33, 0.42, 0.21), blotch)
	var loam := _detail.get_noise_2d(x * 0.4 - 210.0, z * 0.4 + 470.0)
	c = c.lerp(Color(0.33, 0.26, 0.18), smoothstep(0.2, 0.6, loam) * 0.6)
	c = c.lerp(Color(0.74, 0.68, 0.52), smoothstep(1.5, 0.5, h))
	c = c.lerp(Color(0.42, 0.38, 0.30), smoothstep(0.5, 0.1, h))
	c = c.lerp(Color(0.44, 0.42, 0.40), smoothstep(0.2, 0.4, 1.0 - normal_y))
	# The worn trail reads as packed dirt.
	c = c.lerp(Color(0.46, 0.38, 0.26), smoothstep(3.0, 1.1, _trail_dist(x, z)) * 0.75)
	# Mossy dimness deep inland.
	c = c.lerp(Color(0.24, 0.34, 0.20), smoothstep(20.0, -60.0, z) * 0.35)
	# The boundary walls are bare rock above the treeline.
	c = c.lerp(Color(0.46, 0.44, 0.42), smoothstep(22.0, 36.0, h))
	return c

func _make_trail() -> void:
	_trail = [
		Vector2(0.0, 78.0), Vector2(6.0, 68.0), Vector2(16.0, 61.0),
		Vector2(_stream_x(BRIDGE_Z), BRIDGE_Z), Vector2(24.0, 44.0),
		Vector2(10.0, 34.0), Vector2(-6.0, 26.0), Vector2(-16.0, 12.0),
		Vector2(-24.0, -6.0), Vector2(-30.0, -24.0), Vector2(-40.0, -44.0),
		Vector2(-50.0, -64.0), RUIN_POS,
	]

func _trail_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 1e9
	for i in _trail.size() - 1:
		var a := _trail[i]
		var seg := _trail[i + 1] - a
		var t := clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_squared_to(a + seg * t))
	return sqrt(best)

## Shared exclusion for scattered nature: the trail, the ruin clearing, the
## stream bed, the jetty approach, the secrets, and a bare scree apron
## along the boundary cliffs all stay open.
func _clear_of_landmarks(x: float, z: float) -> bool:
	if absf(x) > 118.0 or z < -112.0:
		return false  # the treeline breaks before the rock walls
	if _trail_dist(x, z) < 4.0:
		return false
	if Vector2(x, z).distance_to(RUIN_POS) < 16.0:
		return false
	if absf(x - _stream_x(z)) < 4.0:
		return false
	if absf(x) < 7.0 and z > 66.0:
		return false
	var p := Vector2(x, z)
	if p.distance_to(_pool_pos) < 11.0 or p.distance_to(HOLLOW_POS) < 7.5:
		return false
	for kp: Vector2 in KEPT_POSITIONS:
		if p.distance_to(kp) < 4.0:
			return false
	return true

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step_x := (X_MAX - X_MIN) / RES_X
	var step_z := (Z_MAX - Z_MIN) / RES_Z
	for iz in RES_Z + 1:
		for ix in RES_X + 1:
			var x := X_MIN + ix * step_x
			var z := Z_MIN + iz * step_z
			var h := height_at(x, z)
			var n := _normal_at(x, z)
			st.set_color(_terrain_color(x, z, h, n.y))
			st.set_normal(n)
			st.add_vertex(Vector3(x, h, z))
	var w := RES_X + 1
	for iz in RES_Z:
		for ix in RES_X:
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
	plane.size = Vector2(1600, 1600)
	plane.subdivide_width = 140
	plane.subdivide_depth = 140
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	Forge.mesh(self, plane, mat, Vector3(0, WATER_LEVEL, 300.0))
	Forge.cyl(self, 820, 820, 0.2, Forge.mat(Color(0.02, 0.09, 0.11)), Vector3(0, -3.0, 300.0), Vector3.ZERO, 48)

## The stream: a still ribbon of water lying in the channel the terrain
## carves, following the same centerline downhill to the lake.
func _build_stream() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := 2.0
	var z := POOL_Z + 2.0
	var prev_l: Vector3
	var prev_r: Vector3
	var first := true
	while z < 86.0:
		var cx := _stream_x(z)
		var y := _base_height(cx, z) - 1.5
		y = maxf(y, WATER_LEVEL - 0.5)
		var wide := half_w * (1.0 + smoothstep(60.0, 84.0, z) * 1.4)
		var l := Vector3(cx - wide, y, z)
		var r := Vector3(cx + wide, y, z)
		if not first:
			st.set_normal(Vector3.UP); st.add_vertex(prev_l)
			st.set_normal(Vector3.UP); st.add_vertex(prev_r)
			st.set_normal(Vector3.UP); st.add_vertex(r)
			st.set_normal(Vector3.UP); st.add_vertex(prev_l)
			st.set_normal(Vector3.UP); st.add_vertex(r)
			st.set_normal(Vector3.UP); st.add_vertex(l)
		prev_l = l
		prev_r = r
		first = false
		z += 4.0
	var mesh := st.commit()
	var mat := Forge.mat(Color(0.10, 0.26, 0.28, 0.82), 0.05)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)

func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.39, 0.58)
	sky_mat.sky_horizon_color = Color(0.72, 0.75, 0.68)
	sky_mat.ground_bottom_color = Color(0.10, 0.14, 0.14)
	sky_mat.ground_horizon_color = Color(0.62, 0.66, 0.60)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.75, 0.74)
	env.fog_density = 0.0005
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170.0
	add_child(sun)
	sun.rotation_degrees = Vector3(-34, -140, 0)

func _build_mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var count := 12
	var made := 0
	var i := 0
	while made < 9 and i < count * 3:
		i += 1
		var angle := rng.randf() * TAU
		# Leave the lake sector (facing +Z) open.
		if absf(wrapf(angle - PI / 2.0, -PI, PI)) < 0.85:
			continue
		var dist := rng.randf_range(330.0, 420.0)
		var height := rng.randf_range(100.0, 200.0)
		var radius := rng.randf_range(80.0, 130.0)
		var mi := MeshInstance3D.new()
		mi.mesh = Flora.mountain_mesh(9500 + made, radius, height, height > 155.0)
		add_child(mi)
		mi.position = Vector3(cos(angle) * dist, -8.0, sin(angle) * dist - 30.0)
		mi.rotation.y = rng.randf() * TAU
		made += 1
	# Far haze cones behind them.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 9
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	var far: Array[Transform3D] = []
	var shades: Array[float] = []
	while far.size() < 24:
		var angle := rng.randf() * TAU
		if absf(wrapf(angle - PI / 2.0, -PI, PI)) < 0.8:
			continue
		var dist := rng.randf_range(480.0, 640.0)
		var height := rng.randf_range(120.0, 240.0)
		var radius := rng.randf_range(90.0, 160.0)
		var pos := Vector3(cos(angle) * dist, height / 2.0 - 10.0, sin(angle) * dist - 30.0)
		far.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(radius, height, radius)), pos))
		shades.append(rng.randf_range(0.85, 1.05))
	mm.instance_count = far.size()
	for j in far.size():
		mm.set_instance_transform(j, far[j])
		var c := Color(0.23, 0.31, 0.34)
		mm.set_instance_color(j, Color(c.r * shades[j], c.g * shades[j], c.b * shades[j]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Forge.vc_mat(1.0)
	add_child(mmi)

## The stream's secret source: a spring pool at the foot of the boundary
## cliff, fed by a waterfall down the rock, lit by drifting motes. One of
## the kept books waits at the water's edge.
func _build_glade() -> void:
	var glade := Node3D.new()
	add_child(glade)
	var floor_y := height_at(_pool_pos.x, _pool_pos.y)
	var water_y := floor_y + 1.05

	var water_mat := Forge.mat(Color(0.12, 0.30, 0.30, 0.85), 0.04)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Forge.cyl(glade, 4.3, 4.3, 0.06, water_mat, Vector3(_pool_pos.x, water_y, _pool_pos.y), Vector3.ZERO, 24)

	# The waterfall: a translucent ribbon draped down the cliff face.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wf_x := _pool_pos.x
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var first := true
	var wz := POOL_Z - 12.0
	while wz < POOL_Z - 1.0:
		var y := height_at(wf_x, wz) + 0.14
		y = maxf(y, water_y)
		var l := Vector3(wf_x - 1.1, y, wz)
		var r := Vector3(wf_x + 1.1, y, wz)
		if not first:
			st.set_normal(Vector3.UP); st.add_vertex(prev_l)
			st.set_normal(Vector3.UP); st.add_vertex(prev_r)
			st.set_normal(Vector3.UP); st.add_vertex(r)
			st.set_normal(Vector3.UP); st.add_vertex(prev_l)
			st.set_normal(Vector3.UP); st.add_vertex(r)
			st.set_normal(Vector3.UP); st.add_vertex(l)
		prev_l = l
		prev_r = r
		first = false
		wz += 1.2
	var wf_mesh := st.commit()
	var wf_mat := Forge.mat(Color(0.72, 0.85, 0.88, 0.55), 0.05, Color(0.5, 0.65, 0.7), 0.25)
	wf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wf_mesh.surface_set_material(0, wf_mat)
	var wf := MeshInstance3D.new()
	wf.mesh = wf_mesh
	glade.add_child(wf)

	# Foam where the falls meet the pool.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var foam := Forge.mat(Color(0.88, 0.93, 0.93, 0.75), 0.3)
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 6:
		Forge.sphere(glade, rng.randf_range(0.25, 0.5), foam,
			Vector3(wf_x + rng.randf_range(-1.3, 1.3), water_y + 0.02, POOL_Z - 3.2 + rng.randf_range(-0.6, 0.6)),
			Vector3(1, 0.16, 1))

	# Mossy stones ring the water.
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		var sx := _pool_pos.x + cos(a) * rng.randf_range(4.6, 5.8)
		var sz := _pool_pos.y + sin(a) * rng.randf_range(4.6, 5.8)
		if sz < POOL_Z - 2.5:
			continue  # leave the falls' side to the cliff
		var s := rng.randf_range(0.5, 1.1)
		Forge.mesh(glade, Flora.rock_mesh(40 + i, 0.9), null,
			Vector3(sx, height_at(sx, sz) + s * 0.25, sz),
			Vector3(0, rng.randf() * TAU, 0), Vector3(s, s, s))

	# Motes over the water, and the light they make.
	var mote := Forge.mat(Color(0.85, 0.95, 0.7), 0.4, Color(0.8, 1.0, 0.55), 2.2)
	for i in 12:
		Forge.sphere(glade, rng.randf_range(0.03, 0.06), mote,
			Vector3(_pool_pos.x + rng.randf_range(-4.5, 4.5),
				water_y + rng.randf_range(0.5, 2.8),
				_pool_pos.y + rng.randf_range(-3.5, 4.5)))
	Forge.omni(glade, Color(0.75, 0.95, 0.7), 0.9, 12.0, Vector3(_pool_pos.x, water_y + 2.2, _pool_pos.y + 1.0))

## Looking back across the water: the island, small and hazy, its tower a
## needle against the far mountains.
func _build_island_silhouette() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(60.0, 0, 620.0)
	var haze := Forge.vc_mat(1.0)
	var cone := CylinderMesh.new()
	cone.top_radius = 8.0
	cone.bottom_radius = 85.0
	cone.height = 22.0
	cone.radial_segments = 18
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 3.0, 0)))
	mm.set_instance_color(0, Color(0.26, 0.34, 0.30))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = haze
	root.add_child(mmi)
	var stone := Forge.mat(Color(0.42, 0.42, 0.46), 0.9)
	Forge.cyl(root, 4.2, 5.2, 24.0, stone, Vector3(0, 24.0, 0), Vector3.ZERO, 12)
	Forge.cyl(root, 0.0, 4.6, 5.0, Forge.mat(Color(0.28, 0.20, 0.36), 0.8), Vector3(0, 38.0, 0), Vector3.ZERO, 12)

# -- jetty, boat, voyage -------------------------------------------------------

func _build_jetty_and_boat() -> void:
	var wood := Forge.mat(Color(0.40, 0.29, 0.18), 0.95)
	var wood_dark := Forge.mat(Color(0.28, 0.20, 0.13), 0.95)
	var jetty := Node3D.new()
	add_child(jetty)
	for i in 10:
		var z := 74.0 + i * 1.12
		Forge.box(jetty, Vector3(2.3, 0.12, 1.04), wood, Vector3(0, 1.05, z))
	for side in [-1.0, 1.0]:
		for i in 4:
			var z := 75.0 + i * 3.0
			Forge.cyl(jetty, 0.11, 0.13, 3.6, wood_dark, Vector3(side * 1.05, -0.45, z), Vector3.ZERO, 8)
	Forge.collider_box(jetty, Vector3(2.4, 0.25, 11.6), Vector3(0, 1.03, 79.6))

	_boat = Node3D.new()
	add_child(_boat)
	_boat.position = Vector3(2.8, _boat_base_y, 84.0)
	_build_boat_hull(_boat)
	var boat_shape := BoxShape3D.new()
	boat_shape.size = Vector3(1.5, 1.1, 3.2)
	_boat.add_child(Interactable.make(boat_shape, "Sail back to the island", func(p: Node) -> void:
		_start_voyage(p as Player),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0))))

## The same enchanted rowboat the island builds; kept in sync by eye.
func _build_boat_hull(boat: Node3D) -> void:
	var wood := Forge.mat(Color(0.42, 0.30, 0.18), 0.95)
	var wood_dark := Forge.mat(Color(0.30, 0.21, 0.13), 0.95)
	Forge.box(boat, Vector3(1.1, 0.16, 2.9), wood_dark, Vector3(0, 0.0, 0))
	Forge.box(boat, Vector3(0.13, 0.5, 3.0), wood, Vector3(-0.58, 0.28, 0), Vector3(0, 0, 0.18))
	Forge.box(boat, Vector3(0.13, 0.5, 3.0), wood, Vector3(0.58, 0.28, 0), Vector3(0, 0, -0.18))
	Forge.box(boat, Vector3(1.25, 0.5, 0.13), wood, Vector3(0, 0.28, -1.48), Vector3(-0.2, 0, 0))
	Forge.box(boat, Vector3(1.25, 0.5, 0.13), wood, Vector3(0, 0.28, 1.48), Vector3(0.2, 0, 0))
	Forge.box(boat, Vector3(1.05, 0.07, 0.42), wood, Vector3(0, 0.34, 0.2))
	Forge.cyl(boat, 0.035, 0.035, 2.1, wood_dark, Vector3(-0.2, 0.5, -0.5), Vector3(0.3, 0.4, 1.2), 6)
	Forge.cyl(boat, 0.035, 0.035, 2.1, wood_dark, Vector3(0.25, 0.5, -0.3), Vector3(0.3, -0.5, -1.2), 6)

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
	player.show_message("The knot unties itself. The boat remembers the way.", 6.0)
	_voyage_points = [Vector3(4.5, 0, 100.0), Vector3(0.0, 0, 128.0), Vector3(-4.0, 0, 152.0)]
	_voyage_i = 0
	_voyage_done = func() -> void:
		Game.travel(ISLAND, "voyage")

func _arrive_by_boat(player: Player) -> void:
	_boat.position = Vector3(-4.0, _boat_base_y, 152.0)
	player.sit(_boat_seat())
	_voyage_points = [Vector3(0.0, 0, 118.0), Vector3(4.5, 0, 96.0), Vector3(2.8, 0, 84.0)]
	_voyage_i = 0
	_voyage_done = func() -> void:
		player.stand()
		player.global_transform = _spawns["jetty"]
		player.velocity = Vector3.ZERO
		player.show_message("The far shore. The trees here were old before the tower was young.\n\nA worn trail leads in under the boughs.", 9.0)

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
	pos.x += dir.x * BOAT_SPEED * delta
	pos.z += dir.z * BOAT_SPEED * delta
	_boat.position.x = pos.x
	_boat.position.z = pos.z
	_boat.rotation.y = lerp_angle(_boat.rotation.y, atan2(dir.x, dir.z), delta * 1.6)

# -- the trail ----------------------------------------------------------------

func _build_trail() -> void:
	var stone := CylinderMesh.new()
	stone.top_radius = 0.8
	stone.bottom_radius = 0.9
	stone.height = 0.16
	stone.radial_segments = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = stone
	var rng := RandomNumberGenerator.new()
	rng.seed = 616
	var transforms: Array[Transform3D] = []
	var shades: Array[float] = []
	for i in _trail.size() - 1:
		var a := _trail[i]
		var b := _trail[i + 1]
		var seg_len := a.distance_to(b)
		var steps := int(seg_len / 2.7)
		for s in steps:
			var t := float(s) / steps
			var p := a.lerp(b, t)
			p += Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
			# Let the bridge carry the trail over the water.
			if absf(p.x - _stream_x(p.y)) < 3.6:
				continue
			var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(rng.randf_range(0.75, 1.05), 1.0, rng.randf_range(0.75, 1.05)))
			transforms.append(Transform3D(basis, Vector3(p.x, height_at(p.x, p.y) + 0.03, p.y)))
			shades.append(rng.randf_range(0.85, 1.05))
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		var v := shades[i]
		mm.set_instance_color(i, Color(0.50 * v, 0.48 * v, 0.45 * v))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Forge.vc_mat(1.0)
	add_child(mmi)

	# Way-cairns where the trail bends, stacked by whoever walked it last.
	var cairn_mat := Forge.mat(Color(0.47, 0.46, 0.44), 0.95)
	for i in range(1, _trail.size() - 1, 2):
		var p := _trail[i]
		var side := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * 2.6
		var cx := p.x + side.x
		var cz := p.y + side.y
		var base_h := height_at(cx, cz)
		var y := base_h
		for s in 4:
			var r := 0.34 - s * 0.07
			Forge.sphere(self, r, cairn_mat, Vector3(cx + rng.randf_range(-0.04, 0.04), y + r * 0.7, cz + rng.randf_range(-0.04, 0.04)), Vector3(1, 0.62, 1))
			y += r * 0.9

## Decide where the bridge stands before the terrain is built, so the
## height function can raise its abutments. The deck's walking surface
## ends up at _bridge_base + ~0.35; the banks are raised to match.
func _plan_bridge() -> void:
	var cx := _stream_x(BRIDGE_Z)
	# The stream runs roughly north-south here; the bridge spans east-west.
	var tangent := Vector2(_stream_x(BRIDGE_Z + 1.0) - _stream_x(BRIDGE_Z - 1.0), 2.0).normalized()
	_bridge_yaw = -atan2(tangent.y, tangent.x) + PI / 2.0
	_bridge_base = maxf(_base_height(cx - 4.2, BRIDGE_Z), _base_height(cx + 4.2, BRIDGE_Z))
	var span := Vector2(cos(_bridge_yaw), -sin(_bridge_yaw))
	_abutment_a = Vector2(cx, BRIDGE_Z) + span * 4.6
	_abutment_b = Vector2(cx, BRIDGE_Z) - span * 4.6
	_abutment_h = _bridge_base + 0.32  # flush with the deck ends

func _build_bridge() -> void:
	var wood := Forge.mat(Color(0.38, 0.27, 0.16), 0.95)
	var wood_dark := Forge.mat(Color(0.26, 0.18, 0.11), 0.95)
	var cx := _stream_x(BRIDGE_Z)
	var bridge := Node3D.new()
	add_child(bridge)
	bridge.position = Vector3(cx, _bridge_base, BRIDGE_Z)
	bridge.rotation.y = _bridge_yaw
	var planks := 9
	for i in planks:
		var t := float(i) / (planks - 1) * 2.0 - 1.0
		var arch := (1.0 - t * t) * 0.55
		Forge.box(bridge, Vector3(1.05, 0.09, 1.9), wood, Vector3(t * 4.0, 0.30 + arch, 0))
	for side in [-1.0, 1.0]:
		Forge.box(bridge, Vector3(8.6, 0.09, 0.12), wood_dark, Vector3(0, 1.15, side * 0.85), Vector3(0, 0, 0))
		for i in 5:
			var t := float(i) / 4.0 * 2.0 - 1.0
			var arch := (1.0 - t * t) * 0.55
			Forge.cyl(bridge, 0.05, 0.06, 0.85, wood_dark, Vector3(t * 3.8, 0.72 + arch * 0.85, side * 0.85), Vector3.ZERO, 6)
	Forge.collider_box(bridge, Vector3(3.2, 0.16, 1.95), Vector3(0, 0.62, 0))
	for side in [-1.0, 1.0]:
		Forge.collider_box(bridge, Vector3(2.9, 0.14, 1.95), Vector3(side * 2.9, 0.38, 0), Vector3(0, 0, side * -0.16))

# -- the ruin ------------------------------------------------------------------

## The First Tower: a broken ring of wall, tumbled columns, a cold portal
## ring, the boundary stone, and the wizard's journal on its lectern.
func _build_ruin() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(RUIN_POS.x, RUIN_HEIGHT, RUIN_POS.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var stone := Forge.mat(Color(0.44, 0.44, 0.42), 0.95)
	var stone_mossy := Forge.mat(Color(0.36, 0.41, 0.31), 0.95)
	var stone_dark := Forge.mat(Color(0.34, 0.34, 0.34), 0.95)

	# Broken ring wall: standing on the north arc, fallen to the south.
	var segs := 24
	for i in segs:
		var a := TAU * i / segs
		var standing := absf(wrapf(a - PI * 1.5, -PI, PI)) < PI * 0.62
		var x := cos(a) * 7.5
		var z := sin(a) * 7.5
		var mat_pick := stone_mossy if rng.randf() < 0.45 else stone
		if standing and rng.randf() < 0.85:
			var h := rng.randf_range(0.7, 3.2)
			Forge.box(root, Vector3(2.0, h, 0.8), mat_pick, Vector3(x, h / 2.0 - 0.2, z),
				Vector3(rng.randf_range(-0.05, 0.05), -a + PI / 2.0, rng.randf_range(-0.05, 0.05)))
			if h > 1.2:
				Forge.collider_box(root, Vector3(2.0, h, 0.8), Vector3(x, h / 2.0 - 0.2, z), Vector3(0, -a + PI / 2.0, 0))
		elif rng.randf() < 0.6:
			# A block that let go, lying where it rolled.
			var d := rng.randf_range(1.0, 4.0)
			var bx := cos(a) * (7.5 + d)
			var bz := sin(a) * (7.5 + d)
			Forge.box(root, Vector3(rng.randf_range(0.8, 1.6), 0.7, 0.8), stone_mossy,
				Vector3(bx, 0.15, bz), Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))

	# Columns: two still standing at the north entrance, one spilled.
	for side: float in [-1.0, 1.0]:
		var cx := side * 2.2
		var cz := -7.5
		var drums := 3 if side < 0 else 2
		var y := 0.0
		for d in drums:
			var r := 0.55 - d * 0.05
			Forge.cyl(root, r, r + 0.04, 1.1, stone, Vector3(cx + rng.randf_range(-0.06, 0.06), y + 0.55, cz), Vector3(0, 0, rng.randf_range(-0.04, 0.04)), 12)
			y += 1.1
		Forge.collider_cyl(root, 0.6, y, Vector3(cx, y / 2.0, cz))
	for d in 4:
		Forge.cyl(root, 0.5, 0.5, 1.05, stone_mossy,
			Vector3(4.0 + d * 1.15, 0.32, 4.2 + d * 0.5),
			Vector3(PI / 2.0, rng.randf_range(-0.2, 0.2), 0.35), 12)

	# The lintel that was an arch, leaning against its pillar.
	Forge.box(root, Vector3(3.2, 0.5, 0.6), stone_dark, Vector3(-1.0, 1.6, -8.6), Vector3(0, 0.2, -0.5))

	# Cracked dais and the cold portal ring. Returning the five kept books
	# wakes it (_wake_ring), so keep hold of the pieces.
	Forge.cyl(root, 2.6, 2.9, 0.4, stone_dark, Vector3(0, 0.2, 0), Vector3.ZERO, 20)
	Forge.collider_cyl(root, 2.8, 0.5, Vector3(0, 0.2, 0))
	Forge.torus(root, 1.05, 1.35, Forge.mat(Color(0.33, 0.34, 0.36), 0.92), Vector3(0, 1.85, 0), Vector3(PI / 2.0, 0, 0))
	var ring_shape := BoxShape3D.new()
	ring_shape.size = Vector3(2.6, 3.0, 0.7)
	_ring_root = root
	_ring_body = Interactable.make(ring_shape, "Touch the cold ring", func(p: Node) -> void:
		(p as Player).show_message("The ring is cold, and holds nothing. Whatever door stood here was carried across the water long ago.", 7.0),
		Transform3D(Basis.IDENTITY, Vector3(0, 1.85, 0)))
	root.add_child(_ring_body)

	# The boundary stone, out past the fallen arc.
	var tablet := Node3D.new()
	root.add_child(tablet)
	tablet.position = Vector3(5.6, 0, -5.2)
	tablet.rotation.y = -0.6
	Forge.box(tablet, Vector3(1.5, 2.2, 0.35), stone_mossy, Vector3(0, 0.9, 0), Vector3(rng.randf_range(-0.06, 0.02), 0, 0.07))
	Forge.box(tablet, Vector3(1.1, 1.5, 0.06), stone_dark, Vector3(0, 1.05, 0.17), Vector3(0, 0, 0.07))
	var tablet_shape := BoxShape3D.new()
	tablet_shape.size = Vector3(1.7, 2.4, 0.7)
	tablet.add_child(Interactable.make(tablet_shape, "Read the boundary stone", func(p: Node) -> void:
		(p as Player).open_book(BookLore.tablet()),
		Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0))))

	# The lectern, and the journal the wizard left for the last word.
	var lectern := Node3D.new()
	root.add_child(lectern)
	lectern.position = Vector3(0, 0.4, 2.1)
	lectern.rotation.y = PI
	Forge.box(lectern, Vector3(0.7, 1.1, 0.5), stone, Vector3(0, 0.55, 0))
	Forge.box(lectern, Vector3(0.9, 0.08, 0.7), stone_dark, Vector3(0, 1.14, 0.05), Vector3(-0.35, 0, 0))
	Forge.box(lectern, Vector3(0.5, 0.09, 0.36), Forge.mat(Color(0.32, 0.20, 0.12), 0.8), Vector3(0, 1.24, 0.03), Vector3(-0.35, 0, 0))
	Forge.box(lectern, Vector3(0.46, 0.03, 0.32), Forge.mat(Color(0.88, 0.84, 0.72), 0.9), Vector3(0, 1.30, 0.05), Vector3(-0.35, 0, 0))
	var lectern_shape := BoxShape3D.new()
	lectern_shape.size = Vector3(1.0, 1.7, 0.9)
	lectern.add_child(Interactable.make(lectern_shape, "Read the wizard's journal", func(p: Node) -> void:
		var pages := BookLore.journal_pages()
		(p as Player).open_book(pages[0], pages),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.85, 0))))

	# Fireflies of a sort: faint motes where the magic soaked in.
	Forge.omni(root, Color(0.55, 0.75, 0.65), 0.7, 9.0, Vector3(0, 2.4, 0))

# -- the secrets ----------------------------------------------------------------

## Five books from the First Tower, grown into living trees off the trail.
## Each glows faintly; each is readable; returning all five wakes the ring.
func _build_kept_books() -> void:
	var spots: Array[Vector2] = []
	for kp: Vector2 in KEPT_POSITIONS:
		spots.append(kp)
	spots.append(Vector2(_pool_pos.x - 4.6, _pool_pos.y + 3.5))  # the spring keeps the fifth
	var glow_mat := Forge.mat(Color(0.45, 0.36, 0.20), 0.6, Color(0.75, 0.95, 0.45), 1.3)
	var page_mat := Forge.mat(Color(0.90, 0.87, 0.74), 0.85)
	for i in spots.size():
		var s2 := spots[i]
		var h := height_at(s2.x, s2.y)
		var host := Node3D.new()
		add_child(host)
		host.position = Vector3(s2.x, h - 0.1, s2.y)
		host.rotation.y = float(i) * 1.3
		Forge.mesh(host, Flora.broadleaf_mesh(920 + i), null, Vector3.ZERO, Vector3.ZERO, Vector3(1.9, 1.9, 1.9))
		Forge.collider_cyl(host, 0.55, 3.0, Vector3(0, 1.5, 0))
		# The book, half-swallowed by the trunk, spine out.
		Forge.box(host, Vector3(0.13, 0.46, 0.34), glow_mat, Vector3(0.42, 1.35, 0), Vector3(0, 0, 0.12))
		Forge.box(host, Vector3(0.09, 0.40, 0.28), page_mat, Vector3(0.50, 1.35, 0), Vector3(0, 0, 0.12))
		Forge.omni(host, Color(0.7, 0.95, 0.5), 0.55, 5.5, Vector3(0.7, 1.5, 0))
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 1.2, 1.0)
		var idx := i
		host.add_child(Interactable.make(shape, "Take back the book the forest kept", func(p: Node) -> void:
			_collect_kept(idx, p as Player),
			Transform3D(Basis.IDENTITY, Vector3(0.5, 1.35, 0))))

func _collect_kept(i: int, pl: Player) -> void:
	pl.open_book(BookLore.kept_book(i))
	if _kept_found.has(i):
		return
	_kept_found[i] = true
	var n := _kept_found.size()
	if n < BookLore.KEPT_COUNT:
		pl.show_message("The bark lets it go without argument. %d of %d words returned." % [n, BookLore.KEPT_COUNT], 6.0)
	else:
		_wake_ring()
		pl.show_message("The last word comes home. Far behind you, in the ruin, something very old clears its throat.", 9.0)

## The wizard's last charm: with all five words returned, the cold ring in
## the ruin becomes a door again — one way, home to the jetty.
func _wake_ring() -> void:
	if _ring_root == null or _ring_body == null:
		return
	var hue := Color(0.45, 0.95, 0.55)
	Forge.torus(_ring_root, 1.02, 1.38, Forge.mat(hue * 0.4, 0.3, hue, 2.6), Vector3(0, 1.85, 0), Vector3(PI / 2.0, 0, 0))
	var disc := Forge.mat(Color(hue.r, hue.g, hue.b, 0.5), 0.1, hue, 1.4)
	disc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.cull_mode = BaseMaterial3D.CULL_DISABLED
	Forge.cyl(_ring_root, 1.02, 1.02, 0.04, disc, Vector3(0, 1.85, 0), Vector3(PI / 2.0, 0, 0), 32)
	Forge.omni(_ring_root, hue, 1.3, 9.0, Vector3(0, 2.0, 1.0))
	_ring_body.prompt = "Step through the wizard's last door"
	_ring_body.action = func(p: Node) -> void:
		var pl := p as Player
		Game.blink(func() -> void:
			pl.global_transform = _spawns["jetty"]
			pl.velocity = Vector3.ZERO
			pl.show_message("The old door still knows one way: home to the water.", 7.0))

## The hermit's hollow: a great split tree someone has been living in.
## The fire is cold. The note is not addressed to you, exactly.
func _build_hollow() -> void:
	var h := height_at(HOLLOW_POS.x, HOLLOW_POS.y)
	var hollow := Node3D.new()
	add_child(hollow)
	hollow.position = Vector3(HOLLOW_POS.x, h, HOLLOW_POS.y)
	var bark := Forge.mat(Color(0.22, 0.15, 0.10), 0.95)
	var bark_hi := Forge.mat(Color(0.30, 0.22, 0.13), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	# The trunk: a ring of massive buttress posts, split open to the east.
	var posts := 11
	for k in posts:
		if k in [0, 1, 10]:
			continue  # the opening faces +X, toward the trail side
		var a := TAU * k / posts
		var px := cos(a) * 2.0
		var pz := sin(a) * 2.0
		var lean := Vector3(-cos(a) * 0.08, 0, -sin(a) * 0.08)
		Forge.cyl(hollow, rng.randf_range(0.5, 0.65), rng.randf_range(0.75, 0.95), 8.0,
			bark if rng.randf() < 0.6 else bark_hi,
			Vector3(px, 3.6, pz), lean, 8)
		Forge.collider_cyl(hollow, 0.8, 8.0, Vector3(px, 3.6, pz))
	# The canopy, far overhead.
	for c in [Vector3(-1.2, 8.6, 0.6), Vector3(1.4, 9.2, -0.8), Vector3(0.0, 9.8, 1.2)]:
		Forge.mesh(hollow, Flora.bush_mesh(91), null, c, Vector3.ZERO, Vector3(6.5, 4.5, 6.5))
	# The camp inside: cold firepit, bedroll, candle stubs, root shelf.
	Forge.box(hollow, Vector3(2.6, 0.04, 2.6), Forge.mat(Color(0.24, 0.18, 0.13), 1.0), Vector3(0, 0.03, 0))
	for i in 7:
		var a := TAU * i / 7.0
		Forge.sphere(hollow, 0.14, Forge.mat(Color(0.42, 0.41, 0.40), 0.95), Vector3(cos(a) * 0.55, 0.10, sin(a) * 0.55), Vector3(1, 0.7, 1))
	for i in 4:
		Forge.box(hollow, Vector3(0.28, 0.05, 0.07), Forge.mat(Color(0.08, 0.07, 0.06), 1.0),
			Vector3(rng.randf_range(-0.25, 0.25), 0.08, rng.randf_range(-0.25, 0.25)), Vector3(0, rng.randf() * TAU, 0))
	Forge.cyl(hollow, 0.18, 0.18, 0.7, Forge.mat(Color(0.45, 0.22, 0.20), 0.9), Vector3(-1.05, 0.22, 0.9), Vector3(0, 0, PI / 2.0), 10)
	Forge.box(hollow, Vector3(1.1, 0.07, 0.4), bark_hi, Vector3(-1.35, 1.15, -0.5), Vector3(0, 0.5, 0))
	for i in 3:
		Forge.cyl(hollow, 0.035, 0.045, rng.randf_range(0.08, 0.16), Forge.mat(Color(0.90, 0.87, 0.78), 0.6),
			Vector3(-1.3 + i * 0.18, 1.25, -0.55 + i * 0.08), Vector3.ZERO, 6)
	# The note, folded on the shelf.
	Forge.box(hollow, Vector3(0.26, 0.02, 0.2), Forge.mat(Color(0.92, 0.90, 0.82), 0.8), Vector3(-1.55, 1.22, -0.35), Vector3(0, 0.4, 0))
	var note_shape := BoxShape3D.new()
	note_shape.size = Vector3(0.9, 0.8, 0.7)
	hollow.add_child(Interactable.make(note_shape, "Read the stranger's note", func(p: Node) -> void:
		(p as Player).open_book(BookLore.stranger_note()),
		Transform3D(Basis.IDENTITY, Vector3(-1.45, 1.2, -0.45))))

# -- vegetation ----------------------------------------------------------------

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
	rng.seed = 2718
	var variants: Array[ArrayMesh] = [
		Flora.pine_mesh(101), Flora.pine_mesh(202), Flora.pine_mesh(303),
		Flora.broadleaf_mesh(404), Flora.broadleaf_mesh(505),
		Flora.broadleaf_mesh(606, true),
	]
	var placements: Array = [[], [], [], [], [], []]
	var colliders := Node3D.new()
	add_child(colliders)
	var total := 0
	var attempts := 0
	while attempts < 6000 and total < 650:
		attempts += 1
		var x := rng.randf_range(X_MIN + 6.0, X_MAX - 6.0)
		var z := rng.randf_range(Z_MIN + 6.0, 70.0)
		var h := height_at(x, z)
		if h < 1.2 or h > 20.0:
			continue
		if _normal_at(x, z).y < 0.72:
			continue
		if not _clear_of_landmarks(x, z):
			continue
		var v: int
		if rng.randf() < 0.55:
			v = rng.randi_range(0, 2)
		elif rng.randf() < 0.08:
			v = 5
		else:
			v = rng.randi_range(3, 4)
		# Old growth: everything here is bigger than the island's trees.
		var s := rng.randf_range(1.3, 2.4)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.95, 1.25), s))
		placements[v].append(Transform3D(basis, Vector3(x, h - 0.1, z)))
		total += 1
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.28 * s
		shape.height = 3.0
		cs.shape = shape
		body.add_child(cs)
		colliders.add_child(body)
		body.position = Vector3(x, h + 1.4, z)
	for v in variants.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(placements[v])
		_multimesh_of(variants[v], transforms)

func _build_ferns() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3141
	var variants: Array[ArrayMesh] = [Flora.fern_mesh(11), Flora.fern_mesh(22), Flora.fern_mesh(33)]
	var groups: Array = [[], [], []]
	var placed := 0
	var attempts := 0
	while attempts < 4000 and placed < 900:
		attempts += 1
		var x := rng.randf_range(X_MIN + 6.0, X_MAX - 6.0)
		var z := rng.randf_range(Z_MIN + 6.0, 66.0)
		var h := height_at(x, z)
		if h < 1.0 or h > 17.0:
			continue
		if _trail_dist(x, z) < 2.2 or absf(x - _stream_x(z)) < 2.0:
			continue
		if Vector2(x, z).distance_to(RUIN_POS) < 5.5:
			continue
		var s := rng.randf_range(0.8, 1.6)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.1), s))
		groups[rng.randi_range(0, 2)].append(Transform3D(basis, Vector3(x, h - 0.02, z)))
		placed += 1
	for v in variants.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[v])
		_multimesh_of(variants[v], transforms)

func _build_logs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2222
	var variants: Array[ArrayMesh] = [
		Flora.log_mesh(1), Flora.log_mesh(2), Flora.log_mesh(3), Flora.log_mesh(4),
	]
	var groups: Array = [[], [], [], []]
	var colliders := Node3D.new()
	add_child(colliders)
	var placed := 0
	var attempts := 0
	while attempts < 500 and placed < 36:
		attempts += 1
		var x := rng.randf_range(X_MIN + 10.0, X_MAX - 10.0)
		var z := rng.randf_range(Z_MIN + 10.0, 60.0)
		var h := height_at(x, z)
		if h < 1.2 or h > 16.0 or not _clear_of_landmarks(x, z):
			continue
		if Vector2(x, z).distance_to(RUIN_POS) < 18.0:
			continue
		var yaw := rng.randf() * TAU
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), yaw, rng.randf_range(-0.06, 0.06)))
		var pos := Vector3(x, h + 0.2, z)
		groups[rng.randi_range(0, 3)].append(Transform3D(basis, pos))
		placed += 1
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.4, 0.6, 0.6)
		cs.shape = shape
		body.add_child(cs)
		colliders.add_child(body)
		body.position = pos
		body.rotation.y = yaw
	for v in variants.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[v])
		_multimesh_of(variants[v], transforms)

func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4004
	var variants: Array[ArrayMesh] = [
		Flora.rock_mesh(21, 0.85), Flora.rock_mesh(22, 0.6),
		Flora.rock_mesh(23, 0.3), Flora.rock_mesh(24, 0.7),
	]
	var groups: Array = [[], [], [], []]
	var colliders := Node3D.new()
	add_child(colliders)
	var placed := 0
	var attempts := 0
	while attempts < 700 and placed < 24:
		attempts += 1
		var x := rng.randf_range(X_MIN + 8.0, X_MAX - 8.0)
		var z := rng.randf_range(Z_MIN + 8.0, 64.0)
		var h := height_at(x, z)
		if h < 0.8 or h > 18.0 or not _clear_of_landmarks(x, z):
			continue
		var s := rng.randf_range(1.0, 2.6)
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
	# Smaller stones, thickest along the stream and the shore.
	for spec in [[80, 0.35, 0.8, 0.8, 15.0], [130, 0.1, 0.3, 0.1, 1.4]]:
		placed = 0
		attempts = 0
		while attempts < spec[0] * 5 and placed < spec[0]:
			attempts += 1
			var x := rng.randf_range(X_MIN + 4.0, X_MAX - 4.0)
			var z := rng.randf_range(Z_MIN + 4.0, 80.0)
			var near_stream: bool = absf(x - _stream_x(z)) < 7.0 and z < 80.0
			if not near_stream and rng.randf() < 0.55:
				continue
			var h := height_at(x, z)
			if h < spec[3] or h > spec[4]:
				continue
			if _trail_dist(x, z) < 2.0:
				continue
			var s: float = rng.randf_range(spec[1], spec[2])
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3(s, s, s))
			groups[rng.randi_range(0, 3)].append(Transform3D(basis, Vector3(x, h + s * 0.2, z)))
			placed += 1
	# Scree fallen from the boundary walls, littering the bare apron at
	# their feet. Visual only; the cliffs themselves do the blocking.
	var scree := 0
	attempts = 0
	while attempts < 400 and scree < 46:
		attempts += 1
		var x: float
		var z: float
		match rng.randi_range(0, 2):
			0:
				x = rng.randf_range(119.0, 128.0)
				z = rng.randf_range(-108.0, 70.0)
			1:
				x = rng.randf_range(-128.0, -119.0)
				z = rng.randf_range(-108.0, 70.0)
			_:
				x = rng.randf_range(-116.0, 116.0)
				z = rng.randf_range(-126.0, -113.0)
		if Vector2(x, z).distance_to(_pool_pos) < 12.0:
			continue
		var h := height_at(x, z)
		if h > 26.0:
			continue
		var s := rng.randf_range(0.4, 1.3)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled(Vector3(s, s, s))
		groups[rng.randi_range(0, 3)].append(Transform3D(basis, Vector3(x, h + s * 0.2, z)))
		scree += 1
	for v in variants.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[v])
		_multimesh_of(variants[v], transforms)

func _build_bushes_and_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5005
	var bushes: Array[ArrayMesh] = [Flora.bush_mesh(71), Flora.bush_mesh(72)]
	var bush_groups: Array = [[], []]
	var placed := 0
	var attempts := 0
	while attempts < 800 and placed < 130:
		attempts += 1
		var x := rng.randf_range(X_MIN + 6.0, X_MAX - 6.0)
		var z := rng.randf_range(Z_MIN + 6.0, 66.0)
		var h := height_at(x, z)
		if h < 1.2 or h > 15.0 or not _clear_of_landmarks(x, z):
			continue
		var s := rng.randf_range(0.9, 1.9)
		var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.1), s))
		bush_groups[rng.randi_range(0, 1)].append(Transform3D(basis, Vector3(x, h - 0.05, z)))
		placed += 1
	for v in bushes.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(bush_groups[v])
		_multimesh_of(bushes[v], transforms)

	var grasses: Array[ArrayMesh] = [
		Flora.grass_mesh(61), Flora.grass_mesh(62),
		Flora.grass_mesh(63, Color(0.92, 0.92, 0.96)),
	]
	var counts := [800, 700, 70]
	for v in grasses.size():
		var transforms: Array[Transform3D] = []
		attempts = 0
		while attempts < counts[v] * 3 and transforms.size() < counts[v]:
			attempts += 1
			var x := rng.randf_range(X_MIN + 4.0, X_MAX - 4.0)
			var z := rng.randf_range(Z_MIN + 4.0, 72.0)
			var h := height_at(x, z)
			if h < 1.0 or h > 12.0 or not _clear_of_landmarks(x, z):
				continue
			var s := rng.randf_range(0.8, 1.5)
			var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s, s))
			transforms.append(Transform3D(basis, Vector3(x, h - 0.02, z)))
		_multimesh_of(grasses[v], transforms)

# -- player --------------------------------------------------------------------

func _spawn_player() -> void:
	_spawns = {
		"jetty": Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 79.0)),
	}
	_player = PlayerScript.new()
	add_child(_player)
	_player.home_transform = _spawns["jetty"]
	_player.fall_reset_y = -2.0
	_player.fall_message = "The lake sets you back on the jetty, dripping."
	if Game.spawn_point == "voyage":
		_arrive_by_boat(_player)
	else:
		_player.global_transform = _spawns["jetty"]
