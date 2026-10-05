extends SceneTree

func _init() -> void:
	print("=== RUNNING WANDERER LEDGE & RESET STATE TESTS ===")
	test_wanderer_high_ledge_turns_around()
	test_wanderer_one_block_step_down()
	test_wanderer_flat_walk()
	test_wanderer_one_block_pillar_patrol()
	test_simulation_pause_blocks_placement_until_reset()
	test_blueprint_dialog_modal_centering()
	print("=== ALL WANDERER LEDGE & RESET TESTS PASSED! ===")
	quit(0)

func test_wanderer_high_ledge_turns_around() -> void:
	print("Testing Wanderer facing high ledge (> 1 block drop) turns around...")
	var world := GridWorld.new()
	# Platform at y=1: (0, 1), (1, 1).
	# Deep drop: at x=2, y=1 is empty, y=2 is empty, floor is at y=4!
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(0, 1)))
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(1, 1)))
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(2, 4)))

	# Monster at (1, 0) facing RIGHT (towards x=2 drop)
	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()

	# Rule: forward (2, 0) is empty, down 1 (2, 1) is empty, down 2 (2, 2) is empty -> turns around!
	# Monster should NOT have moved to (2, 0) or (2, 1)
	assert(monster.grid_pos == Vector2i(1, 0), "Monster should remain at (1, 0), not fall off high ledge!")
	assert(monster.direction == BlockData.Direction.LEFT, "Monster should turn around to LEFT!")
	print("  High ledge drop passed: Monster turned around to LEFT without falling.")

func test_wanderer_one_block_step_down() -> void:
	print("Testing Wanderer 1-block step down...")
	var world := GridWorld.new()
	# Platform at y=1: (0, 1), (1, 1).
	# 1-block step down at x=2: y=1 is empty, but y=2 has floor!
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(0, 1)))
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(1, 1)))
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(2, 2)))

	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	# Monster should step down to (2, 1) standing on (2, 2)
	assert(monster.grid_pos == Vector2i(2, 1), "Monster should step down to (2, 1) on 1-block lower ground!")
	assert(monster.direction == BlockData.Direction.RIGHT, "Monster should keep direction RIGHT!")
	print("  1-block step down passed: Monster walked down 1 step.")

func test_wanderer_flat_walk() -> void:
	print("Testing Wanderer flat walk...")
	var world := GridWorld.new()
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(0, 1)))
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(1, 1)))
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(2, 1)))

	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	assert(monster.grid_pos == Vector2i(2, 0), "Monster should walk forward to (2, 0) on flat ground!")
	print("  Flat walk passed.")

func test_wanderer_one_block_pillar_patrol() -> void:
	print("Testing Wanderer on single-block pillar patrols back and forth...")
	var world := GridWorld.new()
	# Only 1 block of floor at (5, 5)
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(5, 5)))

	# Monster on top of pillar at (5, 4) facing RIGHT
	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(5, 4), BlockData.Direction.RIGHT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	# Tick 1: faces right cliff -> turns to LEFT
	sim.step_tick()
	assert(monster.grid_pos == Vector2i(5, 4), "Tick 1: Monster should remain on pillar!")
	assert(monster.direction == BlockData.Direction.LEFT, "Tick 1: Monster should turn to LEFT!")

	# Tick 2: faces left cliff -> turns to RIGHT
	sim.step_tick()
	assert(monster.grid_pos == Vector2i(5, 4), "Tick 2: Monster should remain on pillar!")
	assert(monster.direction == BlockData.Direction.RIGHT, "Tick 2: Monster should turn to RIGHT!")
	print("  Pillar patrol passed: Monster stays on pillar and reverses direction.")

func test_simulation_pause_blocks_placement_until_reset() -> void:
	print("Testing pause blocks placement until Reset...")
	var player: LevelPlayer = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
	root.add_child(player)
	player._ready()

	var lvl := LevelData.new("test_pause", "测试暂停")
	lvl.player_build_area = Rect2i(-5, -5, 10, 10)
	var pol := BlockData.new(BlockData.Type.POLLUTION, Vector2i(3, 0))
	pol.is_world_block = true
	lvl.blocks_data.append(pol.to_dict())
	player.load_level_data(lvl)

	# 1. Initially (before simulation): has_simulated is false. Can place block!
	assert(not player.has_simulated, "Initially has_simulated should be false")
	player.toolbar.select_type(BlockData.Type.BASIC)
	player._try_place_block(Vector2i(-2, 0))
	assert(player.world.has_block(Vector2i(-2, 0)), "Block should be placed in Design state!")

	# 2. Start simulation and step 1 tick
	player.base_tick_duration = 0.001
	player.step_single_tick()
	assert(player.has_simulated == true, "has_simulated should be true after tick!")

	# 3. Simulation is paused / stopped. Now try to place a block:
	player._try_place_block(Vector2i(-3, 0))
	assert(not player.world.has_block(Vector2i(-3, 0)), "Block placement MUST be rejected while paused after simulation!")

	# Try to erase block:
	player._try_erase_block(Vector2i(-2, 0))
	assert(player.world.has_block(Vector2i(-2, 0)), "Block erasure MUST be rejected while paused after simulation!")

	# 4. Now perform Reset (simulating pressing R or Reset button)
	player.reset_simulation()
	assert(player.has_simulated == false, "has_simulated should be false after Reset!")

	# 5. After Reset: can place blocks again!
	player._try_place_block(Vector2i(-3, 0))
	assert(player.world.has_block(Vector2i(-3, 0)), "Block should be placed after Reset!")

	player.queue_free()
	print("  Pause & Reset editing lockout verified successfully.")

func test_blueprint_dialog_modal_centering() -> void:
	print("Testing Blueprint Dialog Modal centering wrapper...")
	var dummy_layer := CanvasLayer.new()
	root.add_child(dummy_layer)

	var save_modal := BlueprintDialogs.show_save_dialog(dummy_layer, false, func(_name, _sel): pass)
	assert(save_modal != null, "Modal wrapper should be created")
	assert(save_modal.name == "BlueprintModalWrapper", "Modal wrapper name verified")
	assert(save_modal.anchors_preset == int(Control.PRESET_FULL_RECT), "Modal should cover FULL_RECT for centering")
	assert(save_modal.center_container != null, "Modal must have CenterContainer")

	save_modal.close()

	var load_modal := BlueprintDialogs.show_load_dialog(dummy_layer, func(_name): pass)
	assert(load_modal != null, "Load modal should be created")
	assert(load_modal.center_container != null, "Load modal must have CenterContainer")
	load_modal.close()

	dummy_layer.queue_free()
	print("  Blueprint modal centering verified.")
