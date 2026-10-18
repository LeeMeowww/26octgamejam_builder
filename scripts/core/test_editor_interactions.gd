extends SceneTree

const KeybindManager = preload("res://scripts/core/KeybindManager.gd")
const EditorClipboard = preload("res://scripts/core/EditorClipboard.gd")
const EditorContextMenu = preload("res://scripts/ui/EditorContextMenu.gd")
const SettingsMenu = preload("res://scripts/ui/SettingsMenu.gd")
const GridView = preload("res://scripts/view/GridView.gd")
const GridWorld = preload("res://scripts/core/GridWorld.gd")
const BlockData = preload("res://scripts/core/BlockData.gd")
const CameraController = preload("res://scripts/view/CameraController.gd")
const Toolbar = preload("res://scripts/ui/Toolbar.gd")
const LevelEditor = preload("res://scripts/ui/LevelEditor.gd")
const LevelPlayer = preload("res://scripts/ui/LevelPlayer.gd")
const Campaign = preload("res://scripts/core/Campaign.gd")
const BlockView = preload("res://scripts/view/BlockView.gd")
const LevelData = preload("res://scripts/core/LevelData.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")

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
	test_cut_and_copy_actions()
	test_wheel_zoom_and_tool_cycle()
	test_undo_redo()
	test_ghost_animated_views()
	test_campaign_chapters_and_nodes()
	test_speed_slider_and_log_scale()

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

	var cut_str: String = KeybindManager.get_action_display_name("cut")
	check(cut_str == "Ctrl+X", "Cut action display name is 'Ctrl+X'")

	# Test custom binding
	KeybindManager.set_binding("delete", KEY_DELETE, false, false, false)
	check(KeybindManager.get_binding("delete").get("key") == KEY_DELETE, "Delete successfully rebound to KEY_DELETE")
	check(KeybindManager.get_action_display_name("delete") == "Del", "Rebound delete display is 'Del'")

	# Reset defaults
	KeybindManager.reset_to_defaults()
	check(KeybindManager.get_binding("delete").get("key") == KEY_X, "Reset to defaults restored delete key to X")

	# Test conflict detection & write failure
	check(KeybindManager.has_conflict("copy", KEY_X, true, false, false), "Ctrl+X conflicts with cut")
	var conflict_act: String = KeybindManager.find_conflicting_action("copy", KEY_X, true, false, false)
	check(conflict_act == "cut", "Conflicting action for Ctrl+X is 'cut'")

	var write_failed: bool = not KeybindManager.set_binding("copy", KEY_X, true, false, false)
	check(write_failed, "Conflicting binding write fails and returns false")
	check(KeybindManager.get_binding("copy").get("key") == KEY_C, "Binding for copy remains unchanged after failed write")

	var same_key_success: bool = KeybindManager.set_binding("copy", KEY_C, true, false, false)
	check(same_key_success, "Re-binding identical key to same action does not conflict with itself")

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
	var has_cut := false
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
				"cut": has_cut = true
				"paste": has_paste = true
				"delete": has_del = true
				"rotate_cw": has_rot_cw = true
				"rotate_ccw": has_rot_ccw = true
				"flip_h": has_flip_h = true
				"flip_v": has_flip_v = true

	check(has_copy and has_cut and has_paste and has_del and has_rot_cw and has_rot_ccw and has_flip_h and has_flip_v,
		"Context menu contains all required actions (Copy, Cut, Paste, Delete, Rotate CW/CCW, Flip H/V)")

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

