class_name MonsterArtwork
extends Node2D

const IDLE_FRAMES := 8
const IDLE_FPS := 8.0
const CELL_ART_SCALE := 60.0 / 64.0
## The supplied monster eye artwork faces left in its unrotated frame.
const ART_DIRECTION_OFFSET := 2

var body: Sprite2D
var eye: EyeAnimator
var _idle_time := 0.0

func _ready() -> void:
	body = Sprite2D.new()
	body.name = "Body"
	body.texture = load("res://scenes/animation/monster_idle.png")
	body.hframes = IDLE_FRAMES
	body.frame = 0
	body.scale = Vector2.ONE * CELL_ART_SCALE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body)

	eye = EyeAnimator.new()
	eye.name = "Eye"
	eye.configure(
		"res://scenes/animation/monster_blink(1).png",
		"res://scenes/animation/monster_blink(1).png",
		7,
		7
	)
	eye.scale = Vector2.ONE * CELL_ART_SCALE
	eye.z_index = 2
	add_child(eye)

func _process(delta: float) -> void:
	_idle_time += delta
	body.frame = int(_idle_time * IDLE_FPS) % IDLE_FRAMES

func set_direction(direction: int) -> void:
	rotation = posmod(direction + ART_DIRECTION_OFFSET, 4) * (PI / 2.0)

func get_direction_rotation(direction: int) -> float:
	return posmod(direction + ART_DIRECTION_OFFSET, 4) * (PI / 2.0)
