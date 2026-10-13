class_name SettingsMenu
extends Control

const UI = preload("res://scripts/ui/UIStyle.gd")

signal closed()

var tab_container: TabContainer
var key_buttons: Dictionary = {} # action_id -> Button
var listening_action: String = ""
var listening_button: Button = null

func _ready() -> void:
	theme = UI.get_theme()
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	# Dim background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.1, 0.9)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var main_panel := PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(680, 560)
	main_panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.BORDER, 16, 24))
	center.add_child(main_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	main_panel.add_child(main_vbox)

	# Header
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "游戏设置"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", UI.ACCENT)
	header_hbox.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_on_close_pressed)
	header_hbox.add_child(close_btn)

	# Multi-tab layout
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	tab_container.custom_minimum_size.y = 400
	main_vbox.add_child(tab_container)

	# Tab 1: 键盘设置
	var keyboard_tab := VBoxContainer.new()
	keyboard_tab.name = "键盘设置"
	keyboard_tab.add_theme_constant_override("separation", 10)
	tab_container.add_child(keyboard_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	keyboard_tab.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(list_vbox)

	# Populate keybind rows grouped by category
	var bindings: Dictionary = KeybindManager.get_bindings()
	var categories: Array[String] = ["编辑操作", "视角与模拟", "快捷方块"]

	for cat in categories:
		var cat_lbl := Label.new()
		cat_lbl.text = "【%s】" % cat
		cat_lbl.add_theme_font_size_override("font_size", 14)
		cat_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		list_vbox.add_child(cat_lbl)

		for act_key in bindings.keys():
			var act: String = str(act_key)
			var data: Dictionary = bindings[act]
			if data.get("category", "") != cat:
				continue

			var row := HBoxContainer.new()
			row.custom_minimum_size.y = 36
			list_vbox.add_child(row)

			var act_lbl := Label.new()
			act_lbl.text = data.get("label", act)
			act_lbl.add_theme_font_size_override("font_size", 15)
			act_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
			row.add_child(act_lbl)

			var key_btn := Button.new()
			key_btn.text = KeybindManager.get_action_display_name(act)
			key_btn.custom_minimum_size = Vector2(140, 32)
			key_btn.focus_mode = FOCUS_NONE
			var target_act: String = act
			key_btn.pressed.connect(func():
				_start_listening(target_act, key_btn)
			)
			row.add_child(key_btn)

			key_buttons[act] = key_btn

		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 10)
		list_vbox.add_child(sep)

	# Bottom actions
	var btm_hbox := HBoxContainer.new()
	btm_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(btm_hbox)

	var reset_btn := Button.new()
	reset_btn.text = "恢复默认设置"
	reset_btn.focus_mode = FOCUS_NONE
	reset_btn.custom_minimum_size = Vector2(130, 40)
	reset_btn.pressed.connect(_on_reset_defaults)
	btm_hbox.add_child(reset_btn)

	var btm_spacer := Control.new()
	btm_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	btm_hbox.add_child(btm_spacer)

	var save_btn := Button.new()
	UI.primary(save_btn)
	save_btn.text = "完成并返回"
	save_btn.focus_mode = FOCUS_NONE
	save_btn.custom_minimum_size = Vector2(130, 40)
	save_btn.pressed.connect(_on_close_pressed)
	btm_hbox.add_child(save_btn)

func _start_listening(act: String, btn: Button) -> void:
	if listening_button != null and listening_action != "":
		listening_button.text = KeybindManager.get_action_display_name(listening_action)
		listening_button.modulate = Color(1.0, 1.0, 1.0)

	listening_action = act
	listening_button = btn
	btn.text = "【请按下新按键...】"
	btn.modulate = Color(0.3, 1.0, 0.7)

func _input(event: InputEvent) -> void:
	if listening_action.is_empty() or listening_button == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		# Ignore standalone modifier key presses
		if code in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
			return

		get_viewport().set_input_as_handled()

		if code == KEY_ESCAPE and listening_action != "cancel_tool":
			# Cancel listening
			listening_button.text = KeybindManager.get_action_display_name(listening_action)
			listening_button.modulate = Color(1.0, 1.0, 1.0)
			listening_action = ""
			listening_button = null
			return

		# Set new binding
		KeybindManager.set_binding(listening_action, code, event.ctrl_pressed, event.shift_pressed, event.alt_pressed)
		listening_button.text = KeybindManager.get_action_display_name(listening_action)
		listening_button.modulate = Color(1.0, 1.0, 1.0)
		listening_action = ""
		listening_button = null

func _on_reset_defaults() -> void:
	KeybindManager.reset_to_defaults()
	_refresh_button_labels()

func _refresh_button_labels() -> void:
	for act in key_buttons.keys():
		var btn: Button = key_buttons[act]
		btn.text = KeybindManager.get_action_display_name(act)
		btn.modulate = Color(1.0, 1.0, 1.0)
	listening_action = ""
	listening_button = null

func _on_close_pressed() -> void:
	if listening_button != null and listening_action != "":
		listening_button.text = KeybindManager.get_action_display_name(listening_action)
		listening_button.modulate = Color(1.0, 1.0, 1.0)
		listening_action = ""
		listening_button = null
	hide()
	closed.emit()