func test_cut_and_copy_actions() -> void:
	print("\n--- 6. Testing Cut & Copy Action Behaviors ---")
	var world := GridWorld.new()
	var b1 := BlockData.new(BlockData.Type.BASIC, Vector2i(2, 3))
	world.add_block(b1)
	check(world.get_block(Vector2i(2, 3)) != null, "Block exists in world prior to cut")

	var selected: Array[BlockData] = [b1]

	# 1. Test Copy does not clear selection
	EditorClipboard.copy(selected)
	check(selected.size() == 1, "Copying does NOT deselect blocks")
	check(EditorClipboard.has_blocks(), "Clipboard has blocks after copy")

	# 2. Test Cut workflow (copy -> delete original -> start multi ghost)
	var gview := GridView.new()
	root.add_child(gview)

	# Execute cut semantics
	EditorClipboard.copy(selected)
	var blocks_to_paste := EditorClipboard.get_blocks()
	for b in selected:
		world.remove_block_at(b.grid_pos)
	selected.clear()
	gview.start_multi_ghost(blocks_to_paste)

	check(world.get_block(Vector2i(2, 3)) == null, "Original block was deleted after cut")
	check(EditorClipboard.has_blocks(), "Clipboard holds the cut block")
	check(gview.is_multi_ghost_active(), "Multi-ghost preview is active after cut")

	gview.cancel_multi_ghost()
	gview.queue_free()

func test_wheel_zoom_and_tool_cycle() -> void:
	print("\n--- 7. Testing Mouse Wheel Zoom vs Ctrl+Wheel Tool Cycling ---")
	# Test key events for copy / cut / delete
	var ev_x := InputEventKey.new()
	ev_x.keycode = KEY_X
	ev_x.pressed = true
	ev_x.ctrl_pressed = false
	check(KeybindManager.is_action_just_pressed(ev_x, "delete"), "Plain X triggers delete")
	check(not KeybindManager.is_action_just_pressed(ev_x, "cut"), "Plain X does NOT trigger cut")

	var ev_ctrl_x := InputEventKey.new()
	ev_ctrl_x.keycode = KEY_X
	ev_ctrl_x.pressed = true
	ev_ctrl_x.ctrl_pressed = true
	check(KeybindManager.is_action_just_pressed(ev_ctrl_x, "cut"), "Ctrl+X triggers cut")
	check(not KeybindManager.is_action_just_pressed(ev_ctrl_x, "delete"), "Ctrl+X does NOT trigger delete")

	var ev_ctrl_c := InputEventKey.new()
	ev_ctrl_c.keycode = KEY_C
	ev_ctrl_c.pressed = true
	ev_ctrl_c.ctrl_pressed = true
	check(KeybindManager.is_action_just_pressed(ev_ctrl_c, "copy"), "Ctrl+C triggers copy")
	check(not KeybindManager.is_action_just_pressed(ev_ctrl_c, "cut"), "Ctrl+C does NOT trigger cut")

	# Test Toolbar tool cycling
	var tb := Toolbar.new()
	root.add_child(tb)
	tb.editing_enabled = true
	tb.select_type(BlockData.Type.BASIC)
	check(tb.current_type == BlockData.Type.BASIC, "Toolbar selected BASIC")

	# Simulating Ctrl + Wheel: cycles tool
	tb.cycle_tool(1)
	check(tb.current_type == BlockData.Type.INHIBITOR, "Cycle tool advances to next block")
	tb.cycle_tool(-1)
	check(tb.current_type == BlockData.Type.BASIC, "Cycle tool returns to previous block")

	tb.queue_free()

func test_undo_redo() -> void:
	print("\n--- 8. Testing Undo & Redo (LevelEditor & LevelPlayer) ---")
	# LevelEditor undo/redo test
	var editor := LevelEditor.new()
	editor.world = GridWorld.new()
	editor.initial_snapshot = editor.world.clone()
	check(not editor.can_undo(), "Initial editor cannot undo")
	check(not editor.can_redo(), "Initial editor cannot redo")

	# Step 1: Place block 1
	editor.record_undo()
	var b1 := BlockData.new(BlockData.Type.BASIC, Vector2i(1, 1))
	editor.world.add_block(b1)
	check(editor.can_undo(), "Can undo after recording and adding block 1")
	check(not editor.can_redo(), "Cannot redo after fresh action")
	check(editor.world.get_block(Vector2i(1, 1)) != null, "Block 1 placed")

	# Step 2: Place block 2
	editor.record_undo()
	var b2 := BlockData.new(BlockData.Type.ROTATOR, Vector2i(1, 2))
	editor.world.add_block(b2)
	check(editor.world.get_block(Vector2i(1, 2)) != null, "Block 2 placed")

	# Step 3: Undo block 2
	editor.undo()
	check(editor.world.get_block(Vector2i(1, 2)) == null, "Undo removed Block 2")
	check(editor.world.get_block(Vector2i(1, 1)) != null, "Block 1 still exists after undoing Block 2")
	check(editor.can_redo(), "Can redo after undo")

	# Step 4: Undo block 1
	editor.undo()
	check(editor.world.get_block(Vector2i(1, 1)) == null, "Undo removed Block 1")
	check(not editor.can_undo(), "Cannot undo any further")

	# Step 5: Redo block 1
	editor.redo()
	check(editor.world.get_block(Vector2i(1, 1)) != null, "Redo restored Block 1")
	check(editor.world.get_block(Vector2i(1, 2)) == null, "Block 2 not restored yet")
	check(editor.can_undo(), "Can undo after redo")
	check(editor.can_redo(), "Can still redo block 2")

	# Step 6: Redo block 2
	editor.redo()
	check(editor.world.get_block(Vector2i(1, 2)) != null, "Redo restored Block 2")
	check(not editor.can_redo(), "Cannot redo further after all redos consumed")

	# Step 7: New action clears redo stack
	editor.undo()
	check(editor.can_redo(), "Can redo after undoing block 2")
	editor.record_undo()
	var b3 := BlockData.new(BlockData.Type.PUSHER, Vector2i(2, 2))
	editor.world.add_block(b3)
	check(not editor.can_redo(), "New action clears redo stack")

	# Step 8: Redo 后再修改：操作栈保留，仅清空恢复栈
	var editor_rd := LevelEditor.new()
	editor_rd.world = GridWorld.new()
	editor_rd.initial_snapshot = editor_rd.world.clone()
	editor_rd.record_undo()
	editor_rd.world.add_block(BlockData.new(BlockData.Type.BASIC, Vector2i(7, 1)))
	editor_rd.record_undo()
	editor_rd.world.add_block(BlockData.new(BlockData.Type.BASIC, Vector2i(7, 2)))
	editor_rd.undo()
	check(editor_rd.can_redo(), "Redo available after undo")
	editor_rd.redo()
	check(editor_rd.undo_stack.size() == 2, "Redo pushes the current state back to the undo stack")
	editor_rd.record_undo()
	editor_rd.world.add_block(BlockData.new(BlockData.Type.BASIC, Vector2i(7, 3)))
	check(not editor_rd.can_redo(), "Edit after redo clears only the redo stack")
	check(editor_rd.undo_stack.size() == 3, "Edit after redo appends to the undo stack")
	editor_rd.undo()
	check(editor_rd.world.get_block(Vector2i(7, 3)) == null, "Undo removes only the post-redo edit")
	check(editor_rd.world.get_block(Vector2i(7, 1)) != null and editor_rd.world.get_block(Vector2i(7, 2)) != null, "Redo-restored blocks survive undo of the later edit")
	editor_rd.queue_free()

	# Step 9: 撤销栈至少保留最近 100 步
	check(LevelEditor.MAX_UNDO_STACK >= 100, "MAX_UNDO_STACK keeps at least 100 steps")
	var editor_deep := LevelEditor.new()
	editor_deep.world = GridWorld.new()
	editor_deep.initial_snapshot = editor_deep.world.clone()
	for i in range(120):
		editor_deep.record_undo()
		editor_deep.world.add_block(BlockData.new(BlockData.Type.BASIC, Vector2i(i, 20)))
	check(editor_deep.undo_stack.size() == LevelEditor.MAX_UNDO_STACK, "Undo stack capped at %d entries" % LevelEditor.MAX_UNDO_STACK)
	var undone_count := 0
	while editor_deep.can_undo():
		editor_deep.undo()
		undone_count += 1
	check(undone_count >= 100, "At least 100 consecutive undos are available (got %d)" % undone_count)
	check(editor_deep.world.get_block(Vector2i(119, 20)) == null, "Newest edit undone")
	check(undone_count != 100 or editor_deep.world.get_block(Vector2i(19, 20)) != null, "State 100 steps back is still retained")
	check(undone_count != 100 or editor_deep.world.get_block(Vector2i(20, 20)) == null, "Only records older than 100 steps get dropped")
	editor_deep.queue_free()

	# Step 10: 工具栏属性变更（变体/子模式/朝向）也必须入撤销栈
	var editor_props := LevelEditor.new()
	editor_props.world = GridWorld.new()
	editor_props.initial_snapshot = editor_props.world.clone()
	editor_props.grid_view = GridView.new()
	var prop_block := BlockData.new(BlockData.Type.ROTATOR, Vector2i(3, 3), BlockData.Direction.RIGHT)
	prop_block.texture_variant = 0
	prop_block.sub_mode = 0
	editor_props.world.add_block(prop_block)
	editor_props.selected_blocks.append(prop_block)

	editor_props._on_toolbar_variant_changed(2)
	check(prop_block.texture_variant == 2, "Variant change applied to selected block")
	check(editor_props.undo_stack.size() == 1, "Variant change recorded one undo step")
	var prop_snapshot: GridWorld = editor_props.undo_stack.back()
	check(prop_snapshot.get_block(Vector2i(3, 3)).texture_variant == 0, "Undo snapshot keeps the previous variant")

	editor_props._on_toolbar_variant_changed(2)
	check(editor_props.undo_stack.size() == 1, "No-op variant change does not pollute the undo stack")

	editor_props._on_toolbar_sub_mode_toggled(1)
	check(prop_block.sub_mode == 1, "Sub-mode change applied to selected block")
	check(editor_props.undo_stack.size() == 2, "Sub-mode change recorded one undo step")

	editor_props._on_toolbar_direction_changed(BlockData.Direction.UP)
	check(prop_block.direction == BlockData.Direction.UP, "Direction change applied to selected block")
	check(editor_props.undo_stack.size() == 3, "Direction change recorded one undo step")

	editor_props.undo()
	var prop_after := editor_props.world.get_block(Vector2i(3, 3))
	check(prop_after != null and prop_after.direction == BlockData.Direction.RIGHT, "Undo restores the previous direction")
	check(prop_after != null and prop_after.texture_variant == 2 and prop_after.sub_mode == 1, "Earlier property changes remain until their own undo step")
	editor_props.queue_free()

	# Step 11: Ctrl+Z / Ctrl+R 键位链路直达编辑器撤销/重做
	check(KeybindManager.get_action_display_name("undo") == "Ctrl+Z", "Undo default binding is Ctrl+Z")
	check(KeybindManager.get_action_display_name("redo") == "Ctrl+R", "Redo default binding is Ctrl+R")
	check(KeybindManager.get_binding("undo").get("category", "") == "编辑操作", "Undo binding belongs to the 编辑操作 settings category")
	check(KeybindManager.get_binding("redo").get("category", "") == "编辑操作", "Redo binding belongs to the 编辑操作 settings category")

	var key_editor := LevelEditor.new()
	key_editor.world = GridWorld.new()
	key_editor.initial_snapshot = key_editor.world.clone()
	key_editor.record_undo()
	key_editor.world.add_block(BlockData.new(BlockData.Type.BASIC, Vector2i(40, 40)))
	check(key_editor.world.get_block(Vector2i(40, 40)) != null, "Key-test block placed")

	var ev_undo := InputEventKey.new()
	ev_undo.keycode = KEY_Z
	ev_undo.physical_keycode = KEY_Z
	ev_undo.ctrl_pressed = true
	ev_undo.pressed = true
	key_editor._unhandled_input(ev_undo)
	check(key_editor.world.get_block(Vector2i(40, 40)) == null, "Ctrl+Z triggers editor undo")

	var ev_redo := InputEventKey.new()
	ev_redo.keycode = KEY_R
	ev_redo.physical_keycode = KEY_R
	ev_redo.ctrl_pressed = true
	ev_redo.pressed = true
	key_editor._unhandled_input(ev_redo)
	check(key_editor.world.get_block(Vector2i(40, 40)) != null, "Ctrl+R triggers editor redo")
	key_editor.queue_free()

	editor.queue_free()

	# LevelPlayer undo/redo test
	var player := LevelPlayer.new()
	player.world = GridWorld.new()
	player.initial_snapshot = player.world.clone()
	player.record_undo()
	player.world.add_block(BlockData.new(BlockData.Type.BASIC, Vector2i(5, 5)))
	check(player.world.get_block(Vector2i(5, 5)) != null, "Player placed block")
	check(player.can_undo(), "Player can undo")
	player.undo()
	check(player.world.get_block(Vector2i(5, 5)) == null, "Player undo removed block")
	check(player.can_redo(), "Player can redo")
	player.redo()
	check(player.world.get_block(Vector2i(5, 5)) != null, "Player redo restored block")

	# Check simulation lock
	player.is_simulating = true
	check(not player.can_undo(), "Player cannot undo during simulation")
	check(not player.can_redo(), "Player cannot redo during simulation")
	player.is_simulating = false

	player.queue_free()

