extends SceneTree

# =====================================================================
# 严格同时性 (t0 快照) 语义回归测试
# 原则：每个方块的行动一律基于回合开始时(t0=上一回合结束)的状态；
# 本回合被旋转/移动的方块仍按 t0 朝向与位置行动，新朝向/位置自下一回合生效。
# 例外（推进-旋转次序）：推进阶段读取旋转后的世界朝向——
# 转向器旋转出的新朝向当回合立即生效于推进方向与推进吞噬判定。
# =====================================================================

func _init() -> void:
	print("=== RUNNING T0 SIMULTANEITY TESTS ===")
	test_rotator_then_destroyer()
	test_rotator_then_replicator()
	test_rotator_then_pusher()
	test_pushed_replicator_writes_t0_front()
	test_pushed_wanderer_yields()
	test_rotated_pushed_destroyer_no_instant_consume()
	print("=== ALL T0 SIMULTANEITY TESTS PASSED SUCCESSFULLY! ===")
	quit(0)

func check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("ASSERT FAIL: ", msg)
		assert(false, msg)

# ---------------------------------------------------------------
# 1. 转向器旋转摧毁器：摧毁器本回合仍按旧朝向，下一回合才用新朝向
# ---------------------------------------------------------------
func test_rotator_then_destroyer() -> void:
	print("Testing Rotator -> Destroyer (t0 facing)...")
	var world := GridWorld.new()
	# 摧毁器在 (5,5) 朝上，t0 面前 (5,4) 为空
	var d := BlockData.new(BlockData.Type.DESTROYER, Vector2i(5, 5), BlockData.Direction.UP)
	# 转向器在 (4,5) 朝右（对准摧毁器），顺时针
	var r := BlockData.new(BlockData.Type.ROTATOR, Vector2i(4, 5), BlockData.Direction.RIGHT)
	r.sub_mode = 0
	# 受害者在摧毁器右侧 (6,5)：只有摧毁器转向右之后才可能被对准
	var x := BlockData.new(BlockData.Type.BASIC, Vector2i(6, 5))
	world.add_block(d); world.add_block(r); world.add_block(x)

	var sim := SimulationEngine.new(world)
	sim.step_tick()
	# 第 1 回合：摧毁器被旋转为朝右（可见），但本回合按 t0 朝上 → 什么都没摧毁
	check(d.direction == BlockData.Direction.RIGHT, "Destroyer should be rotated to RIGHT after tick 1 (got %d)" % d.direction)
	check(world.get_block(Vector2i(6, 5)) != null, "Victim must survive tick 1 (destroyer acts on t0 facing, not the rotated one)!")

	sim.step_tick()
	# 第 2 回合：摧毁器现在朝右，对准 (6,5) → 受害者被摧毁
	check(world.get_block(Vector2i(6, 5)) == null, "Victim should be destroyed in tick 2 (new facing now effective)!")
	print("  Rotator -> Destroyer t0 semantics verified.")

# ---------------------------------------------------------------
# 2. 转向器旋转复制器：本回合复制到 t0 前方，而非旋转后的前方
# ---------------------------------------------------------------
func test_rotator_then_replicator() -> void:
	print("Testing Rotator -> Replicator (t0 write cell)...")
	var world := GridWorld.new()
	# 复制器在 (5,5) 朝上：t0 前方 (5,4) 为空，后方 (5,6) 有源方块
	var rep := BlockData.new(BlockData.Type.REPLICATOR, Vector2i(5, 5), BlockData.Direction.UP)
	var s := BlockData.new(BlockData.Type.BASIC, Vector2i(5, 6))
	# 转向器在 (4,5) 朝右，把复制器从朝上旋成朝右
	var r := BlockData.new(BlockData.Type.ROTATOR, Vector2i(4, 5), BlockData.Direction.RIGHT)
	r.sub_mode = 0
	world.add_block(rep); world.add_block(s); world.add_block(r)

	var sim := SimulationEngine.new(world)
	sim.step_tick()
	# 第 1 回合：条件在 t0 成立（前方(5,4)空、后方(5,6)有方块）→ 副本出现在 t0 前方 (5,4)
	check(world.get_block(Vector2i(5, 4)) != null, "Replica must appear at t0-front (5,4) in tick 1!")
	check(world.get_block(Vector2i(5, 4)).block_type == BlockData.Type.BASIC, "Replica at (5,4) must be a copy of the rear BASIC block!")
	check(world.get_block(Vector2i(6, 5)) == null, "NO replica at rotated-front (6,5) in tick 1 (old buggy behavior)!")
	check(rep.direction == BlockData.Direction.RIGHT, "Replicator should now face RIGHT (rotation visible this tick).")

	# 第 2 回合：复制器朝右：前方 (6,5) 空、后方 (4,5) 是转向器 → 复制转向器
	sim.step_tick()
	var r2 := world.get_block(Vector2i(6, 5))
	check(r2 != null, "Tick 2: replica should appear at new front (6,5).")
	check(r2 != null and r2.block_type == BlockData.Type.ROTATOR, "Tick 2 replica must be a copy of the ROTATOR (now the rear block).")
	print("  Rotator -> Replicator t0 semantics verified.")

