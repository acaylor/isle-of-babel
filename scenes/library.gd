extends Node3D
## The tower's interior: an endless library. Gallery cells stream in around
## the player as they walk, each deterministically furnished from its grid
## coordinates, so the shelves genuinely never end. The entrance cell holds
## the door back to the island and the portal to the tower summit.

const PlayerScript := preload("res://player/player.gd")
const ISLAND := "res://scenes/island.tscn"

const CELL := 14.0
const WALL_H := 7.0
const SHELF_LEN := 5.2
const SHELF_H := 5.6
const SHELF_D := 0.7
const LOAD_RADIUS := 2
const UNLOAD_RADIUS := 4
const BUILDS_PER_FRAME := 2

var _cells := {}  # Vector2i -> Node3D
var _player: Player

# Shared resources, built once.
var _wood := Forge.mat(Color(0.30, 0.20, 0.12), 0.92)
var _wood_dark := Forge.mat(Color(0.20, 0.13, 0.08), 0.95)
var _floor_mat := Forge.mat(Color(0.26, 0.19, 0.13), 0.9)
var _ceiling_mat := Forge.mat(Color(0.14, 0.10, 0.08), 1.0)
var _stone_mat := Forge.mat(Color(0.42, 0.40, 0.44), 0.9)
var _book_mat := Forge.vc_mat(0.9)
var _lamp_mat := Forge.mat(Color(1.0, 0.82, 0.5), 0.3, Color(1.0, 0.75, 0.4), 2.4)
var _floor_mesh: BoxMesh
var _ceiling_mesh: BoxMesh
var _column_mesh: CylinderMesh
var _shelf_mesh: ArrayMesh
var _book_mesh := BoxMesh.new()

const BOOK_COLORS := [
	Color(0.45, 0.15, 0.13), Color(0.25, 0.30, 0.16), Color(0.16, 0.20, 0.33),
	Color(0.40, 0.28, 0.14), Color(0.30, 0.14, 0.25), Color(0.50, 0.42, 0.28),
	Color(0.16, 0.28, 0.26), Color(0.36, 0.31, 0.36),
]

func _ready() -> void:
	_build_shared_meshes()
	_build_environment()
	_spawn_player()
	_stream_cells(true)

func _process(delta: float) -> void:
	_stream_cells(false)
	_bird_process(delta)

# -- shared geometry -------------------------------------------------------

func _build_shared_meshes() -> void:
	_floor_mesh = BoxMesh.new()
	_floor_mesh.size = Vector3(CELL, 0.4, CELL)
	_ceiling_mesh = BoxMesh.new()
	_ceiling_mesh.size = Vector3(CELL, 0.4, CELL)
	_column_mesh = CylinderMesh.new()
	_column_mesh.top_radius = 0.35
	_column_mesh.bottom_radius = 0.42
	_column_mesh.height = WALL_H
	_column_mesh.radial_segments = 12
	_book_mesh.size = Vector3(1, 1, 1)
	_shelf_mesh = _make_shelf_mesh()

## One double-sided bookshelf frame; books are instanced over it separately.
func _make_shelf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array[Array] = []  # [size, position]
	parts.append([Vector3(0.1, SHELF_H, 0.12), Vector3(-SHELF_LEN / 2.0 + 0.05, SHELF_H / 2.0, 0)])
	parts.append([Vector3(0.1, SHELF_H, 0.12), Vector3(SHELF_LEN / 2.0 - 0.05, SHELF_H / 2.0, 0)])
	parts.append([Vector3(0.08, SHELF_H, SHELF_D), Vector3(-SHELF_LEN / 2.0 + 0.04, SHELF_H / 2.0, 0)])
	parts.append([Vector3(0.08, SHELF_H, SHELF_D), Vector3(SHELF_LEN / 2.0 - 0.04, SHELF_H / 2.0, 0)])
	parts.append([Vector3(SHELF_LEN, SHELF_H, 0.1), Vector3(0, SHELF_H / 2.0, 0)])  # spine panel
	parts.append([Vector3(SHELF_LEN, 0.08, SHELF_D), Vector3(0, SHELF_H - 0.04, 0)])  # top
	for level in [0.25, 1.43, 2.78, 4.13]:
		parts.append([Vector3(SHELF_LEN, 0.07, SHELF_D), Vector3(0, level, 0)])
	for p in parts:
		var bm := BoxMesh.new()
		bm.size = p[0]
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, p[1]))
	var mesh := st.commit()
	mesh.surface_set_material(0, _wood)
	return mesh

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.006)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.45, 0.33)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.035, 0.022)
	env.fog_density = 0.055
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# -- streaming -------------------------------------------------------------

