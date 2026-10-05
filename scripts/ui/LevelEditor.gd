class_name LevelEditor
extends Control

var current_level_data: LevelData
var world: GridWorld
var initial_snapshot: GridWorld
var sim_engine: SimulationEngine

# Visual nodes
var camera: CameraController
var grid_view: GridView
var toolbar: Toolbar
var ui_layer: CanvasLayer

# Top Bar controls
var level_name_lbl: Label
var play_btn: Button
var step_btn: Button
var reset_btn: Button
var save_level_btn: Button
var clear_level_btn: Button
var save_machine_btn: Button
var load_machine_btn: Button

# Build area visual editor controls
var set_build_area_btn: Button
var reset_build_area_btn: Button
var build_area_info_lbl: Label
var is_editing_build_area: bool = false
var is_dragging_build_area: bool = false
var build_area_drag_start: Vector2i = Vector2i.ZERO

var is_simulating: bool = false
var is_animating_tick: bool = false

# Mouse interaction
var is_mouse_placing: bool = false
var is_mouse_erasing: bool = false
var is_box_selecting: bool = false
var selected_blocks: Array[BlockData] = []
var box_select_start_world: Vector2 = Vector2.ZERO
var is_right_dragging_selection: bool = false
var right_drag_start_grid: Vector2i = Vector2i.ZERO
var right_drag_orig_positions: Dictionary = {} # BlockData -> Vector2i

func _ready() -> void:
	# Let board clicks reach _unhandled_input; UI panels still consume theirs.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	if current_level_data == null:
		var new_lvl := LevelData.new("custom_01", "新自定关卡")
		load_level(new_lvl)

func load_level(lvl: LevelData) -> void:
	current_level_data = lvl
	if level_name_lbl != null:
		level_name_lbl.text = "【关卡编辑】: %s" % lvl.level_name

	world = GridWorld.new()
	for item in lvl.blocks_data:
		if item is Dictionary:
			var b := BlockData.from_dict(item)
			world.add_block(b)

	initial_snapshot = world.clone()
	sim_engine = SimulationEngine.new(world)

	if grid_view != null:
		grid_view.is_level_editor_mode = true
		grid_view.player_build_area = lvl.player_build_area
		grid_view.set_world(world)

	if camera != null:
		var bounds := world.get_bounds()
		camera.position = Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y * 0.5) * 64.0

	_update_build_area_label()

func _update_build_area_label() -> void:
	if build_area_info_lbl == null or current_level_data == null:
		return
	var a := current_level_data.player_build_area
	if a.size == Vector2i.ZERO:
		build_area_info_lbl.text = "建造区: 全图允许"
	else:
		build_area_info_lbl.text = "建造区: (%d,%d) %dx%d" % [a.position.x, a.position.y, a.size.x, a.size.y]

