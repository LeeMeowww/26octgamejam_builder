extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("=== TESTING 4-CONNECTIVITY GROUPING ===")
	var world := GridWorld.new()

	# Create two disconnected clusters:
	# Cluster A: (0, 0), (0, 1)
	# Cluster B: (5, 5), (5, 6)
	var b1 := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	var b2 := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 1))
	var b3 := BlockData.new(BlockData.Type.BASIC, Vector2i(5, 5))
	var b4 := BlockData.new(BlockData.Type.BASIC, Vector2i(5, 6))

	world.add_block(b1)
	world.add_block(b2)
	world.add_block(b3)
	world.add_block(b4)

	# Try grouping all 4 blocks together
	world.group_blocks([b1, b2, b3, b4])

	assert(b1.structure_id > 0, "b1 has structure")
	assert(b2.structure_id == b1.structure_id, "b1 and b2 share structure ID")
	assert(b3.structure_id > 0, "b3 has structure")
	assert(b4.structure_id == b3.structure_id, "b3 and b4 share structure ID")
	assert(b1.structure_id != b3.structure_id, "Cluster A and Cluster B must have DIFFERENT structure IDs!")
	print("PASS: Disconnected clusters received separate structure IDs!")

	# Now test dissolving a single 4-connected cluster:
	world.group_blocks([b1, b2])
	assert(b1.structure_id == 0 and b2.structure_id == 0, "Cluster A dissolved")
	assert(b3.structure_id > 0 and b4.structure_id > 0, "Cluster B remained grouped")
	print("PASS: Single 4-connected cluster toggles to dissolve!")

	# Now test removing a block between two blocks in a structure:
	# Add block at (5, 7): structure B is (5, 5)-(5, 6)-(5, 7)
	var b5 := BlockData.new(BlockData.Type.BASIC, Vector2i(5, 7))
	world.add_block(b5)
	world.group_blocks([b3, b4, b5])
	var original_sid := b3.structure_id
	assert(b4.structure_id == original_sid and b5.structure_id == original_sid)

	# Remove the middle block b4 at (5, 6)
	world.remove_block_at(Vector2i(5, 6))
	assert(b3.structure_id > 0, "b3 still has structure")
	assert(b5.structure_id > 0, "b5 still has structure")
	assert(b3.structure_id != b5.structure_id, "b3 and b5 must split into different structure IDs when connection broken!")
	print("PASS: Splitting structure when bridge block removed verified!")

	print("=== ALL 4-CONNECTIVITY TESTS PASSED! ===")
	quit(0)
