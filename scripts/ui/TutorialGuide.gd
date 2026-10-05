extends PanelContainer

signal restart_requested()

var lesson: Dictionary = {}
var active_step := -1
var heading: Label
var dialogue: Label
var progress: Label
var task: Label
var reminder: Label
var restart_button: Button

func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101e2b")
	style.border_color = Color("#48cbb0")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	heading = _label(box, 18, Color("#71e5cc"))
	dialogue = _label(box, 15, Color("#d0dce7"))
	box.add_child(HSeparator.new())
	progress = _label(box, 13, Color("#71e5cc"))
	task = _label(box, 17, Color.WHITE)
	reminder = _label(box, 13, Color("#9aafc2"))
	reminder.text = "左键放置 · 右键擦除\nQ / E 调整箭头 · 单步观察结果\n放错了可以擦除；重置保留你的构装。"
	restart_button = Button.new()
	restart_button.text = "重新教学"
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.custom_minimum_size.y = 36
	restart_button.pressed.connect(func(): restart_requested.emit())
	box.add_child(restart_button)

func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func configure(data: Dictionary) -> void:
	lesson = data.duplicate(true)
	active_step = -1
	visible = not lesson.is_empty()
	heading.text = str(lesson.get("title", "母巢教学"))
	dialogue.text = str(lesson.get("intro", ""))
	_fit_height.call_deferred()

func _fit_height() -> void:
	# Wrapped labels settle after the panel receives its fixed width.
	size.y = get_combined_minimum_size().y

func _matches(world: GridWorld, step: Dictionary) -> bool:
	var block := world.get_block(Vector2i(int(step.get("x", 0)), int(step.get("y", 0))))
	if block == null or block.block_type != int(step.get("type", -1)):
		return false
	if step.has("dir") and block.direction != int(step.dir):
		return false
	if step.has("sub_mode") and block.sub_mode != int(step.sub_mode):
		return false
	return true

func next_step(world: GridWorld, ticks: int) -> int:
	var steps: Array = lesson.get("steps", [])
	if ticks == 0:
		for i in range(steps.size()):
			if not _matches(world, steps[i]): return i
	return steps.size()

func can_run(world: GridWorld, ticks: int) -> bool:
	return lesson.is_empty() or next_step(world, ticks) == lesson.get("steps", []).size()

func refresh(world: GridWorld, ticks: int, animating: bool) -> Dictionary:
	if lesson.is_empty(): return {}
	restart_button.disabled = animating
	var index := next_step(world, ticks)
	var steps: Array = lesson.get("steps", [])
	if index != active_step:
		active_step = index
		progress.text = "母巢导师 · %d / %d" % [index + 1, steps.size() + 1]
		if index < steps.size():
			task.text = str(steps[index].get("text", ""))
		else:
			task.text = str(lesson.get("run_text", "点击单步，观察方块的行动。"))
		_fit_height.call_deferred()
	if index < steps.size(): return steps[index]
	return {}
