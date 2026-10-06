extends SceneTree

func _init() -> void:
	print("=== RUNNING PUSHER CONFLICT & PRNG TESTS ===")
	test_head_to_head_pusher_competition()
	test_orthogonal_pusher_competition()
	test_pushed_blocks_competition_and_cascade()
	test_three_way_pusher_competition()
	test_prng_distribution()
	test_prng_seed_reproducibility()
	print("=== ALL PUSHER CONFLICT & PRNG TESTS PASSED! ===")
	quit(0)

func test_head_to_head_pusher_competition() -> void:
	print("Testing Head-to-Head Pusher Competition across 1 empty cell...")
	var world := GridWorld.new()
	# P1 at (0, 0) facing RIGHT (wants to move to (1, 0))
	var p1 := BlockData.new(BlockData.Type.PUSHER, Vector2i(0, 0), BlockData.Direction.RIGHT)
	# P2 at (2, 0) facing LEFT (wants to move to (1, 0))
	var p2 := BlockData.new(BlockData.Type.PUSHER, Vector2i(2, 0), BlockData.Direction.LEFT)

	world.add_block(p1)
	world.add_block(p2)

	var sim := SimulationEngine.new(world)
	# Seed so P1 wins
	sim.rng.seed = 42

	var res := sim.step_tick()

	# Verify: exactly one pusher moved into (1, 0)
	var occupant_at_center := world.get_block(Vector2i(1, 0))
	assert(occupant_at_center != null, "Center cell (1, 0) must be occupied by the winning pusher!")
	assert(world.get_all_blocks().size() == 2, "Both pushers must still exist in world (none overwritten)!")

	var p1_curr := world.get_block(p1.grid_pos)
	var p2_curr := world.get_block(p2.grid_pos)
	assert(p1_curr != null and p2_curr != null, "Both pushers must be retrievable from grid!")

	if p1.grid_pos == Vector2i(1, 0):
		assert(p2.grid_pos == Vector2i(2, 0), "P2 must remain at (2, 0) if P1 won!")
	else:
		assert(p2.grid_pos == Vector2i(1, 0), "P2 must be at (1, 0) if P2 won!")
		assert(p1.grid_pos == Vector2i(0, 0), "P1 must remain at (0, 0) if P2 won!")

	# Tick 2: They are now adjacent and directly facing each other -> stalemate!
	var res2 := sim.step_tick()
	assert(res2.moved_blocks.is_empty(), "In tick 2, opposing adjacent pushers must hold stalemate and not move!")
	assert(world.has_block(p1.grid_pos) and world.has_block(p2.grid_pos), "Both blocks still exist in tick 2!")
	print("  Head-to-head pusher competition verified.")

func test_orthogonal_pusher_competition() -> void:
	print("Testing Orthogonal Pusher Competition...")
	var world := GridWorld.new()
	# P1 at (0, 1) facing RIGHT (wants (1, 1))
	var p1 := BlockData.new(BlockData.Type.PUSHER, Vector2i(0, 1), BlockData.Direction.RIGHT)
	# P2 at (1, 0) facing DOWN (wants (1, 1))
	var p2 := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.DOWN)

	world.add_block(p1)
	world.add_block(p2)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	assert(world.get_all_blocks().size() == 2, "Both pushers must survive in world!")
	var occupant := world.get_block(Vector2i(1, 1))
	assert(occupant != null, "Cell (1, 1) must be occupied by the winner!")

	if occupant == p1:
		assert(p2.grid_pos == Vector2i(1, 0), "P2 must stay at (1, 0) if P1 won!")
	else:
		assert(occupant == p2, "P2 is the occupant!")
		assert(p1.grid_pos == Vector2i(0, 1), "P1 must stay at (0, 1) if P2 won!")

	print("  Orthogonal pusher competition verified.")

