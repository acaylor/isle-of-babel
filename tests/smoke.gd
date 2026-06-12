extends Node
## Headless smoke test. Boots the island, travels into the library, then
## takes the portal to the tower summit, asserting at each step. Run with:
##   godot --headless --path . res://tests/smoke.tscn
## Prints SMOKE OK and exits 0 on success, exits 1 on failure.

func _ready() -> void:
	var observer: Node = preload("res://tests/observer.gd").new()
	get_tree().root.add_child.call_deferred(observer)
	Game.spawn_point = "dock"
	get_tree().change_scene_to_file.call_deferred("res://scenes/island.tscn")
