class_name SimulationEngine
extends RefCounted

signal tick_completed(result: TickResult)
signal level_won()

class TickResult extends RefCounted:
	var step_number: int = 0
	var inhibited_blocks: Array[int] = [] # block_ids
	# Array of { "id": int, "old_dir": int, "new_dir": int }
	var rotated_blocks: Array[Dictionary] = []
	# Array of { "id": int, "old_pos": Vector2i, "new_pos": Vector2i }
	var moved_blocks: Array[Dictionary] = []
	# Array of { "id": int, "old_hp": int, "new_hp": int }
	var damaged_blocks: Array[Dictionary] = []
	# Array of BlockData
	var spawned_blocks: Array[BlockData] = []
	# Array of BlockData
	var destroyed_blocks: Array[BlockData] = []
	# Array of BlockData
	var collected_treasures: Array[BlockData] = []
	var is_victory: bool = false

var world: GridWorld
var player_build_area: Rect2i = Rect2i()
var rng: RandomNumberGenerator
var step_count: int = 0
var initial_pollution_count: int = 0
var initial_treasure_count: int = 0
var collected_treasure_ids: Dictionary = {} # id -> true

func _init(p_world: GridWorld, p_build_area: Rect2i = Rect2i()) -> void:
	world = p_world
	player_build_area = p_build_area
	rng = RandomNumberGenerator.new()
	rng.randomize()
	recount_goals()

func recount_goals() -> void:
	initial_pollution_count = 0
	initial_treasure_count = 0
	collected_treasure_ids.clear()
	for b in world.get_all_blocks():
		if b.block_type == BlockData.Type.POLLUTION:
			initial_pollution_count += 1
		elif b.block_type == BlockData.Type.TREASURE:
			initial_treasure_count += 1

func get_remaining_pollution() -> int:
	var count := 0
	for b in world.get_all_blocks():
		if b.block_type == BlockData.Type.POLLUTION:
			count += 1
	return count

func get_remaining_treasure() -> int:
	var count := 0
	for b in world.get_all_blocks():
		if b.block_type == BlockData.Type.TREASURE:
			count += 1
	return count

# Performs one discrete simulation tick
func step_tick() -> TickResult:
	step_count += 1
	var result := TickResult.new()
	result.step_number = step_count

	world.suppress_events = true
	# Pristine snapshot of world at start of tick (t0) for strict simultaneity
	var snap := world.clone()

	# -------------------------------------------------------------
	# 1. Reset Transient Inhibition & Calculate Active Inhibitors
	# -------------------------------------------------------------
	_simulate_inhibitors(snap, result)

	# -------------------------------------------------------------
	# 2. Rotators (转向器)
	# -------------------------------------------------------------
	_simulate_rotators(snap, result)

	# -------------------------------------------------------------
	# 3. Pushers (推动器) & Structure Movement
	# -------------------------------------------------------------
	_simulate_pushers(snap, result)

	# -------------------------------------------------------------
	# 4. Wanderers (游荡怪物)
	# -------------------------------------------------------------
	_simulate_wanderers(snap, result)

	# -------------------------------------------------------------
	# 5. Replicators (复制器)
	# -------------------------------------------------------------
	_simulate_replicators(snap, result)

	# -------------------------------------------------------------
	# 6. Destroyers (摧毁器)
	# -------------------------------------------------------------
	_simulate_destroyers(snap, result)

	# -------------------------------------------------------------
	# 7. Check Treasure Collection & Victory
	# -------------------------------------------------------------
	_check_treasure_collection(result)

	if _check_victory():
		result.is_victory = true
		level_won.emit()

	world.suppress_events = false
	tick_completed.emit(result)
	return result

