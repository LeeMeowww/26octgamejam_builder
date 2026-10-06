extends SceneTree

var view: SubViewport
var player: LevelPlayer
var failures: Array = []
var checks := 0

func _initialize() -> void:
	call_deferred("run_test")

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
	else:
		print("PASS: ", label)

func frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame

func run_test() -> void:
	print("--- Starting Build Area & Machine Centering Tests ---")
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)

	var scene = load("res://scenes/ui/LevelPlayer.tscn")
	player = scene.instantiate()
	view.add_child(player)
	await frames(10)

	# 1. Setup custom level with build area
	var test_level := LevelData.new("test_build_area", "测试建造区限制")
	test_level.player_build_area = Rect2i(10, 10, 6, 6) # Center is (13.0, 13.0)

	# Add a world block OUTSIDE player build area (e.g., target or terrain at (2, 2))
	var world_target := BlockData.new(BlockData.Type.POLLUTION, Vector2i(2, 2))
	world_target.is_world_block = true
	test_level.blocks_data.append(world_target.to_dict())

	player.load_level_data(test_level)
	await frames(5)

	# Verify world block outside build area does NOT trigger warning
	verify(not player.has_blocks_outside_build_area(), "World block outside build area does not trigger outside warning")
	verify(not player.build_area_warning_panel.visible, "Warning panel hidden when only world blocks outside")
	verify(not player.play_btn.disabled, "Play button enabled when only world blocks outside")

	# 2. Place a player block inside build area (12, 12)
	player.toolbar.select_type(BlockData.Type.BASIC)
	player._try_place_block(Vector2i(12, 12))
	await frames(2)

	verify(not player.has_blocks_outside_build_area(), "Inside player block has no outside warning")
	verify(not player.build_area_warning_panel.visible, "Warning panel remains hidden with inside block")
	verify(not player.play_btn.disabled, "Play button enabled with inside block")

	# 3. Place a player block OUTSIDE build area (4, 4) - Allowed to place, but warns and blocks sim
	player._try_place_block(Vector2i(4, 4))
	await frames(2)

	var outside_block := player.world.get_block(Vector2i(4, 4))
	verify(outside_block != null, "Player is allowed to place block outside build area")
	verify(player.has_blocks_outside_build_area(), "has_blocks_outside_build_area() is true")
	verify(player.get_blocks_outside_build_area().size() == 1, "Exactly 1 block outside build area")
	verify(player.build_area_warning_panel.visible, "Warning panel is visible")
	verify(player.play_btn.disabled, "Play button is disabled")
	verify(player.step_btn.disabled, "Step button is disabled")

	# Attempt to start simulation via start_simulation()
	player.start_simulation()
	await frames(2)
	verify(not player.is_simulating, "start_simulation() rejected when block is outside build area")

	# Attempt single step via step_single_tick()
	var step_count_before := player.sim_engine.step_count
	player.step_single_tick()
	await frames(2)
	verify(player.sim_engine.step_count == step_count_before, "step_single_tick() rejected when block is outside build area")

	# 4. Erase outside block
	player._try_erase_block(Vector2i(4, 4))
	await frames(2)

	verify(not player.has_blocks_outside_build_area(), "has_blocks_outside_build_area() is false after erasing outside block")
	verify(not player.build_area_warning_panel.visible, "Warning panel hidden after erasing outside block")
	verify(not player.play_btn.disabled, "Play button re-enabled after erasing outside block")
	verify(not player.step_btn.disabled, "Step button re-enabled after erasing outside block")

	# 5. Delete outside block via delete_selected_blocks()
	player._try_place_block(Vector2i(5, 5))
	var outside_b2 := player.world.get_block(Vector2i(5, 5))
	player.selected_blocks = [outside_b2]
	verify(player.has_blocks_outside_build_area(), "Outside block placed again")
	verify(player.build_area_warning_panel.visible, "Warning panel visible again")
	player.delete_selected_blocks()
	await frames(2)
	verify(not player.has_blocks_outside_build_area(), "Outside block deleted via delete_selected_blocks()")
	verify(not player.build_area_warning_panel.visible, "Warning panel hidden after delete_selected_blocks()")

	# 6. Test Machine Blueprint Loading - Center of Mass Alignment
	# Create a 3-block machine: (0,0), (2,0), (1,3)
	# Center of mass: ((0.5+2.5+1.5)/3, (0.5+0.5+3.5)/3) = (4.5/3, 4.5/3) = (1.5, 1.5)
	var blueprint_blocks: Array[BlockData] = [
		BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0)),
		BlockData.new(BlockData.Type.BASIC, Vector2i(2, 0)),
		BlockData.new(BlockData.Type.BASIC, Vector2i(1, 3))
	]
	SaveManager.save_machine("test_center_of_mass", blueprint_blocks)

	# Clean player blocks first
	player.clear_player_blocks()
	await frames(2)

	# Load the saved machine
	var loaded_blocks := SaveManager.load_machine("test_center_of_mass")
	verify(loaded_blocks.size() == 3, "Loaded 3 blocks from test machine blueprint")

	# Simulate the centering math used in LevelPlayer._on_load_machine_pressed
	var b_area := player.current_level_data.player_build_area
	var area_center := Vector2(b_area.position) + Vector2(b_area.size) * 0.5 # (10, 10) + (3, 3) = (13.0, 13.0)
	var sum_pos := Vector2.ZERO
	for b in loaded_blocks:
		sum_pos += Vector2(b.grid_pos) + Vector2(0.5, 0.5)
	var machine_center := sum_pos / float(loaded_blocks.size())
	verify(machine_center.is_equal_approx(Vector2(1.5, 1.5)), "Machine center of mass before shift is (1.5, 1.5)")

	var shift := Vector2i(round(area_center.x - machine_center.x), round(area_center.y - machine_center.y))
	verify(shift == Vector2i(12, 12), "Shift correctly calculated to Vector2i(12, 12)")

	for b in loaded_blocks:
		b.grid_pos = b.grid_pos + shift
		b.is_world_block = false
		player.world.add_block(b)
	player._update_build_area_status()
	await frames(2)

	# Calculate loaded center of mass in world
	var loaded_sum := Vector2.ZERO
	for b in loaded_blocks:
		loaded_sum += Vector2(b.grid_pos) + Vector2(0.5, 0.5)
	var final_center := loaded_sum / float(loaded_blocks.size())
	var diff := (final_center - area_center).length()
	print("Machine final center of mass: ", final_center, " Area center: ", area_center, " Diff: ", diff)
	verify(diff < 1.0, "Center of mass is aligned with build area center (diff < 1 cell)")
	verify(not player.has_blocks_outside_build_area(), "All machine blocks are inside build area")
	verify(not player.play_btn.disabled, "Simulation can start after loading centered machine")

	print("\n--- Test Results: %d checks, %d failures ---" % [checks, failures.size()])
	if failures.is_empty():
		print("ALL TESTS PASSED!")
		quit(0)
	else:
		printerr("TESTS FAILED: ", failures)
		quit(1)
