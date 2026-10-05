class_name Toolbar
extends PanelContainer

signal block_type_selected(btype: int)
signal variant_changed(variant_idx: int)
signal sub_mode_toggled(sub_mode: int)
signal direction_changed(dir: int)
signal group_pressed()
signal clear_pressed()
signal save_machine_pressed()
signal load_machine_pressed()

var is_editor_mode: bool = false
var current_type: int = BlockData.Type.BASIC
var current_variant: int = 0
var current_dir: int = BlockData.Direction.RIGHT
var current_sub_mode: int = 0
var is_placing: bool = true # If false, select mode

# UI node references
var btn_group: ButtonGroup
var type_buttons: Dictionary = {} # type -> Button
var variant_btn: Button
var mode_btn: Button
var rotate_btn: Button
var pointer_btn: Button

func setup(p_is_editor_mode: bool) -> void:
	is_editor_mode = p_is_editor_mode
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var h_box := HBoxContainer.new()
	h_box.alignment = BoxContainer.ALIGNMENT_CENTER
	h_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_box.add_theme_constant_override("separation", 8)
	add_child(h_box)

	btn_group = ButtonGroup.new()

	# Pointer / Selection Tool Button
	pointer_btn = Button.new()
	pointer_btn.text = "选择 [V]"
	pointer_btn.toggle_mode = true
	pointer_btn.button_group = btn_group
	pointer_btn.focus_mode = Control.FOCUS_NONE
	pointer_btn.custom_minimum_size = Vector2(64, 32)
	pointer_btn.pressed.connect(func():
		is_placing = false
		block_type_selected.emit(-1)
	)
	h_box.add_child(pointer_btn)

	var sep1 := VSeparator.new()
	h_box.add_child(sep1)

	# Block buttons:
	# In player mode: 0..5 (Basic [1] to Rotator [6])
	# In editor mode: 0..9 (Basic [1] to Pollution [0])
	var max_type := BlockData.Type.POLLUTION if is_editor_mode else BlockData.Type.ROTATOR
	var shortcuts_labels := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

	for t in range(0, max_type + 1):
		var btn := Button.new()
		var short_lbl = shortcuts_labels[t] if t < shortcuts_labels.size() else ""
		var bname = BlockData.SHORT_NAMES.get(t, "方块")
		var full_bname = BlockData.TYPE_NAMES.get(t, "方块")
		btn.text = "%s [%s]" % [bname, short_lbl]
		btn.toggle_mode = true
		btn.button_group = btn_group
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(66, 32)
		
		# Set tooltip
		btn.tooltip_text = "【%s】\n点击选中方块进行放置。\n已选中时再次左键或右键可切换外观变体。\n快捷键: %s" % [full_bname, short_lbl]

		var type_val := t
		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and current_type == type_val and is_placing):
					# Cycle texture variant
					cycle_variant()
		)
		btn.pressed.connect(func():
			is_placing = true
			select_type(type_val)
		)

		type_buttons[t] = btn
		h_box.add_child(btn)

	var sep2 := VSeparator.new()
	h_box.add_child(sep2)

	# Variant cycling button
	variant_btn = Button.new()
	variant_btn.text = "变体: α"
	variant_btn.focus_mode = Control.FOCUS_NONE
	variant_btn.custom_minimum_size = Vector2(64, 32)
	variant_btn.tooltip_text = "切换方块外观纹理样式 (不影响逻辑功能)"
	variant_btn.pressed.connect(cycle_variant)
	h_box.add_child(variant_btn)

	# Submode toggle (for Rotator CW / CCW)
	mode_btn = Button.new()
	mode_btn.text = "转向: CW"
	mode_btn.focus_mode = Control.FOCUS_NONE
	mode_btn.custom_minimum_size = Vector2(68, 32)
	mode_btn.tooltip_text = "按 [F] 切换转向器顺逆时针模式 (CW 顺时针 / CCW 逆时针)"
	mode_btn.pressed.connect(toggle_sub_mode)
	h_box.add_child(mode_btn)

	# Direction Indicator / Rotate button
	rotate_btn = Button.new()
	rotate_btn.text = "朝向: →"
	rotate_btn.focus_mode = Control.FOCUS_NONE
	rotate_btn.custom_minimum_size = Vector2(64, 32)
	rotate_btn.tooltip_text = "当前放置朝向。按 [Q]/[E] 逆时针/顺时针旋转"
	rotate_btn.pressed.connect(func():
		rotate_direction(1)
	)
	h_box.add_child(rotate_btn)

	var sep3 := VSeparator.new()
	h_box.add_child(sep3)

	# Group / Structure button
	var group_btn := Button.new()
	group_btn.text = "编组 [G]"
	group_btn.focus_mode = Control.FOCUS_NONE
	group_btn.custom_minimum_size = Vector2(76, 32)
	group_btn.tooltip_text = "将选中的方块绑定为刚性整体结构（快捷键 G）"
	group_btn.pressed.connect(func():
		group_pressed.emit()
	)
	h_box.add_child(group_btn)

	# Select default
	select_type(BlockData.Type.BASIC)

func select_type(type_val: int) -> void:
	current_type = type_val
	is_placing = true
	if type_buttons.has(type_val):
		type_buttons[type_val].button_pressed = true
	block_type_selected.emit(type_val)
	_update_mode_visibility()

func select_pointer() -> void:
	is_placing = false
	pointer_btn.button_pressed = true
	block_type_selected.emit(-1)

func cycle_variant() -> void:
	current_variant = (current_variant + 1) % 3
	var labels := ["α", "β", "γ"]
	variant_btn.text = "变体: %s" % labels[current_variant]
	variant_changed.emit(current_variant)

func toggle_sub_mode() -> void:
	current_sub_mode = 1 if current_sub_mode == 0 else 0
	mode_btn.text = "转向: " + ("CW" if current_sub_mode == 0 else "CCW")
	sub_mode_toggled.emit(current_sub_mode)

func rotate_direction(step: int) -> void:
	current_dir = posmod(current_dir + step, 4)
	var arrows := ["→", "↓", "←", "↑"]
	rotate_btn.text = "朝向: %s [Q/E]" % arrows[current_dir]
	direction_changed.emit(current_dir)

func _update_mode_visibility() -> void:
	if mode_btn != null:
		mode_btn.visible = (current_type == BlockData.Type.ROTATOR)
