class_name RotatorArtwork
extends Node2D

const TURN_FRAMES := 16
const TURN_FPS := 16.0
const CELL_ART_SCALE := 60.0 / 64.0
const COPPER_TINT := Color(0.72, 0.34, 0.12, 1.0)

var body: Sprite2D
var eye: EyeAnimator
var direction_marker: Sprite2D
var _turn_time := 0.0
var _turn_duration := 1.0
var _turning := false
var _sub_mode := 0

func _ready() -> void:
	var purple_material := ShaderMaterial.new()
	var purple_shader := Shader.new()
	purple_shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); float value = max(max(tex.r, tex.g), tex.b); COLOR = vec4(tint.rgb * value, tex.a * tint.a); }"
	purple_material.shader = purple_shader
	purple_material.set_shader_parameter("tint", COPPER_TINT)
	body = Sprite2D.new()
	body.name = "Body"
	body.scale = Vector2.ONE * CELL_ART_SCALE
	body.position = Vector2(32.0 * CELL_ART_SCALE, 0.0)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.material = purple_material
	add_child(body)
	direction_marker = Sprite2D.new()
	direction_marker.name = "DirectionMarker"
	direction_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	direction_marker.scale = Vector2.ONE * 0.82
	direction_marker.position = Vector2.ZERO
	direction_marker.z_index = 1
	add_child(direction_marker)
	eye = EyeAnimator.new()
	eye.name = "Eye"
	eye.configure("res://scenes/animation/eye_idle(1).png", "res://scenes/animation/eye_blink(1).png", 10, 1)
	eye.scale = Vector2.ONE * CELL_ART_SCALE
	eye.z_index = 2
	add_child(eye)
	_set_texture()

func _process(delta: float) -> void:
	if not _turning:
		body.frame = 0
		return
	_turn_time += delta
	body.frame = mini(int((_turn_time / _turn_duration) * TURN_FRAMES), TURN_FRAMES - 1)
	if _turn_time >= _turn_duration:
		_turning = false
		_turn_time = 0.0
		body.frame = 0

func set_direction(direction: int) -> void:
	rotation = posmod(direction, 4) * (PI / 2.0)

func set_sub_mode(sub_mode: int) -> void:
	_sub_mode = posmod(sub_mode, 2)
	if body != null:
		_set_texture()

func _set_texture() -> void:
	body.texture = load("res://scenes/animation/turn_around_CW.png" if _sub_mode == 0 else "res://scenes/animation/turn_around_CCW.png")
	body.hframes = TURN_FRAMES
	body.frame = 0
	if direction_marker != null:
		direction_marker.texture = load("res://assets/textures/blocks/rotator_cw_marker.svg" if _sub_mode == 0 else "res://assets/textures/blocks/rotator_ccw_marker.svg")

func play_turn(duration: float = 1.0) -> void:
	_turning = true
	_turn_time = 0.0
	_turn_duration = maxf(duration, 0.01)
	body.frame = 0
