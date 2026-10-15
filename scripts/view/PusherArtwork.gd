class_name PusherArtwork
extends Node2D

signal push_finished

const PUSH_FRAMES := 15
const EYE_FRAMES := 10
const PUSH_FPS := 15.0
const EYE_FPS := 10.0
const CELL_ART_SCALE := 60.0 / 64.0
const YELLOW_TINT := Color(1.0, 0.82, 0.035, 1.0)

var body: Sprite2D
var eye: Sprite2D
var _push_time := 0.0
var _eye_time := 0.0
var _pushing := false

func _ready() -> void:
	var yellow_material := ShaderMaterial.new()
	var yellow_shader := Shader.new()
	yellow_shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); float value = max(max(tex.r, tex.g), tex.b); COLOR = vec4(tint.rgb * value, tex.a * tint.a); }"
	yellow_material.shader = yellow_shader
	yellow_material.set_shader_parameter("tint", YELLOW_TINT)

	body = _make_strip("Body", "res://scenes/animation/push.png", PUSH_FRAMES)
	body.material = yellow_material
	body.scale = Vector2.ONE * CELL_ART_SCALE
	eye = _make_strip("Eye", "res://scenes/animation/eye_blink(1).png", EYE_FRAMES)
	eye.scale = Vector2.ONE * CELL_ART_SCALE
	eye.z_index = 2

func _make_strip(node_name: String, path: String, frame_count: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(path)
	sprite.hframes = frame_count
	sprite.frame = 0
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	_eye_time += delta
	eye.frame = int(_eye_time * EYE_FPS) % EYE_FRAMES
	if not _pushing:
		body.frame = 0
		return
	_push_time += delta
	body.frame = mini(int(_push_time * PUSH_FPS), PUSH_FRAMES - 1)
	if _push_time >= float(PUSH_FRAMES) / PUSH_FPS:
		_pushing = false
		body.frame = 0
		push_finished.emit()

func play_push() -> void:
	if _pushing:
		return
	_pushing = true
	_push_time = 0.0
	body.frame = 0

func set_direction(direction: int) -> void:
	rotation = posmod(direction, 4) * (PI / 2.0)
