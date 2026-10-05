class_name LevelSelect
extends Control

var levels: Array[LevelData] = []
var grid_container: GridContainer

func _ready() -> void:
	SaveManager.init_directories()
	levels = SaveManager.get_all_levels()
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.11, 1.0)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.offset_left = 40
	main_vbox.offset_right = -40
	main_vbox.offset_top = 30
	main_vbox.offset_bottom = -30
	add_child(main_vbox)

	# Header HBox
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header_hbox)

	var back_btn := Button.new()
	back_btn.text = "« 返回主菜单"
	back_btn.custom_minimum_size = Vector2(130, 42)
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
	header_hbox.add_child(back_btn)

	var title_vbox := VBoxContainer.new()
	header_hbox.add_child(title_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "格式塔 (Gestalt) - 关卡选择"
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "初次构装？先完成前 5 个教学关，认识六种基础方块，再挑战正式章节。"
	sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	title_vbox.add_child(sub_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	grid_container = GridContainer.new()
	grid_container.columns = 2
	grid_container.add_theme_constant_override("h_separation", 24)
	grid_container.add_theme_constant_override("v_separation", 24)
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_container)

	_populate_level_cards()

func _populate_level_cards() -> void:
	for idx in range(levels.size()):
		var lvl := levels[idx]
		var card := _create_level_card(lvl, idx)
		grid_container.add_child(card)

func _create_level_card(lvl: LevelData, idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 160)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.19, 0.9)
	style.border_color = Color(0.2, 0.5, 0.7, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	# Theme CG Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(72, 72)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_name := "treasure_0.svg" if idx % 2 == 0 else "inhibitor_0.svg"
	icon_rect.texture = BlockView._get_cached_texture("res://assets/textures/blocks/" + tex_name)
	hbox.add_child(icon_rect)

	# Info VBox
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%d. %s" % [idx + 1, lvl.level_name]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.9))
	info_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = lvl.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	info_vbox.add_child(desc_lbl)

	var author_lbl := Label.new()
	author_lbl.text = "作者: %s" % [lvl.author if not lvl.author.is_empty() else "未知母巢"]
	author_lbl.add_theme_font_size_override("font_size", 11)
	author_lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	info_vbox.add_child(author_lbl)

	# Play button
	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn_vbox)

	var enter_btn := Button.new()
	enter_btn.text = "开始挑战 ▶"
	enter_btn.custom_minimum_size = Vector2(110, 48)
	enter_btn.pressed.connect(func():
		_enter_level(idx)
	)
	btn_vbox.add_child(enter_btn)

	return panel

func _enter_level(idx: int) -> void:
	# Load LevelPlayer scene and pass level
	var scene_res = load("res://scenes/ui/LevelPlayer.tscn")
	var player_instance: LevelPlayer = scene_res.instantiate()
	get_tree().root.add_child(player_instance)
	player_instance.load_level_by_index(idx)
	get_tree().current_scene = player_instance
	queue_free()