func _player_cell() -> Vector2i:
	return Vector2i(roundi(_player.global_position.x / CELL), roundi(_player.global_position.z / CELL))

func _stream_cells(everything_now: bool) -> void:
	var center := _player_cell()
	var wanted: Array[Vector2i] = []
	for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var c := center + Vector2i(dx, dz)
			if not _cells.has(c):
				wanted.append(c)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center).length_squared() < (b - center).length_squared())
	var budget := wanted.size() if everything_now else BUILDS_PER_FRAME
	for i in mini(budget, wanted.size()):
		_build_cell(wanted[i])
	for c: Vector2i in _cells.keys():
		var d: Vector2i = (c - center).abs()
		if maxi(d.x, d.y) > UNLOAD_RADIUS:
			_cells[c].queue_free()
			_cells.erase(c)

# -- cell construction -----------------------------------------------------

func _build_cell(c: Vector2i) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(c.x * CELL, 0, c.y * CELL)
	_cells[c] = root

	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x) * 73856093 + int(c.y) * 19349663

	Forge.mesh(root, _floor_mesh, _floor_mat, Vector3(0, -0.2, 0))
	Forge.collider_box(root, Vector3(CELL, 0.4, CELL), Vector3(0, -0.2, 0))
	Forge.mesh(root, _ceiling_mesh, _ceiling_mat, Vector3(0, WALL_H + 0.2, 0))
	# Each cell owns its (-x, -z) corner column, so the lattice has no duplicates.
	var corner := Vector3(-CELL / 2.0, WALL_H / 2.0, -CELL / 2.0)
	Forge.mesh(root, _column_mesh, _stone_mat, corner)
	Forge.collider_cyl(root, 0.42, WALL_H, corner)

	# Each cell owns its west (-x) and north (-z) edges.
	_build_edge(root, rng, true)
	_build_edge(root, rng, false)

	_build_lamp(root, c)
	if c == Vector2i.ZERO:
		_build_entrance(root)
	else:
		_build_furniture(root, rng)

## A shelf-lined edge with a central doorway gap. `west` selects the -x edge,
## otherwise the -z edge.
func _build_edge(root: Node3D, rng: RandomNumberGenerator, west: bool) -> void:
	var inset := CELL / 2.0 - SHELF_D / 2.0 + 0.05
	for offset in [-4.4, 4.4]:
		var pos: Vector3
		var rot: Vector3
		if west:
			pos = Vector3(-inset, 0, offset)
			rot = Vector3(0, PI / 2.0, 0)
		else:
			pos = Vector3(offset, 0, -inset)
			rot = Vector3.ZERO
		var shelf := Node3D.new()
		root.add_child(shelf)
		shelf.position = pos
		shelf.rotation = rot
		Forge.mesh(shelf, _shelf_mesh, null, Vector3.ZERO)
		_fill_books(shelf, rng)
		var shape := BoxShape3D.new()
		shape.size = Vector3(SHELF_LEN, SHELF_H, SHELF_D)
		shelf.add_child(Interactable.make(shape, "Take down a book", func(p: Node) -> void:
			(p as Player).open_book(BookLore.random_book()),
			Transform3D(Basis.IDENTITY, Vector3(0, SHELF_H / 2.0, 0))))

