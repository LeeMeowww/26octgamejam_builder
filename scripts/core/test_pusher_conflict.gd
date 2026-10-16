extends SceneTree

func _init() -> void:
	print("=== RUNNING PUSHER CONFLICT & PRNG TESTS ===")
	test_head_to_head_pusher_competition()
	test_orthogonal_pusher_competition()
	test_pushed_blocks_competition_and_cascade()
	test_three_way_pusher_competition()
	test_prng_distribution()
	test_prng_seed_reproducibility()
	test_hard_block_cannot_be_pushed()
	test_dual_direction_pushers_on_connected_object()
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

func test_hard_block_cannot_be_pushed() -> void:
	print("Testing Hard Block Push Immunity...")
	# 1. Direct push on uninhibited Hard block
	var world := GridWorld.new()
	var pusher := BlockData.new(BlockData.Type.PUSHER, Vector2i(0, 0), BlockData.Direction.RIGHT)
	var hard := BlockData.new(BlockData.Type.HARD, Vector2i(1, 0))
	world.add_block(pusher)
	world.add_block(hard)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()
	assert(res.moved_blocks.is_empty(), "Uninhibited Hard block must not be moved by Pusher!")
	assert(pusher.grid_pos == Vector2i(0, 0), "Pusher must remain at (0, 0)!")
	assert(hard.grid_pos == Vector2i(1, 0), "Hard block must remain at (1, 0)!")

	# 2. Direct push on inhibited Hard block (it is still solid and cannot be moved, only destroyed by Destroyer)
	hard.is_inhibited = true
	var res_inh := sim.step_tick()
	assert(res_inh.moved_blocks.is_empty(), "Inhibited Hard block must also never be moved by Pusher!")
	assert(hard.grid_pos == Vector2i(1, 0), "Hard block must stay at (1, 0) even when inhibited!")

	# 3. Connected structure containing a Hard block
	var world2 := GridWorld.new()
	var sid := world2.create_new_structure_id()
	var p_struct := BlockData.new(BlockData.Type.PUSHER, Vector2i(5, 5), BlockData.Direction.RIGHT)
	var h_struct := BlockData.new(BlockData.Type.HARD, Vector2i(6, 5))
	p_struct.structure_id = sid
	h_struct.structure_id = sid
	world2.add_block(p_struct)
	world2.add_block(h_struct)

	var sim2 := SimulationEngine.new(world2)
	var res2 := sim2.step_tick()
	assert(res2.moved_blocks.is_empty(), "Structure containing a Hard block must not move!")
	assert(p_struct.grid_pos == Vector2i(5, 5), "Structure Pusher must stay at (5, 5)!")
	assert(h_struct.grid_pos == Vector2i(6, 5), "Structure Hard block must stay at (6, 5)!")

	# 4. Cascading push: Pusher -> Basic block -> Hard block
	var world3 := GridWorld.new()
	var p_casc := BlockData.new(BlockData.Type.PUSHER, Vector2i(0, 0), BlockData.Direction.RIGHT)
	var b_casc := BlockData.new(BlockData.Type.BASIC, Vector2i(1, 0))
	var h_casc := BlockData.new(BlockData.Type.HARD, Vector2i(2, 0))
	world3.add_block(p_casc)
	world3.add_block(b_casc)
	world3.add_block(h_casc)

	var sim3 := SimulationEngine.new(world3)
	var res3 := sim3.step_tick()
	assert(res3.moved_blocks.is_empty(), "Chain blocked by Hard block must not move!")
	assert(b_casc.grid_pos == Vector2i(1, 0), "Basic block must not move into Hard block!")

	print("  Hard Block Push Immunity verified.")

func test_dual_direction_pushers_on_connected_object() -> void:
	print("Testing Dual-Direction Pushers on Connected Object (Right + Down)...")
	var trials := 200
	var x_moves := 0
	var y_moves := 0

	for i in range(trials):
		var world := GridWorld.new()
		var sid := world.create_new_structure_id()

		# Object: connected 2x2 shape
		# (1, 1) and (1, 2)
		var b1 := BlockData.new(BlockData.Type.BASIC, Vector2i(1, 1))
		var b2 := BlockData.new(BlockData.Type.BASIC, Vector2i(1, 2))
		b1.structure_id = sid
		b2.structure_id = sid

		# Rightward Pusher at (0, 1) pushing b1 to the right (+X)
		var p_right := BlockData.new(BlockData.Type.PUSHER, Vector2i(0, 1), BlockData.Direction.RIGHT)
		# Downward Pusher at (1, 0) pushing b1 downward (+Y)
		var p_down := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.DOWN)

		world.add_block(b1)
		world.add_block(b2)
		world.add_block(p_right)
		world.add_block(p_down)

		var sim := SimulationEngine.new(world)
		sim.step_tick()

		# Verify: b1 must have moved EITHER (+1, 0) OR (0, +1). It must NEVER move (+1, +1) diagonally!
		var new_pos1 := b1.grid_pos
		var delta := new_pos1 - Vector2i(1, 1)

		assert(delta == Vector2i(1, 0) or delta == Vector2i(0, 1),
			"Object must move purely along chosen axis (+1, 0) or (0, +1), never diagonally (%s)!" % str(delta))

		if delta == Vector2i(1, 0):
			x_moves += 1
			assert(b2.grid_pos == Vector2i(2, 2), "Connected block b2 must follow along X!")
		elif delta == Vector2i(0, 1):
			y_moves += 1
			assert(b2.grid_pos == Vector2i(1, 3), "Connected block b2 must follow along Y!")

	print("  Dual-direction results over %d trials: X-first = %d (%.1f%%), Y-first = %d (%.1f%%)" % [
		trials, x_moves, (float(x_moves) / trials) * 100.0, y_moves, (float(y_moves) / trials) * 100.0
	])
	assert(x_moves >= 60 and x_moves <= 140, "X move rate must be statistically consistent with 50/50 PRNG!")
	assert(y_moves >= 60 and y_moves <= 140, "Y move rate must be statistically consistent with 50/50 PRNG!")
	print("  Dual-direction pusher resolution verified.")
