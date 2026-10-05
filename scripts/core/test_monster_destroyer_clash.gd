extends SceneTree

func _init() -> void:
	print("=== RUNNING MONSTER VS DESTROYER & CONFLICT TESTS ===")
	test_case_one_space_conflict()
	test_case_two_spaces_clash()
	test_case_two_monsters_conflict()
	test_case_destroyer_destroyed_at_zero_hp()
	test_case_already_adjacent_no_double_damage()
	test_case_destroyer_backstab()
	print("=== ALL MONSTER & DESTROYER TESTS PASSED SUCCESSFULLY! ===")
	quit(0)

func _add_floor(world: GridWorld, x_start: int, x_end: int, y: int = 1) -> void:
	for x in range(x_start, x_end + 1):
		world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(x, y)))

func test_case_one_space_conflict() -> void:
	print("Testing 1 Space: Pusher -> Destroyer -> Space <- Monster...")
	var world := GridWorld.new()
	_add_floor(world, 0, 6, 1)

	# Pusher at (1, 0) facing RIGHT, structure 1
	var pusher := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	pusher.structure_id = 1
	world.add_block(pusher)

	# Destroyer at (2, 0) facing RIGHT, structure 1, HP = 2
	var destroyer := BlockData.new(BlockData.Type.DESTROYER, Vector2i(2, 0), BlockData.Direction.RIGHT)
	destroyer.structure_id = 1
	destroyer.hp = 2
	world.add_block(destroyer)

	# (3, 0) is empty space

	# Monster at (4, 0) facing LEFT
	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(4, 0), BlockData.Direction.LEFT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()

	# Conflict resolution: Monster must yield (stay at (4, 0)) when pusher moves into (3, 0)
	# Then Destroyer moves to (3, 0), facing Monster at (4, 0)
	# Simultaneous clash: Destroyer takes 1 damage (HP 2 -> 1), Monster is destroyed!
	var d_world := world.get_block(Vector2i(3, 0))
	assert(d_world != null, "Destroyer should have moved to (3, 0)!")
	assert(d_world.block_type == BlockData.Type.DESTROYER, "Block at (3, 0) should be Destroyer!")
	assert(d_world.hp == 1, "Destroyer should take 1 damage and have 1 HP remaining (actual: %d)!" % d_world.hp)

	var m_world := world.get_block(Vector2i(4, 0))
	assert(m_world == null, "Monster at (4, 0) should have been destroyed!")

	var monster_destroyed := false
	for b in res.destroyed_blocks:
		if b.block_id == monster.block_id:
			monster_destroyed = true
			break
	assert(monster_destroyed, "Monster should be recorded in destroyed_blocks!")

	var destroyer_damaged := false
	for d_info in res.damaged_blocks:
		if d_info.id == destroyer.block_id and d_info.old_hp == 2 and d_info.new_hp == 1:
			destroyer_damaged = true
			break
	assert(destroyer_damaged, "Destroyer should be recorded in damaged_blocks!")
	print("  1-space conflict passed: Monster yielded, Destroyer pushed, mutual clash took 1 HP.")

func test_case_two_spaces_clash() -> void:
	print("Testing 2 Spaces: Pusher -> Destroyer -> Space Space <- Monster...")
	var world := GridWorld.new()
	_add_floor(world, 0, 7, 1)

	# Pusher at (1, 0) facing RIGHT, structure 1
	var pusher := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	pusher.structure_id = 1
	world.add_block(pusher)

	# Destroyer at (2, 0) facing RIGHT, structure 1, HP = 2
	var destroyer := BlockData.new(BlockData.Type.DESTROYER, Vector2i(2, 0), BlockData.Direction.RIGHT)
	destroyer.structure_id = 1
	destroyer.hp = 2
	world.add_block(destroyer)

	# (3, 0) is empty space
	# (4, 0) is empty space

	# Monster at (5, 0) facing LEFT
	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(5, 0), BlockData.Direction.LEFT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()

	# Both move: Destroyer moves (2, 0) -> (3, 0), Monster moves (5, 0) -> (4, 0)
	# Now adjacent and facing each other!
	# Destroyer takes 1 damage (HP 2 -> 1), Monster is destroyed!
	var d_world := world.get_block(Vector2i(3, 0))
	assert(d_world != null, "Destroyer should be at (3, 0)!")
	assert(d_world.hp == 1, "Destroyer should take 1 damage and have 1 HP left (actual: %d)!" % d_world.hp)

	var m_world := world.get_block(Vector2i(4, 0))
	assert(m_world == null, "Monster at (4, 0) should be destroyed!")

	var monster_destroyed := false
	for b in res.destroyed_blocks:
		if b.block_id == monster.block_id:
			monster_destroyed = true
			break
	assert(monster_destroyed, "Monster should be in destroyed_blocks!")
	print("  2-spaces clash passed: Both stepped forward, mutual clash took 1 HP and destroyed monster.")

