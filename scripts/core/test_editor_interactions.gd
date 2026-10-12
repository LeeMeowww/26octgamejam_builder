extends SceneTree

const KeybindManager = preload("res://scripts/core/KeybindManager.gd")
const EditorClipboard = preload("res://scripts/core/EditorClipboard.gd")
const EditorContextMenu = preload("res://scripts/ui/EditorContextMenu.gd")
const SettingsMenu = preload("res://scripts/ui/SettingsMenu.gd")
const GridView = preload("res://scripts/view/GridView.gd")

var passed_checks: int = 0
var failed_checks: int = 0

func check(condition: bool, msg: String) -> void:
	if condition:
		passed_checks += 1
		print("PASS: %s" % msg)
	else:
		failed_checks += 1
		printerr("FAIL: %s" % msg)

func _init() -> void:
	print("=== RUNNING EDITOR INTERACTIONS & NEW FEATURES TESTS ===")
	test_keybind_manager()
	test_editor_clipboard()
	test_ghost_transformations()
	test_context_menu_ui()
	test_connectivity_enforcement()

	print("\n--- Test Results: %d passed, %d failed ---" % [passed_checks, failed_checks])
	if failed_checks == 0:
		print("ALL EDITOR INTERACTION TESTS PASSED!")
		quit(0)
	else:
		printerr("SOME TESTS FAILED!")
		quit(1)

func test_keybind_manager() -> void:
	print("\n--- 1. Testing KeybindManager ---")
	KeybindManager.init_keybinds()
	var del_bind: Dictionary = KeybindManager.get_binding("delete")
	check(del_bind.get("key") == KEY_X, "Default delete key is X")
	check(KeybindManager.get_action_display_name("delete") == "X", "Delete action display name is 'X'")

	var copy_str: String = KeybindManager.get_action_display_name("copy")
	check(copy_str == "Ctrl+C", "Copy action display name is 'Ctrl+C'")

	# Test custom binding
	KeybindManager.set_binding("delete", KEY_DELETE, false, false, false)
	check(KeybindManager.get_binding("delete").get("key") == KEY_DELETE, "Delete successfully rebound to KEY_DELETE")
	check(KeybindManager.get_action_display_name("delete") == "Del", "Rebound delete display is 'Del'")

	# Reset defaults
	KeybindManager.reset_to_defaults()
	check(KeybindManager.get_binding("delete").get("key") == KEY_X, "Reset to defaults restored delete key to X")

func test_editor_clipboard() -> void:
	print("\n--- 2. Testing EditorClipboard ---")
	var b1 := BlockData.new(BlockData.Type.BASIC, Vector2i(10, 10))
	var b2 := BlockData.new(BlockData.Type.ROTATOR, Vector2i(10, 11), BlockData.Direction.RIGHT)
	b2.sub_mode = 0 # CW
	var blocks: Array[BlockData] = [b1, b2]

	EditorClipboard.copy(blocks)
	check(EditorClipboard.has_blocks(), "Clipboard has blocks after copy")

	var pasted: Array[BlockData] = EditorClipboard.get_blocks()
	check(pasted.size() == 2, "Pasted blocks count matches copied count")
	check(pasted[0].grid_pos == Vector2i(10, 10), "Pasted blocks retain positions for ghost placement")
	check(pasted[1].direction == BlockData.Direction.RIGHT, "Pasted blocks retain direction")
	check(pasted[1].sub_mode == 0, "Pasted blocks retain sub_mode")

