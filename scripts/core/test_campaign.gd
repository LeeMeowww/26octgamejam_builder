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
	ConfigFile.new().save(Campaign.PROGRESS_PATH)
	Campaign.active_level = ""
	var levels := SaveManager.get_all_levels()
	check(levels.size() >= 21, "All 14 levels are discoverable")
	var next := Campaign.next_index("custom_level_80400", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_81906", "Gun 1 leads to Gun 2")
	next = Campaign.next_index("custom_level_81906", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_33459", "Gun 2 leads to Gun 3")
	next = Campaign.next_index("custom_level_33459", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_78552", "Gun 3 leads to Acquire 0")
	next = Campaign.next_index("custom_level_78552", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_78513", "Acquire 0 leads to Acquire 1")
	next = Campaign.next_index("custom_level_78513", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_76724", "Acquire 1 leads to Acquire 2")
	next = Campaign.next_index("custom_level_76724", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_25312", "Acquire 2 leads to Acquire 3")
	next = Campaign.next_index("custom_level_25312", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_27833", "Acquire 3 leads to Car 0")
	next = Campaign.next_index("custom_level_27833", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_21314", "Car 0 leads to Car 1")
	next = Campaign.next_index("custom_level_21314", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_28302", "Car 1 leads to Car 2")
	next = Campaign.next_index("custom_level_28302", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_49361", "Car 2 leads to Car 3")
	next = Campaign.next_index("custom_level_49361", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_35377", "Car 3 leads to Counter 1")
	next = Campaign.next_index("custom_level_35377", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_33847", "Counter 1 leads to Counter 2")
	next = Campaign.next_index("custom_level_33847", levels)
	check(next >= 0 and levels[next].level_id == "custom_level_80850", "Counter 2 leads to Counter 3")
	check(Campaign.next_index("custom_level_80850", levels) == -1, "Counter 3 has no forced next level")

	var without_gun_2: Array[LevelData] = []
	for level in levels:
		if level.level_id != "custom_level_81906": without_gun_2.append(level)
	next = Campaign.next_index("custom_level_80400", without_gun_2)
	check(next >= 0 and without_gun_2[next].level_id == "custom_level_33459", "Deleted main level is skipped without resurrection")

	var menu: LevelSelect = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.chapter_buttons.size() >= 5, "Tutorial and four formal chapter tabs exist")
	check(menu.node_buttons.size() == 1, "Only first tutorial is initially visible")
	menu.chapter_buttons[1].pressed.emit()
	await process_frame
	check(menu.node_buttons.size() == 3, "Gun chapter contains 3 nodes")
	check(menu.map.routes.size() == 2, "Gun chapter routes rendered")

	menu.chapter_buttons[2].pressed.emit()
	await process_frame
	check(menu.node_buttons.size() == 4, "Acquire chapter contains 4 nodes")
	check(menu.map.routes.size() == 3, "Acquire chapter routes rendered")

	menu.chapter_buttons[3].pressed.emit()
	await process_frame
	check(menu.node_buttons.size() == 4, "Car chapter contains 4 nodes")
	check(menu.map.routes.size() == 3, "Car chapter routes rendered")

	menu.chapter_buttons[4].pressed.emit()
	await process_frame
	check(menu.node_buttons.size() == 3, "Counter chapter contains 3 nodes")
	check(menu.map.routes.size() == 2, "Counter chapter routes rendered")

	menu.chapter_buttons[1].pressed.emit()
	await process_frame
	menu.node_buttons["custom_level_80400"].pressed.emit()
	await process_frame
	check(not menu.enter_button.disabled and menu.detail_title.text.contains("枪-1"), "Node click opens details")
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
	check(player != null and player.current_level_data.level_id == "custom_level_80400", "Enter button loads selected level")
	player.base_tick_duration = 0.001
	player.queue_free()
	await process_frame
	if FileAccess.file_exists("res://assets/levels/custom_level_relay.json"):
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