func _fill_books(shelf: Node3D, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _book_mesh
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var rows := [0.25, 1.43, 2.78, 4.13]
	for face in [-1.0, 1.0]:
		for row: float in rows:
			var x := -SHELF_LEN / 2.0 + 0.18
			while x < SHELF_LEN / 2.0 - 0.18:
				var width := rng.randf_range(0.09, 0.16)
				if rng.randf() < 0.07:
					x += width  # an empty slot; someone is reading that one
					continue
				var height := rng.randf_range(0.62, 0.95)
				var depth := rng.randf_range(0.34, 0.44)
				var lean := 0.0
				if rng.randf() < 0.06:
					lean = rng.randf_range(-0.16, 0.16)
				var basis := Basis.from_euler(Vector3(0, 0, lean)).scaled(Vector3(width, height, depth))
				transforms.append(Transform3D(basis, Vector3(x + width / 2.0, row + 0.04 + height / 2.0, face * 0.28)))
				var c: Color = BOOK_COLORS[rng.randi() % BOOK_COLORS.size()]
				var v := rng.randf_range(0.8, 1.2)
				colors.append(Color(c.r * v, c.g * v, c.b * v))
				x += width + rng.randf_range(0.0, 0.02)
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _book_mat
	shelf.add_child(mmi)

func _build_lamp(root: Node3D, c: Vector2i) -> void:
	Forge.cyl(root, 0.03, 0.03, 1.2, _wood_dark, Vector3(0, WALL_H - 0.6, 0), Vector3.ZERO, 6)
	Forge.cyl(root, 0.45, 0.12, 0.35, _wood_dark, Vector3(0, WALL_H - 1.25, 0), Vector3.ZERO, 12)
	Forge.sphere(root, 0.18, _lamp_mat, Vector3(0, WALL_H - 1.5, 0))
	if (c.x + c.y) % 2 == 0:
		Forge.omni(root, Color(1.0, 0.78, 0.45), 1.1, 11.0, Vector3(0, WALL_H - 1.8, 0))

func _build_furniture(root: Node3D, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.22:
		# Reading table with a small stack of books and a candle.
		var table := Node3D.new()
		root.add_child(table)
		table.position = Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
		table.rotation.y = rng.randf() * TAU
		Forge.box(table, Vector3(2.2, 0.1, 1.1), _wood, Vector3(0, 0.85, 0))
		for corner_x in [-0.95, 0.95]:
			for corner_z in [-0.4, 0.4]:
				Forge.box(table, Vector3(0.09, 0.85, 0.09), _wood_dark, Vector3(corner_x, 0.42, corner_z))
		Forge.collider_box(table, Vector3(2.2, 0.95, 1.1), Vector3(0, 0.48, 0))
		for i in rng.randi_range(1, 3):
			var c: Color = BOOK_COLORS[rng.randi() % BOOK_COLORS.size()]
			Forge.box(table, Vector3(0.45, 0.07, 0.3), Forge.mat(c, 0.9),
				Vector3(rng.randf_range(-0.6, 0.6), 0.94 + i * 0.07, rng.randf_range(-0.25, 0.25)),
				Vector3(0, rng.randf() * TAU, 0))
		Forge.cyl(table, 0.04, 0.05, 0.22, Forge.mat(Color(0.9, 0.88, 0.8), 0.6), Vector3(0.7, 1.0, 0.2), Vector3.ZERO, 8)
		Forge.sphere(table, 0.045, Forge.mat(Color(1, 0.8, 0.4), 0.3, Color(1.0, 0.7, 0.3), 3.0), Vector3(0.7, 1.15, 0.2))
	elif roll < 0.34:
		# A pile of books somebody abandoned on the floor.
		var pile := Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-3.5, 3.5))
		for i in rng.randi_range(3, 7):
			var c: Color = BOOK_COLORS[rng.randi() % BOOK_COLORS.size()]
			Forge.box(root, Vector3(rng.randf_range(0.35, 0.5), 0.07, rng.randf_range(0.25, 0.35)), Forge.mat(c, 0.9),
				pile + Vector3(rng.randf_range(-0.1, 0.1), 0.04 + i * 0.07, rng.randf_range(-0.1, 0.1)),
				Vector3(0, rng.randf() * TAU, 0))
	elif roll < 0.42:
		# A worn rug.
		Forge.box(root, Vector3(rng.randf_range(2.5, 4.0), 0.03, rng.randf_range(1.8, 2.8)),
			Forge.mat(Color(0.35, 0.12, 0.12), 1.0),
			Vector3(rng.randf_range(-1.5, 1.5), 0.02, rng.randf_range(-1.5, 1.5)),
			Vector3(0, rng.randf() * TAU, 0))

