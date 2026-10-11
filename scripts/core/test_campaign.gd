extends SceneTree

const Campaign = preload("res://scripts/core/Campaign.gd")
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("BLOCKBOUND_TEST_OUTPUT")

func _initialize() -> void:
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
	var next := Campaign.next_index("level_05", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_relay", "Train leads to bridge")
	next = Campaign.next_index("custom_level_relay", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_81605", "Bridge leads to firepower")
	check(Campaign.next_index("custom_level_86910", levels) == -1, "Optional branch has no forced next level")
	var without_bridge: Array[LevelData] = []
	for level in levels:
		if level.level_id != "custom_level_relay": without_bridge.append(level)
	next = Campaign.next_index("level_05", without_bridge)
	check(next >= 0 and without_bridge[next].level_id == "custom_level_81605", "Deleted main level is skipped without resurrection")
	var menu: LevelSelect = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.node_buttons.size() == 5, "Tutorial chapter retains five nodes")
	menu.levels.append(LevelData.new("test_custom", "测试自制关"))
	menu._show_chapter(4)
	check(menu.node_buttons.has("test_custom"), "Unknown levels remain visible in free workshop")
	menu.levels.pop_back()
	menu.chapter_buttons[2].pressed.emit()
	await process_frame
	check(menu.node_buttons.size() == 3, "Automation chapter contains two main nodes and one branch")
	check(menu.map.routes.size() == 2, "Main and branch connections rendered")
	await click(menu.node_buttons["custom_level_relay"])
	check(not menu.enter_button.disabled and menu.detail_title.text.contains("接力发射"), "Node click opens details")
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
	check(player != null and player.current_level_data.level_id == "custom_level_relay", "Enter button loads selected level")
	player.base_tick_duration = 0.001
	var specs := [[2,-11,-6,0],[4,-10,-6,0],[3,-11,-5,0],[3,-10,-5,0]]
	for s in specs:
		player.toolbar.select_type(s[0])
		player.toolbar.current_dir = s[3]
		player._try_place_block(Vector2i(s[1], s[2]))
		check(player.world.has_block(Vector2i(s[1], s[2])), "Build reference module " + str(s))
	player.tutorial_guide.hint_index = 3
	player.tutorial_guide._show_hint()
	await snap("relay_solution")
	for tick in range(80):
		player.step_single_tick()
		while player.is_animating_tick: await process_frame
		if player.victory_dialog.visible: break
	check(player.victory_dialog.visible, "Reference solution wins through LevelPlayer")
	print("BRIDGE WIN TICK: ", player.sim_engine.step_count)
	check(Campaign.completed().has("custom_level_relay"), "Victory persists completion")
	await snap("relay_victory")
	player.reset_simulation()
	check(player.sim_engine.get_remaining_pollution() == 2, "Reset restores both pollution goals")
	player._on_next_level_pressed()
	check(player.current_level_data.level_id == "custom_level_81605", "Victory next follows main route")
	player.queue_free()
	await process_frame
	var returned: LevelSelect = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	root.add_child(returned)
	await process_frame
	check(returned.chapter == 2 and returned.selected_index >= 0, "Returning to map remembers chapter and selected level")
	returned._show_chapter(0)
	await snap("chapter_tutorial")
	returned._show_chapter(1)
	await snap("chapter_workshop")
	returned.queue_free()
	await process_frame
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
