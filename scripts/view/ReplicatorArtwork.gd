class_name ReplicatorArtwork
extends Node2D

const BREED_FRAMES := 12
const BREED_PLAY_FRAMES := 8
const BREED_FPS := 12.0
const CELL_SIZE := 64.0
const CELL_ART_SCALE := 60.0 / 64.0
const GRAY_TINT := Color(0.86, 0.89, 0.93, 1.0)

var body: Sprite2D
var eye: EyeAnimator
var _breed_time := 0.0
var _breeding := false

func _ready() -> void:
	var gray_material := ShaderMaterial.new()
	var gray_shader := Shader.new()
	gray_shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; void fragment() { vec4 tex = texture(TEXTURE, UV); float value = max(max(tex.r, tex.g), tex.b); COLOR = vec4(tint.rgb * value, tex.a * tint.a); }"
	gray_material.shader = gray_shader
	gray_material.set_shader_parameter("tint", GRAY_TINT)

	body = Sprite2D.new()
	body.name = "Body"
	body.texture = load("res://scenes/animation/breed.png")
	body.hframes = BREED_FRAMES
	body.frame = 0
	body.scale = Vector2.ONE * CELL_ART_SCALE
	body.position = Vector2(CELL_SIZE * CELL_ART_SCALE * 0.5, 0.0)
	body.material = gray_material
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body)

	eye = EyeAnimator.new()
	eye.name = "Eye"
	eye.scale = Vector2.ONE * CELL_ART_SCALE
	eye.z_index = 2
	add_child(eye)

func _process(delta: float) -> void:
	if not _breeding:
		return
	_breed_time += delta
	body.frame = mini(int(_breed_time * BREED_FPS), BREED_PLAY_FRAMES - 1)
	if _breed_time >= float(BREED_PLAY_FRAMES) / BREED_FPS:
		_breeding = false
		_breed_time = 0.0
		body.frame = 0
		eye.set_action_locked(false)

func set_direction(direction: int) -> void:
	rotation = posmod(direction, 4) * (PI / 2.0)

func play_breed(_source_block: BlockData) -> void:
	if body == null:
		return
	_breeding = true
	_breed_time = 0.0
	body.frame = 0
	eye.set_action_locked(true)
