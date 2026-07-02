extends Node
## Global game state: input map setup, fade transitions between areas,
## the spawn point the next scene should place the player at, and the
## pause menu.

const VERSION := "0.3.0-alpha"
const FADE_OUT := 0.45
const FADE_IN := 0.7

## "menu" is a sentinel: the island scene builds the title screen with a
## cinematic camera instead of spawning the player.
var spawn_point := "menu"

var _fade: ColorRect
var _busy := false
var _menu: CanvasLayer
var _resume_button: Button

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
	_build_pause_menu()

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

## Quick fade for in-scene magic (the crystal): black out, run the action,
## fade back in.
func blink(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, 0.3)
	await out.finished
	action.call()
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.55)
	await back.finished
	_busy = false

# -- pause menu --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var cs := get_tree().current_scene
		if cs and cs.has_meta("main_menu"):
			return  # nothing to pause on the title screen
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	_menu.visible = tree.paused
	if tree.paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_resume_button.grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_pause_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 90
	_menu.visible = false
	add_child(_menu)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.62)
	_menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.11, 0.94)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(36)
	style.border_color = Color(0.45, 0.40, 0.25)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ISLE  OF  BABEL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.88, 0.82, 0.62))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "the world holds its breath"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	box.add_child(subtitle)

	box.add_child(HSeparator.new())

	_resume_button = menu_button("Resume")
	_resume_button.pressed.connect(toggle_pause)
	box.add_child(_resume_button)

	var to_menu := menu_button("Main Menu")
	to_menu.pressed.connect(func() -> void:
		toggle_pause()
		travel("res://scenes/island.tscn", "menu"))
	box.add_child(to_menu)

	var quit := menu_button("Quit")
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

## Shared button styling for the pause menu and the title screen.
func menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 46)
	b.add_theme_font_size_override("font_size", 19)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.13, 0.19)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.20, 0.19, 0.27)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.set_corner_radius_all(8)
	focus.border_color = Color(0.88, 0.82, 0.62)
	focus.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus)
	return b

# -- input map ---------------------------------------------------------------

func _setup_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("interact", KEY_E)
	_add_key_action("flip", KEY_F)
	_add_key_action("summon", KEY_Q)

func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
