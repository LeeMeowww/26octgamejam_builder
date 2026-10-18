class_name EyeAnimator
extends Sprite2D

const IDLE_TEXTURE_PATH := "res://scenes/animation/eye_idle(1).png"
const BLINK_TEXTURE_PATH := "res://scenes/animation/eye_blink(1).png"
const BLINK_FRAMES := 10
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
		frame = mini(int(_blink_time * BLINK_FPS), BLINK_FRAMES - 1)
		if _blink_time >= float(BLINK_FRAMES) / BLINK_FPS:
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

func _start_blink() -> void:
	_blinking = true
	_blink_time = 0.0
	texture = load(BLINK_TEXTURE_PATH)
	hframes = BLINK_FRAMES
	frame = 0

func _set_idle_frame() -> void:
	texture = load(IDLE_TEXTURE_PATH)
	hframes = 1
	frame = 0

func _schedule_next_blink() -> void:
	_idle_time = 0.0
	_next_blink = _rng.randf_range(MIN_IDLE_TIME, MAX_IDLE_TIME)
