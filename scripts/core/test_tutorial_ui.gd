extends SceneTree
var view: SubViewport
var player: LevelPlayer
var failures: Array = []
var checks := 0
var output_dir: String = OS.get_environment("BLOCKBOUND_TEST_OUTPUT") if not OS.get_environment("BLOCKBOUND_TEST_OUTPUT").is_empty() else "res://build/tutorial-tests"
func _initialize():
	DirAccess.make_dir_recursive_absolute(output_dir)
	call_deferred("run_test")
func verify(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label)
	print(label, ": ", ok)
func frames(count: int = 4):
	for i in range(count): await process_frame
func key(code: int):
	view.gui_release_focus()
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		view.push_input(e, true)
		await frames()
func click(pos: Vector2):
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	view.push_input(move, true)
	await frames()
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = pos
		e.global_position = pos
		e.pressed = down
		view.push_input(e, true)
		await frames()
func snap(name: String):
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
func run_test():
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	player = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
	view.add_child(player)
	await frames(15)
	for i in range(5):
		player.load_level_by_index(i)
		await frames(8)
		var level := player.current_level_data
		verify(level.level_id == "tutorial_%02d" % (i + 1), "lesson_order_" + str(i))
		verify(Rect2(Vector2.ZERO, Vector2(view.size)).encloses(player.tutorial_guide.get_global_rect()), "guide_in_view_" + str(i))
		await snap("lesson_%02d_start" % (i + 1))
		var steps: Array = level.tutorial.steps
		for n in range(steps.size()):
			var s: Dictionary = steps[n]
			await key(KEY_1 + int(s.type))
			var desired := int(s.get("dir", 0))
			for turn in range(posmod(desired - player.toolbar.current_dir, 4)): await key(KEY_E)
			if player.toolbar.current_sub_mode != int(s.get("sub_mode", 0)): await key(KEY_F)
			var pos: Vector2 = player.grid_view.grid_to_world(Vector2i(int(s.x), int(s.y)))
			await click(player.grid_view.get_global_transform_with_canvas() * pos)
			verify(player.tutorial_guide.active_step == n + 1, "mouse_placement_" + str(i) + "_" + str(n))
		verify(not player.step_btn.disabled, "step_unlocked_" + str(i))
		await snap("lesson_%02d_ready" % (i + 1))
		for tick in range(10):
			await click(player.step_btn.get_global_rect().get_center())
			await create_timer(0.4).timeout
			if player.victory_dialog.visible: break
		verify(player.victory_dialog.visible, "mouse_step_wins_" + str(i))
		verify(Rect2(Vector2.ZERO, Vector2(view.size)).encloses(player.victory_dialog.get_global_rect()), "victory_in_view_" + str(i))
		await snap("lesson_%02d_complete" % (i + 1))
		await click(player.victory_dialog.next_btn.get_global_rect().get_center())
		verify(player.current_level_index == i + 1, "next_lesson_" + str(i))
	verify(player.current_level_data.level_id == "level_01", "tutorials_lead_to_first_chapter")
	verify(not player.tutorial_guide.visible, "ordinary_chapter_hides_guide")
	var f := FileAccess.open(output_dir.path_join("visual-results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
	f.close()
	quit(0 if failures.is_empty() else 1)