func test_ghost_animated_views() -> void:
	print("\n--- 9. Testing Ghost Animated BlockViews ---")
	var gview := GridView.new()
	root.add_child(gview)

	# 1. Single preview
	gview.update_preview(true, BlockData.Type.BASIC, BlockData.Direction.RIGHT, 0, 0, Vector2i(4, 4))
	check(gview.preview_block_view != null, "Single preview uses BlockView")
	check(gview.preview_block_view.visible, "Single preview is visible")
	check(gview.preview_block_view.basic_artwork != null, "Preview BlockView has basic_artwork")
	check(gview.preview_block_view.basic_artwork.visible, "Preview BlockView basic_artwork is visible for BASIC block")
	check(gview.preview_block_view.modulate.a > 0.5 and gview.preview_block_view.modulate.a < 0.9, "Single preview has ghost transparency")

	# Switch preview to PUSHER
	gview.update_preview(true, BlockData.Type.PUSHER, BlockData.Direction.RIGHT, 0, 0, Vector2i(4, 4))
	check(gview.preview_block_view.pusher_artwork != null, "Preview BlockView has pusher_artwork")
	check(gview.preview_block_view.pusher_artwork.visible, "Preview BlockView pusher_artwork is visible for PUSHER block")

	# Switch preview to DESTROYER
	gview.update_preview(true, BlockData.Type.DESTROYER, BlockData.Direction.RIGHT, 0, 0, Vector2i(4, 4))
	check(gview.preview_block_view.destroyer_artwork != null, "Preview BlockView has destroyer_artwork")
	check(gview.preview_block_view.destroyer_artwork.visible, "Preview BlockView destroyer_artwork is visible for DESTROYER block")

	# Inactive preview hides it
	gview.update_preview(false, BlockData.Type.BASIC, 0, 0, 0, Vector2i(4, 4))
	check(not gview.preview_block_view.visible, "Preview view is hidden when inactive")

	# 2. Multi-ghost preview
	var b_basic := BlockData.new(BlockData.Type.BASIC, Vector2i(0, 0))
	var b_pusher := BlockData.new(BlockData.Type.PUSHER, Vector2i(1, 0), BlockData.Direction.UP)
	var b_dest := BlockData.new(BlockData.Type.DESTROYER, Vector2i(0, 1), BlockData.Direction.RIGHT)
	gview.start_multi_ghost([b_basic, b_pusher, b_dest])

	check(gview.is_multi_ghost_active(), "Multi-ghost is active")
	check(gview.multi_ghost_sprites.size() == 3, "Multi-ghost spawned 3 BlockViews")

	for v in gview.multi_ghost_sprites:
		check(v is BlockView, "Each multi-ghost sprite is a BlockView instance")
		check(v.modulate.a > 0.5 and v.modulate.a < 0.9, "Multi-ghost BlockView is semi-transparent")

	var v_basic := gview.multi_ghost_sprites[0]
	var v_pusher := gview.multi_ghost_sprites[1]
	var v_dest := gview.multi_ghost_sprites[2]

	check(v_basic.basic_artwork.visible, "Multi-ghost BASIC view uses animated basic_artwork")
	check(v_pusher.pusher_artwork.visible, "Multi-ghost PUSHER view uses animated pusher_artwork")
	check(v_dest.destroyer_artwork.visible, "Multi-ghost DESTROYER view uses animated destroyer_artwork")

	# Test rotation maintains animated views
	gview.rotate_multi_ghost_cw()
	check(v_pusher.block_data.direction == BlockData.Direction.RIGHT, "Pusher rotated CW to RIGHT")
	check(v_pusher.pusher_artwork.visible, "Pusher artwork remains visible after rotation")

	# Test cancel clears sprites
	gview.cancel_multi_ghost()
	check(not gview.is_multi_ghost_active(), "Multi-ghost inactive after cancel")
	check(gview.multi_ghost_sprites.is_empty(), "Multi-ghost sprites cleared on cancel")

	gview.queue_free()

