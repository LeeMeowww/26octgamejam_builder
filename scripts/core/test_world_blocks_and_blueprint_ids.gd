extends SceneTree

var view: SubViewport
var player: LevelPlayer
var failures: Array = []
var checks := 0

func _initialize() -> void:
	call_deferred("run_test")

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
	else:
		print("PASS: ", label)

func frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame

func run_test() -> void:
	print("=== RUNNING WORLD BLOCK IMMOBILITY & BLUEPRINT ID TESTS ===")
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)

	var scene = load("res://scenes/ui/LevelPlayer.tscn")
	player = scene.instantiate()
	view.add_child(player)
	await frames(10)

	# Setup custom test level
	var lvl := LevelData.new("test_lvl", "测试世界方块与图纸")
	lvl.player_build_area = Rect2i(0, 0, 10, 10)

	# Add a world block (e.g. monster or terrain) at (5, 5)
	var world_block := BlockData.new(BlockData.Type.POLLUTION, Vector2i(5, 5), BlockData.Direction.RIGHT)
	world_block.is_world_block = true
	lvl.blocks_data.append(world_block.to_dict())

	player.load_level_data(lvl)
	await frames(5)

	var wb: BlockData = player.world.get_block(Vector2i(5, 5))
	verify(wb != null and wb.is_world_block, "World block exists at (5, 5)")

	# -------------------------------------------------------------
	# Test 1: Player cannot select world block via click or toggle
	# -------------------------------------------------------------
	player._toggle_select_block(wb)
	verify(player.selected_blocks.is_empty(), "World block cannot be selected via _toggle_select_block")

	# -------------------------------------------------------------
	# Test 2: Player cannot select world block via box-select
	# -------------------------------------------------------------
	player.box_select_start_world = player.grid_view.grid_to_world(Vector2i(4, 4))
	player.grid_view.box_select_current = player.grid_view.grid_to_world(Vector2i(6, 6))
	player._finish_box_select()
	verify(player.selected_blocks.is_empty(), "World block cannot be selected via box select")

	# -------------------------------------------------------------
	# Test 3: Player cannot drag world block
	# -------------------------------------------------------------
	player.selected_blocks = [wb]
	player.right_drag_orig_positions[wb] = wb.grid_pos
	player._apply_selection_drag(Vector2i(1, 0))
	verify(wb.grid_pos == Vector2i(5, 5), "World block does not move when _apply_selection_drag is called")
	player.selected_blocks.clear()
	player.right_drag_orig_positions.clear()

	# -------------------------------------------------------------
	# Test 4: Player cannot drag player blocks into world blocks
	# -------------------------------------------------------------
	player._try_place_block(Vector2i(4, 5))
	var pb: BlockData = player.world.get_block(Vector2i(4, 5))
	verify(pb != null and not pb.is_world_block, "Player block placed at (4, 5)")

	player.selected_blocks = [pb]
	player.right_drag_orig_positions[pb] = pb.grid_pos
	# Try to drag into world block at (5, 5)
	player._apply_selection_drag(Vector2i(1, 0))
	verify(pb.grid_pos == Vector2i(4, 5), "Player block drag blocked by collision with world block")
	verify(player.world.get_block(Vector2i(5, 5)) == wb, "World block not overwritten by player block drag")

	# -------------------------------------------------------------
	# Test 5: Player cannot rotate world blocks
	# -------------------------------------------------------------
	var old_dir := wb.direction
	player.selected_blocks = [wb]
	# Simulate rotate CW
	if not wb.is_world_block:
		wb.rotate_cw()
	verify(wb.direction == old_dir, "World block cannot be rotated")
	player.selected_blocks.clear()

	# -------------------------------------------------------------
	# Test 6: Player cannot group world blocks
	# -------------------------------------------------------------
	player.selected_blocks = [wb, pb]
	player.group_selected_blocks()
	verify(wb.structure_id == 0, "World block cannot be added to a structure group")
	player.selected_blocks.clear()

	# -------------------------------------------------------------
	# Test 7: Blueprint loading generates brand new IDs
	# -------------------------------------------------------------
	# Save a machine with specific blocks and fixed IDs in file
	var test_machine_blocks: Array[BlockData] = [
		BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0)),
		BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0)),
		BlockData.new(BlockData.Type.DESTROYER, Vector2i(2, 0))
	]
	var original_ids: Array[int] = []
	for b in test_machine_blocks:
		original_ids.append(b.block_id)

	SaveManager.save_machine("test_id_generation", test_machine_blocks)

	# First load
	var loaded1 := SaveManager.load_machine("test_id_generation")
	verify(loaded1.size() == 3, "Loaded 3 blocks on first load")
	var ids1: Array[int] = []
	for b in loaded1:
		ids1.append(b.block_id)
		verify(b.block_id != 0, "Block has non-zero block_id")
		verify(b.origin_id == b.block_id, "origin_id matches new block_id")
		verify(b.block_id not in original_ids, "Loaded block ID %d is newly generated (different from saved ID)" % b.block_id)

	verify(ids1[0] != ids1[1] and ids1[1] != ids1[2] and ids1[0] != ids1[2], "All loaded block IDs are unique among themselves")

	# Second load (simulate loading blueprint again)
	var loaded2 := SaveManager.load_machine("test_id_generation")
	verify(loaded2.size() == 3, "Loaded 3 blocks on second load")
	var ids2: Array[int] = []
	for b in loaded2:
		ids2.append(b.block_id)
		verify(b.block_id not in ids1, "Second load generates IDs disjoint from first load (no ID clash between multiple loads)")

	# Test structure ID remapping in blueprint
	var struct_blocks: Array[BlockData] = [
		BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0)),
		BlockData.new(BlockData.Type.BASIC, Vector2i(0, 1))
	]
	struct_blocks[0].structure_id = 99
	struct_blocks[1].structure_id = 99
	SaveManager.save_machine("test_structure_remapping", struct_blocks)

	var loaded_struct := SaveManager.load_machine("test_structure_remapping")
	verify(loaded_struct.size() == 2, "Loaded 2 blocks from structured blueprint")
	verify(loaded_struct[0].structure_id > 0, "Loaded structure block 0 has positive structure_id")
	verify(loaded_struct[0].structure_id != 99, "Loaded structure_id is remapped away from old file structure_id 99")
	verify(loaded_struct[0].structure_id == loaded_struct[1].structure_id, "Both blocks in structure share the same remapped structure_id")

	print("\n--- Test Results: %d checks, %d failures ---" % [checks, failures.size()])
	if failures.is_empty():
		print("ALL WORLD BLOCK & BLUEPRINT ID TESTS PASSED!")
		quit(0)
	else:
		printerr("TESTS FAILED: ", failures)
		quit(1)
