class_name EyeAnimator
extends Sprite2D

var idle_texture_path := "res://scenes/animation/eye_idle(1).png"
var blink_texture_path := "res://scenes/animation/eye_blink(1).png"
var idle_frames := 1
var blink_frames := 10
const BLINK_FPS := 12.0
const MIN_IDLE_TIME := 1.5
const MAX_IDLE_TIME := 4.5

var _rng := RandomNumberGenerator.new()
var _idle_time := 0.0
var _next_blink := 2.5
var _blink_time := 0.0
var _blinking := false
var _action_locked := false

func _ready() -> void:
	_rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_set_idle_frame()
	_schedule_next_blink()

func _process(delta: float) -> void:
	if _action_locked:
		_set_idle_frame()
		return
	if _blinking:
		_blink_time += delta
		frame = mini(int(_blink_time * BLINK_FPS), blink_frames - 1)
		if _blink_time >= float(blink_frames) / BLINK_FPS:
			_blinking = false
			_set_idle_frame()
			_schedule_next_blink()
		return
	_idle_time += delta
	if _idle_time >= _next_blink:
		_start_blink()

func set_action_locked(locked: bool) -> void:
	_action_locked = locked
	if locked:
		_blinking = false
		_set_idle_frame()
	else:
		_schedule_next_blink()

func configure(p_idle_texture_path: String, p_blink_texture_path: String, p_blink_frames: int, p_idle_frames: int = 1) -> void:
	idle_texture_path = p_idle_texture_path
	blink_texture_path = p_blink_texture_path
	blink_frames = p_blink_frames
	idle_frames = maxi(1, p_idle_frames)
	if is_inside_tree():
		_set_idle_frame()

func _start_blink() -> void:
	_blinking = true
	_blink_time = 0.0
	texture = load(blink_texture_path)
	hframes = blink_frames
	frame = 0

func _set_idle_frame() -> void:
	texture = load(idle_texture_path)
	hframes = idle_frames
	frame = 0

func _schedule_next_blink() -> void:
	_idle_time = 0.0
	_next_blink = _rng.randf_range(MIN_IDLE_TIME, MAX_IDLE_TIME)
