extends Node
## Drives the smoke test from outside the scene tree's current scene, so it
## survives Game.travel() scene changes. Stages are time-based because the
## fade transitions are.

var _time := 0.0
var _stage := 0

func _process(delta: float) -> void:
	_time += delta
	if _time > 17.0:
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
					Game.travel("res://scenes/island.tscn", "tower_top")
		2:
			if _time > 8.0:
				_stage = 3
				_expect_scene("Island")
				var p := _expect_player()
				if p and p.global_position.y < 30.0:
					_fail("expected player on the summit balcony, got y=%.1f" % p.global_position.y)
				elif p:
					Game.travel("res://scenes/island.tscn", "menu")
		3:
			if _time > 11.5:
				_stage = 4
				_expect_scene("Island")
				var cs := get_tree().current_scene
				if not cs.has_meta("main_menu"):
					_fail("menu spawn did not build the title screen")
				elif not cs.find_children("", "CharacterBody3D", true, false).is_empty():
					_fail("title screen should not spawn a player")
				else:
					print("SMOKE OK")
					get_tree().quit(0)

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
