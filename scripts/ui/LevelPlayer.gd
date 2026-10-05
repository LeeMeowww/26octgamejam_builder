class_name LevelPlayer
extends Control

const TutorialGuideScript = preload("res://scripts/ui/TutorialGuide.gd")
var tutorial_guide: TutorialGuideScript

signal back_to_menu_requested()

# Current level data & state
var current_level_data: LevelData
var current_level_index: int = 0
var all_levels: Array[LevelData] = []

var world: GridWorld
var initial_snapshot: GridWorld # For Reset functionality
var sim_engine: SimulationEngine

# Visual nodes
var camera: CameraController
var grid_view: GridView
var toolbar: Toolbar
var victory_dialog: VictoryDialog

# Top bar controls
var play_btn: Button
var step_btn: Button
var reset_btn: Button
var speed_slider: HSlider
var speed_label: Label
var goal_label: Label
var level_title_label: Label

# Simulation running state
var is_simulating: bool = false
var is_animating_tick: bool = false
var has_simulated: bool = false
var sim_speed_multiplier: float = 1.0 # 0.2x ~ 2.0x
var base_tick_duration: float = 0.35 # seconds
var ui_layer: CanvasLayer

# Selection & Editing state
var selected_blocks: Array[BlockData] = []
var is_mouse_placing: bool = false
var is_mouse_erasing: bool = false
var is_box_selecting: bool = false
var box_select_start_world: Vector2 = Vector2.ZERO
var is_right_dragging_selection: bool = false
var right_drag_start_grid: Vector2i = Vector2i.ZERO
var right_drag_orig_positions: Dictionary = {} # BlockData -> Vector2i

func _ready() -> void:
	# Let board clicks reach _unhandled_input; UI panels still consume theirs.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SaveManager.init_directories()
	all_levels = SaveManager.get_all_levels()

	_build_ui_layout()

	# If no specific level was set externally, load the first level
	if current_level_data == null:
		if not all_levels.is_empty():
			load_level_by_index(0)
		else:
			var default_lvl := LevelData.new("default", "启蒙空间")
			load_level_data(default_lvl)

func load_level_by_index(idx: int) -> void:
	if idx >= 0 and idx < all_levels.size():
		current_level_index = idx
		load_level_data(all_levels[idx])

func load_level_data(lvl_data: LevelData) -> void:
	selected_blocks.clear()
	if victory_dialog != null: victory_dialog.hide()
	current_level_data = lvl_data
	if level_title_label != null:
		level_title_label.text = "【%s】 %s" % [lvl_data.level_id, lvl_data.level_name]

	# Build world from level blocks
	world = GridWorld.new()
	for item in lvl_data.blocks_data:
		if item is Dictionary:
			var b := BlockData.from_dict(item)
			world.add_block(b)

	# Take pristine snapshot
	initial_snapshot = world.clone()

	# Setup simulation engine
	sim_engine = SimulationEngine.new(world, lvl_data.player_build_area)
	sim_engine.level_won.connect(_on_level_won)

	# Setup grid view
	if grid_view != null:
		grid_view.player_build_area = lvl_data.player_build_area
		grid_view.is_level_editor_mode = false
		grid_view.set_world(world)

	# Center camera
	if camera != null:
		var bounds := world.get_bounds()
		var center := Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y * 0.5) * 64.0
		camera.position = center
		if not lvl_data.tutorial.is_empty():
			# Keep the small teaching board to the left of the guide panel.
			camera.position = center + Vector2(160, 0)
			camera.zoom = Vector2.ONE

	is_simulating = false
	is_animating_tick = false
	has_simulated = false
	if tutorial_guide != null:
		tutorial_guide.configure(lvl_data.tutorial)
	_refresh_tutorial()
	_update_sim_buttons()
	_update_goal_display()

