class_name SaveManager
extends RefCounted

const USER_LEVELS_DIR = "user://levels"
const USER_MACHINES_DIR = "user://machines"
const RES_LEVELS_DIR = "res://assets/levels"

static func init_directories() -> void:
	if not DirAccess.dir_exists_absolute(USER_LEVELS_DIR):
		DirAccess.make_dir_recursive_absolute(USER_LEVELS_DIR)
	if not DirAccess.dir_exists_absolute(USER_MACHINES_DIR):
		DirAccess.make_dir_recursive_absolute(USER_MACHINES_DIR)
	ensure_default_levels()

# -------------------------------------------------------------
# Levels Management
# -------------------------------------------------------------

static func get_all_levels() -> Array[LevelData]:
	init_directories()
	var levels_dict: Dictionary = {} # level_id -> LevelData

	# 1. Load built-in levels
	var res_dir := DirAccess.open(RES_LEVELS_DIR)
	if res_dir:
		res_dir.list_dir_begin()
		var file_name := res_dir.get_next()
		while not file_name.is_empty():
			if not res_dir.current_is_dir() and file_name.ends_with(".json"):
				var lvl := load_level_from_path(RES_LEVELS_DIR + "/" + file_name)
				if lvl != null:
					levels_dict[lvl.level_id] = lvl
			file_name = res_dir.get_next()

	# 2. Load user levels (overrides or adds)
	var user_dir := DirAccess.open(USER_LEVELS_DIR)
	if user_dir:
		user_dir.list_dir_begin()
		var file_name := user_dir.get_next()
		while not file_name.is_empty():
			if not user_dir.current_is_dir() and file_name.ends_with(".json"):
				var lvl := load_level_from_path(USER_LEVELS_DIR + "/" + file_name)
				if lvl != null:
					levels_dict[lvl.level_id] = lvl
			file_name = user_dir.get_next()

	var result: Array[LevelData] = []
	for lvl in levels_dict.values():
		result.append(lvl)

	# Sort by order_index
	result.sort_custom(func(a: LevelData, b: LevelData):
		if a.order_index != b.order_index:
			return a.order_index < b.order_index
		return a.level_name < b.level_name
	)

	return result