func _simulate_inhibitors(snap: GridWorld, result: TickResult) -> void:
	for b in world.get_all_blocks():
		b.is_inhibited = false
	for sb in snap.get_all_blocks():
		sb.is_inhibited = false

	var all_snap_blocks := snap.get_all_blocks()
	var block_by_id: Dictionary = {} # int -> BlockData
	for sb in all_snap_blocks:
		block_by_id[sb.block_id] = sb

	# Key: inhibitor block_id -> target block_id (if front has block and rear has block)
	# Key: block_id -> Array[int] (ids of sensing inhibitors pointing to this block)
	var inhibitor_targets: Dictionary = {} # int -> int
	var incoming_inhibitors: Dictionary = {} # int -> Array[int]

	for sb in all_snap_blocks:
		incoming_inhibitors[sb.block_id] = []

	for sb in all_snap_blocks:
		if sb.block_type == BlockData.Type.INHIBITOR:
			var front_pos := sb.grid_pos + sb.get_forward_vec()
			# Does this inhibitor detect any block in front at t0?
			if snap.has_block(front_pos):
				var rear_pos := sb.grid_pos + sb.get_backward_vec()
				var target_b := snap.get_block(rear_pos)
				if target_b != null:
					inhibitor_targets[sb.block_id] = target_b.block_id
					if incoming_inhibitors.has(target_b.block_id):
						incoming_inhibitors[target_b.block_id].append(sb.block_id)

	# State resolution:
	# settled_inhibited: block_id -> bool
	# settled_active: inh_id -> bool (true if this inhibitor is active and fires inhibition)
	# settled_inactive: inh_id -> bool (true if this inhibitor cannot fire inhibition)
	var settled_inhibited: Dictionary = {} # int -> bool
	var settled_active: Dictionary = {} # int -> bool
	var settled_inactive: Dictionary = {} # int -> bool

	var unsettled_ids: Dictionary = {} # int -> bool
	for sb in all_snap_blocks:
		unsettled_ids[sb.block_id] = true

	var changed := true
	while changed:
		changed = false
		for b_id in unsettled_ids.keys():
			var incoming: Array = incoming_inhibitors.get(b_id, [])

			var has_active_inhibition := false
			var all_incoming_inactive := true

			for inc_id in incoming:
				if settled_active.get(inc_id, false):
					has_active_inhibition = true
					break
				if not settled_inactive.get(inc_id, false):
					all_incoming_inactive = false

			if has_active_inhibition:
				# Reached by an active inhibitor -> definitively INHIBITED
				settled_inhibited[b_id] = true
				settled_inactive[b_id] = true # Inhibited blocks lose ability to inhibit
				unsettled_ids.erase(b_id)
				changed = true
			elif all_incoming_inactive:
				# All potential inhibitors targeting this block are inactive (or none exist)
				# -> definitively NOT INHIBITED
				settled_inhibited[b_id] = false
				var sb: BlockData = block_by_id[b_id]
				if sb.block_type == BlockData.Type.INHIBITOR:
					if inhibitor_targets.has(b_id):
						settled_active[b_id] = true
					else:
						settled_inactive[b_id] = true
				else:
					settled_inactive[b_id] = true
				unsettled_ids.erase(b_id)
				changed = true

		# Handle mutual cycle deadlock fallback (if graph contains mutual inhibition loops)
		if not changed and not unsettled_ids.is_empty():
			var cycle_fired := false
			var nodes_to_settle: Array[int] = []
			for b_id in unsettled_ids.keys():
				var sb: BlockData = block_by_id[b_id]
				if sb.block_type == BlockData.Type.INHIBITOR and inhibitor_targets.has(b_id):
					nodes_to_settle.append(b_id)
					nodes_to_settle.append(inhibitor_targets[b_id])
					cycle_fired = true

			for nid in nodes_to_settle:
				settled_inhibited[nid] = true
				settled_inactive[nid] = true
				unsettled_ids.erase(nid)

			if cycle_fired:
				changed = true
			else:
				for b_id in unsettled_ids.keys():
					settled_inhibited[b_id] = false
				unsettled_ids.clear()

	# Apply final inhibition states to world and snap
	for sb in all_snap_blocks:
		if settled_inhibited.get(sb.block_id, false):
			sb.is_inhibited = true
			result.inhibited_blocks.append(sb.block_id)
			for wb in world.get_all_blocks():
				if wb.block_id == sb.block_id:
					wb.is_inhibited = true
					break

func _simulate_rotators(snap: GridWorld, result: TickResult) -> void:
	# "本身有顺时针逆时针两种模式, 会将前方(指向)的方块按方向旋转90°."
	# "当多个转向器同时指向一个目标时, 该目标旋转角度为各自之和"
	var rotation_deltas: Dictionary = {} # target block_id -> sum of delta (+1 for CW, -1 for CCW)
	for snap_b in snap.get_all_blocks():
		if snap_b.block_type == BlockData.Type.ROTATOR and not snap_b.is_inhibited:
			var target_pos := snap_b.grid_pos + snap_b.get_forward_vec()
			var target_snap := snap.get_block(target_pos)
			if target_snap != null:
				var delta := 1 if snap_b.sub_mode == 0 else -1
				rotation_deltas[target_snap.block_id] = rotation_deltas.get(target_snap.block_id, 0) + delta

	for tid in rotation_deltas.keys():
		var total_delta: int = rotation_deltas[tid]
		for wb in world.get_all_blocks():
			if wb.block_id == tid:
				var old_dir := wb.direction
				var new_dir := posmod(old_dir + total_delta, 4)
				if old_dir != new_dir:
					wb.direction = new_dir
					result.rotated_blocks.append({
						"id": wb.block_id,
						"old_dir": old_dir,
						"new_dir": new_dir
					})
				for sb in snap.get_all_blocks():
					if sb.block_id == tid:
						sb.direction = new_dir
						break
				break

