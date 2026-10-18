class_name RotatorArtwork
extends Node2D

signal turn_finished

const TURN_FRAMES := 16
const TURN_FPS := 16.0
const CELL_SIZE := 64.0
const CELL_ART_SCALE := 60.0 / 64.0
const VIOLET_TINT := Color(0.82, 0.16, 1.0, 1.0)

var body: Sprite2D
var eye: EyeAnimator
var direction_marker: Sprite2D
var _turn_time := 0.0
var _turning := false
var _sub_mode := 0

func _ready() -> void:
	var violet_material := ShaderMaterial.new()
	var violet_shader := Shader.new()
	violet_shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); float value = max(max(tex.r, tex.g), tex.b); COLOR = vec4(tint.rgb * value, tex.a * tint.a); }"
	violet_material.shader = violet_shader
	violet_material.set_shader_parameter("tint", VIOLET_TINT)

	body = Sprite2D.new()
	body.name = "Body"
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.scale = Vector2.ONE * CELL_ART_SCALE
	# Keep the first cell centered on the rotator; the second cell extends forward.
	body.position = Vector2(CELL_SIZE * CELL_ART_SCALE * 0.5, 0.0)
	body.material = violet_material
	add_child(body)
	_set_body_texture()

	eye = EyeAnimator.new()
	eye.name = "Eye"
	eye.scale = Vector2.ONE * CELL_ART_SCALE
	eye.z_index = 2
	add_child(eye)

	direction_marker = Sprite2D.new()
	direction_marker.name = "DirectionMarker"
	direction_marker.z_index = 1
	direction_marker.scale = Vector2.ONE * 0.72
	direction_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(direction_marker)
	_set_direction_marker()

func _process(delta: float) -> void:
	if not _turning:
		return
	_turn_time += delta
	body.frame = mini(int(_turn_time * TURN_FPS), TURN_FRAMES - 1)
	if _turn_time >= float(TURN_FRAMES) / TURN_FPS:
		_turning = false
		_turn_time = 0.0
		body.frame = 0
		eye.set_action_locked(false)
		turn_finished.emit()

func set_direction(direction: int) -> void:
	rotation = posmod(direction, 4) * (PI / 2.0)

func set_sub_mode(sub_mode: int) -> void:
	_sub_mode = 0 if sub_mode == 0 else 1
	_set_body_texture()
	_set_direction_marker()

func play_turn() -> void:
	if body == null:
		return
	_set_body_texture()
	_turning = true
	_turn_time = 0.0
	body.frame = 0
	eye.set_action_locked(true)

func _set_body_texture() -> void:
	if body == null:
		return
	var texture_name := "turn_around_CW.png" if _sub_mode == 0 else "turn_around_CCW.png"
	body.texture = load("res://scenes/animation/" + texture_name)
	body.hframes = TURN_FRAMES
	body.frame = 0

func _set_direction_marker() -> void:
	if direction_marker == null:
		return
	var marker_name := "rotator_cw_marker.svg" if _sub_mode == 0 else "rotator_ccw_marker.svg"
	direction_marker.texture = load("res://assets/textures/blocks/" + marker_name)
