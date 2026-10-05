class_name MainMenu
extends Control

var title_label: Label
var subtitle_label: Label

func _ready() -> void:
	SaveManager.init_directories()
	_build_ui()

func _build_ui() -> void:
	# Dark bio-mechanical gradient background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1, 1.0)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Decorative background bio-cells
	var deco_node := Control.new()
	deco_node.set_anchors_preset(PRESET_FULL_RECT)
	add_child(deco_node)

	var center_vbox := VBoxContainer.new()
	center_vbox.set_anchors_preset(PRESET_CENTER)
	center_vbox.add_theme_constant_override("separation", 24)
	center_vbox.custom_minimum_size = Vector2(480, 0)
	add_child(center_vbox)

	# Title Banner
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 8)
	center_vbox.add_child(title_box)

	title_label = Label.new()
	title_label.text = "格  式  塔"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 54)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.8))
	title_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "GESTALT : 生物机械构装解谜"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9, 0.85))
	title_box.add_child(subtitle_label)

	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(300, 16)
	center_vbox.add_child(sep)

	# Menu Buttons
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 14)
	center_vbox.add_child(btn_vbox)

	var play_btn := _create_menu_button("开始游玩 (Play Levels)", Color(0.15, 0.85, 0.6))
	play_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn")
	)
	btn_vbox.add_child(play_btn)

	var editor_btn := _create_menu_button("关卡编辑器 (Level Editor)", Color(0.2, 0.7, 1.0))
	editor_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/LevelManager.tscn")
	)
	btn_vbox.add_child(editor_btn)

	var quit_btn := _create_menu_button("退出游戏 (Quit)", Color(0.8, 0.4, 0.4))
	quit_btn.pressed.connect(func():
		get_tree().quit()
	)
	btn_vbox.add_child(quit_btn)

	# Footer / Instructions hint
	var footer := Label.new()
	footer.text = "鼠标滚轮/双指缩放 | WASD平移 | Q/E旋转 | F反转 | G结构成组 | 空格开始模拟"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	center_vbox.add_child(footer)

	# Subtle pulsing animation on title
	var t := create_tween().set_loops()
	t.tween_property(title_label, "modulate", Color(1.1, 1.2, 1.2, 1.0), 2.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(title_label, "modulate", Color(0.9, 1.0, 1.0, 1.0), 2.0).set_trans(Tween.TRANS_SINE)

func _create_menu_button(btn_text: String, accent_color: Color) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(360, 52)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", accent_color)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.09, 0.13, 0.18, 0.85)
	normal_style.border_color = Color(0.2, 0.3, 0.45, 0.8)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.12, 0.18, 0.26, 0.95)
	hover_style.border_color = accent_color
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn
