extends SceneTree

func _init() -> void:
	print("\n=== RUNNING PROTECTED BLOCKS & TREASURE LINEAGE TESTS ===")
	test_protected_cannot_be_replicated()
	test_protected_block_destruction_prevents_victory_destroyer()
	test_protected_block_destruction_prevents_victory_wanderer()
	test_treasure_lineage_collection_and_multiple_copies()
	test_treasure_replicated_can_satisfy_lineage()
	test_pollution_absolute_count_zero_required()
	test_protected_serialization()
	print("=== ALL PROTECTED & TREASURE LINEAGE TESTS PASSED! ===\n")
	quit(0)

# -------------------------------------------------------------
# 1. Protected Blocks Cannot Be Replicated
# -------------------------------------------------------------
func test_protected_cannot_be_replicated() -> void:
	print("Testing Protected block cannot be replicated by Replicator...")
	var world := GridWorld.new()
	# Protected block at (0, 0), Replicator at (1, 0) facing RIGHT (towards (2, 0))
	var prot := BlockData.new(BlockData.Type.PROTECTED, Vector2i(0, 0))
	var rep := BlockData.new(BlockData.Type.REPLICATOR, Vector2i(1, 0), BlockData.Direction.RIGHT)
	world.add_block(prot)
	world.add_block(rep)

	var sim := SimulationEngine.new(world)
	var res := sim.step_tick()

	assert(res.spawned_blocks.is_empty(), "Replicator must NOT spawn any copy of a Protected block!")
	assert(not world.has_block(Vector2i(2, 0)), "Target cell (2, 0) should remain empty!")
	assert(sim.get_remaining_protected() == 1, "Protected block count should remain 1!")
	print("  Protected block replication immunity passed.")

# -------------------------------------------------------------
# 2. Protected Block Destroyed by Destroyer Prevents Victory
# -------------------------------------------------------------
func test_protected_block_destruction_prevents_victory_destroyer() -> void:
	print("Testing Protected block destruction by Destroyer prevents victory...")
	var world := GridWorld.new()
	var build_area := Rect2i(0, 0, 5, 5)

	# Pollution at (10, 0) destroyed by Destroyer at (9, 0)
	var pol := BlockData.new(BlockData.Type.POLLUTION, Vector2i(10, 0))
	var des_pol := BlockData.new(BlockData.Type.DESTROYER, Vector2i(9, 0), BlockData.Direction.RIGHT)

	# Protected block at (2, 2) destroyed by Destroyer at (1, 2) facing RIGHT
	var prot := BlockData.new(BlockData.Type.PROTECTED, Vector2i(2, 2))
	var des_prot := BlockData.new(BlockData.Type.DESTROYER, Vector2i(1, 2), BlockData.Direction.RIGHT)

	world.add_block(pol)
	world.add_block(des_pol)
	world.add_block(prot)
	world.add_block(des_prot)

	var sim := SimulationEngine.new(world, build_area)
	assert(sim.initial_protected_count == 1, "Initial protected count should be 1")
	assert(sim.initial_pollution_count == 1, "Initial pollution count should be 1")

	var res := sim.step_tick()
	assert(sim.get_remaining_pollution() == 0, "Pollution should be destroyed")
	assert(sim.get_remaining_protected() == 0, "Protected block should have been destroyed")
	assert(sim.destroyed_protected_count == 1, "sim.destroyed_protected_count should be 1")
	assert(res.is_victory == false, "Victory must FAIL when a protected block is destroyed!")
	print("  Destroyer destroying protected block preventing victory passed.")

# -------------------------------------------------------------
# 3. Protected Block Destroyed by Wanderer Prevents Victory
# -------------------------------------------------------------
func test_protected_block_destruction_prevents_victory_wanderer() -> void:
	print("Testing Protected block destruction by Wanderer prevents victory...")
	var world := GridWorld.new()
	var build_area := Rect2i(0, 0, 5, 5)

	# Protected block at (2, 0) with 1 HP
	var prot := BlockData.new(BlockData.Type.PROTECTED, Vector2i(2, 0))
	prot.hp = 1
	var monster := BlockData.new(BlockData.Type.WANDERER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	# Floor underneath
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(1, 1)))
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(2, 1)))
	# Also ceiling so monster cannot jump over
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(2, -1)))

	# 1 pollution destroyed at tick 1
	var pol := BlockData.new(BlockData.Type.POLLUTION, Vector2i(10, 0))
	var des := BlockData.new(BlockData.Type.DESTROYER, Vector2i(9, 0), BlockData.Direction.RIGHT)

	world.add_block(prot)
	world.add_block(monster)
	world.add_block(pol)
	world.add_block(des)

	var sim := SimulationEngine.new(world, build_area)
	var res := sim.step_tick()

	assert(sim.get_remaining_pollution() == 0, "Pollution should be destroyed")
	assert(sim.get_remaining_protected() == 0, "Protected block should be destroyed by monster hit")
	assert(res.is_victory == false, "Victory must FAIL when monster destroys protected block!")
	print("  Wanderer destroying protected block preventing victory passed.")

# -------------------------------------------------------------
# 4. Treasure Lineage: Multiple copies of one treasure cannot substitute for another
# -------------------------------------------------------------
func test_treasure_lineage_collection_and_multiple_copies() -> void:
	print("Testing Treasure lineage collection: copies of one cannot substitute for another...")
	var world := GridWorld.new()
	var build_area := Rect2i(0, 0, 4, 4)

	# 2 initial distinct treasures
	var t1 := BlockData.new(BlockData.Type.TREASURE, Vector2i(10, 0))
	var t2 := BlockData.new(BlockData.Type.TREASURE, Vector2i(10, 5))
	world.add_block(t1)
	world.add_block(t2)

	var sim := SimulationEngine.new(world, build_area)
	assert(sim.get_total_treasure_lineages() == 2, "There must be 2 distinct initial treasure lineages")

	# Simulate replicating t1 twice:
	# Clone t1 to create replica1 and replica2
	var r1 := t1.duplicate_block(true)
	r1.grid_pos = Vector2i(1, 1) # inside build_area
	var r2 := t1.duplicate_block(true)
	r2.grid_pos = Vector2i(2, 1) # inside build_area
	world.add_block(r1)
	world.add_block(r2)

	# Also bring original t1 into build area
	world.move_block(t1.grid_pos, Vector2i(1, 2))

	# Now 3 instances of t1 lineage are inside build area, but 0 instances of t2
	var res := sim.step_tick()

	assert(sim.get_collected_treasure_lineage_count() == 1, "Only 1 distinct lineage should be collected")
	assert(sim.has_collected_all_treasures() == false, "All treasures should NOT be collected yet (t2 is missing)!")
	assert(res.is_victory == false, "Victory should NOT be achieved because t2 is still missing!")

	# Now bring t2 into build area
	world.move_block(t2.grid_pos, Vector2i(2, 2))
	var res2 := sim.step_tick()

	assert(sim.get_collected_treasure_lineage_count() == 2, "Both lineages should now be collected")
	assert(sim.has_collected_all_treasures() == true, "All treasures should now be collected!")
	assert(res2.is_victory == true, "Victory should now be achieved!")
	print("  Multiple copies of one treasure cannot substitute for another passed.")

# -------------------------------------------------------------
# 5. Replicated Treasure Satisfies Lineage
# -------------------------------------------------------------
func test_treasure_replicated_can_satisfy_lineage() -> void:
	print("Testing replicated treasure can satisfy lineage while original stays on map...")
	var world := GridWorld.new()
	var build_area := Rect2i(0, 0, 4, 4)

	var t1 := BlockData.new(BlockData.Type.TREASURE, Vector2i(10, 0))
	world.add_block(t1)

	var sim := SimulationEngine.new(world, build_area)

	# Replicator copies t1
	var replica := t1.duplicate_block(true)
	replica.grid_pos = Vector2i(1, 1) # placed inside build area
	world.add_block(replica)

	# Original t1 remains outside at (10, 0)
	var res := sim.step_tick()

	assert(not world.has_block(Vector2i(1, 1)), "Replica inside build area should be collected")
	assert(world.has_block(Vector2i(10, 0)), "Original t1 should still be on grid")
	assert(sim.has_collected_all_treasures() == true, "Collecting the replica satisfies the lineage!")
	assert(res.is_victory == true, "Level won by collecting replica even though original remains on map!")
	print("  Replicated treasure satisfies lineage passed.")

# -------------------------------------------------------------
# 6. Pollution Absolute Count Must Be Zero
# -------------------------------------------------------------
func test_pollution_absolute_count_zero_required() -> void:
	print("Testing Pollution requires absolute remaining count to be 0...")
	var world := GridWorld.new()
	var build_area := Rect2i(0, 0, 4, 4)

	var pol1 := BlockData.new(BlockData.Type.POLLUTION, Vector2i(5, 0))
	world.add_block(pol1)

	var sim := SimulationEngine.new(world, build_area)
	assert(sim.initial_pollution_count == 1)

	# Pollution is replicated, creating a second pollution block pol2
	var pol2 := pol1.duplicate_block(true)
	pol2.grid_pos = Vector2i(6, 0)
	world.add_block(pol2)

	# Destroyer destroys pol1, but pol2 remains
	var des := BlockData.new(BlockData.Type.DESTROYER, Vector2i(4, 0), BlockData.Direction.RIGHT)
	world.add_block(des)

	var res := sim.step_tick()
	assert(not world.has_block(Vector2i(5, 0)), "pol1 should be destroyed")
	assert(world.has_block(Vector2i(6, 0)), "pol2 should still exist")
	assert(sim.get_remaining_pollution() == 1, "Remaining pollution should be 1")
	assert(res.is_victory == false, "Victory cannot be achieved while any pollution remains in world!")

	# Now destroy pol2 as well
	world.remove_block_at(Vector2i(6, 0))
	var res2 := sim.step_tick()
	assert(sim.get_remaining_pollution() == 0, "All pollution should be 0")
	assert(res2.is_victory == true, "Victory achieved once absolute pollution count is 0!")
	print("  Pollution absolute count 0 requirement passed.")

# -------------------------------------------------------------
# 7. Protected Serialization
# -------------------------------------------------------------
func test_protected_serialization() -> void:
	print("Testing Protected block to_dict and from_dict...")
	var b := BlockData.new(BlockData.Type.PROTECTED, Vector2i(3, 4), BlockData.Direction.UP)
	b.hp = 2
	b.max_hp = 2
	var dict := b.to_dict()
	assert(dict["type"] == BlockData.Type.PROTECTED)
	assert(dict["origin_id"] == b.block_id)

	var restored := BlockData.from_dict(dict)
	assert(restored.block_type == BlockData.Type.PROTECTED)
	assert(restored.grid_pos == Vector2i(3, 4))
	assert(restored.direction == BlockData.Direction.UP)
	assert(restored.origin_id == b.block_id)
	assert(restored.is_player_block() == false)
	assert(restored.is_immune() == false)
	print("  Protected block serialization passed.")
