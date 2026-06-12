class_name Player
extends CharacterBody3D
## First-person controller: WASD + mouse look, Shift to sprint, Space to
## jump, E to interact with whatever the crosshair rests on. Builds its own
## camera, collider and HUD so scenes can just instance the script.

const WALK_SPEED := 5.0
const SPRINT_SPEED := 9.0
const JUMP_VELOCITY := 4.6
const MOUSE_SENSITIVITY := 0.0025
const INTERACT_RANGE := 3.4

## Scenes set this; falling below it teleports the player back home.
var fall_reset_y := -2.5
var fall_message := ""
var home_transform := Transform3D.IDENTITY

var camera: Camera3D

var _ray: RayCast3D
var _pitch := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _prompt_label: Label
var _message_label: Label
var _message_panel: PanelContainer
var _message_timer: Timer

func _ready() -> void:
	_build_body()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_body() -> void:
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	cs.shape = capsule
	add_child(cs)
	cs.position = Vector3(0, 0.9, 0)

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.far = 1600.0
	add_child(camera)
	camera.position = Vector3(0, 1.62, 0)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -INTERACT_RANGE)
	camera.add_child(_ray)
	_ray.add_exception(self)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
	dot.custom_minimum_size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 19)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt_label.add_theme_constant_override("outline_size", 7)
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_prompt_label)
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position.y -= 110

	_message_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.07, 0.78)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	_message_panel.add_theme_stylebox_override("panel", style)
	_message_panel.custom_minimum_size = Vector2(520, 0)
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.visible = false
	hud.add_child(_message_panel)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_panel.add_child(_message_label)

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func() -> void: _message_panel.visible = false)
	add_child(_message_timer)

func show_message(text: String, duration := 8.0) -> void:
	_message_label.text = text
	_message_panel.visible = true
	_message_panel.reset_size()
	_message_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message_panel.position += Vector2(0, -170 - _message_panel.size.y)
	_message_timer.start(duration)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
		camera.rotation.x = _pitch
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 10.0)
	move_and_slide()

	if global_position.y < fall_reset_y:
		global_transform = home_transform
		velocity = Vector3.ZERO
		_pitch = 0.0
		camera.rotation.x = 0.0
		if fall_message != "":
			show_message(fall_message, 5.0)

	_update_interact()

func _update_interact() -> void:
	var target: Interactable = null
	if _ray.is_colliding():
		var hit := _ray.get_collider()
		if hit is Interactable:
			target = hit
	_prompt_label.text = "[E]  %s" % target.prompt if target else ""
	if target and Input.is_action_just_pressed("interact"):
		target.interact(self)
