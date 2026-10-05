class_name LevelManager
extends Control

var levels: Array[LevelData] = []
var selected_index: int = -1

# UI Nodes
var level_item_list: ItemList
var move_up_btn: Button
var move_down_btn: Button
var new_level_btn: Button
var delete_level_btn: Button

# Right-hand Property inputs
var prop_panel: PanelContainer
var id_edit: LineEdit
var name_edit: LineEdit
var desc_edit: TextEdit
var author_edit: LineEdit
var theme_opt: OptionButton
var build_area_summary_lbl: Label
var save_prop_btn: Button
var open_editor_btn: Button

func _ready() -> void:
	SaveManager.init_directories()
	levels = SaveManager.get_all_levels()
	_build_ui()
	if not levels.is_empty():
		_select_level(0)

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.11, 1.0)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	main_vbox.offset_left = 32
	main_vbox.offset_right = -32
	main_vbox.offset_top = 24
	main_vbox.offset_bottom = -24
	main_vbox.add_theme_constant_override("separation", 16)

	# Header
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(header_hbox)

	var back_btn := Button.new()
	back_btn.text = "« 返回主菜单"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.custom_minimum_size = Vector2(130, 40)
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
	header_hbox.add_child(back_btn)

	var title_lbl := Label.new()
	title_lbl.text = "关卡管理中心 (Level Manager)"
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	header_hbox.add_child(title_lbl)

	# Split view: Left = Level list with reordering; Right = Level properties
	var split_hbox := HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(split_hbox)

	# ----------------- LEFT PANEL (List & Order) -----------------
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(360, 0)
	left_vbox.add_theme_constant_override("separation", 10)
	split_hbox.add_child(left_vbox)

	var list_header := Label.new()
	list_header.text = "关卡列表 (可上下调整顺序)"
	list_header.add_theme_font_size_override("font_size", 16)
	list_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	left_vbox.add_child(list_header)

	level_item_list = ItemList.new()
	level_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_item_list.item_selected.connect(_select_level)
	level_item_list.item_activated.connect(func(idx: int):
		_select_level(idx)
		_on_open_level_editor()
	)
	left_vbox.add_child(level_item_list)

	# Buttons for reorder & create / delete
	var reorder_hbox := HBoxContainer.new()
	reorder_hbox.add_theme_constant_override("separation", 8)
	left_vbox.add_child(reorder_hbox)

	move_up_btn = Button.new()
	move_up_btn.text = "▲ 上移"
	move_up_btn.focus_mode = Control.FOCUS_NONE
	move_up_btn.pressed.connect(_on_move_up)
	reorder_hbox.add_child(move_up_btn)

	move_down_btn = Button.new()
	move_down_btn.text = "▼ 下移"
	move_down_btn.focus_mode = Control.FOCUS_NONE
	move_down_btn.pressed.connect(_on_move_down)
	reorder_hbox.add_child(move_down_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reorder_hbox.add_child(spacer)

	new_level_btn = Button.new()
	new_level_btn.text = "＋ 新建关卡"
	new_level_btn.focus_mode = Control.FOCUS_NONE
	new_level_btn.pressed.connect(_on_create_level)
	reorder_hbox.add_child(new_level_btn)

	delete_level_btn = Button.new()
	delete_level_btn.text = "删除关卡"
	delete_level_btn.focus_mode = Control.FOCUS_NONE
	delete_level_btn.pressed.connect(_on_delete_level)
	reorder_hbox.add_child(delete_level_btn)

	# ----------------- RIGHT PANEL (Properties Form) -----------------
	prop_panel = PanelContainer.new()
	prop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.09, 0.12, 0.17, 0.95)
	p_style.border_color = Color(0.2, 0.35, 0.5, 0.8)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(12)
	p_style.content_margin_left = 28
	p_style.content_margin_right = 28
	p_style.content_margin_top = 20
	p_style.content_margin_bottom = 20
	prop_panel.add_theme_stylebox_override("panel", p_style)
	split_hbox.add_child(prop_panel)

	var form_vbox := VBoxContainer.new()
	form_vbox.add_theme_constant_override("separation", 14)
	prop_panel.add_child(form_vbox)

	var form_title := Label.new()
	form_title.text = "关卡详细属性设置"
	form_title.add_theme_font_size_override("font_size", 18)
	form_title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.7))
	form_vbox.add_child(form_title)

	# Level ID
	var id_box := HBoxContainer.new()
	var id_lbl := Label.new()
	id_lbl.text = "关卡标识 ID: "
	id_lbl.custom_minimum_size = Vector2(120, 0)
	id_box.add_child(id_lbl)
	id_edit = LineEdit.new()
	id_edit.editable = false # immutable primary key
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_box.add_child(id_edit)
	form_vbox.add_child(id_box)

	# Level Name
	var name_box := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "关卡名称: "
	name_lbl.custom_minimum_size = Vector2(120, 0)
	name_box.add_child(name_lbl)
	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(name_edit)
	form_vbox.add_child(name_box)

	# Level Author
	var auth_box := HBoxContainer.new()
	var auth_lbl := Label.new()
	auth_lbl.text = "设计作者: "
	auth_lbl.custom_minimum_size = Vector2(120, 0)
	auth_box.add_child(auth_lbl)
	author_edit = LineEdit.new()
	author_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auth_box.add_child(author_edit)
	form_vbox.add_child(auth_box)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = "关卡任务描述与提示:"
	form_vbox.add_child(desc_lbl)
	desc_edit = TextEdit.new()
	desc_edit.custom_minimum_size = Vector2(0, 70)
	form_vbox.add_child(desc_edit)

	# CG / Theme Selection
	var theme_box := HBoxContainer.new()
	var theme_lbl := Label.new()
	theme_lbl.text = "关卡CG/视觉主题: "
	theme_lbl.custom_minimum_size = Vector2(120, 0)
	theme_box.add_child(theme_lbl)
	theme_opt = OptionButton.new()
	theme_opt.add_item("青色微管核心 (Cyan Core)", 0)
	theme_opt.add_item("紫电突触 (Purple Synapse)", 1)
	theme_opt.add_item("蔚蓝纤毛涡流 (Azure Cilia)", 2)
	theme_opt.add_item("异化毒瘴 (Toxic Magenta)", 3)
	theme_box.add_child(theme_opt)
	form_vbox.add_child(theme_box)

	# Player Build Area Info
	var area_lbl := Label.new()
	area_lbl.text = "玩家允许建造区域 (可在关卡编辑器内直接按住鼠标框选设定):"
	form_vbox.add_child(area_lbl)

	build_area_summary_lbl = Label.new()
	build_area_summary_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	form_vbox.add_child(build_area_summary_lbl)

	var btn_spacer := Control.new()
	btn_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_vbox.add_child(btn_spacer)

	# Bottom Actions HBox
	var action_hbox := HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_END
	action_hbox.add_theme_constant_override("separation", 16)
	form_vbox.add_child(action_hbox)

	save_prop_btn = Button.new()
	save_prop_btn.text = "保存关卡属性"
	save_prop_btn.focus_mode = Control.FOCUS_NONE
	save_prop_btn.custom_minimum_size = Vector2(130, 42)
	save_prop_btn.pressed.connect(_on_save_properties)
	action_hbox.add_child(save_prop_btn)

	open_editor_btn = Button.new()
	open_editor_btn.text = "进入关卡方块编辑 >>"
	open_editor_btn.focus_mode = Control.FOCUS_NONE
	open_editor_btn.custom_minimum_size = Vector2(160, 42)
	open_editor_btn.pressed.connect(_on_open_level_editor)
	action_hbox.add_child(open_editor_btn)

	_refresh_list()