func _build_ui() -> void:
	# Canvas
	var canvas_node := Node2D.new()
	canvas_node.name = "Canvas"
	add_child(canvas_node)

	grid_view = GridView.new()
	grid_view.name = "GridView"
	grid_view.is_level_editor_mode = true
	canvas_node.add_child(grid_view)

	camera = CameraController.new()
	camera.name = "Camera2D"
	canvas_node.add_child(camera)

	# UI Layer (Keeps UI pinned to screen, unaffected by Camera2D)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	# Top Bar
	var top_panel := PanelContainer.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	top_style.border_color = Color(0.2, 0.35, 0.5, 0.8)
	top_style.set_border_width_all(1)
	top_style.content_margin_left = 16
	top_style.content_margin_right = 16
	top_style.content_margin_top = 6
	top_style.content_margin_bottom = 6
	top_panel.add_theme_stylebox_override("panel", top_style)
	ui_layer.add_child(top_panel)
	top_panel.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 6)
	top_panel.add_child(top_vbox)

	# --- Row 1: Navigation, Level Name, and Build Area Tools ---
	var row1_hbox := HBoxContainer.new()
	row1_hbox.add_theme_constant_override("separation", 14)
	top_vbox.add_child(row1_hbox)

	var back_btn := Button.new()
	back_btn.text = "« 关卡管理"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/LevelManager.tscn")
	)
	row1_hbox.add_child(back_btn)

	level_name_lbl = Label.new()
	level_name_lbl.text = "【关卡编辑】"
	level_name_lbl.add_theme_font_size_override("font_size", 15)
	level_name_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	row1_hbox.add_child(level_name_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1_hbox.add_child(spacer)

	build_area_info_lbl = Label.new()
	build_area_info_lbl.text = "建造区: 全图允许"
	build_area_info_lbl.add_theme_font_size_override("font_size", 14)
	build_area_info_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.5))
	row1_hbox.add_child(build_area_info_lbl)

	# Build area visual edit tools
	set_build_area_btn = Button.new()
	set_build_area_btn.text = "框选建造区"
	set_build_area_btn.toggle_mode = true
	set_build_area_btn.focus_mode = Control.FOCUS_NONE
	set_build_area_btn.custom_minimum_size = Vector2(90, 32)
	set_build_area_btn.tooltip_text = "点击后在网格上按住左键拖拽，直观划定玩家建造区域"
	set_build_area_btn.toggled.connect(func(pressed: bool):
		is_editing_build_area = pressed
		if pressed:
			set_build_area_btn.text = "拖拽网格以设定..."
			set_build_area_btn.modulate = Color(0.3, 1.0, 0.6)
		else:
			set_build_area_btn.text = "框选建造区"
			set_build_area_btn.modulate = Color(1.0, 1.0, 1.0)
	)
	row1_hbox.add_child(set_build_area_btn)

	reset_build_area_btn = Button.new()
	reset_build_area_btn.text = "全图允许"
	reset_build_area_btn.focus_mode = Control.FOCUS_NONE
	reset_build_area_btn.custom_minimum_size = Vector2(76, 32)
	reset_build_area_btn.tooltip_text = "清除建造区限制（允许全图放置）"
	reset_build_area_btn.pressed.connect(func():
		if current_level_data:
			current_level_data.player_build_area = Rect2i()
			grid_view.player_build_area = Rect2i()
			grid_view.queue_redraw()
			_update_build_area_label()
	)
	row1_hbox.add_child(reset_build_area_btn)

	# --- Row 2: File/Blueprint and Test Simulation Controls ---
	var row2_hbox := HBoxContainer.new()
	row2_hbox.add_theme_constant_override("separation", 10)
	top_vbox.add_child(row2_hbox)

	clear_level_btn = Button.new()
	clear_level_btn.text = "清空画布"
	clear_level_btn.focus_mode = Control.FOCUS_NONE
	clear_level_btn.custom_minimum_size = Vector2(76, 32)
	clear_level_btn.tooltip_text = "清空关卡所有方块"
	clear_level_btn.pressed.connect(clear_all_blocks)
	row2_hbox.add_child(clear_level_btn)

	save_machine_btn = Button.new()
	save_machine_btn.text = "存图纸"
	save_machine_btn.focus_mode = Control.FOCUS_NONE
	save_machine_btn.custom_minimum_size = Vector2(64, 32)
	save_machine_btn.tooltip_text = "将当前机械结构保存为图纸"
	save_machine_btn.pressed.connect(_on_save_machine)
	row2_hbox.add_child(save_machine_btn)

	load_machine_btn = Button.new()
	load_machine_btn.text = "读图纸"
	load_machine_btn.focus_mode = Control.FOCUS_NONE
	load_machine_btn.custom_minimum_size = Vector2(64, 32)
	load_machine_btn.tooltip_text = "导入图纸"
	load_machine_btn.pressed.connect(_on_load_machine)
	row2_hbox.add_child(load_machine_btn)

	save_level_btn = Button.new()
	save_level_btn.text = "保存关卡"
	save_level_btn.focus_mode = Control.FOCUS_NONE
	save_level_btn.custom_minimum_size = Vector2(80, 32)
	save_level_btn.pressed.connect(save_level_layout)
	row2_hbox.add_child(save_level_btn)

	var sep_sim := VSeparator.new()
	row2_hbox.add_child(sep_sim)

	# Test simulation buttons
	play_btn = Button.new()
	play_btn.text = "测试 [空格]"
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.custom_minimum_size = Vector2(96, 32)
	play_btn.pressed.connect(toggle_simulation)
	row2_hbox.add_child(play_btn)

	step_btn = Button.new()
	step_btn.text = "单步"
	step_btn.focus_mode = Control.FOCUS_NONE
	step_btn.custom_minimum_size = Vector2(56, 32)
	step_btn.pressed.connect(step_tick)
	row2_hbox.add_child(step_btn)

	reset_btn = Button.new()
	reset_btn.text = "重置"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.custom_minimum_size = Vector2(56, 32)
	reset_btn.pressed.connect(reset_simulation)
	row2_hbox.add_child(reset_btn)

	# Bottom Toolbar (with all 10 blocks)
	toolbar = Toolbar.new()
	toolbar.name = "Toolbar"
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btm_style := StyleBoxFlat.new()
	btm_style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	btm_style.border_color = Color(0.2, 0.35, 0.5, 0.8)
	btm_style.set_border_width_all(1)
	btm_style.set_corner_radius_all(8)
	btm_style.content_margin_left = 12
	btm_style.content_margin_right = 12
	btm_style.content_margin_top = 8
	btm_style.content_margin_bottom = 8
	toolbar.add_theme_stylebox_override("panel", btm_style)
	ui_layer.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_top = -52
	toolbar.offset_bottom = 0

	toolbar.setup(true) # Editor mode allows all 10 types
	toolbar.block_type_selected.connect(_on_toolbar_block_selected)
	toolbar.variant_changed.connect(_on_toolbar_variant_changed)
	toolbar.sub_mode_toggled.connect(_on_toolbar_sub_mode_toggled)
	toolbar.direction_changed.connect(_on_toolbar_direction_changed)
	toolbar.group_pressed.connect(group_selected_blocks)

