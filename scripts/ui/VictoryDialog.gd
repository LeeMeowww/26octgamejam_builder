class_name VictoryDialog
extends PanelContainer

signal next_level_pressed()
signal replay_pressed()
signal level_select_pressed()

var title_label: Label
var details_label: Label
var next_btn: Button

func _init() -> void:
	custom_minimum_size = Vector2(460, 280)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	style.border_color = Color(0.1, 0.9, 0.6, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	title_label = Label.new()
	title_label.text = "★ 关卡达成：格式塔共振！ ★"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.7))
	vbox.add_child(title_label)

	details_label = Label.new()
	details_label.text = "目标全部达成！\n所有坏疽病原体均已清除，高能质粒回收完毕。"
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(details_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)

	var replay_btn := Button.new()
	replay_btn.text = "重新调整"
	replay_btn.custom_minimum_size = Vector2(100, 42)
	replay_btn.pressed.connect(func():
		visible = false
		replay_pressed.emit()
	)
	btn_hbox.add_child(replay_btn)

	var list_btn := Button.new()
	list_btn.text = "关卡列表"
	list_btn.custom_minimum_size = Vector2(100, 42)
	list_btn.pressed.connect(func():
		visible = false
		level_select_pressed.emit()
	)
	btn_hbox.add_child(list_btn)

	next_btn = Button.new()
	next_btn.text = "进入下一关 >>"
	next_btn.custom_minimum_size = Vector2(130, 42)
	next_btn.pressed.connect(func():
		visible = false
		next_level_pressed.emit()
	)
	btn_hbox.add_child(next_btn)

func show_victory(step_count: int, has_next: bool) -> void:
	details_label.text = "目标达成！耗时 %d 个离散周期。\n所有坏疽病原体已净化，高能质粒回收完毕！" % step_count
	next_btn.visible = has_next
	visible = true