func _build_ui_layout() -> void:
	# 1. 2D World Canvas Node
	var canvas_node := Node2D.new()
	canvas_node.name = "Canvas"
	add_child(canvas_node)

	grid_view = GridView.new()
	grid_view.name = "GridView"
	canvas_node.add_child(grid_view)

	camera = CameraController.new()
	camera.name = "Camera2D"
	canvas_node.add_child(camera)

	# 2. UI Layer (Keeps UI pinned to screen, unaffected by Camera2D)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	var top_panel := PanelContainer.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.07, 0.1, 0.14, 0.9)
	top_style.border_color = Color(0.18, 0.25, 0.35, 0.8)
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

	# --- Row 1: Navigation, Level Info, and Goal Badge ---
	var row1_hbox := HBoxContainer.new()
	row1_hbox.add_theme_constant_override("separation", 16)
	top_vbox.add_child(row1_hbox)

	var back_btn := Button.new()
	back_btn.text = "« 关卡列表"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func():
		back_to_menu_requested.emit()
		get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn")
	)
	row1_hbox.add_child(back_btn)

	level_title_label = Label.new()
	level_title_label.text = "关卡标题"
	level_title_label.add_theme_font_size_override("font_size", 15)
	level_title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	row1_hbox.add_child(level_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1_hbox.add_child(spacer)

	# Goal status display (Pill badge)
	goal_label = Label.new()
	goal_label.text = "[目标] 污染源剩余: 0 | 待回收宝藏: 0"
	goal_label.add_theme_font_size_override("font_size", 14)
	goal_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	row1_hbox.add_child(goal_label)

	# --- Row 2: Blueprint Management & Simulation Controls ---
	var row2_hbox := HBoxContainer.new()
	row2_hbox.add_theme_constant_override("separation", 10)
	top_vbox.add_child(row2_hbox)

	var clear_btn := Button.new()
	clear_btn.text = "新建清空"
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.custom_minimum_size = Vector2(76, 32)
	clear_btn.tooltip_text = "清空建造区内所有自建方块"
	clear_btn.pressed.connect(clear_player_blocks)
	row2_hbox.add_child(clear_btn)

	var save_btn := Button.new()
	save_btn.text = "存图纸"
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.custom_minimum_size = Vector2(64, 32)
	save_btn.tooltip_text = "将当前建造的机械保存为图纸"
	save_btn.pressed.connect(_on_save_machine_pressed)
	row2_hbox.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "读图纸"
	load_btn.focus_mode = Control.FOCUS_NONE
	load_btn.custom_minimum_size = Vector2(64, 32)
	load_btn.tooltip_text = "加载已保存的机械图纸"
	load_btn.pressed.connect(_on_load_machine_pressed)
	row2_hbox.add_child(load_btn)

	var sep_sim := VSeparator.new()
	row2_hbox.add_child(sep_sim)

	# Sim control buttons
	play_btn = Button.new()
	play_btn.text = "开始 [空格]"
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.custom_minimum_size = Vector2(96, 32)
	play_btn.pressed.connect(toggle_simulation)
	row2_hbox.add_child(play_btn)

	step_btn = Button.new()
	step_btn.text = "单步"
	step_btn.focus_mode = Control.FOCUS_NONE
	step_btn.custom_minimum_size = Vector2(56, 32)
	step_btn.pressed.connect(step_single_tick)
	row2_hbox.add_child(step_btn)

	reset_btn = Button.new()
	reset_btn.text = "重置 [R]"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.custom_minimum_size = Vector2(64, 32)
	reset_btn.tooltip_text = "重置关卡到初始状态 (快捷键: R)"
	reset_btn.pressed.connect(reset_simulation)
	row2_hbox.add_child(reset_btn)

	var sep2 := VSeparator.new()
	row2_hbox.add_child(sep2)

	# Speed slider: 0.2x to 2.0x
	var speed_hbox := HBoxContainer.new()
	speed_hbox.add_theme_constant_override("separation", 6)
	row2_hbox.add_child(speed_hbox)

	var speed_title := Label.new()
	speed_title.text = "速度:"
	speed_hbox.add_child(speed_title)

	speed_slider = HSlider.new()
	speed_slider.focus_mode = Control.FOCUS_NONE
	speed_slider.min_value = 0.2
	speed_slider.max_value = 2.0
	speed_slider.step = 0.1
	speed_slider.value = 1.0
	speed_slider.custom_minimum_size = Vector2(80, 20)
	speed_slider.value_changed.connect(func(val: float):
		sim_speed_multiplier = val
		speed_label.text = "%.1fx" % val
	)
	speed_hbox.add_child(speed_slider)

	speed_label = Label.new()
	speed_label.text = "1.0x"
	speed_hbox.add_child(speed_label)

	# 3. Bottom Toolbar
	toolbar = Toolbar.new()
	toolbar.name = "Toolbar"
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btm_style := StyleBoxFlat.new()
	btm_style.bg_color = Color(0.07, 0.1, 0.14, 0.92)
	btm_style.border_color = Color(0.18, 0.25, 0.35, 0.8)
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

	toolbar.setup(false) # Player mode
	toolbar.block_type_selected.connect(_on_toolbar_block_selected)
	toolbar.variant_changed.connect(_on_toolbar_variant_changed)
	toolbar.sub_mode_toggled.connect(_on_toolbar_sub_mode_toggled)
	toolbar.direction_changed.connect(_on_toolbar_direction_changed)
	toolbar.group_pressed.connect(group_selected_blocks)

	# Optional teaching panel; ordinary levels have no lesson data.
	tutorial_guide = TutorialGuideScript.new()
	ui_layer.add_child(tutorial_guide)
	tutorial_guide.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	tutorial_guide.offset_left = -336
	tutorial_guide.offset_right = -16
	tutorial_guide.offset_top = 108
	tutorial_guide.offset_bottom = 108
	tutorial_guide.restart_requested.connect(func():
		if not is_animating_tick: load_level_data(current_level_data)
	)

	# 4. Victory Dialog (Hidden initially)
	victory_dialog = VictoryDialog.new()
	victory_dialog.visible = false
	ui_layer.add_child(victory_dialog)
	victory_dialog.set_anchors_and_offsets_preset(PRESET_CENTER)
	victory_dialog.resized.connect(_center_victory_dialog)
	victory_dialog.next_level_pressed.connect(_on_next_level_pressed)
	victory_dialog.replay_pressed.connect(reset_simulation)
	victory_dialog.level_select_pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn")
	)

