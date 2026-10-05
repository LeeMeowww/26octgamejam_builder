class_name CameraController
extends Camera2D

@export var move_speed: float = 600.0
@export var min_zoom: float = 0.25
@export var max_zoom: float = 3.5
@export var zoom_step: float = 1.15

var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_cam_pos: Vector2 = Vector2.ZERO

# Multi-touch pinch & pan tracking
var active_touches: Dictionary = {} # index -> Vector2 (screen position)
var touch_prev_distance: float = 0.0
var touch_prev_midpoint: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	# Keyboard WASD / Arrow keys pan
	var input_vec := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_vec.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vec.y += 1.0

	if input_vec != Vector2.ZERO:
		position += input_vec.normalized() * (move_speed / zoom.x) * delta

func _unhandled_input(event: InputEvent) -> void:
	# Mouse Wheel Zoom centered on mouse cursor
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_point(zoom_step, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_point(1.0 / zoom_step, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start_mouse = get_viewport().get_mouse_position()
				drag_start_cam_pos = position
			else:
				is_dragging = false

	# Mouse Middle-Drag Pan
	elif event is InputEventMouseMotion and is_dragging:
		var current_mouse := get_viewport().get_mouse_position()
		var diff := current_mouse - drag_start_mouse
		position = drag_start_cam_pos - (diff / zoom.x)

	# Touch events (Mobile / Touchpad multi-touch)
	elif event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
		else:
			active_touches.erase(event.index)
			touch_prev_distance = 0.0

	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position
		if active_touches.size() == 2:
			# Multi-touch dual finger pinch & pan
			var t0: Vector2 = active_touches.values()[0]
			var t1: Vector2 = active_touches.values()[1]
			var current_dist := t0.distance_to(t1)
			var current_mid := (t0 + t1) * 0.5

			if touch_prev_distance > 0.0:
				var factor := current_dist / touch_prev_distance
				var mid_world := (current_mid - get_viewport_rect().size * 0.5) / zoom.x + position
				_zoom_at_point(factor, mid_world)

				# Pan by midpoint movement
				var mid_delta := current_mid - touch_prev_midpoint
				position -= mid_delta / zoom.x

			touch_prev_distance = current_dist
			touch_prev_midpoint = current_mid

func _zoom_at_point(factor: float, anchor_world_point: Vector2) -> void:
	var old_zoom := zoom.x
	var target_zoom := clampf(old_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(old_zoom, target_zoom):
		return

	zoom = Vector2(target_zoom, target_zoom)
	# Re-center so anchor_world_point remains under mouse
	var new_world_point := (get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5) / zoom.x + position
	position += (anchor_world_point - new_world_point)
