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

var _reading := false
var _consume_interact := false
var _book_pages: Array = []
var _book_page_i := 0
var _seat: Node3D
var _book_root: Control
var _book_title: Label
var _book_author: Label
var _book_volume: Label
var _book_chapter: Label
var _book_body: Label
var _book_page: Label

func _ready() -> void:
	_build_body()
	_build_hud()
	# Noisy procedural terrain: allow steeper slopes than the 45° default
	# and snap harder to the ground so small bumps don't bounce the walk.
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.35
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
	# Text arrives after anchoring; grow from the center so it stays centered.
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH

	# A container band above the bottom of the screen keeps the message
	# panel positioned and sized correctly no matter when text arrives.
	var msg_holder := CenterContainer.new()
	msg_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(msg_holder)
	msg_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	msg_holder.offset_top = -360
	msg_holder.offset_bottom = -150

	_message_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.07, 0.78)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	_message_panel.add_theme_stylebox_override("panel", style)
	_message_panel.custom_minimum_size = Vector2(520, 0)
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.visible = false
	msg_holder.add_child(_message_panel)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_panel.add_child(_message_label)

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func() -> void: _message_panel.visible = false)
	add_child(_message_timer)

	_build_book_ui(hud)

## A full-screen open book: leather cover, two parchment pages, generated
## text. Shown by open_book(), dismissed with E/Esc, re-rolled with F.
func _build_book_ui(hud: CanvasLayer) -> void:
	_book_root = Control.new()
	_book_root.visible = false
	_book_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_book_root)
	_book_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var cover := PanelContainer.new()
	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = Color(0.20, 0.11, 0.08)
	cover_style.set_corner_radius_all(10)
	cover_style.set_content_margin_all(16)
	cover_style.border_color = Color(0.55, 0.42, 0.18)
	cover_style.set_border_width_all(2)
	cover.add_theme_stylebox_override("panel", cover_style)
	center.add_child(cover)

	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 0)
	cover.add_child(pages)

	var ink := Color(0.26, 0.19, 0.12)
	var faded := Color(0.42, 0.33, 0.24)

	var left := _make_page(Color(0.90, 0.85, 0.72))
	pages.add_child(left)
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(360, 470)
	left_box.add_theme_constant_override("separation", 12)
	left.add_child(left_box)
	left_box.add_child(_page_spacer())
	_book_title = _page_label(28, ink, HORIZONTAL_ALIGNMENT_CENTER)
	left_box.add_child(_book_title)
	_book_author = _page_label(15, faded, HORIZONTAL_ALIGNMENT_CENTER)
	left_box.add_child(_book_author)
	_book_volume = _page_label(13, faded, HORIZONTAL_ALIGNMENT_CENTER)
	left_box.add_child(_book_volume)
	left_box.add_child(_page_spacer())
	var ornament := _page_label(20, faded, HORIZONTAL_ALIGNMENT_CENTER)
	ornament.text = "—  ❦  —"
	left_box.add_child(ornament)
	left_box.add_child(_page_spacer())

	var spine := ColorRect.new()
	spine.color = Color(0.13, 0.07, 0.05)
	spine.custom_minimum_size = Vector2(8, 0)
	pages.add_child(spine)

	var right := _make_page(Color(0.93, 0.88, 0.76))
	pages.add_child(right)
	var right_box := VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(430, 470)
	right_box.add_theme_constant_override("separation", 12)
	right.add_child(right_box)
	_book_chapter = _page_label(15, ink, HORIZONTAL_ALIGNMENT_CENTER)
	right_box.add_child(_book_chapter)
	var rule := ColorRect.new()
	rule.color = Color(0.62, 0.52, 0.38)
	rule.custom_minimum_size = Vector2(0, 1)
	right_box.add_child(rule)
	_book_body = _page_label(14, ink, HORIZONTAL_ALIGNMENT_LEFT)
	_book_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(_book_body)
	_book_page = _page_label(12, faded, HORIZONTAL_ALIGNMENT_CENTER)
	right_box.add_child(_book_page)

	var hint := Label.new()
	hint.text = "F — leaf further    ·    E — close the book"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 28

func _make_page(tone: Color) -> PanelContainer:
	var page := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = tone
	style.set_corner_radius_all(3)
	style.set_content_margin_all(26)
	page.add_theme_stylebox_override("panel", style)
	return page

func _page_label(size: int, color: Color, halign: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = halign
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _page_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer

## Open the reading UI. Pass `pages` for a fixed text (the ruin's journal):
## F then leafs through those pages in order instead of pulling another
## random book off the shelf.
func open_book(book: Dictionary, pages: Array = []) -> void:
	_book_pages = pages
	_book_page_i = 0
	_fill_book(book)
	_book_root.visible = true
	_reading = true
	_prompt_label.text = ""
	_message_panel.visible = false

func close_book() -> void:
	_reading = false
	_book_root.visible = false

func _flip_page() -> void:
	if _book_pages.size() > 1:
		_book_page_i = (_book_page_i + 1) % _book_pages.size()
		_fill_book(_book_pages[_book_page_i])
	else:
		_fill_book(BookLore.random_book())

## Seat the player on a moving node (the boat). Position follows the seat;
## the head stays free to look around. stand() releases them.
func sit(seat: Node3D) -> void:
	_seat = seat
	velocity = Vector3.ZERO
	_prompt_label.text = ""

func stand() -> void:
	_seat = null

func _fill_book(book: Dictionary) -> void:
	_book_title.text = book.title
	_book_author.text = "by %s" % book.author
	_book_volume.text = "Volume %d" % book.volume
	_book_chapter.text = book.chapter
	_book_body.text = book.body
	_book_page.text = "— %d —" % book.page

func show_message(text: String, duration := 8.0) -> void:
	_message_label.text = text
	_message_panel.visible = true
	_message_timer.start(duration)

func _unhandled_input(event: InputEvent) -> void:
	if _reading:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			close_book()
			# The E press that closed the book is still just_pressed when
			# _update_interact() runs, with the ray still on the shelf —
			# eat it so it can't immediately take down another book.
			if event.is_action_pressed("interact"):
				_consume_interact = true
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("flip"):
			_flip_page()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
		camera.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if _seat:
		velocity = Vector3.ZERO
		global_position = _seat.global_position
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump") and not _reading:
		velocity.y = JUMP_VELOCITY

	if _reading:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * 10.0)
		move_and_slide()
		return

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
	var pressed := Input.is_action_just_pressed("interact")
	if pressed and _consume_interact:
		_consume_interact = false
		pressed = false
	if target and pressed:
		target.interact(self)