# -------------------------------------------------------------
# Simulation Flow
# -------------------------------------------------------------
func toggle_simulation() -> void:
	if is_simulating:
		pause_simulation()
	else:
		start_simulation()

func start_simulation() -> void:
	if not _tutorial_can_run(): return
	if is_simulating:
		return
	is_simulating = true
	has_simulated = true
	_update_sim_buttons()
	_run_sim_loop()

func pause_simulation() -> void:
	is_simulating = false
	_update_sim_buttons()

func step_single_tick() -> void:
	if not _tutorial_can_run(): return
	if is_animating_tick:
		return
	has_simulated = true
	_update_sim_buttons()
	_execute_tick()

func reset_simulation() -> void:
	is_simulating = false
	is_animating_tick = false
	has_simulated = false
	victory_dialog.visible = false

	# Restore from initial snapshot
	world = initial_snapshot.clone()
	var b_area := current_level_data.player_build_area if current_level_data else Rect2i()
	sim_engine = SimulationEngine.new(world, b_area)
	sim_engine.level_won.connect(_on_level_won)
	grid_view.set_world(world)

	_update_sim_buttons()
	_update_goal_display()
	_refresh_tutorial()

func _run_sim_loop() -> void:
	if not is_simulating:
		return
	if is_animating_tick:
		return
	_execute_tick()

