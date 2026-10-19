extends "res://scripts/core/test_tutorial_redesign.gd"
const Campaign = preload("res://scripts/core/Campaign.gd")
const Acts = preload("res://scripts/core/TutorialActs.gd")

func place_solution(player: LevelPlayer) -> void:
	if player.current_level_data.tutorial.get("edit_sequence", "") == "move_then_copy":
		var seed: BlockData = player.world.get_all_blocks().filter(func(b): return not b.is_world_block)[0]
		player.selected_blocks.append(seed)
		player.cut_selected_blocks()
		player.grid_view.update_multi_ghost_position(Vector2i(0,1))
		player._try_place_ghost_blocks(Vector2i(0,1))
		player.selected_blocks.append(player.world.get_block(Vector2i(0,1)))
		player._on_context_menu_action("copy")
		for pos in [Vector2i(0,0),Vector2i(-1,0),Vector2i(1,0)]:
			player._on_context_menu_action("paste")
			player.grid_view.update_multi_ghost_position(pos)
			player._try_place_ghost_blocks(pos)
		verify(player.tutorial_guide.edit_progress == 3, "move then copy practice completed")
		return
	if player.current_level_data.tutorial.get("edit_practice", false):
		var start := player.current_level_data.player_build_area.position + Vector2i(1, 1)
		player.toolbar.select_type(0)
		player._try_place_block(start)
		player.toolbar.deselect_tool()
		player.selected_blocks.append(player.world.get_block(start))
		player._on_context_menu_action("copy")
		player._on_context_menu_action("paste")
		player.grid_view.update_multi_ghost_position(start + Vector2i.RIGHT)
		player._try_place_ghost_blocks(start + Vector2i.RIGHT)
		player.selected_blocks.assign([player.world.get_block(start), player.world.get_block(start + Vector2i.RIGHT)])
		player.cut_selected_blocks()
		player.grid_view.update_multi_ghost_position(start + Vector2i(1, 1))
		player._try_place_ghost_blocks(start + Vector2i(1, 1))
		verify(player.tutorial_guide.edit_progress == 3, "copy paste move exercise completed")
		player.clear_player_blocks()
	for part in player.current_level_data.tutorial.reference:
		await click(player.toolbar.type_buttons[int(part[0])].get_global_rect().get_center())
		for turn in range(posmod(int(part[3]) - player.toolbar.current_dir, 4)):
			await click(player.toolbar.rotate_btn.get_global_rect().get_center())
		if int(part[0]) == 5 and int(part[4]) != player.toolbar.current_sub_mode:
			await click(player.toolbar.mode_btn.get_global_rect().get_center())
		var pos := Vector2i(int(part[1]), int(part[2]))
		await click(player.grid_view.get_global_transform_with_canvas() * player.grid_view.grid_to_world(pos))
		verify(player.world.get_block(pos) != null, "mouse placement in act " + str(player.tutorial_act))
	if player.current_level_data.tutorial.group_reference:
		for block in player.world.get_all_blocks():
			if not block.is_world_block: player.selected_blocks.append(block)
		await click(player.toolbar.group_button.get_global_rect().get_center())

func finish_act(player: LevelPlayer) -> void:
	for tick in range(32):
		await click(player.step_btn.get_global_rect().get_center())
		while player.is_animating_tick: await process_frame
		if player.victory_dialog.visible or not player.tutorial_transition.is_empty(): return