# ---------------------------------------------------------------
# 3. 转向器旋转推动器：推进-旋转次序 —— 本回合即按旋转后的方向推进
# ---------------------------------------------------------------
func test_rotator_then_pusher() -> void:
	print("Testing Rotator -> Pusher (rotated push direction)...")
	var world := GridWorld.new()
	# 推动器在 (5,5) 朝上，前方 (5,4) 有方块 B
	var p := BlockData.new(BlockData.Type.PUSHER, Vector2i(5, 5), BlockData.Direction.UP)
	var b := BlockData.new(BlockData.Type.BASIC, Vector2i(5, 4))
	# 转向器在 (4,5) 朝右，把推动器从朝上旋成朝右
	var r := BlockData.new(BlockData.Type.ROTATOR, Vector2i(4, 5), BlockData.Direction.RIGHT)
	r.sub_mode = 0
	world.add_block(p); world.add_block(b); world.add_block(r)

	var sim := SimulationEngine.new(world)
	sim.step_tick()
	# 第 1 回合：推进按旋转后的朝向(右)执行：
	# - 推动器自推进到 (6,5)
	# - B 不再处于推动路径上（旧朝向上方），保持 (5,4) 不动
	check(p.direction == BlockData.Direction.RIGHT, "Pusher should now face RIGHT (rotation visible).")
	check(p.grid_pos == Vector2i(6, 5), "Pusher should self-propel RIGHT (rotated direction) to (6,5), got %s" % [p.grid_pos])
	check(b.grid_pos == Vector2i(5, 4), "Block B (no longer in path) must stay at (5,4), got %s" % [b.grid_pos])
	print("  Rotator -> Pusher rotate-then-push order verified.")

# ---------------------------------------------------------------
# 4. 复制器被推动：副本仍写在 t0 前方格子
# ---------------------------------------------------------------
func test_pushed_replicator_writes_t0_front() -> void:
	print("Testing Pushed Replicator (write cell = t0 front)...")
	var world := GridWorld.new()
	# 复制器在 (5,5) 朝右：t0 前方 (6,5) 空、后方 (4,5) 有源方块
	var rep := BlockData.new(BlockData.Type.REPLICATOR, Vector2i(5, 5), BlockData.Direction.RIGHT)
	var s := BlockData.new(BlockData.Type.BASIC, Vector2i(4, 5))
	# 推动器在 (5,6) 朝上：把复制器连同自己向上推一格
	var pu := BlockData.new(BlockData.Type.PUSHER, Vector2i(5, 6), BlockData.Direction.UP)
	world.add_block(rep); world.add_block(s); world.add_block(pu)

	var sim := SimulationEngine.new(world)
	sim.step_tick()
	# 复制器被推到 (5,4)，但副本必须出现在 t0 前方 (6,5)（"上一回合前方为空的那个格子"）
	check(rep.grid_pos == Vector2i(5, 4), "Replicator should be pushed UP to (5,4), got %s" % [rep.grid_pos])
	var copy := world.get_block(Vector2i(6, 5))
	check(copy != null, "Replica must appear at t0-front (6,5) even though replicator was pushed!")
	check(copy != null and copy.block_type == BlockData.Type.BASIC, "Replica must be a copy of rear source block!")
	check(world.get_block(Vector2i(6, 4)) == null, "NO replica at (6,4) (new-position-front = old buggy behavior)!")
	print("  Pushed Replicator t0 write cell verified.")