static func save_level(level_data: LevelData) -> bool:
	init_directories()
	var path := "%s/%s.json" % [USER_LEVELS_DIR, level_data.level_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open level file for writing: " + path)
		return false
	var json_str := JSON.stringify(level_data.to_dict(), "\t")
	file.store_string(json_str)
	file.close()
	return true

static func load_level(level_id: String) -> LevelData:
	init_directories()
	var user_path := "%s/%s.json" % [USER_LEVELS_DIR, level_id]
	if FileAccess.file_exists(user_path):
		return load_level_from_path(user_path)
	var res_path := "%s/%s.json" % [RES_LEVELS_DIR, level_id]
	if FileAccess.file_exists(res_path):
		return load_level_from_path(res_path)
	return null

static func load_level_from_path(path: String) -> LevelData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return LevelData.from_dict(parsed)
	return null

static func delete_level(level_id: String) -> bool:
	var user_path := "%s/%s.json" % [USER_LEVELS_DIR, level_id]
	if FileAccess.file_exists(user_path):
		var err := DirAccess.remove_absolute(user_path)
		return err == OK
	return false

static func reorder_levels(level_ids: Array) -> void:
	for idx in range(level_ids.size()):
		var lid := str(level_ids[idx])
		var lvl := load_level(lid)
		if lvl != null:
			lvl.order_index = idx
			save_level(lvl)

# -------------------------------------------------------------
# Machine Blueprint Management (Player Saved Creations)
# -------------------------------------------------------------

static func save_machine(name: String, blocks: Array[BlockData]) -> bool:
	init_directories()
	var clean_name := name.validate_filename()
	if clean_name.is_empty():
		clean_name = "machine_%d" % [Time.get_unix_time_from_system()]
	var path := "%s/%s.json" % [USER_MACHINES_DIR, clean_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	# Calculate minimum pos to normalize to (0,0) offset
	var min_pos := Vector2i(999999, 999999)
	for b in blocks:
		min_pos.x = mini(min_pos.x, b.grid_pos.x)
		min_pos.y = mini(min_pos.y, b.grid_pos.y)

	var block_list: Array = []
	for b in blocks:
		var d := b.to_dict()
		d["pos_x"] = b.grid_pos.x - min_pos.x
		d["pos_y"] = b.grid_pos.y - min_pos.y
		block_list.append(d)

	var data := {
		"machine_name": name,
		"saved_at": Time.get_datetime_string_from_system(),
		"blocks": block_list
	}

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

static func load_machine(name: String) -> Array[BlockData]:
	init_directories()
	var path := "%s/%s.json" % [USER_MACHINES_DIR, name.validate_filename()]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	var result: Array[BlockData] = []
	if parsed is Dictionary and parsed.has("blocks"):
		for item in parsed["blocks"]:
			if item is Dictionary:
				result.append(BlockData.from_dict(item))
	return result

static func get_saved_machines() -> Array[String]:
	init_directories()
	var result: Array[String] = []
	var dir := DirAccess.open(USER_MACHINES_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				result.append(file_name.get_basename())
			file_name = dir.get_next()
	result.sort()
	return result

static func delete_machine(name: String) -> bool:
	var path := "%s/%s.json" % [USER_MACHINES_DIR, name.validate_filename()]
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path) == OK
	return false

# -------------------------------------------------------------
# Default Built-In Level Generator
# -------------------------------------------------------------

static func ensure_default_levels() -> void:
	if not DirAccess.dir_exists_absolute(RES_LEVELS_DIR):
		DirAccess.make_dir_recursive_absolute(RES_LEVELS_DIR)

	var lvl1_path := RES_LEVELS_DIR + "/level_01.json"
	if not FileAccess.file_exists(lvl1_path):
		var lvl1 := LevelData.new("level_01", "第一章：初生吞噬")
		lvl1.description = "基础构造：在建造区放置【推动器】与【摧毁器】，让机械向前行进并消灭远处的污染源！"
		lvl1.author = "母巢核心"
		lvl1.order_index = 0
		lvl1.cg_theme = "cyan_core"
		lvl1.player_build_area = Rect2i(-6, -4, 6, 8)
		# Place target pollution at (6, 0)
		var p1 := BlockData.new(BlockData.Type.POLLUTION, Vector2i(6, 0))
		p1.is_world_block = true
		lvl1.blocks_data.append(p1.to_dict())
		# Decorative boundary
		for y in range(-5, 6):
			var wall_top := BlockData.new(BlockData.Type.HARD, Vector2i(-7, y))
			wall_top.is_world_block = true
			lvl1.blocks_data.append(wall_top.to_dict())
			var wall_bot := BlockData.new(BlockData.Type.HARD, Vector2i(8, y))
			wall_bot.is_world_block = true
			lvl1.blocks_data.append(wall_bot.to_dict())
		var f := FileAccess.open(lvl1_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(lvl1.to_dict(), "\t"))
		f.close()

	var lvl2_path := RES_LEVELS_DIR + "/level_02.json"
	if not FileAccess.file_exists(lvl2_path):
		var lvl2 := LevelData.new("level_02", "第二章：抑制破壁")
		lvl2.description = "高级机制：坚硬方块挡住了通路。使用【抑制器】对准其后方使其失效，再用【摧毁器】将其清除！"
		lvl2.author = "母巢核心"
		lvl2.order_index = 1
		lvl2.cg_theme = "purple_synapse"
		lvl2.player_build_area = Rect2i(-7, -4, 6, 8)
		# Hard block at (3, 0)
		var h := BlockData.new(BlockData.Type.HARD, Vector2i(3, 0))
		h.is_world_block = true
		lvl2.blocks_data.append(h.to_dict())
		# Pollution behind it at (5, 0)
		var p2 := BlockData.new(BlockData.Type.POLLUTION, Vector2i(5, 0))
		p2.is_world_block = true
		lvl2.blocks_data.append(p2.to_dict())
		var f2 := FileAccess.open(lvl2_path, FileAccess.WRITE)
		f2.store_string(JSON.stringify(lvl2.to_dict(), "\t"))
		f2.close()

	var lvl3_path := RES_LEVELS_DIR + "/level_03.json"
	if not FileAccess.file_exists(lvl3_path):
		var lvl3 := LevelData.new("level_03", "第三章：转向器与宝藏回收")
		lvl3.description = "转向与回收：将拐角处的【宝藏】推动并回收至左侧玩家建造区！利用【转向器】与【推动器】协调运作！"
		lvl3.author = "母巢核心"
		lvl3.order_index = 2
		lvl3.cg_theme = "azure_cilia"
		lvl3.player_build_area = Rect2i(-6, -5, 5, 10)
		# Treasure at (4, 4)
		var tr := BlockData.new(BlockData.Type.TREASURE, Vector2i(4, 4))
		tr.is_world_block = true
		lvl3.blocks_data.append(tr.to_dict())
		# Obstacle wall at (2, -2) to (2, 2)
		for y in range(-2, 3):
			var obs := BlockData.new(BlockData.Type.HARD, Vector2i(2, y))
			obs.is_world_block = true
			lvl3.blocks_data.append(obs.to_dict())
		var f3 := FileAccess.open(lvl3_path, FileAccess.WRITE)
		f3.store_string(JSON.stringify(lvl3.to_dict(), "\t"))
		f3.close()

	var lvl4_path := RES_LEVELS_DIR + "/level_04.json"
	if not FileAccess.file_exists(lvl4_path):
		var lvl4 := LevelData.new("level_04", "第四章：游荡怪物")
		lvl4.description = "怪物对抗：一只游荡怪物正在巡逻。摧毁它并消除后方的污染源！"
		lvl4.author = "母巢核心"
		lvl4.order_index = 3
		lvl4.cg_theme = "toxic_magenta"
		lvl4.player_build_area = Rect2i(-8, -4, 5, 8)
		# Floor for wanderer
		for x in range(0, 7):
			var fl := BlockData.new(BlockData.Type.HARD, Vector2i(x, 2))
			fl.is_world_block = true
			lvl4.blocks_data.append(fl.to_dict())
		# Wanderer at (2, 1)
		var wand := BlockData.new(BlockData.Type.WANDERER, Vector2i(2, 1), BlockData.Direction.RIGHT)
		wand.is_world_block = true
		lvl4.blocks_data.append(wand.to_dict())
		# Pollution at (6, 1)
		var pol := BlockData.new(BlockData.Type.POLLUTION, Vector2i(6, 1))
		pol.is_world_block = true
		lvl4.blocks_data.append(pol.to_dict())
		var f4 := FileAccess.open(lvl4_path, FileAccess.WRITE)
		f4.store_string(JSON.stringify(lvl4.to_dict(), "\t"))
		f4.close()