func _refresh_list() -> void:
	level_item_list.clear()
	for i in range(levels.size()):
		var lvl := levels[i]
		level_item_list.add_item("%d. %s [%s]" % [i + 1, lvl.level_name, lvl.level_id])

	if selected_index >= 0 and selected_index < levels.size():
		level_item_list.select(selected_index)
	elif not levels.is_empty():
		_select_level(0)

func _select_level(idx: int) -> void:
	if idx < 0 or idx >= levels.size():
		return
	selected_index = idx
	level_item_list.select(idx)

	var lvl := levels[idx]
	id_edit.text = lvl.level_id
	name_edit.text = lvl.level_name
	desc_edit.text = lvl.description
	author_edit.text = lvl.author

	# Match theme
	match lvl.cg_theme:
		"cyan_core": theme_opt.selected = 0
		"purple_synapse": theme_opt.selected = 1
		"azure_cilia": theme_opt.selected = 2
		"toxic_magenta": theme_opt.selected = 3
		_: theme_opt.selected = 0

	if lvl.player_build_area.size == Vector2i.ZERO:
		build_area_summary_lbl.text = "当前设定: 【全图允许建造】（进入编辑器后可随时框选限定区域）"
	else:
		build_area_summary_lbl.text = "当前设定: 起点 (%d, %d)，尺寸 %d × %d（在编辑器顶部点击【框选建造区】可鼠标重划）" % [
			lvl.player_build_area.position.x, lvl.player_build_area.position.y,
			lvl.player_build_area.size.x, lvl.player_build_area.size.y
		]

