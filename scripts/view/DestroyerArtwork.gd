class_name DestroyerArtwork
extends Node2D

const IDLE_FRAMES := 8
const EAT_FRAMES := 16
const IDLE_FPS := 8.0
const EAT_FPS := 16.0
const CELL_ART_SCALE := 60.0 / 64.0
const RED_TINT := Color(1.0, 0.035, 0.035, 1.0)

var body: Sprite2D
var eye: EyeAnimator
var eat: Sprite2D
var _idle_time := 0.0
var _eat_time := 0.0
var _eating := false

func _ready() -> void:
	var red_material := ShaderMaterial.new()
	var red_shader := Shader.new()
	red_shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); float value = max(max(tex.r, tex.g), tex.b); COLOR = vec4(tint.rgb * value, tex.a * tint.a); }"
	red_material.shader = red_shader
	red_material.set_shader_parameter("tint", RED_TINT)
	body = _make_strip("Body", "res://scenes/animation/eat_cell(1).png", IDLE_FRAMES)
	body.material = red_material
	body.scale = Vector2.ONE * CELL_ART_SCALE
	eye = EyeAnimator.new()
	eye.name = "Eye"
	eye.configure("res://scenes/animation/eye_idle(1).png", "res://scenes/animation/eye_blink(1).png", 10, 1)
	eye.scale = Vector2.ONE * CELL_ART_SCALE
	eye.z_index = 2
	add_child(eye)
	eat = _make_strip("Eat", "res://scenes/animation/eating(1).png", EAT_FRAMES)
	# eating(1).png is authored as 16 frames of 128x64: exactly two cells.
	eat.material = red_material
	eat.scale = Vector2.ONE * CELL_ART_SCALE
	eat.position = Vector2(32.0, 0.0)
	eat.z_index = 1
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
	body.frame = int(_idle_time * IDLE_FPS) % IDLE_FRAMES
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
			eye.set_action_locked(false)

func play_eat() -> void:
	if _eating:
		return
	_eating = true
	_eat_time = 0.0
	eat.frame = 0
	eat.visible = true
	body.visible = false
	eye.visible = true
	eye.set_action_locked(true)

func set_direction(direction: int) -> void:
	rotation = posmod(direction, 4) * (PI / 2.0)