func run_tests() -> void:
	var saved_progress := Campaign.completed()
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var player: LevelPlayer = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
	view.add_child(player)
	await process_frame
	for i in range(7):
		var id := "tutorial_%02d" % i
		var level := SaveManager.load_level_from_path("res://assets/levels/" + id + ".json")
		level.level_id = "test_acts_%d_%s" % [Time.get_ticks_usec(),id]
		verify(wins(level, level.tutorial.reference, level.tutorial.group_reference), id + " simple act solvable")
		var advanced := Acts.followup_level(level)
		if advanced != null:
			verify(wins(advanced, advanced.tutorial.reference, advanced.tutorial.group_reference), id + " shifted second act solvable")
			var initial_targets := make_world(level, []).get_all_blocks().filter(func(b): return b.block_type == 9).size()
			var later_targets := make_world(advanced, []).get_all_blocks().filter(func(b): return b.block_type == 9).size()
			if i == 5:
				verify(initial_targets == 1 and later_targets == 1 and make_world(advanced, []).get_all_blocks().filter(func(b): return b.block_type == 4).size() == 2, id + " transfers inhibition from armor to cell function")
			else:
				verify((initial_targets == 0 and later_targets == 0) if i == 0 else (initial_targets == 1 and later_targets > initial_targets), id + " task escalation")
		player.load_level_data(level)
		player.base_tick_duration = 0.001
		await process_frame
		for page_index in range(player.tutorial_dialogue.pages.size()):
			player.tutorial_dialogue.page = page_index
			player.tutorial_dialogue._display_page()
			verify(player.tutorial_dialogue.portrait.texture.resource_path == level.tutorial.dialogue_portraits[page_index], id + " expression changes with dialogue page")
		player.tutorial_dialogue.page = 0
		player.tutorial_dialogue._display_page()
		player.tutorial_dialogue.advance()
		await snap(id + "_act1_intro")
		await click(player.tutorial_dialogue.skip_button.get_global_rect().get_center())
		await place_solution(player)
		await snap(id + "_act1_solution")
		player.undo()
		player.redo()
		verify(player.sim_engine.construction_inspection == (i == 0), id + " undo redo preserves lesson objective")
		verify(player.sim_engine.level_won.is_connected(player._on_level_won), id + " undo redo preserves completion callback")
		await finish_act(player)
		if advanced == null:
			verify(player.victory_dialog.visible and Campaign.completed().has(level.level_id), id + " single act completes lesson")
			verify(player.tutorial_transition.is_empty(), id + " no deleted act transition")
			await snap(id + "_single_complete")
			continue
		verify(player.tutorial_transition == "briefing", id + " victory opens story instead of completion")
		verify(not player.victory_dialog.visible and not Campaign.completed().has(level.level_id), id + " no premature completion record")
		verify(player.reset_btn.disabled and not player._tutorial_can_run(), id + " briefing locks simulation")
		player.tutorial_dialogue.advance()
		verify(player.tutorial_dialogue.portrait.texture.resource_path == level.tutorial.transition_portraits[0], id + " transition expression")
		await snap(id + "_transition_story")
		var departure := player.camera.position
		await click(player.tutorial_dialogue.skip_button.get_global_rect().get_center())
		verify(player.tutorial_transition == "panning" and player.tutorial_pan_blocker.visible, id + " camera transition blocks clicks")
		await create_timer(0.5).timeout
		verify(player.camera.position.distance_to(departure) > (1 if i == 0 else 50), id + " camera moves across world")
		await snap(id + "_camera_pan")
		await create_timer(0.9).timeout
		verify(player.tutorial_act == 1 and player.tutorial_transition.is_empty(), id + " enters second act")
		verify(player.tutorial_dialogue.visible and not player.tutorial_pan_blocker.visible, id + " arrival dialogue")
		verify(player.camera.position.distance_to(departure) > (1 if i == 0 else 600), id + " destination camera positioned")
		verify(player.world.get_all_blocks().filter(func(b): return not b.is_world_block).size() == (1 if i == 0 else 0), id + " destination starts with authored editable cells")
		player.tutorial_dialogue.advance()
		await snap(id + "_act2_intro")
		await click(player.tutorial_dialogue.skip_button.get_global_rect().get_center())
		await place_solution(player)
		await snap(id + "_act2_solution")
		player.reset_simulation()
		verify(player.tutorial_act == 1 and player.current_level_data.player_build_area == advanced.player_build_area, id + " reset stays in second act")
		await finish_act(player)
		verify(player.victory_dialog.visible and Campaign.completed().has(level.level_id), id + " both acts complete lesson")
		await snap(id + "_lesson_complete")
		player.load_level_data(level)
		verify(player.tutorial_act == 0 and player.current_level_data == level, id + " reopening starts first act")
	# Interrupt a camera transition and ensure its callback cannot overwrite another level.
	player.load_level_data(SaveManager.load_level("tutorial_05"))
	player.tutorial_dialogue.close()
	player._begin_tutorial_transition()
	player.tutorial_dialogue.close()
	player.load_level_data(SaveManager.load_level("custom_level_80400"))
	await create_timer(1.4).timeout
	verify(player.current_level_data.level_id == "custom_level_80400" and not player.tutorial_dialogue.visible, "cancelled camera does not reopen stale dialogue")
	verify(not player.tutorial_pan_blocker.visible and player.camera.is_processing_unhandled_input(), "normal level input restored")
	player.queue_free()
	view.queue_free()
	await process_frame
	var config := ConfigFile.new()
	config.load(Campaign.PROGRESS_PATH)
	config.set_value("campaign", "completed", saved_progress)
	config.save(Campaign.PROGRESS_PATH)
	print("TWO ACT CHECKS: ", checks, "; FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