func _execute_tick() -> void:
	is_animating_tick = true
	var res := sim_engine.step_tick()
	_update_goal_display()

	var duration := base_tick_duration / sim_speed_multiplier
	grid_view.play_tick_animation(res, duration, func():
		is_animating_tick = false
		if res.is_victory:
			pause_simulation()
		elif is_simulating:
			_run_sim_loop()
	)

func _on_level_won() -> void:
	pause_simulation()
	var has_next := (current_level_index + 1 < all_levels.size())
	victory_dialog.show_victory(sim_engine.step_count, has_next)
	if not current_level_data.tutorial.is_empty():
		victory_dialog.details_label.text = str(current_level_data.tutorial.get("success", "学会了！继续下一课吧。"))
	_center_victory_dialog.call_deferred()

func _center_victory_dialog() -> void:
	victory_dialog.position = (get_viewport_rect().size - victory_dialog.size) * 0.5

func _tutorial_can_run() -> bool:
	return tutorial_guide == null or tutorial_guide.can_run(world, sim_engine.step_count)

func _refresh_tutorial() -> void:
	if tutorial_guide == null or world == null or sim_engine == null: return
	var target: Dictionary = tutorial_guide.refresh(world, sim_engine.step_count, is_animating_tick)
	if grid_view.tutorial_target != target:
		grid_view.tutorial_target = target
		grid_view.queue_redraw()
	var ready := _tutorial_can_run()
	play_btn.disabled = not ready
	step_btn.disabled = not ready

func _on_next_level_pressed() -> void:
	if current_level_index + 1 < all_levels.size():
		load_level_by_index(current_level_index + 1)

func _update_sim_buttons() -> void:
	if play_btn != null:
		play_btn.text = "暂停 [空格]" if is_simulating else ("继续 [空格]" if has_simulated else "开始 [空格]")
	if reset_btn != null:
		reset_btn.text = "重置 [R]"

func _update_goal_display() -> void:
	if goal_label != null and sim_engine != null:
		var parts: Array[String] = []
		var p := sim_engine.get_remaining_pollution()
		var tr_col := sim_engine.get_collected_treasure_lineage_count()
		var tr_total := sim_engine.get_total_treasure_lineages()
		var prot_cur := sim_engine.get_remaining_protected()
		var prot_init := sim_engine.initial_protected_count

		if sim_engine.initial_pollution_count > 0 or p > 0:
			parts.append("污染源: %d" % p)
		if tr_total > 0:
			parts.append("宝藏回收: %d/%d" % [tr_col, tr_total])
		if prot_init > 0:
			var prot_lost := prot_init - prot_cur
			if prot_lost > 0 or sim_engine.destroyed_protected_count > 0:
				parts.append("保护目标: 失败(已损毁)")
			else:
				parts.append("保护目标: 完好(%d/%d)" % [prot_cur, prot_init])

		if parts.is_empty():
			goal_label.text = "目标: 自由实验"
		else:
			goal_label.text = "目标: " + " | ".join(parts)

