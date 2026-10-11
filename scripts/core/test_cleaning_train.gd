extends SceneTree

var failures: Array[String] = []
var checks := 0
var output_dir := OS.get_environment("BLOCKBOUND_TEST_OUTPUT")

func _initialize() -> void:
	call_deferred("run_tests")

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print(label, ": ", ok)

func build(player: LevelPlayer, grouped: bool, inhibitor_dir: int = 3) -> void:
	for spec in [[2, -3, 0, 0], [4, -2, 0, 0], [1, -1, -1, inhibitor_dir], [4, -1, -2, 0]]:
		player.toolbar.select_type(spec[0])
		player.toolbar.current_dir = spec[3]
		var pos := Vector2i(spec[1], spec[2])
		player._try_place_block(pos)
		verify(player.world.has_block(pos), "Player can place module at " + str(pos))
		player.selected_blocks.append(player.world.get_block(pos))
	if grouped: player.group_selected_blocks()

func snap(view: SubViewport, file_name: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(output_dir.path_join(file_name + ".png"))

func run_tests() -> void:
	var levels := SaveManager.get_all_levels()
	var index := -1
	for i in range(levels.size()):
		if levels[i].level_id == "level_05": index = i
	verify(index >= 0, "New level appears in level selection")
	if index < 0:
		quit(1)
		return
	verify(levels[index - 1].level_id == "level_04", "New level follows chapter four")
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var player: LevelPlayer = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
	view.add_child(player)
	await process_frame
	player.load_level_by_index(index)
	player.base_tick_duration = 0.001
	verify(player.sim_engine.get_remaining_pollution() == 2, "Two pollution goals")
	await snap(view, "train_start")
	build(player, true)
	verify(player.selected_blocks.size() == 4, "Four-module optional challenge")
	await snap(view, "train_ready")
	var won_tick := 0
	for tick in range(20):
		player.step_single_tick()
		while player.is_animating_tick: await process_frame
		if player.victory_dialog.visible:
			won_tick = player.sim_engine.step_count
			break
	verify(won_tick > 0, "Four-module machine wins without editing during simulation")
	verify(player.sim_engine.get_remaining_pollution() == 0, "Both pollution sources cleared")
	for x in [0, 2, 4]:
		var block := player.world.get_block(Vector2i(x, 0))
		verify(block == null or block.block_type != BlockData.Type.HARD, "Gate cleared: " + str(x))
	print("SOLUTION TICKS: ", won_tick)
	await snap(view, "train_complete")
	player.reset_simulation()
	verify(player.sim_engine.get_remaining_pollution() == 2 and not player.victory_dialog.visible, "Reset restores goals and hides victory")
	verify(player.world.get_block(Vector2i(-3, 0)).structure_id > 0, "Reset preserves grouped machine")
	for variant in [0, 1]:
		player.load_level_by_index(index)
		build(player, variant == 1, 1 if variant == 1 else 3)
		for tick in range(20): player.sim_engine.step_tick()
		verify(player.sim_engine.get_remaining_pollution() > 0, "Incomplete design does not win: " + str(variant))
	player.load_level_by_index(index)
	for tick in range(20): player.sim_engine.step_tick()
	verify(player.sim_engine.get_remaining_pollution() == 2, "Empty build does not solve level")
	print("TRAIN CHECKS: ", checks, "; FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
