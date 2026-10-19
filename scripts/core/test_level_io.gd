extends SceneTree

# Verifies the official-release feature set:
#  - Level JSON import / export helpers (SaveManager) and LevelManager UI wiring
#  - LevelManager metadata page no longer offers CG theme / player build area
#  - Chapter map no longer shows node subtitles, "核心机制", "目标" title,
#    main/side-branch wording or the free-exploration hint
#  - Main menu footer line removed

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): printerr("TEST WATCHDOG TIMEOUT!"); quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print(message, ": ", ok)

func detach(node: Node) -> void:
	root.remove_child(node)
	node.free()

func run() -> void:
	# ---------- SaveManager import / export round trip ----------
	var original := LevelData.new("io_probe_level", "导入导出探针")
	original.author = "测试工匠"
	original.description = "验证导入导出。"
	original.player_build_area = Rect2i(-3, -2, 6, 5)
	original.blocks_data = [
		{"block_id": 12345, "block_type": 0, "direction": 0, "grid_pos": {"x": 1, "y": 2},
		 "structure_id": 0, "sub_mode": 0, "texture_variant": 1}
	]
	var text := SaveManager.export_level_text(original)
	check(text.contains("\"level_id\": \"io_probe_level\""), "Exported JSON carries the level id")
	var parsed := SaveManager.parse_level_text(text)
	check(parsed != null and parsed.level_name == "导入导出探针" and parsed.blocks_data.size() == 1, "Parsed JSON restores level + blocks")
	check(parsed.player_build_area == Rect2i(-3, -2, 6, 5), "Parsed JSON restores build area")

	var tmp_path := "/tmp/opencode/io_probe_level.json"
	check(SaveManager.export_level_file(original, tmp_path), "export_level_file writes the file")
	var reloaded := SaveManager.import_level_file(tmp_path)
	check(reloaded != null and reloaded.level_id == "io_probe_level", "import_level_file reads the file back")
	check(SaveManager.import_level_file("/tmp/opencode/does_not_exist.json") == null, "Missing file returns null")
	check(SaveManager.parse_level_text("not json") == null, "Malformed text returns null")

	# ---------- unique / safe id generation ----------
	check(SaveManager.make_unique_level_id("fresh_id", ["a", "b"]) == "fresh_id", "Unused safe id is kept")
	var regenerated := SaveManager.make_unique_level_id("a", ["a", "b"])
	check(regenerated != "a" and not regenerated.is_empty(), "Conflicting id is regenerated")
	check(not ["a", "b"].has(regenerated), "Regenerated id avoids collision")
	var unsafe := SaveManager.make_unique_level_id("../evil path", [])
	check(unsafe == unsafe.validate_filename() and not unsafe.contains("/"), "Unsafe id is sanitized")

	# ---------- LevelManager metadata page ----------
	var manager: LevelManager = load("res://scenes/ui/LevelManager.tscn").instantiate()
	root.add_child(manager)
	await process_frame
	check(manager.export_level_btn != null and manager.import_level_btn != null, "Import/Export buttons exist")
	check(manager.export_file_dialog != null and manager.import_file_dialog != null, "Import/Export file dialogs exist")
	check(manager.get("theme_opt") == null, "CG/theme option removed from metadata page")
	check(manager.get("build_area_summary_lbl") == null, "Build-area section removed from metadata page")

	# Import flow persists the level and selects it (cleaned up afterwards)
	var ids_before: Array = []
	for l in manager.levels: ids_before.append(l.level_id)
	var incoming := LevelData.new("custom_level_2", "外来关卡")
	incoming.description = "从文件导入。"
	manager._apply_imported_level(incoming)
	check(manager.levels.size() == ids_before.size() + 1, "Import adds one level to the library")
	var imported_id := manager.levels[manager.selected_index].level_id if manager.selected_index >= 0 else ""
	check(imported_id != "" and not ids_before.has(imported_id), "Imported level gets a fresh unique id")
	check(SaveManager.load_level(imported_id) != null, "Imported level is persisted and loadable")
	check(manager.io_status_lbl.text.contains("已导入"), "Import reports success")
	# Clean up without creating a tombstone in the user save data.
	DirAccess.remove_absolute("user://levels/%s.json" % imported_id)
	var res_probe := "res://assets/levels/%s.json" % imported_id
	if FileAccess.file_exists(res_probe):
		DirAccess.remove_absolute(res_probe)
	manager.queue_free()
	await process_frame

	# ---------- Chapter map content ----------
	var menu: LevelSelect = load("res://scenes/ui/LevelSelect.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var hint_ok := true
	var stack: Array[Node] = [menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			var t: String = (n as Label).text
			if t.contains("主线") or t.contains("支线") or t.contains("所有关卡可自由探索") or t.contains("核心机制"):
				hint_ok = false
		for c in n.get_children(): stack.append(c)
	check(hint_ok, "Chapter map has no main/side-branch or free-exploration wording")

	var gun_level := -1
	for i in range(menu.levels.size()):
		if menu.levels[i].level_id == "custom_level_80400": gun_level = i
	if gun_level >= 0:
		var button: Button = menu.node_buttons["custom_level_80400"]
		check(not button.text.contains("\n"), "Level node has no subtitle line under the name")
		menu._select_level(gun_level)
		await process_frame
		var detail := menu.detail_body.get_parsed_text()
		check(not detail.contains("核心机制"), "Detail panel drops the core-mechanism section")
		check(not detail.contains("目标"), "Detail panel drops the goal heading")
		check(not detail.contains("主线") and not detail.contains("支线"), "Detail panel drops main/side-branch label")
		check(detail.contains(menu.levels[gun_level].description), "Detail panel keeps the goal text")
		check(menu.detail_title.text == "枪-1", "Detail title shows the level name only")
	menu.queue_free()
	await process_frame

	# ---------- Main menu footer ----------
	var main_menu: MainMenu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	root.add_child(main_menu)
	await process_frame
	var footer_ok := true
	var mstack: Array[Node] = [main_menu]
	while not mstack.is_empty():
		var n: Node = mstack.pop_back()
		if n is Label:
			var t: String = (n as Label).text
			if t.contains("自由构装解谜") or t.contains("主线") or t.contains("支线"):
				footer_ok = false
		for c in n.get_children(): mstack.append(c)
	check(footer_ok, "Main menu footer / branch wording removed")
	main_menu.queue_free()
	await process_frame

	print("LEVEL IO CHECKS: ", checks, "; FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)