## The entrance chamber: a freestanding stone arch holding the door back to
## the island, and a dais with the portal to the tower summit.
func _build_entrance(root: Node3D) -> void:
	var wood := Forge.mat(Color(0.32, 0.22, 0.13), 0.9)
	var arch := Node3D.new()
	root.add_child(arch)
	arch.position = Vector3(0, 0, 4.5)
	Forge.box(arch, Vector3(0.55, 3.4, 0.55), _stone_mat, Vector3(-1.3, 1.7, 0))
	Forge.box(arch, Vector3(0.55, 3.4, 0.55), _stone_mat, Vector3(1.3, 1.7, 0))
	Forge.box(arch, Vector3(3.4, 0.55, 0.6), _stone_mat, Vector3(0, 3.55, 0))
	Forge.box(arch, Vector3(2.05, 2.9, 0.18), wood, Vector3(0, 1.45, 0))
	Forge.sphere(arch, 0.09, Forge.mat(Color(0.8, 0.65, 0.2), 0.3), Vector3(-0.62, 1.4, 0.16))
	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(2.4, 3.1, 0.7)
	arch.add_child(Interactable.make(door_shape, "Return to the island", func(_p: Node) -> void:
		Game.travel(ISLAND, "tower_door"),
		Transform3D(Basis.IDENTITY, Vector3(0, 1.55, 0))))

	Forge.cyl(root, 2.3, 2.6, 0.35, _stone_mat, Vector3(0, 0.17, -3.8), Vector3.ZERO, 24)
	Forge.collider_cyl(root, 2.5, 0.4, Vector3(0, 0.17, -3.8))
	Forge.portal(root, Vector3(0, 0.35, -3.8), "Step through the portal", func(_p: Node) -> void:
		Game.travel(ISLAND, "tower_top"))

	# A worn rug between door and dais, and a brighter welcome.
	Forge.box(root, Vector3(2.6, 0.03, 5.0), Forge.mat(Color(0.36, 0.13, 0.13), 1.0), Vector3(0, 0.02, 0.4))
	Forge.omni(root, Color(1.0, 0.8, 0.5), 1.3, 13.0, Vector3(0, WALL_H - 2.0, 0.5))

# -- player ----------------------------------------------------------------

func _spawn_player() -> void:
	var spawns := {
		"entrance": Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 3.0)),
		"portal": Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(0, 0.6, -1.4)),
	}
	_player = PlayerScript.new()
	add_child(_player)
	var t: Transform3D = spawns.get(Game.spawn_point, spawns["entrance"])
	_player.global_transform = t
	_player.home_transform = spawns["entrance"]
	_player.fall_reset_y = -30.0
	# A warm lantern that travels with the reader.
	Forge.omni(_player.camera, Color(1.0, 0.82, 0.55), 1.3, 16.0, Vector3(0.3, -0.2, 0.3))
	if Game.spawn_point == "entrance":
		_player.show_message("The tower is larger inside than out.\nThe shelves hold every book ever written, and they do not end.\n\nShould you wander too deep, whistle (Q) — the library will lend you a page.", 11.0)