# -------------------------------------------------------------
# Input & Placement Handling
# -------------------------------------------------------------
func _process(_delta: float) -> void:
	_refresh_tutorial()
	# Update ghost preview under mouse
	if grid_view != null and toolbar != null:
		var mouse_world := grid_view.get_global_mouse_position()
		var grid_pos := grid_view.world_to_grid(mouse_world)
		if toolbar.is_placing and not is_simulating and not has_simulated:
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
	# Space: toggle simulation
	if event.is_action_pressed("toggle_sim"):
		toggle_simulation()
		get_viewport().set_input_as_handled()
		return

	# R: Reset simulation
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code == KEY_R:
			reset_simulation()
			get_viewport().set_input_as_handled()
			return

	# Number keys: 1..6 for player blocks (1: Basic, 2: Inhibitor, 3: Pusher, 4: Replicator, 5: Destroyer, 6: Rotator)
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code >= KEY_1 and code <= KEY_6:
			toolbar.select_type(code - KEY_1)
			get_viewport().set_input_as_handled()
			return
		elif code == KEY_V:
			toolbar.pointer_btn.button_pressed = true
			toolbar.is_placing = false
			toolbar.block_type_selected.emit(-1)
			get_viewport().set_input_as_handled()
			return

	# Q / E: Rotate
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

	# F: Flip / submode toggle
	if event.is_action_pressed("flip_mode"):
		toolbar.toggle_sub_mode()
		get_viewport().set_input_as_handled()
		return

	# G: Group structure
	if event.is_action_pressed("group_structure"):
		group_selected_blocks()
		get_viewport().set_input_as_handled()
		return

	# Delete / Backspace: Delete selected
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			delete_selected_blocks()
			get_viewport().set_input_as_handled()
			return

	# Mouse clicks for placement, erasure, and box-selection
	if event is InputEventMouseButton:
		var mouse_world := grid_view.get_global_mouse_position()
		var grid_pos := grid_view.world_to_grid(mouse_world)

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if toolbar.is_placing:
					if not is_simulating and not has_simulated:
						is_mouse_placing = true
						_try_place_block(grid_pos)
				else:
					# Selection tool
					if not Input.is_key_pressed(KEY_SHIFT):
						_clear_selection()
					var clicked_block := world.get_block(grid_pos)
					if clicked_block != null:
						_toggle_select_block(clicked_block)
					else:
						# Start box select
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
					if not is_simulating and not has_simulated:
						is_right_dragging_selection = true
						right_drag_start_grid = grid_pos
						right_drag_orig_positions.clear()
						for b in selected_blocks:
							right_drag_orig_positions[b] = b.grid_pos
				else:
					if not is_simulating and not has_simulated:
						is_mouse_erasing = true
						_try_erase_block(grid_pos)
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
			_try_place_block(grid_pos)
		elif is_mouse_erasing:
			_try_erase_block(grid_pos)
		elif is_box_selecting:
			grid_view.box_select_current = mouse_world
			grid_view.queue_redraw()

# -------------------------------------------------------------
# Block Placement & Erasure
# -------------------------------------------------------------
func _try_place_block(grid_pos: Vector2i) -> void:
	if is_simulating or has_simulated:
		return
	if not grid_view.is_in_build_area(grid_pos):
		return

	var existing := world.get_block(grid_pos)
	if existing != null:
		if existing.is_world_block:
			return # Cannot overwrite level terrain in play mode
		world.remove_block_at(grid_pos)

	var new_block := BlockData.new(toolbar.current_type, grid_pos, toolbar.current_dir)
	new_block.texture_variant = toolbar.current_variant
	new_block.sub_mode = toolbar.current_sub_mode
	new_block.is_world_block = false
	world.add_block(new_block)

	# Update initial snapshot so Reset keeps player's current design
	_update_initial_snapshot()

func _try_erase_block(grid_pos: Vector2i) -> void:
	if is_simulating or has_simulated:
		return
	var b := world.get_block(grid_pos)
	if b != null:
		if b.is_world_block:
			return # Protected world blocks
		world.remove_block_at(grid_pos)
		_update_initial_snapshot()

func _update_initial_snapshot() -> void:
	if not is_simulating and not has_simulated:
		initial_snapshot = world.clone()

# -------------------------------------------------------------
# Selection & Grouping
# -------------------------------------------------------------
func _clear_selection() -> void:
	for b in selected_blocks:
		var v := grid_view.get_view(b.block_id)
		if v != null:
			v.is_selected = false
			v.queue_redraw()
	selected_blocks.clear()

func _toggle_select_block(b: BlockData) -> void:
	var idx := selected_blocks.find(b)
	if idx >= 0:
		selected_blocks.remove_at(idx)
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
	if is_simulating or has_simulated:
		return
	if selected_blocks.is_empty():
		return
	world.group_blocks(selected_blocks)
	for b in selected_blocks:
		var v := grid_view.get_view(b.block_id)
		if v != null:
			v.update_appearance()
	_update_initial_snapshot()