func test_ghost_transformations() -> void:
	print("\n--- 3. Testing Ghost Preview & Synchronous Orientations ---")
	var gview := GridView.new()
	root.add_child(gview)

	var b_right := BlockData.new(BlockData.Type.PUSHER, Vector2i(2, 0), BlockData.Direction.RIGHT)
	var b_rot := BlockData.new(BlockData.Type.ROTATOR, Vector2i(0, 2), BlockData.Direction.UP)
	b_rot.sub_mode = 0 # CW rotator

	gview.start_multi_ghost([b_right, b_rot])
	check(gview.is_multi_ghost_active(), "Multi ghost is active after start_multi_ghost")

	# Test Rotate CW:
	# Right (0) rotated CW -> Down (1)
	# Up (3) rotated CW -> Right (0)
	gview.rotate_multi_ghost_cw()
	var gblocks: Array[Dictionary] = gview.multi_ghost_blocks
	check(gblocks[0]["dir"] == BlockData.Direction.DOWN, "Rotating ghost CW transforms RIGHT to DOWN")
	check(gblocks[1]["dir"] == BlockData.Direction.RIGHT, "Rotating ghost CW transforms UP to RIGHT")

	# Test Rotate CCW: Down back to Right
	gview.rotate_multi_ghost_ccw()
	check(gblocks[0]["dir"] == BlockData.Direction.RIGHT, "Rotating ghost CCW transforms DOWN back to RIGHT")

	# Test Flip Horizontal:
	# Direction: RIGHT -> LEFT
	# Rotator sub_mode: CW (0) -> CCW (1)
	gview.flip_multi_ghost_h()
	check(gblocks[0]["dir"] == BlockData.Direction.LEFT, "Flip H transforms RIGHT to LEFT")
	check(gblocks[1]["sub_mode"] == 1, "Flip H inverts Rotator sub_mode from CW (0) to CCW (1)")

	# Flip H again restores
	gview.flip_multi_ghost_h()
	check(gblocks[0]["dir"] == BlockData.Direction.RIGHT, "Flip H again restores RIGHT")
	check(gblocks[1]["sub_mode"] == 0, "Flip H again restores Rotator sub_mode to CW (0)")

	# Test Flip Vertical:
	# b_rot was UP -> DOWN
	gview.flip_multi_ghost_v()
	check(gblocks[1]["dir"] == BlockData.Direction.DOWN, "Flip V transforms UP to DOWN")
	check(gblocks[1]["sub_mode"] == 1, "Flip V inverts Rotator sub_mode from CW (0) to CCW (1)")

	# Test Placement conflict check
	var world := GridWorld.new()
	var existing := BlockData.new(BlockData.Type.BASIC, Vector2i(5, 5))
	world.add_block(existing)
	gview.set_world(world)
	gview.player_build_area = Rect2i(0, 0, 10, 10)

	var conflict_b := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	gview.start_multi_ghost([conflict_b])

	# Position ghost over existing block
	gview.update_multi_ghost_position(Vector2i(5, 5))
	check(not gview.can_place_multi_ghost(), "Cannot place ghost when conflicting with existing blocks")

	# Position ghost outside player_build_area
	gview.update_multi_ghost_position(Vector2i(20, 20))
	check(not gview.can_place_multi_ghost(), "Cannot place ghost outside player_build_area")

	# Position ghost in free space inside build area
	gview.cancel_multi_ghost()
	var single_b := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	gview.start_multi_ghost([single_b])
	gview.update_multi_ghost_position(Vector2i(1, 1))
	check(gview.can_place_multi_ghost(), "Can place ghost when clear in player build area")

	gview.queue_free()

func test_context_menu_ui() -> void:
	print("\n--- 4. Testing EditorContextMenu ---")
	var menu := EditorContextMenu.new()
	root.add_child(menu)
	menu.popup_at(Vector2(100, 100), true)
	check(menu.visible, "Context menu becomes visible on popup_at")

	# Verify menu entries
	var has_copy := false
	var has_paste := false
	var has_del := false
	var has_rot_cw := false
	var has_rot_ccw := false
	var has_flip_h := false
	var has_flip_v := false

	for child in menu.menu_vbox.get_children():
		if child is Button:
			match child.name:
				"copy": has_copy = true
				"paste": has_paste = true
				"delete": has_del = true
				"rotate_cw": has_rot_cw = true
				"rotate_ccw": has_rot_ccw = true
				"flip_h": has_flip_h = true
				"flip_v": has_flip_v = true

	check(has_copy and has_paste and has_del and has_rot_cw and has_rot_ccw and has_flip_h and has_flip_v,
		"Context menu contains all required actions (Copy, Paste, Delete, Rotate CW/CCW, Flip H/V)")

	menu.queue_free()

func test_connectivity_enforcement() -> void:
	print("\n--- 5. Testing 4-Connectivity Rules ---")
	var world := GridWorld.new()
	# Create two disconnected blocks
	var b1 := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	var b2 := BlockData.new(BlockData.Type.BASIC, Vector2i(5, 5))
	world.add_block(b1)
	world.add_block(b2)

	world.group_blocks([b1, b2])
	check(b1.structure_id > 0, "Block 1 has positive structure ID")
	check(b2.structure_id > 0, "Block 2 has positive structure ID")
	check(b1.structure_id != b2.structure_id, "Disconnected blocks in grouping split into separate structure IDs")
