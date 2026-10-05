extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run_tests")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func run_tests() -> void:
	var levels := SaveManager.get_all_levels()
	verify(levels.size() >= 9, "Five lessons and four original levels must be available")
	for i in range(5):
		var id := "tutorial_%02d" % (i + 1)
		verify(levels[i].level_id == id, "Tutorial order: " + id)
		var level := SaveManager.load_level(id)
		verify(LevelData.from_dict(level.to_dict()).tutorial == level.tutorial, "Lesson survives serialization: " + id)
		var player: LevelPlayer = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
		root.add_child(player)
		await process_frame
		player.load_level_data(level)
		player.base_tick_duration = 0.001
		verify(player.tutorial_guide.visible, "Guide visible: " + id)
		player.step_single_tick()
		verify(player.sim_engine.step_count == 0, "Premature simulation blocked: " + id)
		var steps: Array = level.tutorial.steps
		for n in range(steps.size()):
			var instruction: Dictionary = steps[n]
			verify(player.tutorial_guide.next_step(player.world, 0) == n, "Expected guide step: " + id)
			player.toolbar.select_type(int(instruction.type))
			player.toolbar.current_dir = int(instruction.get("dir", 0))
			player.toolbar.current_sub_mode = int(instruction.get("sub_mode", 0))
			player._try_place_block(Vector2i(int(instruction.x), int(instruction.y)))
			player._refresh_tutorial()
		verify(player._tutorial_can_run(), "Completed setup unlocks simulation: " + id)
		var first: Dictionary = steps[0]
		var first_pos := Vector2i(int(first.x), int(first.y))
		var saved_block := player.world.get_block(first_pos).duplicate_block(false)
		player.world.remove_block_at(first_pos)
		verify(not player._tutorial_can_run(), "Removing a required block locks simulation again: " + id)
		player.world.add_block(saved_block)
		player._update_initial_snapshot()
		for tick in range(12):
			player.step_single_tick()
			while player.is_animating_tick: await process_frame
			if player.victory_dialog.visible: break
		verify(player.victory_dialog.visible, "Guided solution wins: " + id)
		verify(player.sim_engine.get_remaining_pollution() == 0, "Pollution cleared: " + id)
		print(id, " solved in ", player.sim_engine.step_count, " ticks")
		player.reset_simulation()
		verify(player.sim_engine.step_count == 0 and not player.victory_dialog.visible, "Reset: " + id)
		verify(player._tutorial_can_run(), "Reset preserves valid construction: " + id)
		player.tutorial_guide.restart_requested.emit()
		verify(not player._tutorial_can_run(), "Restart lesson clears player construction: " + id)
		verify(player.tutorial_guide.active_step == 0, "Restart returns guide to first step: " + id)
		player.load_level_data(SaveManager.load_level("level_01"))
		verify(not player.tutorial_guide.visible and player._tutorial_can_run(), "Original levels remain unrestricted")
		verify(player.grid_view.tutorial_target.is_empty(), "Original levels have no target marker")
		player.free()
	print("TUTORIAL CHECKS: ", checks, "; FAILURES: ", failures.size())
	quit(0 if failures.is_empty() else 1)
