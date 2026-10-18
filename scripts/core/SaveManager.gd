class_name SaveManager
extends RefCounted

const USER_LEVELS_DIR = "user://levels"
const USER_MACHINES_DIR = "user://machines"
const RES_LEVELS_DIR = "res://assets/levels"
const DELETED_LEVELS_PATH = "user://deleted_levels.json"

# Development builds (editor runs and debug exports) mirror level edits back to
# the project's own asset folder / dev server. Official release exports must NOT
# touch the developer's local assets: player levels then live only in user://.
static func is_dev_sync_enabled() -> bool:
	return not OS.has_feature("release")

static func init_directories() -> void:
	if not DirAccess.dir_exists_absolute(USER_LEVELS_DIR):
		DirAccess.make_dir_recursive_absolute(USER_LEVELS_DIR)
	if not DirAccess.dir_exists_absolute(USER_MACHINES_DIR):
		DirAccess.make_dir_recursive_absolute(USER_MACHINES_DIR)

	var migration_flag := "user://.migrated_v2"
	if not FileAccess.file_exists(migration_flag):
		for legacy_id in ["level_01", "level_02", "level_03"]:
			var p := "%s/%s.json" % [USER_LEVELS_DIR, legacy_id]
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
			_add_deleted_level_id(legacy_id)
		var mf := FileAccess.open(migration_flag, FileAccess.WRITE)
		if mf != null:
			mf.store_string("v2")
			mf.close()

# -------------------------------------------------------------
# Levels Management (Equal Status for All Levels)
# -------------------------------------------------------------

static func get_all_levels() -> Array[LevelData]:
	init_directories()
	var levels_dict: Dictionary = {} # level_id -> LevelData
	var deleted_ids: Dictionary = _get_deleted_level_ids()

	# 1. Load built-in levels (skipping tombstoned/deleted ones)
	var res_dir := DirAccess.open(RES_LEVELS_DIR)
	if res_dir:
		res_dir.list_dir_begin()
		var file_name := res_dir.get_next()
		while not file_name.is_empty():
			if not res_dir.current_is_dir() and file_name.ends_with(".json"):
				var lvl_id := file_name.get_basename()
				if not deleted_ids.has(lvl_id):
					var lvl := load_level_from_path(RES_LEVELS_DIR + "/" + file_name)
					if lvl != null and not deleted_ids.has(lvl.level_id):
						levels_dict[lvl.level_id] = lvl
			file_name = res_dir.get_next()

	# 2. Load user levels (overrides or adds, skipping deleted ones)
	var user_dir := DirAccess.open(USER_LEVELS_DIR)
	if user_dir:
		user_dir.list_dir_begin()
		var file_name := user_dir.get_next()
		while not file_name.is_empty():
			if not user_dir.current_is_dir() and file_name.ends_with(".json"):
				var lvl_id := file_name.get_basename()
				if not deleted_ids.has(lvl_id):
					var lvl := load_level_from_path(USER_LEVELS_DIR + "/" + file_name)
					if lvl != null and not deleted_ids.has(lvl.level_id):
						levels_dict[lvl.level_id] = lvl
			file_name = user_dir.get_next()

	var result: Array[LevelData] = []
	for lvl in levels_dict.values():
		result.append(lvl)

	# Sort by order_index, then level_name
	result.sort_custom(func(a: LevelData, b: LevelData):
		if a.order_index != b.order_index:
			return a.order_index < b.order_index
		return a.level_name < b.level_name
	)

	return result