# ---------------------------------------------------------------
# 5. 怪物被推动的回合：退让（不走路/不攻击/不转向）
# ---------------------------------------------------------------
func test_pushed_wanderer_yields() -> void:
	print("Testing Pushed Wanderer yields...")
	var world := GridWorld.new()
	# 怪物在 (5,4) 朝右，脚下有地板 (5,5)/(6,5)
	var w := BlockData.new(BlockData.Type.WANDERER, Vector2i(5, 4), BlockData.Direction.RIGHT)
	world.add_block(w)
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(5, 5)))
	world.add_block(BlockData.new(BlockData.Type.HARD, Vector2i(6, 5)))
	# 推动器在 (6,4) 朝左：把怪物向左推到 (4,4)，自己跟进 (5,4)
	var pu := BlockData.new(BlockData.Type.PUSHER, Vector2i(6, 4), BlockData.Direction.LEFT)
	world.add_block(pu)

	var sim := SimulationEngine.new(world)
	sim.step_tick()
	# 怪物被推动 → 本回合退让：停在 (4,4)，不得从新位置"瞬移走"到 t0 前方 (6,4)
	check(w.grid_pos == Vector2i(4, 4), "Pushed wanderer should yield at (4,4), got %s" % [w.grid_pos])
	check(world.get_block(Vector2i(6, 4)) == null or world.get_block(Vector2i(6, 4)) == pu, "Wanderer must NOT teleport-walk to t0-front (6,4)!")
	check(pu.hp == 2, "Pusher must not be attacked by a pushed (yielding) wanderer!")
	print("  Pushed Wanderer yield verified.")

# ---------------------------------------------------------------
# 6. 被旋转+被推动的摧毁器：吞噬推进判定用旋转后朝向（推进-旋转次序）
# ---------------------------------------------------------------
func test_rotated_pushed_destroyer_no_instant_consume() -> void:
	print("Testing Rotated+Pushed Destroyer (consume uses rotated facing)...")
	var world := GridWorld.new()
	# 推动器 (1,0) 朝右 + 摧毁器 (2,0) 朝上，同结构编组
	var p1 := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.RIGHT)
	p1.structure_id = 1
	var d := BlockData.new(BlockData.Type.DESTROYER, Vector2i(2, 0), BlockData.Direction.UP)
	d.structure_id = 1
	# 转向器 (2,1) 朝上，对准摧毁器，把它从朝上旋成朝右
	var r := BlockData.new(BlockData.Type.ROTATOR, Vector2i(2, 1), BlockData.Direction.UP)
	r.sub_mode = 0
	# 目标方块 (3,0)
	var m := BlockData.new(BlockData.Type.BASIC, Vector2i(3, 0))
	world.add_block(p1); world.add_block(d); world.add_block(r); world.add_block(m)

	var sim := SimulationEngine.new(world)
	sim.step_tick()
	# 第 1 回合：摧毁器被旋转为朝右，与推进方向一致 → 吞噬目标并推进
	check(d.direction == BlockData.Direction.RIGHT, "Destroyer should be rotated to RIGHT in tick 1.")
	check(not _world_has_id(world, m.block_id), "Target should be consumed in tick 1 (rotated facing matches push direction).")
	check(d.grid_pos == Vector2i(3, 0), "Destroyer should advance into consumed cell (3,0), got %s" % [d.grid_pos])
	print("  Rotated+Pushed Destroyer rotate-then-push consume verified.")

func _world_has_id(w: GridWorld, id: int) -> bool:
	for b in w.get_all_blocks():
		if b.block_id == id:
			return true
	return false