func _on_save_properties() -> void:
	if selected_index < 0 or selected_index >= levels.size():
		return
	var lvl := levels[selected_index]
	lvl.level_name = name_edit.text.strip_edges()
	lvl.description = desc_edit.text.strip_edges()
	lvl.author = author_edit.text.strip_edges()

	var themes := ["cyan_core", "purple_synapse", "azure_cilia", "toxic_magenta"]
	var s_idx := clampi(theme_opt.selected, 0, themes.size() - 1)
	lvl.cg_theme = themes[s_idx]

	SaveManager.save_level(lvl)
	_refresh_list()

func _on_create_level() -> void:
	var new_id := "custom_level_%d" % [int(Time.get_unix_time_from_system()) % 100000]
	var new_lvl := LevelData.new(new_id, "新建自定关卡")
	new_lvl.order_index = levels.size()
	new_lvl.author = "造物主"
	new_lvl.player_build_area = Rect2i(-5, -4, 5, 8)
	SaveManager.save_level(new_lvl)

	levels = SaveManager.get_all_levels()
	_refresh_list()
	_select_level(levels.size() - 1)

func _on_delete_level() -> void:
	if selected_index < 0 or selected_index >= levels.size():
		return
	var lvl := levels[selected_index]
	SaveManager.delete_level(lvl.level_id)
	levels = SaveManager.get_all_levels()
	selected_index = mini(selected_index, levels.size() - 1)
	_refresh_list()

func _on_move_up() -> void:
	if selected_index <= 0:
		return
	var item = levels[selected_index]
	levels.remove_at(selected_index)
	levels.insert(selected_index - 1, item)
	selected_index -= 1

	var ids := []
	for l in levels:
		ids.append(l.level_id)
	SaveManager.reorder_levels(ids)
	_refresh_list()

func _on_move_down() -> void:
	if selected_index >= levels.size() - 1 or selected_index < 0:
		return
	var item = levels[selected_index]
	levels.remove_at(selected_index)
	levels.insert(selected_index + 1, item)
	selected_index += 1

	var ids := []
	for l in levels:
		ids.append(l.level_id)
	SaveManager.reorder_levels(ids)
	_refresh_list()

func _on_open_level_editor() -> void:
	if selected_index < 0 or selected_index >= levels.size():
		return
	_on_save_properties()
	var lvl := levels[selected_index]

	var editor_scene = load("res://scenes/ui/LevelEditor.tscn")
	var editor_instance: LevelEditor = editor_scene.instantiate()
	get_tree().root.add_child(editor_instance)
	editor_instance.load_level(lvl)
	get_tree().current_scene = editor_instance
	queue_free()