func test_campaign_chapters_and_nodes() -> void:
	print("\n--- 10. Testing Campaign Chapters & New Levels ---")
	check(Campaign.CHAPTERS.size() == 4, "Campaign has 4 chapters (0..3)")
	check(Campaign.CHAPTERS[0][0] == "枪", "Chapter 0 name is '枪'")
	check(Campaign.CHAPTERS[1][0] == "获取", "Chapter 1 name is '获取'")
	check(Campaign.CHAPTERS[2][0] == "车", "Chapter 2 name is '车'")
	check(Campaign.CHAPTERS[3][0] == "计数器", "Chapter 3 name is '计数器'")

	# Check Chapter 0 (枪)
	check(Campaign.NODES.has("custom_level_80400"), "Node custom_level_80400 (枪-1) exists")
	check(Campaign.NODES["custom_level_80400"][0] == 0 and Campaign.NODES["custom_level_80400"][1] == "枪-1", "枪-1 configuration matches")
	check(Campaign.NODES["custom_level_80400"][7] == "custom_level_81906", "枪-1 leads to 枪-2")

	check(Campaign.NODES.has("custom_level_81906"), "Node custom_level_81906 (枪-2) exists")
	check(Campaign.NODES["custom_level_81906"][0] == 0 and Campaign.NODES["custom_level_81906"][1] == "枪-2", "枪-2 configuration matches")
	check(Campaign.NODES["custom_level_81906"][7] == "custom_level_33459", "枪-2 leads to 枪-3")

	check(Campaign.NODES.has("custom_level_33459"), "Node custom_level_33459 (枪-3) exists")
	check(Campaign.NODES["custom_level_33459"][0] == 0 and Campaign.NODES["custom_level_33459"][1] == "枪-3", "枪-3 configuration matches")
	check(Campaign.NODES["custom_level_33459"][7] == "custom_level_78552", "枪-3 connects to Chapter 1 (获取-0)")

	# Check Chapter 1 (获取)
	check(Campaign.NODES.has("custom_level_78552"), "Node custom_level_78552 (获取-0) exists")
	check(Campaign.NODES["custom_level_78552"][0] == 1 and Campaign.NODES["custom_level_78552"][1] == "获取-0", "获取-0 configuration matches")
	check(Campaign.NODES["custom_level_78552"][7] == "custom_level_78513", "获取-0 leads to 获取-1")

	check(Campaign.NODES.has("custom_level_78513"), "Node custom_level_78513 (获取-1) exists")
	check(Campaign.NODES["custom_level_78513"][0] == 1 and Campaign.NODES["custom_level_78513"][1] == "获取-1", "获取-1 configuration matches")
	check(Campaign.NODES["custom_level_78513"][7] == "custom_level_76724", "获取-1 leads to 获取-2")

	check(Campaign.NODES.has("custom_level_76724"), "Node custom_level_76724 (获取-2) exists")
	check(Campaign.NODES["custom_level_76724"][0] == 1 and Campaign.NODES["custom_level_76724"][1] == "获取-2", "获取-2 configuration matches")
	check(Campaign.NODES["custom_level_76724"][7] == "custom_level_25312", "获取-2 leads to 获取-3")

	check(Campaign.NODES.has("custom_level_25312"), "Node custom_level_25312 (获取-3) exists")
	check(Campaign.NODES["custom_level_25312"][0] == 1 and Campaign.NODES["custom_level_25312"][1] == "获取-3", "获取-3 configuration matches")
	check(Campaign.NODES["custom_level_25312"][7] == "custom_level_27833", "获取-3 connects to Chapter 2 (车-0)")

	# Check Chapter 2 (车)
	check(Campaign.NODES.has("custom_level_27833"), "Node custom_level_27833 (车-0) exists")
	check(Campaign.NODES["custom_level_27833"][0] == 2 and Campaign.NODES["custom_level_27833"][1] == "车-0", "车-0 configuration matches")
	check(Campaign.NODES["custom_level_27833"][7] == "custom_level_21314", "车-0 leads to 车-1")

	check(Campaign.NODES.has("custom_level_21314"), "Node custom_level_21314 (车-1) exists")
	check(Campaign.NODES["custom_level_21314"][0] == 2 and Campaign.NODES["custom_level_21314"][1] == "车-1", "车-1 configuration matches")
	check(Campaign.NODES["custom_level_21314"][7] == "custom_level_28302", "车-1 leads to 车-2")

	check(Campaign.NODES.has("custom_level_28302"), "Node custom_level_28302 (车-2) exists")
	check(Campaign.NODES["custom_level_28302"][0] == 2 and Campaign.NODES["custom_level_28302"][1] == "车-2", "车-2 configuration matches")
	check(Campaign.NODES["custom_level_28302"][7] == "custom_level_49361", "车-2 leads to 车-3")

	check(Campaign.NODES.has("custom_level_49361"), "Node custom_level_49361 (车-3) exists")
	check(Campaign.NODES["custom_level_49361"][0] == 2 and Campaign.NODES["custom_level_49361"][1] == "车-3", "车-3 configuration matches")
	check(Campaign.NODES["custom_level_49361"][7] == "custom_level_35377", "车-3 connects to Chapter 3 (计数器-1)")

	# Check Chapter 3 (计数器)
	check(Campaign.NODES.has("custom_level_35377"), "Node custom_level_35377 (计数器-1) exists")
	check(Campaign.NODES["custom_level_35377"][0] == 3 and Campaign.NODES["custom_level_35377"][1] == "计数器-1", "计数器-1 configuration matches")
	check(Campaign.NODES["custom_level_35377"][7] == "custom_level_33847", "计数器-1 leads to 计数器-2")

	check(Campaign.NODES.has("custom_level_33847"), "Node custom_level_33847 (计数器-2) exists")
	check(Campaign.NODES["custom_level_33847"][0] == 3 and Campaign.NODES["custom_level_33847"][1] == "计数器-2", "计数器-2 configuration matches")
	check(Campaign.NODES["custom_level_33847"][7] == "custom_level_80850", "计数器-2 leads to 计数器-3")

	check(Campaign.NODES.has("custom_level_80850"), "Node custom_level_80850 (计数器-3) exists")
	check(Campaign.NODES["custom_level_80850"][0] == 3 and Campaign.NODES["custom_level_80850"][1] == "计数器-3", "计数器-3 configuration matches")
	check(Campaign.NODES["custom_level_80850"][7] == "", "计数器-3 has no next level")

	# Verify level json files on disk
	var all_levels: Array[LevelData] = SaveManager.get_all_levels()
	var level_ids: Array[String] = []
	for lvl in all_levels:
		level_ids.append(lvl.level_id)

	var req_levels := [
		"custom_level_80400",
		"custom_level_81906",
		"custom_level_33459",
		"custom_level_35377",
		"custom_level_33847",
		"custom_level_80850",
		"custom_level_78552",
		"custom_level_78513",
		"custom_level_76724",
		"custom_level_25312",
		"custom_level_27833",
		"custom_level_21314",
		"custom_level_28302",
		"custom_level_49361"
	]
	for lid in req_levels:
		check(level_ids.has(lid), "Level %s successfully loaded from disk" % lid)

