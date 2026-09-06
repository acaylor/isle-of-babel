class_name Forge
## Static helpers for building procedural geometry. Everything in the game
## is assembled at runtime from these, so no binary assets live in the repo.

## MultiMeshes are culled as a whole. Local cells keep a visible tree from
## submitting every tree of its variant across the map. Keep full silhouettes
## at every distance (including the tower balcony and boat crossings).
static func scatter(parent: Node3D, source: Mesh, transforms: Array[Transform3D], cell_size := 48.0) -> void:
	assert(cell_size > 0.0)
	var cells: Dictionary[Vector2i, Array] = {}
	for placement in transforms:
		var key := Vector2i(floori(placement.origin.x / cell_size), floori(placement.origin.z / cell_size))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(placement)
	for key: Vector2i in cells:
		var origin := Vector3((key.x + 0.5) * cell_size, 0.0, (key.y + 0.5) * cell_size)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = source
		mm.instance_count = cells[key].size()
		var bounds := AABB()
		for i in mm.instance_count:
			var placement: Transform3D = cells[key][i]
			placement.origin -= origin
			mm.set_instance_transform(i, placement)
			# Wind moves vertices beyond the undeformed mesh, in local space.
			var instance_bounds: AABB = placement * source.get_aabb().grow(0.1)
			bounds = instance_bounds if i == 0 else bounds.merge(instance_bounds)
		mm.custom_aabb = bounds
		var instance := MultiMeshInstance3D.new()
		instance.name = "Scatter_%d_%d" % [key.x, key.y]
		instance.multimesh = mm
		instance.position = origin
		parent.add_child(instance)

static func mat(color: Color, rough := 0.95, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m

## Material that displays per-vertex / per-instance colors. The colors we
## author are sRGB, so flag them as such or they render washed out.
static func vc_mat(rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	return m

static func mesh(parent: Node, m: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if material:
		mi.material_override = material
	parent.add_child(mi)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	return mi

static func box(parent: Node, size: Vector3, material: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return mesh(parent, bm, material, pos, rot)

static func cyl(parent: Node, r_top: float, r_bottom: float, h: float, material: Material, pos: Vector3, rot := Vector3.ZERO, radial := 24) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = radial
	return mesh(parent, cm, material, pos, rot)

static func sphere(parent: Node, r: float, material: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	return mesh(parent, sm, material, pos, Vector3.ZERO, scl)

static func torus(parent: Node, inner: float, outer: float, material: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	return mesh(parent, tm, material, pos, rot)

static func collider_box(parent: Node, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.position = pos
	body.rotation = rot
	return body

static func collider_cyl(parent: Node, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.position = pos
	return body

## A Sky driven by the procedural sky shader — drifting fbm clouds, a sun
## disc with halo, horizon haze — colored per scene.
static func sky(top: Color, horizon: Color, ground_bottom: Color, ground_horizon: Color, coverage := 0.45) -> Sky:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/sky.gdshader")
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("horizon_color", horizon)
	m.set_shader_parameter("ground_bottom_color", ground_bottom)
	m.set_shader_parameter("ground_horizon_color", ground_horizon)
	m.set_shader_parameter("cloud_coverage", coverage)
	var s := Sky.new()
	s.sky_material = m
	return s

static func omni(parent: Node, color: Color, energy: float, light_range: float, pos: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	parent.add_child(l)
	l.position = pos
	return l

## A free-standing magic portal: glowing ring, translucent disc, light, and
## an Interactable body. Faces +Z by default; rotate the returned root.
static func portal(parent: Node, pos: Vector3, prompt_text: String, on_interact: Callable, hue := Color(0.35, 0.85, 1.0)) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var ring_mat := mat(hue * 0.4, 0.3, hue, 3.2)
	torus(root, 1.05, 1.35, ring_mat, Vector3(0, 1.45, 0), Vector3(PI / 2.0, 0, 0))
	var disc_mat := mat(Color(hue.r, hue.g, hue.b, 0.55), 0.1, hue, 1.6)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl(root, 1.05, 1.05, 0.04, disc_mat, Vector3(0, 1.45, 0), Vector3(PI / 2.0, 0, 0), 32)
	omni(root, hue, 1.2, 7.0, Vector3(0, 1.6, 0.8))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.9, 0.7)
	var body := Interactable.make(shape, prompt_text, on_interact, Transform3D(Basis.IDENTITY, Vector3(0, 1.45, 0)))
	root.add_child(body)
	return root
