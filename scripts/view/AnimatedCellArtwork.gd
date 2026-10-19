class_name AnimatedCellArtwork
extends Node2D

const CELL_ART_SCALE := 60.0 / 64.0
var body: Sprite2D
var _frames := 1
var _fps := 8.0
var _time := 0.0

func configure(texture_path: String, frame_count: int = 8, fps: float = 8.0) -> void:
	_frames = maxi(frame_count, 1)
	_fps = maxf(fps, 0.01)
	if body == null:
		body = Sprite2D.new()
		body.name = "Body"
		body.scale = Vector2.ONE * CELL_ART_SCALE
		body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(body)
	body.texture = load(texture_path)
	body.hframes = _frames
	body.frame = 0

func _process(delta: float) -> void:
	if body == null:
		return
	_time += delta
	body.frame = int(_time * _fps) % _frames

func set_direction(direction: int) -> void:
	rotation = posmod(direction, 4) * (PI / 2.0)
