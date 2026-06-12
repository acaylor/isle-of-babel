extends Node
## Global game state: input map setup, fade transitions between areas,
## and the spawn point the next scene should place the player at.

const FADE_OUT := 0.45
const FADE_IN := 0.7

var spawn_point := "dock"

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Fade to black, switch scenes, fade back in. `spawn` names a spawn point
## the destination scene knows about (see island.gd / library.gd).
func travel(scene_path: String, spawn: String) -> void:
	if _busy:
		return
	_busy = true
	spawn_point = spawn
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_OUT)
	await out.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_IN)
	await back.finished
	_busy = false

func _setup_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("interact", KEY_E)

func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