func toggle_simulation() -> void:
	if is_simulating:
		is_simulating = false
		play_btn.text = "测试 [空格]"
	else:
		initial_snapshot = world.clone()
		is_simulating = true
		play_btn.text = "暂停 [空格]"
		_run_sim_loop()

func step_tick() -> void:
	if is_animating_tick:
		return
	is_animating_tick = true
	var res := sim_engine.step_tick()
	grid_view.play_tick_animation(res, 0.3, func():
		is_animating_tick = false
	)

func reset_simulation() -> void:
	is_simulating = false
	is_animating_tick = false
	play_btn.text = "测试 [空格]"

	world = initial_snapshot.clone()
	sim_engine = SimulationEngine.new(world)
	grid_view.set_world(world)

func _run_sim_loop() -> void:
	if not is_simulating or is_animating_tick:
		return
	is_animating_tick = true
	var res := sim_engine.step_tick()
	grid_view.play_tick_animation(res, 0.35, func():
		is_animating_tick = false
		if is_simulating:
			_run_sim_loop()
	)

func save_level_layout() -> void:
	if current_level_data == null:
		return
	var blocks_list: Array = []
	for b in world.get_all_blocks():
		blocks_list.append(b.to_dict())
	current_level_data.blocks_data = blocks_list
	SaveManager.save_level(current_level_data)
	initial_snapshot = world.clone()

	# Visual confirmation
	save_level_btn.text = "✓ 已保存！"
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_callback(func():
		save_level_btn.text = "保存关卡"
	)

func _process(_delta: float) -> void:
	if grid_view != null and toolbar != null:
		var mouse_world := grid_view.get_global_mouse_position()
		var grid_pos := grid_view.world_to_grid(mouse_world)
		if toolbar.is_placing and not is_simulating and not is_editing_build_area:
			grid_view.update_preview(
				true,
				toolbar.current_type,
				toolbar.current_dir,
				toolbar.current_variant,
				toolbar.current_sub_mode,
				grid_pos
			)
		else:
			grid_view.update_preview(false, 0, 0, 0, 0, grid_pos)