func test_case_two_monsters_conflict() -> void:
	print("Testing 2 Monsters Conflict: Monster A -> Space <- Monster B...")
	var world := GridWorld.new()
	_add_floor(world, 0, 5, 1)

	# Monster A at (1, 0) facing RIGHT
	var ma := BlockData.new(BlockData.Type.WANDERER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	world.add_block(ma)

	# (2, 0) is empty space

	# Monster B at (3, 0) facing LEFT
	var mb := BlockData.new(BlockData.Type.WANDERER, Vector2i(3, 0), BlockData.Direction.LEFT)
	world.add_block(mb)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()

	# Exactly one should have moved to (2, 0), and one stayed
	var mid_b := world.get_block(Vector2i(2, 0))
	assert(mid_b != null, "One monster must have won the cell (2, 0)!")
	assert(mid_b.block_type == BlockData.Type.WANDERER, "Block at (2, 0) must be a Wanderer!")

	# Total live monsters must still be 2
	var total_wanderers := 0
	for b in world.get_all_blocks():
		if b.block_type == BlockData.Type.WANDERER:
			total_wanderers += 1
	assert(total_wanderers == 2, "Both monsters should survive conflict!")
	assert(res.moved_blocks.size() == 1, "Only one monster should have moved!")
	print("  2 monsters conflict passed: One stepped into the space, the other yielded.")

func test_case_destroyer_destroyed_at_zero_hp() -> void:
	print("Testing Destroyer Destroyed at 0 HP (Mutual Destruction)...")
	var world := GridWorld.new()
	_add_floor(world, 0, 7, 1)

	var pusher := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	pusher.structure_id = 1
	world.add_block(pusher)

	# Destroyer with 1 HP!
	var destroyer := BlockData.new(BlockData.Type.DESTROYER, Vector2i(2, 0), BlockData.Direction.RIGHT)
	destroyer.structure_id = 1
	destroyer.hp = 1
	world.add_block(destroyer)

	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(5, 0), BlockData.Direction.LEFT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()

	# Both move, face each other, both take lethal damage and are destroyed
	assert(world.get_block(Vector2i(3, 0)) == null, "Destroyer at 0 HP should be removed!")
	assert(world.get_block(Vector2i(4, 0)) == null, "Monster should be removed!")

	var d_destroyed := false
	var m_destroyed := false
	for b in res.destroyed_blocks:
		if b.block_id == destroyer.block_id:
			d_destroyed = true
		if b.block_id == monster.block_id:
			m_destroyed = true
	assert(d_destroyed, "Destroyer must be in destroyed_blocks!")
	assert(m_destroyed, "Monster must be in destroyed_blocks!")
	print("  Mutual destruction at 0 HP passed.")

func test_case_already_adjacent_no_double_damage() -> void:
	print("Testing Already Adjacent at t0 (No Double Damage)...")
	var world := GridWorld.new()
	_add_floor(world, 0, 5, 1)

	# Wall at (4, 0) behind monster so monster cannot jump/walk away
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(4, 0)))

	# Destroyer at (2, 0) facing RIGHT, HP = 2
	var destroyer := BlockData.new(BlockData.Type.DESTROYER, Vector2i(2, 0), BlockData.Direction.RIGHT)
	destroyer.hp = 2
	world.add_block(destroyer)

	# Monster at (3, 0) facing LEFT, already adjacent!
	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(3, 0), BlockData.Direction.LEFT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()

	# Step 4: Monster attacks Destroyer (HP 2 -> 1)
	# Step 6: Destroyer destroys Monster
	# Destroyer should have HP = 1 (NOT 0, no double damage!)
	var d_world := world.get_block(Vector2i(2, 0))
	assert(d_world != null, "Destroyer should survive with 1 HP!")
	assert(d_world.hp == 1, "Destroyer HP should be 1 (actual: %d)!" % d_world.hp)
	assert(world.get_block(Vector2i(3, 0)) == null, "Monster should be destroyed!")
	print("  Already adjacent passed: exactly 1 damage taken, no double damage.")

func test_case_destroyer_backstab() -> void:
	print("Testing Backstab (Destroyer hits Monster from behind)...")
	var world := GridWorld.new()
	_add_floor(world, 0, 7, 1)

	# Hard block at (5, 0) blocking monster from moving
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(5, 0)))

	var pusher := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	pusher.structure_id = 1
	world.add_block(pusher)

	var destroyer := BlockData.new(BlockData.Type.DESTROYER, Vector2i(2, 0), BlockData.Direction.RIGHT)
	destroyer.structure_id = 1
	destroyer.hp = 2
	world.add_block(destroyer)

	# (3, 0) is empty space
	# Monster at (4, 0) facing RIGHT (back towards (3, 0))
	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(4, 0), BlockData.Direction.RIGHT)
	world.add_block(monster)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()

	# Destroyer moves to (3, 0) and destroys Monster at (4, 0) from behind
	# Monster was not facing Destroyer, so Destroyer takes 0 damage (HP remains 2)
	var d_world := world.get_block(Vector2i(3, 0))
	assert(d_world != null, "Destroyer should be at (3, 0)!")
	assert(d_world.hp == 2, "Destroyer should take 0 damage on backstab (actual: %d)!" % d_world.hp)
	assert(world.get_block(Vector2i(4, 0)) == null, "Monster should be destroyed!")
	print("  Backstab passed: Destroyer took 0 damage, Monster was destroyed.")
