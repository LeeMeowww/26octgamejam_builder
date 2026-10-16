class_name DestroyerArtwork
extends Node2D

const IDLE_FRAMES := 8
const EYE_FRAMES := 10
const EAT_FRAMES := 16
const IDLE_FPS := 8.0
const EYE_FPS := 10.0
const EAT_FPS := 16.0
const CELL_ART_SCALE := 60.0 / 64.0
const RED_TINT := Color(1.0, 0.035, 0.035, 1.0)

var body: Sprite2D
var eye: Sprite2D
var eat: Sprite2D
var _idle_time := 0.0
var _eye_time := 0.0
var _eat_time := 0.0
var _eating := false

func _ready() -> void:
	var red_material := ShaderMaterial.new()
	var red_shader := Shader.new()
	red_shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); float value = max(max(tex.r, tex.g), tex.b); COLOR = vec4(tint.rgb * value, tex.a * tint.a); }"
	red_material.shader = red_shader
	red_material.set_shader_parameter("tint", RED_TINT)
	body = _make_strip("Body", "res://scenes/animation/idle_animate.png", IDLE_FRAMES)
	body.material = red_material
	body.scale = Vector2.ONE * CELL_ART_SCALE
	eye = _make_strip("Eye", "res://scenes/animation/eye_blink(1).png", EYE_FRAMES)
	eye.scale = Vector2.ONE * CELL_ART_SCALE
	eat = _make_strip("Eat", "res://scenes/animation/eat.png", EAT_FRAMES)
	# eat.png is authored as 16 frames of 128x64: exactly two idle cells.
	eat.material = red_material
	eat.scale = Vector2.ONE * CELL_ART_SCALE
	eat.position = Vector2(32.0, 0.0)
	eat.z_index = 1
	eye.z_index = 2
	eat.visible = false

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
	_idle_time += delta
	_eye_time += delta
	body.frame = int(_idle_time * IDLE_FPS) % IDLE_FRAMES
	eye.frame = int(_eye_time * EYE_FPS) % EYE_FRAMES
	if _eating:
		body.visible = false
		eye.visible = true
		_eat_time += delta
		eat.frame = mini(int(_eat_time * EAT_FPS), EAT_FRAMES - 1)
		if _eat_time >= float(EAT_FRAMES) / EAT_FPS:
			_eating = false
			eat.visible = false
			body.visible = true
			eye.visible = true

func play_eat() -> void:
	if _eating:
		return
	_eating = true
	_eat_time = 0.0
	eat.frame = 0
	eat.visible = true
	body.visible = false
	eye.visible = true

func set_direction(direction: int) -> void:
	rotation = posmod(direction, 4) * (PI / 2.0)