static func save_level(level_data: LevelData) -> bool:
	init_directories()
	var level_id := level_data.level_id
	var dict_data := level_data.to_dict()

	# 1. Un-tombstone if it was previously marked deleted
	_remove_deleted_level_id(level_id)

	# 2. Save to user://levels
	var user_path := "%s/%s.json" % [USER_LEVELS_DIR, level_id]
	var file := FileAccess.open(user_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open level file for writing: " + user_path)
		return false
	file.store_string(JSON.stringify(dict_data, "\t"))
	file.close()

	# 3. Mirror to the project source only while developing.
	#    Release builds never link player edits back to the local assets.
	if is_dev_sync_enabled():
		if OS.has_feature("web"):
			_send_dev_server_request("/api/levels/save", {
				"level_id": level_id,
				"data": dict_data
			})
		elif OS.has_feature("editor"):
			# Running from the editor maps res:// to the on-disk project folder.
			var res_path := "%s/%s.json" % [RES_LEVELS_DIR, level_id]
			var rf := FileAccess.open(res_path, FileAccess.WRITE)
			if rf != null:
				rf.store_string(JSON.stringify(dict_data, "\t"))
				rf.close()

	return true

static func load_level(level_id: String) -> LevelData:
	init_directories()
	var deleted_ids: Dictionary = _get_deleted_level_ids()
	if deleted_ids.has(level_id):
		return null
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
	init_directories()
	var deleted_something := false

	# 1. Mark in tombstone so it won't be resurrected by res://
	_add_deleted_level_id(level_id)

	# 2. Delete from user://levels
	var user_path := "%s/%s.json" % [USER_LEVELS_DIR, level_id]
	if FileAccess.file_exists(user_path):
		var err := DirAccess.remove_absolute(user_path)
		if err == OK:
			deleted_something = true

	# 3. Synchronize deletion to source disk (local PC or Dev Server)
	if is_dev_sync_enabled():
		if OS.has_feature("web"):
			_send_dev_server_request("/api/levels/delete", {
				"level_id": level_id
			})
			deleted_something = true
		elif OS.has_feature("editor"):
			var res_path := "%s/%s.json" % [RES_LEVELS_DIR, level_id]
			if FileAccess.file_exists(res_path):
				var err := DirAccess.remove_absolute(res_path)
				if err == OK:
					deleted_something = true

	return deleted_something or true

static func reorder_levels(level_ids: Array) -> void:
	for idx in range(level_ids.size()):
		var lid := str(level_ids[idx])
		var lvl := load_level(lid)
		if lvl != null:
			lvl.order_index = idx
			save_level(lvl)

	if OS.has_feature("web") and is_dev_sync_enabled():
		_send_dev_server_request("/api/levels/reorder", {
			"order": level_ids
		})

# -------------------------------------------------------------
# Level Import / Export (JSON files exchanged between players)
# -------------------------------------------------------------

static func export_level_text(level_data: LevelData) -> String:
	return JSON.stringify(level_data.to_dict(), "\t")

static func export_level_file(level_data: LevelData, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入关卡导出文件: " + path)
		return false
	file.store_string(export_level_text(level_data))
	file.close()
	return true

static func parse_level_text(text: String) -> LevelData:
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return LevelData.from_dict(parsed)
	return null

static func import_level_file(path: String) -> LevelData:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return parse_level_text(text)

# Keep imported level_id safe (filename-safe) and unique against the existing library.
# A conflicting or invalid id is replaced with a freshly generated custom id.
static func make_unique_level_id(preferred_id: String, existing_ids: Array) -> String:
	var taken := {}
	for id in existing_ids:
		taken[str(id)] = true
	var candidate := preferred_id.strip_edges()
	var valid := not candidate.is_empty() and candidate == candidate.validate_filename()
	if not valid or taken.has(candidate):
		var stamp := int(Time.get_unix_time_from_system()) % 100000
		candidate = "custom_level_%d" % stamp
		var suffix := 1
		while taken.has(candidate):
			candidate = "custom_level_%d_%d" % [stamp, suffix]
			suffix += 1
	return candidate

# -------------------------------------------------------------
# Tombstone Helpers (Client Deletion Persistence)
# -------------------------------------------------------------

static func _get_deleted_level_ids() -> Dictionary:
	if not FileAccess.file_exists(DELETED_LEVELS_PATH):
		return {}
	var file := FileAccess.open(DELETED_LEVELS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	var result: Dictionary = {}
	if parsed is Array:
		for item in parsed:
			result[str(item)] = true
	elif parsed is Dictionary:
		result = parsed
	return result

static func _add_deleted_level_id(level_id: String) -> void:
	var ids := _get_deleted_level_ids()
	ids[level_id] = true
	var file := FileAccess.open(DELETED_LEVELS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(ids.keys(), "\t"))
		file.close()

static func _remove_deleted_level_id(level_id: String) -> void:
	var ids := _get_deleted_level_ids()
	if ids.has(level_id):
		ids.erase(level_id)
		var file := FileAccess.open(DELETED_LEVELS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(ids.keys(), "\t"))
			file.close()

# -------------------------------------------------------------
# Dev Server Synchronization (Option 2)
# -------------------------------------------------------------

static func _send_dev_server_request(endpoint: String, payload_dict: Dictionary) -> void:
	if OS.has_feature("web"):
		var payload_json := JSON.stringify(payload_dict)
		var js_code := """
		(function() {
			try {
				var data = %s;
				fetch('%s', {
					method: 'POST',
					headers: {'Content-Type': 'application/json'},
					body: typeof data === 'string' ? data : JSON.stringify(data)
				}).then(function(res) {
					if (res.ok) {
						console.log('[DevServer] Sync ok:', '%s');
					} else {
						console.warn('[DevServer] Sync non-200:', res.status);
					}
				}).catch(function(err) {
					// Harmless when offline / static release hosting
					console.warn('[DevServer] Sync failed (expected if offline/production):', err);
				});
			} catch(e) {
				console.warn('[DevServer] Sync exception:', e);
			}
		})();
		""" % [JSON.stringify(payload_json), endpoint, endpoint]
		JavaScriptBridge.eval(js_code)

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
		var structure_id_map: Dictionary = {}
		for item in parsed["blocks"]:
			if item is Dictionary:
				var b := BlockData.from_dict(item)
				# 重新生成全局唯一新 ID，防止与关卡现有方块 ID 冲突
				b.block_id = BlockData.generate_new_id()
				b.origin_id = b.block_id
				# 结构组 ID 重映射，保持图纸内部成组关系的同时避免与关卡现有结构冲突
				var old_sid := b.structure_id
				if old_sid > 0:
					if not structure_id_map.has(old_sid):
						structure_id_map[old_sid] = BlockData.generate_new_id()
					b.structure_id = structure_id_map[old_sid]
				result.append(b)
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