func test_pushed_blocks_competition_and_cascade() -> void:
	print("Testing Pushed Blocks Competition with Cascading Blockage...")
	var world := GridWorld.new()
	# Pusher 1 at (-1, 1) pushing Block A at (0, 1) towards (1, 1)
	var p1 := BlockData.new(BlockData.Type.PUSHER, Vector2i(-1, 1), BlockData.Direction.RIGHT)
	var a := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 1))

	# Pusher 2 at (1, -1) pushing Block B at (1, 0) towards (1, 1)
	var p2 := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, -1), BlockData.Direction.DOWN)
	var b := BlockData.new(BlockData.Type.BASIC, Vector2i(1, 0))

	world.add_block(p1)
	world.add_block(a)
	world.add_block(p2)
	world.add_block(b)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	assert(world.get_all_blocks().size() == 4, "All 4 blocks must survive!")
	var occupant := world.get_block(Vector2i(1, 1))
	assert(occupant != null, "Target cell (1, 1) must be occupied!")

	if occupant == a:
		assert(p1.grid_pos == Vector2i(0, 1), "P1 must have moved forward behind A!")
		assert(b.grid_pos == Vector2i(1, 0), "B must have failed and stayed at (1, 0)!")
		assert(p2.grid_pos == Vector2i(1, -1), "P2 must have been stopped behind B!")
	else:
		assert(occupant == b, "B must have won!")
		assert(p2.grid_pos == Vector2i(1, 0), "P2 must have moved forward behind B!")
		assert(a.grid_pos == Vector2i(0, 1), "A must have failed and stayed at (0, 1)!")
		assert(p1.grid_pos == Vector2i(-1, 1), "P1 must have been stopped behind A!")

	print("  Pushed blocks competition and cascading blockage verified.")

func test_three_way_pusher_competition() -> void:
	print("Testing Three-way Pusher Competition...")
	var world := GridWorld.new()
	var p1 := BlockData.new(BlockData.Type.PUSHER, Vector2i(0, 1), BlockData.Direction.RIGHT)
	var p2 := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.DOWN)
	var p3 := BlockData.new(BlockData.Type.PUSHER, Vector2i(2, 1), BlockData.Direction.LEFT)

	world.add_block(p1)
	world.add_block(p2)
	world.add_block(p3)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	assert(world.get_all_blocks().size() == 3, "All 3 pushers must survive!")
	var occupant := world.get_block(Vector2i(1, 1))
	assert(occupant != null, "Target cell (1, 1) must have exactly 1 winner!")

	var moved_count := 0
	if p1.grid_pos == Vector2i(1, 1): moved_count += 1
	if p2.grid_pos == Vector2i(1, 1): moved_count += 1
	if p3.grid_pos == Vector2i(1, 1): moved_count += 1
	assert(moved_count == 1, "Exactly one pusher must have moved into (1, 1)!")

	print("  Three-way pusher competition verified.")

func test_prng_distribution() -> void:
	print("Testing PRNG Distribution over 200 trials...")
	var p1_wins := 0
	var p2_wins := 0
	var trials := 200

	for i in range(trials):
		var world := GridWorld.new()
		var p1 := BlockData.new(BlockData.Type.PUSHER, Vector2i(0, 0), BlockData.Direction.RIGHT)
		var p2 := BlockData.new(BlockData.Type.PUSHER, Vector2i(2, 0), BlockData.Direction.LEFT)
		world.add_block(p1)
		world.add_block(p2)

		var sim := SimulationEngine.new(world)
		# sim.rng is randomized in _init
		sim.step_tick()

		if p1.grid_pos == Vector2i(1, 0):
			p1_wins += 1
		elif p2.grid_pos == Vector2i(1, 0):
			p2_wins += 1
		else:
			assert(false, "One pusher must have reached (1, 0)!")

	print("  Results: P1 wins = %d (%.1f%%), P2 wins = %d (%.1f%%)" % [p1_wins, (float(p1_wins) / trials) * 100.0, p2_wins, (float(p2_wins) / trials) * 100.0])
	# With 200 trials of 50%, wins should easily fall between 30% and 70% (60 to 140)
	assert(p1_wins >= 60 and p1_wins <= 140, "P1 win rate must be statistically consistent with true PRNG (got %d / %d)!" % [p1_wins, trials])
	assert(p2_wins >= 60 and p2_wins <= 140, "P2 win rate must be statistically consistent with true PRNG (got %d / %d)!" % [p2_wins, trials])
	print("  PRNG statistical distribution verified.")

func test_prng_seed_reproducibility() -> void:
	print("Testing PRNG Seed Reproducibility...")
	var run_with_seed = func(seed_val: int) -> Vector2i:
		var world := GridWorld.new()
		var p1 := BlockData.new(BlockData.Type.PUSHER, Vector2i(0, 0), BlockData.Direction.RIGHT)
		var p2 := BlockData.new(BlockData.Type.PUSHER, Vector2i(2, 0), BlockData.Direction.LEFT)
		world.add_block(p1)
		world.add_block(p2)
		var sim := SimulationEngine.new(world)
		sim.rng.seed = seed_val
		sim.step_tick()
		return p1.grid_pos

	var pos1: Vector2i = run_with_seed.call(12345)
	var pos2: Vector2i = run_with_seed.call(12345)
	assert(pos1 == pos2, "Same seed must produce identical deterministic results!")
	print("  Seed reproducibility verified.")