func test_speed_slider_and_log_scale() -> void:
	print("\n--- 11. Testing Speed Slider in Editor & Player (Logarithmic 0.2x-20x) ---")
	# 1. Test LevelEditor speed slider
	var editor: LevelEditor = load("res://scenes/ui/LevelEditor.tscn").instantiate()
	root.add_child(editor)
	editor._ready()
	
	check(editor.speed_slider != null, "LevelEditor has speed_slider instance")
	check(editor.speed_label != null, "LevelEditor has speed_label instance")
	check(absf(editor.speed_slider.min_value - 0.2) < 0.001, "Editor slider min_value is 0.2")
	check(absf(editor.speed_slider.max_value - 20.0) < 0.001, "Editor slider max_value is 20.0 (up to 20x)")
	check(editor.speed_slider.exp_edit == true, "Editor slider exp_edit is enabled (logarithmic scale)")
	check(absf(editor.sim_speed_multiplier - 1.0) < 0.001, "Default sim_speed_multiplier is 1.0")
	check(editor.speed_label.text == "1.0x", "Default speed_label is '1.0x'")

	# Change slider value in editor
	editor.speed_slider.value = 5.0
	editor.speed_slider.value_changed.emit(5.0)
	check(absf(editor.sim_speed_multiplier - 5.0) < 0.05, "Editor sim_speed_multiplier updated to ~5.0x")
	check(editor.speed_label.text.contains("5."), "Editor speed_label reflects ~5.0x")

	editor.speed_slider.value = 20.0
	editor.speed_slider.value_changed.emit(20.0)
	check(absf(editor.sim_speed_multiplier - 20.0) < 0.05, "Editor sim_speed_multiplier set to 20.0x")
	check(editor.speed_label.text == "20.0x", "Editor speed_label reflects '20.0x'")

	editor.queue_free()

	# 2. Test LevelPlayer speed slider
	var player: LevelPlayer = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
	root.add_child(player)
	player._ready()

	check(player.speed_slider != null, "LevelPlayer has speed_slider instance")
	check(player.speed_label != null, "LevelPlayer has speed_label instance")
	check(absf(player.speed_slider.min_value - 0.2) < 0.001, "Player slider min_value is 0.2")
	check(absf(player.speed_slider.max_value - 20.0) < 0.001, "Player slider max_value is 20.0 (up to 20x)")
	check(player.speed_slider.exp_edit == true, "Player slider exp_edit is enabled (logarithmic scale)")
	check(absf(player.sim_speed_multiplier - 1.0) < 0.001, "Player default sim_speed_multiplier is 1.0")
	check(player.speed_label.text == "1.0x", "Player default speed_label is '1.0x'")

	# Change slider value in player
	player.speed_slider.value = 15.0
	player.speed_slider.value_changed.emit(15.0)
	check(absf(player.sim_speed_multiplier - 15.0) < 0.05, "Player sim_speed_multiplier updated to ~15.0x")
	check(player.speed_label.text.contains("15."), "Player speed_label reflects ~15.0x")

	# Test log scale distribution
	player.speed_slider.value = 1.0
	check(player.speed_slider.ratio > 0.3 and player.speed_slider.ratio < 0.4, "1.0x speed is nicely positioned at ~35%% of slider on log scale")

	player.queue_free()