func _unhandled_input(event: InputEvent) -> void:
	# Build area visual drag editing mode
	if is_editing_build_area:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_world := grid_view.get_global_mouse_position()
			var grid_pos := grid_view.world_to_grid(mouse_world)
			if event.pressed:
				is_dragging_build_area = true
				build_area_drag_start = grid_pos
				grid_view.player_build_area = Rect2i(grid_pos.x, grid_pos.y, 1, 1)
				grid_view.queue_redraw()
				if build_area_info_lbl != null:
					build_area_info_lbl.text = "框选中: (%d,%d) 1x1" % [grid_pos.x, grid_pos.y]
			elif is_dragging_build_area:
				is_dragging_build_area = false
				var x1 := mini(build_area_drag_start.x, grid_pos.x)
				var y1 := mini(build_area_drag_start.y, grid_pos.y)
				var w := absi(grid_pos.x - build_area_drag_start.x) + 1
				var h := absi(grid_pos.y - build_area_drag_start.y) + 1
				var new_area := Rect2i(x1, y1, w, h)
				current_level_data.player_build_area = new_area
				grid_view.player_build_area = new_area
				grid_view.queue_redraw()
				_update_build_area_label()
				set_build_area_btn.button_pressed = false
				is_editing_build_area = false
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseMotion and is_dragging_build_area:
			var mouse_world := grid_view.get_global_mouse_position()
			var grid_pos := grid_view.world_to_grid(mouse_world)
			var x1 := mini(build_area_drag_start.x, grid_pos.x)
			var y1 := mini(build_area_drag_start.y, grid_pos.y)
			var w := absi(grid_pos.x - build_area_drag_start.x) + 1
			var h := absi(grid_pos.y - build_area_drag_start.y) + 1
			grid_view.player_build_area = Rect2i(x1, y1, w, h)
			grid_view.queue_redraw()
			if build_area_info_lbl != null:
				build_area_info_lbl.text = "框选中: (%d,%d) %dx%d" % [x1, y1, w, h]
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("toggle_sim"):
		toggle_simulation()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code == KEY_R:
			reset_simulation()
			get_viewport().set_input_as_handled()
			return

	# Number keys: 1..9, 0 for all blocks
	# 1: Basic, 2: Inhibitor, 3: Pusher, 4: Replicator, 5: Destroyer, 6: Rotator, 7: Hard, 8: Wanderer, 9: Treasure, 0: Pollution
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code >= KEY_1 and code <= KEY_9:
			toolbar.select_type(code - KEY_1)
			get_viewport().set_input_as_handled()
			return
		elif code == KEY_0:
			toolbar.select_type(BlockData.Type.POLLUTION)
			get_viewport().set_input_as_handled()
			return
		elif code == KEY_MINUS:
			toolbar.select_type(BlockData.Type.PROTECTED)
			get_viewport().set_input_as_handled()
			return
		elif code == KEY_V:
			toolbar.pointer_btn.button_pressed = true
			toolbar.is_placing = false
			toolbar.block_type_selected.emit(-1)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("rotate_cw"):
		if not selected_blocks.is_empty():
			for b in selected_blocks:
				b.rotate_cw()
				var v := grid_view.get_view(b.block_id)
				if v != null:
					v.update_appearance()
		else:
			toolbar.rotate_direction(1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("rotate_ccw"):
		if not selected_blocks.is_empty():
			for b in selected_blocks:
				b.rotate_ccw()
				var v := grid_view.get_view(b.block_id)
				if v != null:
					v.update_appearance()
		else:
			toolbar.rotate_direction(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("flip_mode"):
		toolbar.toggle_sub_mode()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("group_structure"):
		group_selected_blocks()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			delete_selected_blocks()
			get_viewport().set_input_as_handled()
			return

	# Mouse clicks
	if event is InputEventMouseButton:
		var mouse_world := grid_view.get_global_mouse_position()
		var grid_pos := grid_view.world_to_grid(mouse_world)

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if toolbar.is_placing:
					is_mouse_placing = true
					_place_block_editor(grid_pos)
				else:
					if not Input.is_key_pressed(KEY_SHIFT):
						_clear_selection()
					var b := world.get_block(grid_pos)
					if b != null:
						_toggle_select(b)
					else:
						is_box_selecting = true
						box_select_start_world = mouse_world
						grid_view.is_box_selecting = true
						grid_view.box_select_start = mouse_world
						grid_view.box_select_current = mouse_world
						grid_view.queue_redraw()
			else:
				is_mouse_placing = false
				if is_box_selecting:
					is_box_selecting = false
					grid_view.is_box_selecting = false
					_finish_box_select()
					grid_view.queue_redraw()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var clicked_block := world.get_block(grid_pos)
				var is_on_selection := false
				if not selected_blocks.is_empty():
					if clicked_block != null and clicked_block in selected_blocks:
						is_on_selection = true
					elif clicked_block == null:
						var sel_bounds := _get_selection_bounds()
						if sel_bounds.grow(1).has_point(grid_pos):
							is_on_selection = true

				if is_on_selection:
					is_right_dragging_selection = true
					right_drag_start_grid = grid_pos
					right_drag_orig_positions.clear()
					for b in selected_blocks:
						right_drag_orig_positions[b] = b.grid_pos
				else:
					is_mouse_erasing = true
					_erase_block_editor(grid_pos)
			else:
				if is_right_dragging_selection:
					is_right_dragging_selection = false
					var final_delta := grid_pos - right_drag_start_grid
					if final_delta != Vector2i.ZERO:
						_apply_selection_drag(final_delta)
					else:
						for b in selected_blocks:
							var v := grid_view.get_view(b.block_id)
							if v != null:
								v.position = grid_view.grid_to_world(b.grid_pos)
					grid_view.queue_redraw()
				is_mouse_erasing = false

	elif event is InputEventMouseMotion:
		var mouse_world := grid_view.get_global_mouse_position()
		var grid_pos := grid_view.world_to_grid(mouse_world)

		if is_right_dragging_selection:
			var delta := grid_pos - right_drag_start_grid
			for b in selected_blocks:
				var v := grid_view.get_view(b.block_id)
				if v != null and right_drag_orig_positions.has(b):
					var preview_pos: Vector2i = right_drag_orig_positions[b] + delta
					v.position = grid_view.grid_to_world(preview_pos)
			grid_view.queue_redraw()
		elif is_mouse_placing:
			_place_block_editor(grid_pos)
		elif is_mouse_erasing:
			_erase_block_editor(grid_pos)
		elif is_box_selecting:
			grid_view.box_select_current = mouse_world
			grid_view.queue_redraw()

func _place_block_editor(grid_pos: Vector2i) -> void:
	if is_simulating:
		return
	world.remove_block_at(grid_pos)
	var new_block := BlockData.new(toolbar.current_type, grid_pos, toolbar.current_dir)
	new_block.texture_variant = toolbar.current_variant
	new_block.sub_mode = toolbar.current_sub_mode
	new_block.is_world_block = true
	world.add_block(new_block)
	initial_snapshot = world.clone()

func _erase_block_editor(grid_pos: Vector2i) -> void:
	if is_simulating:
		return
	world.remove_block_at(grid_pos)
	initial_snapshot = world.clone()

func _clear_selection() -> void:
	for b in selected_blocks:
		var v := grid_view.get_view(b.block_id)
		if v != null:
			v.is_selected = false
			v.queue_redraw()
	selected_blocks.clear()

func _toggle_select(b: BlockData) -> void:
	if b in selected_blocks:
		selected_blocks.erase(b)
		var v := grid_view.get_view(b.block_id)
		if v != null:
			v.is_selected = false
			v.queue_redraw()
	else:
		selected_blocks.append(b)
		var v := grid_view.get_view(b.block_id)
		if v != null:
			v.is_selected = true
			v.queue_redraw()

func _finish_box_select() -> void:
	var r := Rect2(box_select_start_world, grid_view.box_select_current - box_select_start_world).abs()
	var min_grid := grid_view.world_to_grid(r.position)
	var max_grid := grid_view.world_to_grid(r.position + r.size)

	for y in range(min_grid.y, max_grid.y + 1):
		for x in range(min_grid.x, max_grid.x + 1):
			var b := world.get_block(Vector2i(x, y))
			if b != null and b not in selected_blocks:
				selected_blocks.append(b)
				var v := grid_view.get_view(b.block_id)
				if v != null:
					v.is_selected = true
					v.queue_redraw()

func group_selected_blocks() -> void:
	if selected_blocks.is_empty():
		return
	world.group_blocks(selected_blocks)
	for b in selected_blocks:
		var v := grid_view.get_view(b.block_id)
		if v != null:
			v.update_appearance()
	initial_snapshot = world.clone()

func delete_selected_blocks() -> void:
	for b in selected_blocks:
		world.remove_block_at(b.grid_pos)
	selected_blocks.clear()
	initial_snapshot = world.clone()

func _get_selection_bounds() -> Rect2i:
	if selected_blocks.is_empty():
		return Rect2i()
	var min_p := Vector2i(999999, 999999)
	var max_p := Vector2i(-999999, -999999)
	for b in selected_blocks:
		min_p.x = mini(min_p.x, b.grid_pos.x)
		min_p.y = mini(min_p.y, b.grid_pos.y)
		max_p.x = maxi(max_p.x, b.grid_pos.x)
		max_p.y = maxi(max_p.y, b.grid_pos.y)
	return Rect2i(min_p.x, min_p.y, max_p.x - min_p.x + 1, max_p.y - min_p.y + 1)

func _apply_selection_drag(delta: Vector2i) -> void:
	if selected_blocks.is_empty() or delta == Vector2i.ZERO:
		return

	var new_positions: Dictionary = {}
	for b in selected_blocks:
		if right_drag_orig_positions.has(b):
			new_positions[b] = right_drag_orig_positions[b] + delta
		else:
			new_positions[b] = b.grid_pos + delta

	# 1. Remove unselected blocks colliding with new target positions
	for b in selected_blocks:
		var target_p: Vector2i = new_positions[b]
		var occupant := world.get_block(target_p)
		if occupant != null and occupant not in selected_blocks:
			world.remove_block_at(target_p)

	# 2. Batch move selected blocks
	var move_entries: Array[Dictionary] = []
	for b in selected_blocks:
		move_entries.append({
			"block": b,
			"old_pos": b.grid_pos,
			"new_pos": new_positions[b]
		})
	world.batch_move_blocks(move_entries)

	# 3. Synchronize views and visual appearance
	for b in selected_blocks:
		var v := grid_view.get_view(b.block_id)
		if v != null:
			v.position = grid_view.grid_to_world(b.grid_pos)
			v.update_appearance()

	initial_snapshot = world.clone()

func clear_all_blocks() -> void:
	world.clear()
	selected_blocks.clear()
	initial_snapshot = world.clone()
	sim_engine = SimulationEngine.new(world)

func _on_save_machine() -> void:
	var has_sel := not selected_blocks.is_empty()
	var target_parent: Node = ui_layer if ui_layer != null else self
	BlueprintDialogs.show_save_dialog(target_parent, has_sel, func(m_name: String, only_selected: bool):
		var target_blocks: Array[BlockData] = []
		if only_selected and not selected_blocks.is_empty():
			target_blocks = selected_blocks.duplicate()
		else:
			target_blocks = world.get_all_blocks().duplicate()
		SaveManager.save_machine(m_name, target_blocks)
	)

func _on_load_machine() -> void:
	var target_parent: Node = ui_layer if ui_layer != null else self
	BlueprintDialogs.show_load_dialog(target_parent, func(m_name: String):
		var blocks := SaveManager.load_machine(m_name)
		var center_grid := grid_view.world_to_grid(camera.position)
		for b in blocks:
			b.grid_pos = center_grid + b.grid_pos
			b.is_world_block = true
			world.add_block(b)
		initial_snapshot = world.clone()
	)

# -------------------------------------------------------------
# Toolbar signal handlers
# -------------------------------------------------------------
func _on_toolbar_block_selected(btype: int) -> void:
	pass

func _on_toolbar_variant_changed(variant_idx: int) -> void:
	if not selected_blocks.is_empty():
		for b in selected_blocks:
			b.texture_variant = variant_idx
			var v := grid_view.get_view(b.block_id)
			if v != null:
				v.update_appearance()

func _on_toolbar_sub_mode_toggled(mode: int) -> void:
	if not selected_blocks.is_empty():
		for b in selected_blocks:
			b.sub_mode = mode
			var v := grid_view.get_view(b.block_id)
			if v != null:
				v.update_appearance()

func _on_toolbar_direction_changed(dir: int) -> void:
	if not selected_blocks.is_empty():
		for b in selected_blocks:
			b.direction = dir
			var v := grid_view.get_view(b.block_id)
			if v != null:
				v.update_appearance()

