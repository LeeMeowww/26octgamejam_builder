extends SceneTree
const Campaign = preload("res://scripts/core/Campaign.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run() -> void:
	var saved := FileAccess.get_file_as_bytes(Campaign.PROGRESS_PATH) if FileAccess.file_exists(Campaign.PROGRESS_PATH) else PackedByteArray()
	var config := ConfigFile.new()
	# Old tutorial records must not silently complete the rebuilt curriculum.
	config.set_value("campaign", "completed", {"tutorial_05": 1, "tutorial_01": 1, "custom_level_78552": 4})
	config.save(Campaign.PROGRESS_PATH)
	var authored := SaveManager.load_level_from_path("res://assets/levels/tutorial_00.json")
	var stale := LevelData.from_dict(authored.to_dict())
	stale.tutorial.erase("revision")
	stale.level_name = "old local lesson"
	var override_path := SaveManager.USER_LEVELS_DIR.path_join("tutorial_00.json")
	SaveManager.init_directories()
	var original_override := FileAccess.get_file_as_bytes(override_path) if FileAccess.file_exists(override_path) else PackedByteArray()
	var override_file := FileAccess.open(override_path, FileAccess.WRITE)
	override_file.store_string(JSON.stringify(stale.to_dict()))
	override_file.close()
	check(SaveManager.load_level("tutorial_00").level_name == authored.level_name, "direct load prefers rebuilt lesson over stale override")
	for level in SaveManager.get_all_levels():
		if level.level_id == "tutorial_00": check(level.level_name == authored.level_name, "map prefers rebuilt lesson over stale override")
	stale.tutorial.revision = 2
	check(SaveManager._prefer_current_tutorial(stale, authored) == stale, "current revision user edits remain usable")
	if original_override.is_empty(): DirAccess.remove_absolute(override_path)
	else:
		override_file = FileAccess.open(override_path, FileAccess.WRITE)
		override_file.store_buffer(original_override)
		override_file.close()
	Campaign.active_level = "tutorial_05"
	var menu: LevelSelect = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.selected_index == -1, "locked last visit ignored")
	check(Campaign.completed().has("custom_level_78552"), "ordinary campaign progress preserved")
	for n in range(7):
		menu._show_chapter(0)
		await process_frame
		check(menu.node_buttons.size() == n + 1, "only sequentially unlocked lessons visible")
		check(menu.map.routes.size() == n, "continuous route without locked placeholders")
		for i in range(7):
			var id: String = Campaign.TUTORIAL_ORDER[i]
			check(Campaign.is_unlocked(id) == (i <= n), "access matches prerequisite chain")
			check(menu.node_buttons.has(id) == (i <= n), "visibility matches access")
			if i > n:
				for j in range(menu.levels.size()):
					if menu.levels[j].level_id == id:
						var before := root.get_child_count()
						menu._enter_level(j)
						check(root.get_child_count() == before, "direct UI entry cannot bypass lock")
		var current: String = Campaign.TUTORIAL_ORDER[n]
		check(Campaign.next_index(current, menu.levels) == -1, "no next lesson before completion")
		Campaign.mark_completed(current, 10)
		var next := Campaign.next_index(current, menu.levels)
		check((next >= 0 and menu.levels[next].level_id == Campaign.TUTORIAL_ORDER[n+1]) if n < 6 else next == -1, "completion unlocks next button immediately")
		Campaign.mark_completed(current, 20)
		check(Campaign.completed()[current] == 10, "replay preserves best completion")
		if n in [0, 3, 6] and DisplayServer.get_name() != "headless":
			var output := OS.get_environment("BLOCKBOUND_TEST_OUTPUT")
			if not output.is_empty():
				DirAccess.make_dir_recursive_absolute(output)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("route_%d.png" % (n+1)))
	menu._show_chapter(1)
	check(menu.node_buttons.size() == 3, "upstream pickup chapter preserved")
	if saved.is_empty(): DirAccess.remove_absolute(Campaign.PROGRESS_PATH)
	else:
		var file := FileAccess.open(Campaign.PROGRESS_PATH, FileAccess.WRITE)
		file.store_buffer(saved)
		file.close()
	Campaign.active_level = ""
	menu.queue_free()
	await process_frame
	print("ROUTE CHECKS: ", checks, "; FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
