extends "res://scripts/core/test_tutorial_redesign.gd"
const Acts = preload("res://scripts/core/TutorialActs.gd")

func press(player: LevelPlayer, code: int, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	player._unhandled_input(event)

func select_at(player: LevelPlayer, pos: Vector2i) -> void:
	player._clear_selection()
	player.selected_blocks.append(player.world.get_block(pos))

func paste_at(player: LevelPlayer, pos: Vector2i) -> void:
	player.grid_view.update_multi_ghost_position(pos)
	player._try_place_ghost_blocks(pos)

func run_tests() -> void:
	view = SubViewport.new()
	view.size = Vector2i(1280,720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var player: LevelPlayer = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
	view.add_child(player)
	await process_frame
	var original := SaveManager.load_level("tutorial_00")
	var level := Acts.followup_level(original)
	level.level_id = "seed_lesson_test"
	player.load_level_data(level)
	player.tutorial_dialogue.close()
	var seed := Vector2i(-2,2)
	var target := Vector2i(0,1)
	verify(player.world.get_block(seed) != null and not player.world.get_block(seed).is_world_block, "seed editable")
	verify(player.world.get_all_blocks().filter(func(b): return not b.is_world_block).size() == 1, "exactly one starting cell")
	player.toolbar.select_type(0)
	verify(not player.toolbar.is_placing and player.toolbar.type_buttons[0].disabled, "tool selection disabled")
	press(player, KEY_1)
	player.toolbar.cycle_tool(1)
	verify(not player.toolbar.is_placing, "number and cycling cannot place")
	player.toolbar.current_type = 0
	player._try_place_block(Vector2i(3,1))
	verify(player.world.get_block(Vector2i(3,1)) == null, "placement rejected at rule layer")
	player.toolbar.deselect_tool()
	select_at(player,seed)
	press(player,KEY_C,true)
	press(player,KEY_V,true)
	paste_at(player,target)
	verify(player.world.get_block(target) == null and player.tutorial_guide.edit_progress == 0, "copy cannot skip move")
	press(player,KEY_ESCAPE)
	select_at(player,seed)
	press(player,KEY_X,true)
	press(player,KEY_ESCAPE)
	player.undo()
	verify(player.world.get_block(seed) != null and player.tutorial_guide.edit_progress == 0, "cancel cut recoverable with undo")
	select_at(player,seed)
	press(player,KEY_X,true)
	paste_at(player,Vector2i(1,1))
	verify(player.tutorial_guide.edit_progress == 0, "wrong destination not accepted")
	select_at(player,Vector2i(1,1))
	press(player,KEY_X,true)
	paste_at(player,target)
	verify(player.tutorial_guide.edit_progress == 1 and player.world.get_block(target) != null, "move to exact (0,1)")
	await process_frame
	await snap("seed_moved")
	select_at(player,target)
	press(player,KEY_C,true)
	verify(player.tutorial_guide.edit_progress == 2, "copy relocated seed advances")
	press(player,KEY_V,true)
	paste_at(player,Vector2i(0,2))
	verify(player.tutorial_guide.edit_progress == 2, "blocked paste not credited")
	paste_at(player,Vector2i(0,0))
	verify(player.tutorial_guide.edit_progress == 3, "valid paste credited")
	for pos in [Vector2i(-1,0),Vector2i(1,0)]:
		press(player,KEY_V,true)
		paste_at(player,pos)
	verify(player.world.get_all_blocks().filter(func(b): return not b.is_world_block).size() == 4, "one seed and three copies")
	verify(player._tutorial_can_run(), "connection ready")
	player.base_tick_duration = 0.001
	player.step_single_tick()
	while player.is_animating_tick: await process_frame
	verify(player.victory_dialog.visible, "connection wins")
	verify("做得很好" in player.victory_dialog.details_label.text and "拖框" in player.victory_dialog.details_label.text, "praise and batch explanation at completion")
	await snap("seed_completed")
	player._apply_level_data(level,false)
	verify(player.tutorial_guide.edit_progress == 0 and player.world.get_block(seed) != null, "restart restores seed and lesson")
	player.load_level_data(original)
	player.tutorial_dialogue.close()
	player.toolbar.select_type(0)
	verify(player.toolbar.is_placing and not player.toolbar.type_buttons[0].disabled, "first act still permits placement")
	print("SEED_LESSON_CHECKS: ",checks," FAILURES: ",failures)
	quit(0 if failures.is_empty() else 1)
