extends Node3D
## Visual-check harness for movie-maker runs. Loads a scene and optionally
## parks a free camera, driven by environment variables so no throwaway
## scenes are needed:
##   CAP_SCENE  res:// path (default the forest)
##   CAP_SPAWN  spawn point handed to Game (default "jetty")
##   CAP_CAM    "x,y,z" for a fixed camera; omit to keep the player's view
##   CAP_LOOK   "x,y,z" the fixed camera looks at (default origin)
##   CAP_BENCH_FRAMES  sample this many frames after 120 warmup frames,
##                     print timing/render counters, then quit (no movie).
## Example:
##   Godot --path . res://tests/capture.tscn --write-movie /tmp/cap/f.png \
##     --fixed-fps 10 --quit-after 30

var _bench_frames := 0
var _warmup := 120
var _last_tick := 0
var _frame_ms: Array[float] = []
var _draw_calls := 0.0
var _primitives := 0.0

func _ready() -> void:
	_bench_frames = maxi(0, OS.get_environment("CAP_BENCH_FRAMES").to_int())
	set_process(_bench_frames > 0)
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

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _warmup > 0:
		_warmup -= 1
		_last_tick = now
		return
	_frame_ms.append(float(now - _last_tick) / 1000.0)
	_last_tick = now
	_draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if _frame_ms.size() < _bench_frames:
		return
	_frame_ms.sort()
	print("CAP BENCH ", JSON.stringify({
		"frames": _bench_frames,
		"median_ms": _frame_ms[_bench_frames / 2],
		"p95_ms": _frame_ms[mini(_bench_frames - 1, ceili(_bench_frames * 0.95) - 1)],
		"mean_draw_calls": _draw_calls / _bench_frames,
		"mean_primitives": _primitives / _bench_frames,
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"display_driver": DisplayServer.get_name(),
	}))
	get_tree().quit()

func _vec(s: String) -> Vector3:
	var parts := s.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
