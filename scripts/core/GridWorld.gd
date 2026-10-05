class_name GridWorld
extends RefCounted

signal block_added(block: BlockData)
signal block_removed(block: BlockData)
signal block_moved(block: BlockData, old_pos: Vector2i, new_pos: Vector2i)
signal structure_changed(structure_id: int)

# Key: Vector2i -> BlockData
var _cells: Dictionary = {}

# Next available structure ID (positive non-zero integers)
var _next_structure_id: int = 1

# If true, block_added / block_removed / block_moved are suppressed (used during simulation ticks)
var suppress_events: bool = false

func get_block(pos: Vector2i) -> BlockData:
	return _cells.get(pos, null)

func has_block(pos: Vector2i) -> bool:
	return _cells.has(pos)

func get_all_blocks() -> Array[BlockData]:
	var result: Array[BlockData] = []
	for block in _cells.values():
		result.append(block)
	return result

func add_block(block: BlockData) -> bool:
	if _cells.has(block.grid_pos):
		return false
	_cells[block.grid_pos] = block
	if block.structure_id >= _next_structure_id:
		_next_structure_id = block.structure_id + 1
	if not suppress_events:
		block_added.emit(block)
	return true

func remove_block_at(pos: Vector2i) -> BlockData:
	if not _cells.has(pos):
		return null
	var block: BlockData = _cells[pos]
	_cells.erase(pos)
	if block.structure_id > 0:
		var sid := block.structure_id
		block.structure_id = 0
		if not suppress_events:
			structure_changed.emit(sid)
	if not suppress_events:
		block_removed.emit(block)
	return block

func move_block(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not _cells.has(from_pos):
		return false
	if _cells.has(to_pos) and from_pos != to_pos:
		return false
	var block: BlockData = _cells[from_pos]
	_cells.erase(from_pos)
	block.grid_pos = to_pos
	_cells[to_pos] = block
	if not suppress_events:
		block_moved.emit(block, from_pos, to_pos)
	return true

func batch_move_blocks(entries: Array[Dictionary]) -> void:
	for entry in entries:
		_cells.erase(entry["old_pos"])
	for entry in entries:
		var b: BlockData = entry["block"]
		b.grid_pos = entry["new_pos"]
		_cells[entry["new_pos"]] = b
		if not suppress_events:
			block_moved.emit(b, entry["old_pos"], entry["new_pos"])

func clear() -> void:
	var blocks := get_all_blocks()
	_cells.clear()
	for b in blocks:
		block_removed.emit(b)

# --- Structure Grouping Logic ---

func create_new_structure_id() -> int:
	var sid := _next_structure_id
	_next_structure_id += 1
	return sid

func get_structure_blocks(structure_id: int) -> Array[BlockData]:
	var result: Array[BlockData] = []
	if structure_id <= 0:
		return result
	for block in _cells.values():
		if block.structure_id == structure_id:
			result.append(block)
	return result

func group_blocks(blocks: Array[BlockData]) -> int:
	if blocks.is_empty():
		return 0
	# Check if all blocks already share the same positive structure_id -> if so, dissolve
	var first_sid: int = blocks[0].structure_id
	var all_same: bool = (first_sid > 0)
	for b in blocks:
		if b.structure_id != first_sid:
			all_same = false
			break
	
	if all_same:
		# Toggle off: dissolve group
		for b in blocks:
			b.structure_id = 0
		structure_changed.emit(first_sid)
		return 0
	else:
		# Assign new structure ID
		var new_sid := create_new_structure_id()
		for b in blocks:
			b.structure_id = new_sid
		structure_changed.emit(new_sid)
		return new_sid

func dissolve_structure(structure_id: int) -> void:
	if structure_id <= 0:
		return
	for b in _cells.values():
		if b.structure_id == structure_id:
			b.structure_id = 0
	structure_changed.emit(structure_id)

func get_bounds() -> Rect2i:
	if _cells.is_empty():
		return Rect2i(0, 0, 1, 1)
	var min_x: int = 999999
	var min_y: int = 999999
	var max_x: int = -999999
	var max_y: int = -999999
	for pos in _cells.keys():
		min_x = mini(min_x, pos.x)
		min_y = mini(min_y, pos.y)
		max_x = maxi(max_x, pos.x)
		max_y = maxi(max_y, pos.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func clone() -> GridWorld:
	var world := GridWorld.new()
	world._next_structure_id = _next_structure_id
	for block in _cells.values():
		var copy: BlockData = block.duplicate_block(false)
		world._cells[copy.grid_pos] = copy
	return world

func serialize() -> Array:
	var list := []
	for block in _cells.values():
		list.append(block.to_dict())
	return list

func deserialize(data_list: Array) -> void:
	clear()
	for item in data_list:
		if item is Dictionary:
			var block := BlockData.from_dict(item)
			add_block(block)
