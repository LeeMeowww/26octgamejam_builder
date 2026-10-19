extends SceneTree

var failures: Array[String] = []
var checks := 0
var view: SubViewport
var output := OS.get_environment("BLOCKBOUND_TEST_OUTPUT")

func _initialize() -> void:
	call_deferred("run_tests")

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func make_world(level: LevelData, parts: Array, grouped: bool = false) -> GridWorld:
	var world := GridWorld.new()
	for data in level.blocks_data: world.add_block(BlockData.from_dict(data))
	var added: Array[BlockData] = []
	for part in parts:
		var b := BlockData.new(int(part[0]), Vector2i(int(part[1]), int(part[2])), int(part[3]))
		b.sub_mode = int(part[4])
		world.add_block(b)
		added.append(b)
	if grouped: world.group_blocks(added)
	return world

func wins(level: LevelData, parts: Array, grouped: bool = false) -> bool:
	var sim := SimulationEngine.new(make_world(level, parts, grouped), level.player_build_area)
	sim.construction_inspection = level.tutorial.get("goal", "") == "connect"
	for tick in range(32):
		if sim.step_tick().is_victory: return true
	return false

func snap(name: String) -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	view.get_texture().get_image().save_png(output.path_join(name + ".png"))

func click(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	view.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		view.push_input(event, true)
		await process_frame

func key(code: int) -> void:
	view.gui_release_focus()
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		view.push_input(event, true)
		await process_frame

func run_tests() -> void:
	for i in range(7):
		var level := SaveManager.load_level("tutorial_%02d" % i)
		for act in [level, LevelData.from_dict(level.tutorial.followup)]:
			verify(wins(act, act.tutorial.reference, act.tutorial.group_reference), "reference solution wins")
			verify(not wins(act, []), "empty construction cannot win")
	print("REFERENCE CHECKS: ", checks, "; FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
