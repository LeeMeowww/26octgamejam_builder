extends RefCounted

# Equipment budgets are explicit puzzle constraints, not solution-coordinate checks.
static func check_world(world: GridWorld, lesson: Dictionary, area: Rect2i) -> String:
	if not lesson.get("experiment", false): return ""
	var limits: Dictionary = lesson.get("equipment", {})
	var counts := {}
	for block in world.get_all_blocks():
		if block.is_world_block: continue
		var key := str(block.block_type)
		if not limits.has(key): return "本实验未提供这种器材，请移除后再运行。"
		if not area.has_point(block.grid_pos): return "请将器材放回绿色实验台。"
		counts[key] = int(counts.get(key, 0)) + 1
		if counts[key] > int(limits[key]): return "器材数量超出本实验配额。"
	return ""

static func can_place(world: GridWorld, lesson: Dictionary, area: Rect2i, type: int, pos: Vector2i) -> bool:
	if lesson.get("no_direct_placement", false): return false
	if not lesson.get("experiment", false): return true
	var candidate := world.clone()
	candidate.remove_block_at(pos)
	candidate.add_block(BlockData.new(type, pos))
	return check_world(candidate, lesson, area).is_empty()

static func inventory(world: GridWorld, lesson: Dictionary) -> String:
	var parts: Array[String] = []
	for key in lesson.get("equipment", {}):
		var used := 0
		for block in world.get_all_blocks():
			if not block.is_world_block and block.block_type == int(key): used += 1
		parts.append("%s %d/%d" % [BlockData.SHORT_NAMES[int(key)], used, int(lesson.equipment[key])])
	return "本关器材 · 已用 / 配额\n" + "   ".join(parts)