# -- the guide bird ----------------------------------------------------------
# The creative way home: a loose page folds itself into a paper bird that
# flies above the shelves toward the entrance, waiting if the reader falls
# behind, and dissolving over the portal dais.

const BIRD_ALTITUDE := 6.2
const BIRD_SPEED := 6.5
const BIRD_LEASH := 16.0

var _bird: Node3D
var _bird_wing_l: Node3D
var _bird_wing_r: Node3D
var _bird_phase := 0.0
var _bird_state := ""  # rise / fly / land

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("summon"):
		summon_guide_bird()
		get_viewport().set_input_as_handled()

func summon_guide_bird() -> void:
	if _bird:
		return
	_bird = Node3D.new()
	add_child(_bird)
	_bird.global_position = _player.global_position + Vector3(0, 1.6, 0)
	var paper := Forge.mat(Color(0.96, 0.94, 0.86), 0.6, Color(1.0, 0.95, 0.75), 0.9)
	Forge.box(_bird, Vector3(0.10, 0.07, 0.42), paper, Vector3.ZERO)
	Forge.box(_bird, Vector3(0.05, 0.05, 0.16), paper, Vector3(0, 0.06, -0.26), Vector3(0.5, 0, 0))
	Forge.box(_bird, Vector3(0.04, 0.10, 0.12), paper, Vector3(0, 0.05, 0.24), Vector3(-0.6, 0, 0))
	_bird_wing_l = Node3D.new()
	_bird.add_child(_bird_wing_l)
	Forge.box(_bird_wing_l, Vector3(0.5, 0.015, 0.24), paper, Vector3(-0.27, 0, 0))
	_bird_wing_r = Node3D.new()
	_bird.add_child(_bird_wing_r)
	Forge.box(_bird_wing_r, Vector3(0.5, 0.015, 0.24), paper, Vector3(0.27, 0, 0))
	Forge.omni(_bird, Color(1.0, 0.9, 0.6), 0.8, 6.0, Vector3.ZERO)
	_bird_state = "rise"
	_player.show_message("A loose page folds itself into wings. Follow.", 5.0)

func _bird_process(delta: float) -> void:
	if not _bird:
		return
	_bird_phase += delta
	var flap := sin(_bird_phase * 13.0) * 0.55
	_bird_wing_l.rotation.z = -flap
	_bird_wing_r.rotation.z = flap
	var pos := _bird.global_position
	match _bird_state:
		"rise":
			pos.y += delta * 3.0
			if pos.y >= BIRD_ALTITUDE:
				pos.y = BIRD_ALTITUDE
				_bird_state = "fly"
		"fly":
			var home := Vector3(0, BIRD_ALTITUDE, -3.8)
			var to_home := home - pos
			to_home.y = 0
			# Wait for the reader rather than abandoning them in the stacks.
			var player_gap := Vector2(pos.x - _player.global_position.x, pos.z - _player.global_position.z).length()
			if player_gap < BIRD_LEASH and to_home.length() > 1.0:
				pos += to_home.normalized() * BIRD_SPEED * delta
			pos.y = BIRD_ALTITUDE + sin(_bird_phase * 2.2) * 0.15
			if to_home.length() <= 1.0:
				_bird_state = "land"
			if to_home.length() > 0.5:
				var target := pos + to_home.normalized()
				_bird.look_at(Vector3(target.x, pos.y, target.z), Vector3.UP)
		"land":
			var dais := Vector3(0, 1.6, -3.8)
			pos = pos.move_toward(dais, delta * 2.5)
			_bird.scale = _bird.scale.move_toward(Vector3(0.05, 0.05, 0.05), delta * 0.45)
			if pos.distance_to(dais) < 0.2 or _bird.scale.x <= 0.07:
				_bird.queue_free()
				_bird = null
				return
	_bird.global_position = pos
