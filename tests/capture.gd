extends Node3D
## Visual-check harness for movie-maker runs. Loads a scene and optionally
## parks a free camera, driven by environment variables so no throwaway
## scenes are needed:
##   CAP_SCENE  res:// path (default the forest)
##   CAP_SPAWN  spawn point handed to Game (default "jetty")
##   CAP_CAM    "x,y,z" for a fixed camera; omit to keep the player's view
##   CAP_LOOK   "x,y,z" the fixed camera looks at (default origin)
## Example:
##   Godot --path . res://tests/capture.tscn --write-movie /tmp/cap/f.png \
##     --fixed-fps 10 --quit-after 30

func _ready() -> void:
	var spawn := OS.get_environment("CAP_SPAWN")
	Game.spawn_point = spawn if spawn != "" else "jetty"
	var path := OS.get_environment("CAP_SCENE")
	if path == "":
		path = "res://scenes/forest.tscn"
	var scene: Node = load(path).instantiate()
	add_child(scene)
	var cam_s := OS.get_environment("CAP_CAM")
	if cam_s != "":
		var cam := Camera3D.new()
		cam.far = 1600.0
		add_child(cam)
		cam.position = _vec(cam_s)
		cam.look_at(_vec(OS.get_environment("CAP_LOOK")))
		cam.current = true

func _vec(s: String) -> Vector3:
	var parts := s.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
