extends Node
## Drives the smoke test from outside the scene tree's current scene, so it
## survives Game.travel() scene changes. Stages are time-based because the
## fade transitions are.

var _time := 0.0
var _stage := 0
var _test_shelf: Interactable
var _bridge_west := Vector2.ZERO
var _bridge_dir := Vector2.ZERO
var _bridge_deck_y := 0.0

func _process(delta: float) -> void:
	_time += delta
	if _time > 62.0:
		_fail("timed out in stage %d" % _stage)
	match _stage:
		0:
			if _time > 1.0:
				_stage = 1
				_expect_scene("Island")
				if _expect_player():
					Game.travel("res://scenes/library.tscn", "entrance")
		1:
			if _time > 4.5:
				_stage = 2
				_expect_scene("Library")
				var p := _expect_player()
				if p and p.global_position.y < -1.0:
					_fail("player fell through the library floor")
				if p:
					var book := BookLore.random_book()
					for field in ["title", "author", "chapter", "body"]:
						if String(book[field]).is_empty():
							_fail("random_book produced an empty %s" % field)
					p.open_book(book)
					if not p._reading:
						_fail("open_book did not enter reading state")
					p.close_book()
					var library := get_tree().current_scene
					if library.has_method("summon_guide_bird"):
						library.summon_guide_bird()
					else:
						_fail("library has no summon_guide_bird")
					var candles: Variant = library.get("_candles")
					if not (candles is Array) or (candles as Array).is_empty():
						_fail("library has no floating candles")
					# Park a book-shelf interactable right under the crosshair
					# so the next stages can exercise the E key end to end.
					var shape := BoxShape3D.new()
					_test_shelf = Interactable.make(shape, "Take down a book",
						func(pl: Node) -> void: (pl as Player).open_book(BookLore.random_book()),
						Transform3D(Basis.IDENTITY, p.global_position + Vector3(0, 1.62, -2.0)))
					library.add_child(_test_shelf)
		2:
			if _time > 5.4:
				_stage = 3
				_press_interact(true)
		3:
			if _time > 6.0:
				_stage = 4
				_press_interact(false)
				var p := _expect_player()
				if p and not p._reading:
					_fail("pressing E at a shelf did not open a book")
		4:
			if _time > 6.5:
				_stage = 5
				_press_interact(true)
		5:
			if _time > 7.1:
				_stage = 6
				_press_interact(false)
				var p := _expect_player()
				if p and p._reading:
					_fail("E closed the book but immediately took down another (E acted like F)")
				if _test_shelf:
					_test_shelf.queue_free()
					_test_shelf = null
				Game.travel("res://scenes/island.tscn", "tower_top")
		6:
			if _time > 10.5:
				_stage = 7
				_expect_scene("Island")
				var p := _expect_player()
				if p and p.global_position.y < 30.0:
					_fail("expected player on the summit balcony, got y=%.1f" % p.global_position.y)
				elif p:
					Game.travel("res://scenes/island.tscn", "menu")
		7:
			if _time > 14.0:
				_stage = 8
				_expect_scene("Island")
				var cs := get_tree().current_scene
				if not cs.has_meta("main_menu"):
					_fail("menu spawn did not build the title screen")
				elif not cs.find_children("", "CharacterBody3D", true, false).is_empty():
					_fail("title screen should not spawn a player")
				else:
					Game.travel("res://scenes/forest.tscn", "jetty")
		8:
			if _time > 18.0:
				_stage = 9
				_expect_scene("Forest")
				var p := _expect_player()
				if p and p.global_position.y < -1.0:
					_fail("player fell through the forest")
				if p:
					var pages := BookLore.journal_pages()
					if pages.size() < 3:
						_fail("the wizard's journal has too few pages")
					for page in pages:
						for field in ["title", "chapter", "body"]:
							if String(page[field]).is_empty():
								_fail("journal page has an empty %s" % field)
					p.open_book(pages[0], pages)
					p._flip_page()
					if p._book_page_i != 1:
						_fail("F did not leaf to the journal's next page")
					p.close_book()
					if String(BookLore.tablet()["body"]).is_empty():
						_fail("the boundary stone has no inscription")
					# The secrets: every kept book and the stranger's note
					# must read, and returning all five must wake the ring.
					for i in BookLore.KEPT_COUNT:
						if String(BookLore.kept_book(i)["body"]).is_empty():
							_fail("kept book %d has no text" % i)
					if String(BookLore.stranger_note()["body"]).is_empty():
						_fail("the stranger's note is blank")
					var forest := get_tree().current_scene
					for i in BookLore.KEPT_COUNT:
						forest._collect_kept(i, p)
					p.close_book()
					if forest._kept_found.size() != BookLore.KEPT_COUNT:
						_fail("collecting every kept book did not register")
					if forest._ring_body.prompt != "Step through the wizard's last door":
						_fail("returning all five books did not wake the ring")
					# Walk across the footbridge with real held input: the
					# deck must meet the banks, no jumping required.
					_bridge_west = forest._abutment_b
					_bridge_dir = (forest._abutment_a - _bridge_west).normalized()
					_bridge_deck_y = forest._bridge_base
					var start := _bridge_west - _bridge_dir * 2.0
					var yaw := atan2(-_bridge_dir.x, -_bridge_dir.y)
					p.global_transform = Transform3D(Basis.from_euler(Vector3(0, yaw, 0)),
						Vector3(start.x, forest.height_at(start.x, start.y) + 0.4, start.y))
					p.velocity = Vector3.ZERO
					_walk(true)
		9:
			if _time > 19.6:
				_stage = 10
				var p := _expect_player()
				# Mid-crossing: on the deck, not wading in the stream below.
				if p and p.global_position.y < _bridge_deck_y - 0.5:
					_fail("waded through the stream instead of walking the bridge (y=%.1f)" % p.global_position.y)
		10:
			if _time > 22.5:
				_stage = 11
				var p := _expect_player()
				if p:
					var along := (Vector2(p.global_position.x, p.global_position.z) - _bridge_west).dot(_bridge_dir)
					if along < 9.0:
						_fail("could not walk across the footbridge, made it %.1fm" % along)
					# March straight at the boundary: the cliffs must stop
					# a held-forward walk without any invisible wall.
					var forest := get_tree().current_scene
					p.global_transform = Transform3D(Basis.from_euler(Vector3(0, -PI / 2.0, 0)),
						Vector3(119.0, forest.height_at(119.0, -20.0) + 0.4, -20.0))
					p.velocity = Vector3.ZERO
					_walk(true)
		11:
			if _time > 30.5:
				_stage = 12
				_walk(false)
				var p := _expect_player()
				# Eight seconds of held forward is ~40m on open ground; the
				# meandering wall foot sits at 116–149, so anything past 145
				# means the player crested the boundary.
				if p and p.global_position.x > 145.0:
					_fail("walked up and over the boundary cliffs, x=%.1f" % p.global_position.x)
				else:
					# Ride the arrival leg of the voyage end to end.
					Game.travel("res://scenes/forest.tscn", "voyage")
		12:
			if _time > 35.0:
				_stage = 13
				_expect_scene("Forest")
				var p := _expect_player()
				if p and p._seat == null:
					_fail("voyage spawn should seat the player in the boat")
		13:
			if _time > 48.0:
				_stage = 14
				var p := _expect_player()
				if p and p._seat != null:
					_fail("the boat never delivered the player to the jetty")
				elif p and (p.global_position.z < 70.0 or p.global_position.z > 92.0):
					_fail("disembarked in the wrong place, z=%.1f" % p.global_position.z)
				else:
					Game.travel("res://scenes/island.tscn", "dock")
		14:
			if _time > 51.5:
				_stage = 15
				_expect_scene("Island")
				var p := _expect_player()
				if p:
					# Walk the path's final climb to the tower door: the
					# plateau's south side must be a steady ramp, not a lip.
					var island := get_tree().current_scene
					p.global_transform = Transform3D(Basis.IDENTITY,
						Vector3(0, island.height_at(0.0, 8.0) + 0.4, 8.0))
					p.velocity = Vector3.ZERO
					_walk(true)
		15:
			if _time > 56.0:
				_stage = 16
				_walk(false)
				var p := _expect_player()
				if p and (p.global_position.z > -4.0 or p.global_position.y < 13.0):
					_fail("could not walk up to the tower door, stopped at z=%.1f y=%.1f" % [p.global_position.z, p.global_position.y])
				else:
					print("SMOKE OK")
					get_tree().quit(0)

## Feed a real E press/release through the input pipeline, so both the
## event path (_unhandled_input) and the polled path (is_action_just_pressed
## in _physics_process) see it — exactly like a player at the keyboard.
func _press_interact(pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = pressed
	Input.parse_input_event(ev)

## Hold (or release) the forward key, as if the player were walking.
func _walk(forward: bool) -> void:
	if forward:
		Input.action_press("move_forward")
	else:
		Input.action_release("move_forward")

func _expect_scene(expected: String) -> void:
	var cs := get_tree().current_scene
	var actual := cs.name if cs else &"<none>"
	if actual != expected:
		_fail("expected scene %s, got %s" % [expected, actual])

func _expect_player() -> Player:
	var found := get_tree().current_scene.find_children("", "CharacterBody3D", true, false)
	if found.is_empty():
		_fail("no player in scene")
		return null
	return found[0] as Player

func _fail(msg: String) -> void:
	print("SMOKE FAIL: ", msg)
	push_error("SMOKE FAIL: " + msg)
	get_tree().quit(1)