# -----------------------------------------------------------------
# Pusher & Structure Movement Resolution
# -----------------------------------------------------------------
func _simulate_pushers(snap: GridWorld, result: TickResult) -> void:
	# Group current blocks into entities:
	# - Structure (structure_id > 0)
	# - Single block (structure_id == 0)
	var all_blocks := world.get_all_blocks()
	var entities: Array[Array] = [] # Array of Array[BlockData]
	var block_to_entity: Dictionary = {} # BlockData -> Array[BlockData]
	var sid_to_entity: Dictionary = {} # int -> Array[BlockData]

	for b in all_blocks:
		if b.structure_id > 0:
			if not sid_to_entity.has(b.structure_id):
				var ent: Array[BlockData] = []
				sid_to_entity[b.structure_id] = ent
				entities.append(ent)
			sid_to_entity[b.structure_id].append(b)
			block_to_entity[b] = sid_to_entity[b.structure_id]
		else:
			var ent: Array[BlockData] = [b]
			entities.append(ent)
			block_to_entity[b] = ent

	# Accumulate push forces on entities
	# Key: entity (Array) -> Dictionary { "x_pos": bool, "x_neg": bool, "y_pos": bool, "y_neg": bool }
	var entity_forces: Dictionary = {}
	for ent in entities:
		entity_forces[ent] = { "x_pos": false, "x_neg": false, "y_pos": false, "y_neg": false }

	for snap_b in snap.get_all_blocks():
		if snap_b.block_type == BlockData.Type.PUSHER and not snap_b.is_inhibited:
			var fwd := snap_b.get_forward_vec()
			var target_pos := snap_b.grid_pos + fwd
			var target_snap_block := snap.get_block(target_pos)

			var target_block: BlockData = null
			if target_snap_block != null:
				for wb in all_blocks:
					if wb.block_id == target_snap_block.block_id:
						target_block = wb
						break

			var own_block: BlockData = null
			for wb in all_blocks:
				if wb.block_id == snap_b.block_id:
					own_block = wb
					break

			var target_entity = block_to_entity.get(target_block, null)
			var own_entity = block_to_entity.get(own_block, null)

			if target_entity != null:
				_apply_force_to_entity(entity_forces[target_entity], fwd)
			if own_entity != null:
				_apply_force_to_entity(entity_forces[own_entity], fwd)

	# Calculate net intended delta for each entity
	var entity_deltas: Dictionary = {}
	for ent in entities:
		var f = entity_forces[ent]
		var dx := 0
		if f.x_pos and not f.x_neg:
			dx = 1
		elif f.x_neg and not f.x_pos:
			dx = -1

		var dy := 0
		if f.y_pos and not f.y_neg:
			dy = 1
		elif f.y_neg and not f.y_pos:
			dy = -1

		entity_deltas[ent] = Vector2i(dx, dy)

	# Collision & Blockage Check:
	# If any entity cannot move, its delta becomes (0,0).
	# Cascading: run until no more entities are stopped.
	var changed := true
	while changed:
		changed = false
		for ent in entities:
			var delta: Vector2i = entity_deltas[ent]
			if delta == Vector2i.ZERO:
				continue

			# Check if moving this entity creates an invalid collision
			var can_move := true
			for b: BlockData in ent:
				var next_pos := b.grid_pos + delta
				var occupant := world.get_block(next_pos)
				if occupant != null and occupant not in ent:
					# Hit another block outside entity
					# If occupant is HARD and uninhibited, absolutely cannot move!
					if occupant.is_immune():
						can_move = false
						break
					# If occupant is moving in the exact same direction, it might be fine,
					# but if occupant is stopped or moving in conflicting direction, blocked!
					var occ_ent = block_to_entity.get(occupant, null)
					var occ_delta: Vector2i = entity_deltas.get(occ_ent, Vector2i.ZERO)
					if occ_delta != delta:
						can_move = false
						break

			if not can_move:
				entity_deltas[ent] = Vector2i.ZERO
				changed = true

	# Apply valid movements
	# To prevent overwriting when swapping cells, sort or remove from grid first then re-insert
	var moved_entries: Array[Dictionary] = []
	for ent in entities:
		var delta: Vector2i = entity_deltas[ent]
		if delta != Vector2i.ZERO:
			for b: BlockData in ent:
				moved_entries.append({
					"block": b,
					"old_pos": b.grid_pos,
					"new_pos": b.grid_pos + delta
				})

	if not moved_entries.is_empty():
		world.batch_move_blocks(moved_entries)
		for entry in moved_entries:
			var b: BlockData = entry["block"]
			result.moved_blocks.append({
				"id": b.block_id,
				"old_pos": entry["old_pos"],
				"new_pos": entry["new_pos"]
			})

