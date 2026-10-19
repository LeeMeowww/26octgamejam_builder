extends RefCounted

static func followup_level(root: LevelData) -> LevelData:
	var data: Dictionary = root.tutorial.get("followup", {}).duplicate(true)
	if data.is_empty(): return null
	var offset := int(root.tutorial.get("followup_offset_x", 16))
	data.level_id = root.level_id
	data.level_name = root.level_name
	data.player_build_area.x = int(data.player_build_area.x) + offset
	for block in data.blocks: block.pos_x = int(block.pos_x) + offset
	for part in data.tutorial.get("reference", []): part[1] = int(part[1]) + offset
	var pattern := RegEx.new()
	pattern.compile("\\((-?\\d+),\\s*(-?\\d+)\\)")
	var hints: Array = data.tutorial.get("hints", [])
	for i in range(hints.size()):
		var value := str(hints[i])
		var matches := pattern.search_all(value)
		matches.reverse()
		for found in matches:
			value = value.left(found.get_start()) + "(%d,%s)" % [int(found.get_string(1)) + offset, found.get_string(2)] + value.substr(found.get_end())
		hints[i] = value
	return LevelData.from_dict(data)