func delete_selected_blocks() -> void:
	if is_simulating or has_simulated:
		return
	for b in selected_blocks:
		if not b.is_world_block:
			world.remove_block_at(b.grid_pos)
	selected_blocks.clear()
	_update_initial_snapshot()

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
	if is_simulating or has_simulated:
		return
	if selected_blocks.is_empty() or delta == Vector2i.ZERO:
		return

	var new_positions: Dictionary = {}
	for b in selected_blocks:
		if right_drag_orig_positions.has(b):
			new_positions[b] = right_drag_orig_positions[b] + delta
		else:
			new_positions[b] = b.grid_pos + delta

	# Check build area bounds and world blocks protection
	var can_move := true
	for b in selected_blocks:
		var target_p: Vector2i = new_positions[b]
		if not grid_view.is_in_build_area(target_p):
			can_move = false
			break
		var occ := world.get_block(target_p)
		if occ != null and occ not in selected_blocks and occ.is_world_block:
			can_move = false
			break

	if not can_move:
		# Reset visual positions
		for b in selected_blocks:
			var v := grid_view.get_view(b.block_id)
			if v != null:
				v.position = grid_view.grid_to_world(b.grid_pos)
		return

	# 1. Remove non-selected player blocks at target positions
	for b in selected_blocks:
		var target_p: Vector2i = new_positions[b]
		var occ := world.get_block(target_p)
		if occ != null and occ not in selected_blocks:
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

	# 3. Synchronize views
	for b in selected_blocks:
		var v := grid_view.get_view(b.block_id)
		if v != null:
			v.position = grid_view.grid_to_world(b.grid_pos)
			v.update_appearance()

	_update_initial_snapshot()

func clear_player_blocks() -> void:
	if is_simulating:
		return
	if has_simulated:
		reset_simulation()
	var all_b := world.get_all_blocks()
	for b in all_b:
		if not b.is_world_block:
			world.remove_block_at(b.grid_pos)
	selected_blocks.clear()
	_update_initial_snapshot()

# -------------------------------------------------------------
# Blueprint Save / Load Modals
# -------------------------------------------------------------
func _on_save_machine_pressed() -> void:
	if is_simulating:
		return
	var has_sel := not selected_blocks.is_empty()
	var target_parent: Node = ui_layer if ui_layer != null else self
	BlueprintDialogs.show_save_dialog(target_parent, has_sel, func(m_name: String, only_selected: bool):
		var target_blocks: Array[BlockData] = []
		if only_selected and not selected_blocks.is_empty():
			for b in selected_blocks:
				if not b.is_world_block:
					target_blocks.append(b)
		else:
			var source_blocks = initial_snapshot.get_all_blocks() if has_simulated else world.get_all_blocks()
			for b in source_blocks:
				if not b.is_world_block:
					target_blocks.append(b)

		SaveManager.save_machine(m_name, target_blocks)
	)

func _on_load_machine_pressed() -> void:
	if is_simulating:
		return
	var target_parent: Node = ui_layer if ui_layer != null else self
	BlueprintDialogs.show_load_dialog(target_parent, func(m_name: String):
		if has_simulated:
			reset_simulation()
		var blocks := SaveManager.load_machine(m_name)
		if blocks.is_empty():
			return
		# Paste onto canvas centered at camera position
		var center_grid := grid_view.world_to_grid(camera.position)
		for b in blocks:
			var target_pos := center_grid + b.grid_pos
			b.grid_pos = target_pos
			b.is_world_block = false
			world.add_block(b)
		_update_initial_snapshot()
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

func _on_toolbar_sub_mode_toggled(sub_mode: int) -> void:
	if not selected_blocks.is_empty():
		for b in selected_blocks:
			if b.block_type == BlockData.Type.ROTATOR:
				b.sub_mode = sub_mode
				var v := grid_view.get_view(b.block_id)
				if v != null:
					v.update_appearance()

func _on_toolbar_direction_changed(dir: int) -> void:
	pass
