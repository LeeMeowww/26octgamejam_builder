class_name MainMenu
extends Control

const UI = preload("res://scripts/ui/UIStyle.gd")
const Campaign = preload("res://scripts/core/Campaign.gd")
var title_label: Label
var subtitle_label: Label
var settings_menu: SettingsMenu

func _ready() -> void:
	if title_label != null: return
	KeybindManager.init_keybinds()
	SaveManager.init_directories()
	theme = UI.get_theme()
	MusicManager.play_ambient()
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 90)
	center.add_child(row)
	var intro := VBoxContainer.new()
	intro.custom_minimum_size.x = 480
	intro.add_theme_constant_override("separation", 20)
	row.add_child(intro)
	UI.label(intro, "G E S T A L T   /   构 装 实 验 室", 15, UI.ACCENT)
	title_label = UI.label(intro, "格 式 塔", 68)
	subtitle_label = UI.label(intro, "让简单规则，长成复杂机械。", 24, UI.MUTED)
	var space := Control.new()
	space.custom_minimum_size.y = 12
	intro.add_child(space)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 16)
	intro.add_child(cells)
	for texture in ["inhibitor_0", "pusher_0", "replicator_0", "destroyer_0"]:
		var tile := TextureRect.new()
		tile.texture = load("res://assets/textures/blocks/" + texture + ".svg")
		tile.custom_minimum_size = Vector2(64, 64)
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cells.add_child(tile)
	UI.label(intro, "搭建  →  观察  →  改进", 20, UI.ACCENT)
	UI.label(intro, "没有唯一答案，只有你创造的下一种可能。", 16, UI.MUTED)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 360
	card.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.BORDER, 16, 28))
	row.add_child(card)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	card.add_child(actions)
	UI.label(actions, "开始一次构装", 24)
	UI.label(actions, "循着主线学习，也可以探索支线。", 15, UI.MUTED)
	var play := _button(actions, "探索章节地图  →")
	UI.primary(play)
	play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn"))
	var learn := _button(actions, "第一次来？从基础开始")
	learn.pressed.connect(func():
		Campaign.active_level = "tutorial_01"
		get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn")
	)
	actions.add_child(HSeparator.new())
	var editor := _button(actions, "创作工坊")
	editor.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/LevelManager.tscn"))
	var settings_btn := _button(actions, "系统设置")
	settings_btn.pressed.connect(func():
		settings_menu.visible = true
	)
	var quit_button := _button(actions, "退出游戏")
	quit_button.pressed.connect(func(): get_tree().quit())

	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	add_child(settings_menu)

	var footer := UI.label(self, "自由构装解谜   /   鼠标与键盘操作   /   关内可随时查看操作帮助", 14, UI.MUTED)
	footer.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	footer.offset_top = -50
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	parent.add_child(button)
	return button