func _apply_force_to_entity(force_dict: Dictionary, dir_vec: Vector2i) -> void:
	if dir_vec.x > 0:
		force_dict.x_pos = true
	elif dir_vec.x < 0:
		force_dict.x_neg = true

	if dir_vec.y > 0:
		force_dict.y_pos = true
	elif dir_vec.y < 0:
		force_dict.y_neg = true

# -----------------------------------------------------------------
# Wanderer (游荡怪物) Simulation
# -----------------------------------------------------------------
func _simulate_wanderers(snap: GridWorld, result: TickResult) -> void:
	for snap_b in snap.get_all_blocks():
		if snap_b.block_type != BlockData.Type.WANDERER or snap_b.is_inhibited:
			continue

		var b: BlockData = null
		for wb in world.get_all_blocks():
			if wb.block_id == snap_b.block_id:
				b = wb
				break
		if b == null:
			continue

		# Wanderer horizontal direction (only Left or Right)
		var horiz_dir := Vector2i.RIGHT if (snap_b.direction == BlockData.Direction.RIGHT or snap_b.direction == BlockData.Direction.DOWN) else Vector2i.LEFT
		var forward_pos := snap_b.grid_pos + horiz_dir
		var target_snap := snap.get_block(forward_pos)

		if target_snap != null:
			# Contact damage
			var target_world := world.get_block(forward_pos)
			if target_world != null and not target_world.is_immune():
				var old_hp := target_world.hp
				target_world.hp = maxi(0, target_world.hp - 1)
				result.damaged_blocks.append({
					"id": target_world.block_id,
					"old_hp": old_hp,
					"new_hp": target_world.hp
				})
				if target_world.hp <= 0:
					world.remove_block_at(target_world.grid_pos)
					result.destroyed_blocks.append(target_world)

			# Try to jump up 1 block:
			# Needs above current (snap_b.grid_pos + UP) to be empty, and above target (forward_pos + UP) to be empty
			var up_vec := Vector2i(0, -1)
			var head_pos := snap_b.grid_pos + up_vec
			var jump_pos := forward_pos + up_vec

			if not world.has_block(head_pos) and not world.has_block(jump_pos):
				# Jump up onto the step!
				var old_pos := b.grid_pos
				world.move_block(old_pos, jump_pos)
				result.moved_blocks.append({
					"id": b.block_id,
					"old_pos": old_pos,
					"new_pos": jump_pos
				})
			else:
				# Cannot jump, turn around!
				var old_dir := b.direction
				b.direction = BlockData.Direction.LEFT if horiz_dir == Vector2i.RIGHT else BlockData.Direction.RIGHT
				result.rotated_blocks.append({
					"id": b.block_id,
					"old_dir": old_dir,
					"new_dir": b.direction
				})
		else:
			# Forward is empty: check if there is floor or if falling
			var ground_pos := forward_pos + Vector2i(0, 1)
			if world.has_block(ground_pos):
				# Normal step forward
				var old_pos := b.grid_pos
				world.move_block(old_pos, forward_pos)
				result.moved_blocks.append({
					"id": b.block_id,
					"old_pos": old_pos,
					"new_pos": forward_pos
				})
			else:
				# Drop down (fall 1 step forward and down)
				var drop_pos := forward_pos + Vector2i(0, 1)
				var old_pos := b.grid_pos
				world.move_block(old_pos, drop_pos)
				result.moved_blocks.append({
					"id": b.block_id,
					"old_pos": old_pos,
					"new_pos": drop_pos
				})

