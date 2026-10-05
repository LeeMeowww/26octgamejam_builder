extends SceneTree

func _init() -> void:
	print("=== RUNNING INHIBITOR CHAIN TESTS ===")
	test_four_inhibitors_with_front_object()
	test_four_inhibitors_without_front_object()
	test_three_inhibitors_with_front_object()
	test_two_inhibitors_with_front_object()
	test_single_inhibitor()
	test_mutual_inhibition_cycle()
	test_external_breaker_into_cycle()
	print("=== ALL INHIBITOR CHAIN TESTS PASSED! ===")
	quit(0)

func test_four_inhibitors_with_front_object() -> void:
	print("Testing 4 inhibitors in a row WITH front object...")
	# Front is +X (RIGHT). Rear is -X (LEFT).
	# O at (0, 0)
	# I1 at (-1, 0) facing RIGHT (front=(0,0) [O], rear=(-2,0) [I2])
	# I2 at (-2, 0) facing RIGHT (front=(-1,0) [I1], rear=(-3,0) [I3])
	# I3 at (-3, 0) facing RIGHT (front=(-2,0) [I2], rear=(-4,0) [I4])
	# I4 at (-4, 0) facing RIGHT (front=(-3,0) [I3], rear=(-5,0) [X])
	# X at (-5, 0)
	var world := GridWorld.new()
	var obj_front := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	var i1 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-1, 0), BlockData.Direction.RIGHT)
	var i2 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-2, 0), BlockData.Direction.RIGHT)
	var i3 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-3, 0), BlockData.Direction.RIGHT)
	var i4 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-4, 0), BlockData.Direction.RIGHT)
	var obj_rear := BlockData.new(BlockData.Type.BASIC, Vector2i(-5, 0))

	world.add_block(obj_front)
	world.add_block(i1)
	world.add_block(i2)
	world.add_block(i3)
	world.add_block(i4)
	world.add_block(obj_rear)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	# I1 senses O -> I1 active -> I2 inhibited
	# I2 inhibited -> I3 not inhibited
	# I3 senses I2 and not inhibited -> I3 active -> I4 inhibited
	# I4 inhibited -> obj_rear (X) not inhibited!
	assert(i1.is_inhibited == false, "I1 should NOT be inhibited!")
	assert(i2.is_inhibited == true, "I2 should BE inhibited!")
	assert(i3.is_inhibited == false, "I3 should NOT be inhibited!")
	assert(i4.is_inhibited == true, "I4 should BE inhibited!")
	assert(obj_rear.is_inhibited == false, "Final object X should NOT be inhibited!")
	print("  4 inhibitors with front object verified: [I1: Active, I2: Inhibited, I3: Active, I4: Inhibited, X: Not Inhibited].")

func test_four_inhibitors_without_front_object() -> void:
	print("Testing 4 inhibitors in a row WITHOUT front object...")
	# Empty at (0, 0)
	# I1 at (-1, 0) facing RIGHT
	# I2 at (-2, 0) facing RIGHT
	# I3 at (-3, 0) facing RIGHT
	# I4 at (-4, 0) facing RIGHT
	# X at (-5, 0)
	var world := GridWorld.new()
	var i1 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-1, 0), BlockData.Direction.RIGHT)
	var i2 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-2, 0), BlockData.Direction.RIGHT)
	var i3 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-3, 0), BlockData.Direction.RIGHT)
	var i4 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-4, 0), BlockData.Direction.RIGHT)
	var obj_rear := BlockData.new(BlockData.Type.BASIC, Vector2i(-5, 0))

	world.add_block(i1)
	world.add_block(i2)
	world.add_block(i3)
	world.add_block(i4)
	world.add_block(obj_rear)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	# I1 senses nothing -> I1 inactive -> I2 not inhibited
	# I2 senses I1 and not inhibited -> I2 active -> I3 inhibited
	# I3 inhibited -> I4 not inhibited
	# I4 senses I3 and not inhibited -> I4 active -> obj_rear (X) inhibited!
	assert(i1.is_inhibited == false, "I1 should NOT be inhibited (just idle)!")
	assert(i2.is_inhibited == false, "I2 should NOT be inhibited (active)!")
	assert(i3.is_inhibited == true, "I3 should BE inhibited!")
	assert(i4.is_inhibited == false, "I4 should NOT be inhibited (active)!")
	assert(obj_rear.is_inhibited == true, "Final object X should BE inhibited!")
	print("  4 inhibitors without front object verified: [I1: Idle, I2: Active, I3: Inhibited, I4: Active, X: Inhibited].")

