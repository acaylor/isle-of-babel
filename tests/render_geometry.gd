extends SceneTree
## Headless invariants for spatial batching: instance counts, bounded cells,
## and conservative visibility bounds for scaled, wind-animated meshes.

func _initialize() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var mesh := BoxMesh.new()
	var placements: Array[Transform3D] = []
	for x: float in [-96.1, -48.0, -0.1, 0.0, 47.9, 48.0, 120.0]:
		placements.append(Transform3D(Basis.from_euler(Vector3(0.2, 0.7, -0.1)).scaled(Vector3(2, 3, 1)), Vector3(x, 7, x)))
	Forge.scatter(parent, mesh, placements)
	if not _check(parent.get_child_count() == 5, "expected five occupied spatial cells"):
		return
	var total := 0
	for child: MultiMeshInstance3D in parent.get_children():
		var mm := child.multimesh
		total += mm.instance_count
		var expected_count := 0
		for placement in placements:
			var cell := Vector2i(floori(placement.origin.x / 48.0), floori(placement.origin.z / 48.0))
			var center := Vector3((cell.x + 0.5) * 48.0, 0, (cell.y + 0.5) * 48.0)
			if not center.is_equal_approx(child.position):
				continue
			expected_count += 1
			var expected: AABB = placement * mesh.get_aabb().grow(0.1)
			var actual: AABB = child.transform * mm.custom_aabb
			if not _check(actual.grow(0.001).encloses(expected), "wind bounds clipped"):
				return
		if not _check(expected_count == mm.instance_count, "cell lost or duplicated instances"):
			return
	if not _check(total == placements.size(), "placement count changed"):
		return
	var empty := Node3D.new()
	root.add_child(empty)
	Forge.scatter(empty, mesh, [])
	if not _check(empty.get_child_count() == 0, "empty scatter allocated a batch"):
		return
	print("RENDER GEOMETRY OK")
	quit()

func _check(condition: bool, reason: String) -> bool:
	if not condition:
		push_error("RENDER GEOMETRY FAIL: " + reason)
		quit(1)
	return condition