# -----------------------------------------------------------------
# Replicator (复制器) Simulation
# -----------------------------------------------------------------
func _simulate_replicators(snap: GridWorld, result: TickResult) -> void:
	# "若后方有方块, 则将其复制到前方. 保持其朝向."
	# "当复制器写入位置本身有方块时, 什么也不发生. 当两个复制器复制位置冲突时, 随机写入一格"
	# "复制出的方块不自动继承结构"
	var write_candidates: Dictionary = {}

	for snap_b in snap.get_all_blocks():
		if snap_b.block_type == BlockData.Type.REPLICATOR and not snap_b.is_inhibited:
			var src_pos := snap_b.grid_pos + snap_b.get_backward_vec()
			# Source block is read from t0 snapshot!
			var src_block := snap.get_block(src_pos)

			if src_block != null:
				if src_block.is_immune():
					# 坚硬方块未被抑制无法被复制
					continue

				# Replicator's current location in world (in case it was pushed)
				var rep_curr_pos := snap_b.grid_pos
				for wb in world.get_all_blocks():
					if wb.block_id == snap_b.block_id:
						rep_curr_pos = wb.grid_pos
						break

				var dest_pos := rep_curr_pos + snap_b.get_forward_vec()

				# Destination must currently be unoccupied in world
				if world.has_block(dest_pos):
					continue

				if not write_candidates.has(dest_pos):
					write_candidates[dest_pos] = []
				write_candidates[dest_pos].append(src_block)

	for dest_pos in write_candidates.keys():
		var candidates: Array = write_candidates[dest_pos]
		# True RNG selection if multiple replicators conflict on same dest_pos
		var chosen_src: BlockData = candidates[rng.randi_range(0, candidates.size() - 1)]

		var replica := chosen_src.duplicate_block(true)
		replica.grid_pos = dest_pos
		replica.structure_id = 0 # Does NOT inherit structure
		replica.hp = replica.max_hp
		replica.is_inhibited = false
		world.add_block(replica)
		result.spawned_blocks.append(replica)

# -----------------------------------------------------------------
# Destroyer (摧毁器) Simulation
# -----------------------------------------------------------------
func _simulate_destroyers(snap: GridWorld, result: TickResult) -> void:
	var to_destroy: Dictionary = {} # block_id -> BlockData

	for snap_b in snap.get_all_blocks():
		if snap_b.block_type == BlockData.Type.DESTROYER and not snap_b.is_inhibited:
			var target_pos := snap_b.grid_pos + snap_b.get_forward_vec()
			var target_snap := snap.get_block(target_pos)
			if target_snap != null and not target_snap.is_immune():
				to_destroy[target_snap.block_id] = target_snap

			# Also check current front position if destroyer moved
			var cur_pos := snap_b.grid_pos
			for wb in world.get_all_blocks():
				if wb.block_id == snap_b.block_id:
					cur_pos = wb.grid_pos
					break
			var cur_front := cur_pos + snap_b.get_forward_vec()
			var cur_target := world.get_block(cur_front)
			if cur_target != null and not cur_target.is_immune() and cur_target.block_id != snap_b.block_id:
				to_destroy[cur_target.block_id] = cur_target

	for tid in to_destroy.keys():
		for wb in world.get_all_blocks():
			if wb.block_id == tid:
				world.remove_block_at(wb.grid_pos)
				result.destroyed_blocks.append(wb)
				break

# -----------------------------------------------------------------
# Treasure Collection & Goal Checking
# -----------------------------------------------------------------
func _check_treasure_collection(result: TickResult) -> void:
	# 宝藏回收规则：宝藏必须被机械推动/搬运带回玩家建造区域内才算被回收！
	var all_blocks := world.get_all_blocks()
	var treasures_to_collect: Array[BlockData] = []

	for b in all_blocks:
		if b.block_type == BlockData.Type.TREASURE:
			if player_build_area.size != Vector2i.ZERO:
				# 有指定建造区时：必须带回建造区内
				if player_build_area.has_point(b.grid_pos):
					treasures_to_collect.append(b)
			else:
				# 若关卡为无限制建造区（全图模式）：与机械相邻即可回收
				var collected := false
				for offset in BlockData.DIR_VECTORS:
					var neighbor := world.get_block(b.grid_pos + offset)
					if neighbor != null and neighbor.is_player_block():
						collected = true
						break
				if collected:
					treasures_to_collect.append(b)

	for tr in treasures_to_collect:
		collected_treasure_ids[tr.block_id] = true
		world.remove_block_at(tr.grid_pos)
		result.collected_treasures.append(tr)

func _check_victory() -> bool:
	# Victory condition:
	# 1. All POLLUTION blocks destroyed
	# 2. All TREASURE blocks collected
	var remaining_pollution := get_remaining_pollution()
	var remaining_treasure := get_remaining_treasure()

	if remaining_pollution == 0 and remaining_treasure == 0:
		# Only declare victory if there was at least 1 goal initially, or if board is clear
		return true
	return false