func test_three_inhibitors_with_front_object() -> void:
	print("Testing 3 inhibitors with front object...")
	var world := GridWorld.new()
	var obj_front := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	var i1 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-1, 0), BlockData.Direction.RIGHT)
	var i2 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-2, 0), BlockData.Direction.RIGHT)
	var i3 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-3, 0), BlockData.Direction.RIGHT)
	var x := BlockData.new(BlockData.Type.BASIC, Vector2i(-4, 0))

	world.add_block(obj_front)
	world.add_block(i1)
	world.add_block(i2)
	world.add_block(i3)
	world.add_block(x)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	assert(i1.is_inhibited == false, "I1 should NOT be inhibited")
	assert(i2.is_inhibited == true, "I2 should BE inhibited")
	assert(i3.is_inhibited == false, "I3 should NOT be inhibited")
	assert(x.is_inhibited == true, "X should BE inhibited")
	print("  3 inhibitors with front object verified: [I1: Active, I2: Inhibited, I3: Active, X: Inhibited].")

func test_two_inhibitors_with_front_object() -> void:
	print("Testing 2 inhibitors with front object...")
	var world := GridWorld.new()
	var obj_front := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	var i1 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-1, 0), BlockData.Direction.RIGHT)
	var i2 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-2, 0), BlockData.Direction.RIGHT)
	var x := BlockData.new(BlockData.Type.BASIC, Vector2i(-3, 0))

	world.add_block(obj_front)
	world.add_block(i1)
	world.add_block(i2)
	world.add_block(x)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	assert(i1.is_inhibited == false, "I1 should NOT be inhibited")
	assert(i2.is_inhibited == true, "I2 should BE inhibited")
	assert(x.is_inhibited == false, "X should NOT be inhibited")
	print("  2 inhibitors with front object verified: [I1: Active, I2: Inhibited, X: Not Inhibited].")

func test_single_inhibitor() -> void:
	print("Testing 1 single inhibitor with front object...")
	var world := GridWorld.new()
	var obj_front := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	var i1 := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-1, 0), BlockData.Direction.RIGHT)
	var x := BlockData.new(BlockData.Type.BASIC, Vector2i(-2, 0))

	world.add_block(obj_front)
	world.add_block(i1)
	world.add_block(x)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	assert(i1.is_inhibited == false, "I1 should NOT be inhibited")
	assert(x.is_inhibited == true, "X should BE inhibited")
	print("  1 inhibitor verified: [I1: Active, X: Inhibited].")

func test_mutual_inhibition_cycle() -> void:
	print("Testing mutual inhibition cycle (back-to-back inhibitors)...")
	var world := GridWorld.new()
	# I_A at (0, 0) facing RIGHT (front=(1,0), rear=(-1,0))
	# O_A at (1, 0)
	# I_B at (-1, 0) facing LEFT (front=(-2,0), rear=(0,0))
	# O_B at (-2, 0)
	var oa := BlockData.new(BlockData.Type.BASIC, Vector2i(1, 0))
	var ia := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(0, 0), BlockData.Direction.RIGHT)
	var ib := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-1, 0), BlockData.Direction.LEFT)
	var ob := BlockData.new(BlockData.Type.BASIC, Vector2i(-2, 0))

	world.add_block(oa)
	world.add_block(ia)
	world.add_block(ib)
	world.add_block(ob)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	# Both fire simultaneously into each other's rear -> both become inhibited
	assert(ia.is_inhibited == true, "I_A should BE inhibited")
	assert(ib.is_inhibited == true, "I_B should BE inhibited")
	print("  Mutual cycle verified: both mutually inhibit simultaneously.")

func test_external_breaker_into_cycle() -> void:
	print("Testing external master breaking cycle...")
	var world := GridWorld.new()
	# E at (1, 0) facing RIGHT: front=(2,0)[O_E], rear=(0,0)[I_A]
	# O_E at (2, 0)
	# I_A at (0, 0) facing RIGHT: front=(1,0)[E], rear=(-1,0)[I_B]
	# I_B at (-1, 0) facing LEFT: front=(-2,0)[O_B], rear=(0,0)[I_A]
	# O_B at (-2, 0)
	var oe := BlockData.new(BlockData.Type.BASIC, Vector2i(2, 0))
	var e := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(1, 0), BlockData.Direction.RIGHT)
	var ia := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(0, 0), BlockData.Direction.RIGHT)
	var ib := BlockData.new(BlockData.Type.INHIBITOR, Vector2i(-1, 0), BlockData.Direction.LEFT)
	var ob := BlockData.new(BlockData.Type.BASIC, Vector2i(-2, 0))

	world.add_block(oe)
	world.add_block(e)
	world.add_block(ia)
	world.add_block(ib)
	world.add_block(ob)

	var sim := SimulationEngine.new(world)
	sim.step_tick()

	# E is not inhibited -> E active -> I_A inhibited!
	# I_A is inhibited -> I_A cannot inhibit I_B!
	# I_B senses O_B and is not inhibited -> I_B active!
	assert(e.is_inhibited == false, "E should NOT be inhibited")
	assert(ia.is_inhibited == true, "I_A should BE inhibited by E")
	assert(ib.is_inhibited == false, "I_B should NOT be inhibited")
	print("  External master verified: E inhibits I_A, freeing I_B to be active.")
