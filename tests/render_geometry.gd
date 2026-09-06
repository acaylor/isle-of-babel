extends SceneTree
## Headless invariants for spatial batching: instance counts, bounded cells,
## conservative visibility bounds for wind-animated meshes, and one readable
## node name per mesh variant.

const CELL := 48.0
const SWAY_SHADER := "res://shaders/sway.gdshader"

func _initialize() -> void:
	if not _check_cells():
		return
	if not _check_sway_padding():
		return
	if not _check_wind_bounds():
		return
	if not _check_names():
		return
	print("RENDER GEOMETRY OK")
	quit()

## Negative cell coordinates, cell boundaries, instance counts, empty input.
func _check_cells() -> bool:
	var parent := Node3D.new()
	root.add_child(parent)
	var mesh := BoxMesh.new()
	var placements := _placements()
	Forge.scatter(parent, mesh, placements)
	if not _check(parent.get_child_count() == 5, "expected five occupied spatial cells"):
		return false
	var total := 0
	for child: MultiMeshInstance3D in parent.get_children():
		total += child.multimesh.instance_count
		var expected_count := 0
		for placement in placements:
			if _cell_center(placement).is_equal_approx(child.position):
				expected_count += 1
		if not _check(expected_count == child.multimesh.instance_count, "cell lost or duplicated instances"):
			return false
	if not _check(total == placements.size(), "placement count changed"):
		return false
	var empty := Node3D.new()
	root.add_child(empty)
	Forge.scatter(empty, mesh, [])
	return _check(empty.get_child_count() == 0, "empty scatter allocated a batch")

## The padding must come from the sway shader, not from a constant that has
## to be kept in step with it by hand.
func _check_sway_padding() -> bool:
	if not _check(is_zero_approx(Forge.sway_padding(BoxMesh.new())), "static mesh padded for wind"):
		return false
	var explicit := BoxMesh.new()
	explicit.material = _sway_material(0.42)
	if not _check(is_equal_approx(Forge.sway_padding(explicit), 0.42), "padding ignores the material's sway_amp"):
		return false
	# Flora's living meshes must still reach this path at all.
	if not _check(Forge.sway_padding(Flora.grass_mesh(1)) > 0.0, "flora lost its wind sway"):
		return false
	return _check(is_zero_approx(Forge.sway_padding(Flora.rock_mesh(1, 0.5))), "static flora padded for wind")

## Bounds must survive instance scale and rotation, at whatever amplitude the
## shader is actually running: raise sway_amp and these bounds must follow.
func _check_wind_bounds() -> bool:
	var parent := Node3D.new()
	root.add_child(parent)
	var mesh := BoxMesh.new()
	mesh.material = _sway_material(0.42)
	var amp: float = float((mesh.material as ShaderMaterial).get_shader_parameter("sway_amp"))
	var placements := _placements()
	Forge.scatter(parent, mesh, placements)
	for child: MultiMeshInstance3D in parent.get_children():
		for placement in placements:
			if not _cell_center(placement).is_equal_approx(child.position):
				continue
			var expected: AABB = placement * mesh.get_aabb().grow(amp)
			var actual: AABB = child.transform * child.multimesh.custom_aabb
			if not _check(actual.grow(0.001).encloses(expected), "wind bounds clipped"):
				return false
	return true

## Cell keys repeat for every variant a scene scatters, so the name has to
## carry the mesh or Godot renames the collisions to @Scatter_0_0@N.
func _check_names() -> bool:
	var parent := Node3D.new()
	root.add_child(parent)
	var placement: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(4, 0, 4))]
	Forge.scatter(parent, Flora.pine_mesh(11), placement)
	Forge.scatter(parent, Flora.pine_mesh(22), placement)
	if not _check(parent.get_child_count() == 2, "one cell per variant expected"):
		return false
	for name: String in ["Scatter_pine_11_0_0", "Scatter_pine_22_0_0"]:
		if not _check(parent.get_node_or_null(NodePath(name)) != null, "batch name collided: " + name):
			return false
	return true

func _placements() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for x: float in [-96.1, -48.0, -0.1, 0.0, 47.9, 48.0, 120.0]:
		out.append(Transform3D(Basis.from_euler(Vector3(0.2, 0.7, -0.1)).scaled(Vector3(2, 3, 1)), Vector3(x, 7, x)))
	return out

func _cell_center(placement: Transform3D) -> Vector3:
	var cell := Vector2i(floori(placement.origin.x / CELL), floori(placement.origin.z / CELL))
	return Vector3((cell.x + 0.5) * CELL, 0.0, (cell.y + 0.5) * CELL)

func _sway_material(amp: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SWAY_SHADER)
	mat.set_shader_parameter("sway_amp", amp)
	return mat

func _check(condition: bool, reason: String) -> bool:
	if not condition:
		push_error("RENDER GEOMETRY FAIL: " + reason)
		quit(1)
	return condition
