extends SceneTree

const Campaign = preload("res://scripts/core/Campaign.gd")
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("BLOCKBOUND_TEST_OUTPUT")

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): printerr("TEST WATCHDOG TIMEOUT!"); quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print(message, ": ", ok)

func snap(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if output.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	await process_frame

func run() -> void:
	var old_progress := FileAccess.get_file_as_bytes(Campaign.PROGRESS_PATH) if FileAccess.file_exists(Campaign.PROGRESS_PATH) else PackedByteArray()
	Campaign.active_level = ""
	var levels := SaveManager.get_all_levels()
	check(levels.size() >= 11, "New level is discoverable")
	var next := Campaign.next_index("tutorial_05", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_78552", "Tutorial leads to pickup 1-1")
	next = Campaign.next_index("custom_level_78552", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_78513", "Pickup 1-1 leads to 1-2")
	next = Campaign.next_index("custom_level_78513", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_76724", "Pickup 1-2 leads to 1-3")
	next = Campaign.next_index("custom_level_76724", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_80400", "Pickup 1-3 leads to gun 2-1")
	check(Campaign.next_index("custom_level_86910", levels) == -1, "Optional branch has no forced next level")
	var without_1_2: Array[LevelData] = []
	for level in levels:
		if level.level_id != "custom_level_78513": without_1_2.append(level)
	next = Campaign.next_index("custom_level_78552", without_1_2)
	check(next >= 0 and without_1_2[next].level_id == "custom_level_76724", "Deleted main level is skipped without resurrection")
	var menu: LevelSelect = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.node_buttons.size() == 5, "Tutorial chapter retains five nodes")
	menu.levels.append(LevelData.new("test_custom", "测试自制关"))
	menu._show_chapter(Campaign.CHAPTERS.size())
	check(menu.node_buttons.has("test_custom"), "Unknown levels remain visible in free workshop")
	menu.levels.pop_back()

	menu.chapter_buttons[1].pressed.emit()
	await process_frame
	check(menu.node_buttons.size() == 3, "Pickup chapter contains three main nodes")
	check(menu.map.routes.size() == 2, "Main connections rendered in Pickup chapter")

	menu.chapter_buttons[2].pressed.emit()
	await process_frame
	check(menu.node_buttons.size() == 4, "Gun chapter contains three main nodes and one branch")
	check(menu.map.routes.size() == 3, "Main and branch connections rendered in Gun chapter")

	menu.chapter_buttons[0].pressed.emit()
	await process_frame
	menu.node_buttons["tutorial_01"].pressed.emit()
	await process_frame
	check(not menu.enter_button.disabled and menu.detail_title.text.contains("第一次清理"), "Node click opens details")
	check(not menu.detail_body.get_parsed_text().contains("难度") and not menu.detail_body.get_parsed_text().contains("下一站"), "Details omit difficulty and next destination")
	await snap("chapter_map")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 540)
		await process_frame
		await process_frame
		await snap("chapter_map_small")
		check(menu.enter_button.get_global_rect().end.x <= root.get_visible_rect().size.x, "Details remain inside small viewport")
		root.size = Vector2i(1280, 720)
		await process_frame
		await process_frame
	menu.enter_button.pressed.emit()
	await process_frame
	var player: LevelPlayer = current_scene as LevelPlayer
	if player == null:
		for child in root.get_children():
			if child is LevelPlayer:
				player = child
				break
	check(player != null and player.current_level_data.level_id == "tutorial_01", "Enter button loads selected level")
	player.base_tick_duration = 0.001
	player.toolbar.select_type(0)
	player._try_place_block(Vector2i(-1, 0))
	player.toolbar.select_type(4)
	player.toolbar.current_dir = 0
	player._try_place_block(Vector2i(1, 0))
	player._refresh_tutorial()
	check(player.world.has_block(Vector2i(1, 0)), "Build destroyer at (1, 0)")
	await snap("tutorial_solution")
	for tick in range(10):
		player.step_single_tick()
		while player.is_animating_tick: await process_frame
		if player.victory_dialog.visible: break
	check(player.victory_dialog.visible, "Reference solution wins through LevelPlayer")
	check(Campaign.completed().has("tutorial_01"), "Victory persists completion")
	await snap("tutorial_victory")
	player.reset_simulation()
	check(player.sim_engine.get_remaining_pollution() == 1, "Reset restores pollution goal")
	player._on_next_level_pressed()
	check(player.current_level_data.level_id == "tutorial_02", "Victory next follows main route")
	player.queue_free()
	await process_frame
	var returned: LevelSelect = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	root.add_child(returned)
	await process_frame
	check(returned.chapter == 0 and returned.selected_index >= 0, "Returning to map remembers chapter and selected level")
	returned._show_chapter(0)
	await snap("chapter_tutorial")
	returned._show_chapter(1)
	await snap("chapter_pickup")
	returned.queue_free()
	await process_frame
	var specs := [[2,-11,-6,0],[4,-10,-6,0],[3,-11,-5,0],[3,-10,-5,0]]
	for seed_value in range(1, 11):
		var level := SaveManager.load_level("custom_level_relay")
		var world := GridWorld.new()
		for item in level.blocks_data: world.add_block(BlockData.from_dict(item))
		for s in specs: world.add_block(BlockData.new(s[0], Vector2i(s[1], s[2]), s[3]))
		var sim := SimulationEngine.new(world, level.player_build_area)
		sim.rng.seed = seed_value
		var won := false
		for tick in range(80):
			if sim.step_tick().is_victory:
				won = true
				break
		check(won, "Reference seed " + str(seed_value))
	for variant in range(3):
		var level := SaveManager.load_level("custom_level_relay")
		var world := GridWorld.new()
		for item in level.blocks_data: world.add_block(BlockData.from_dict(item))
		if variant == 1:
			world.add_block(BlockData.new(2, Vector2i(-11,-4), 0))
			world.add_block(BlockData.new(4, Vector2i(-10,-4), 0))
		if variant == 2:
			for s in specs:
				if s[1] == -10 and s[2] == -5: continue
				world.add_block(BlockData.new(s[0], Vector2i(s[1], s[2]), s[3]))
		var sim := SimulationEngine.new(world, level.player_build_area)
		for tick in range(80): sim.step_tick()
		check(sim.get_remaining_pollution() > 0, "Negative: empty / single shot / missing replicator " + str(variant))
	print("CAMPAIGN CHECKS: ", checks, "; FAILURES: ", failures)
	if old_progress.is_empty(): DirAccess.remove_absolute(Campaign.PROGRESS_PATH)
	else:
		var file := FileAccess.open(Campaign.PROGRESS_PATH, FileAccess.WRITE)
		file.store_buffer(old_progress)
	quit(0 if failures.is_empty() else 1)
