extends SceneTree

var failures: Array[String] = []
var checks := 0
var output := OS.get_environment("BLOCKBOUND_TEST_OUTPUT")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print(message, ": ", ok)

func snap(name: String) -> void:
	if DisplayServer.get_name() == "headless" or output.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	await process_frame

func run() -> void:
	root.gui_embed_subwindows = true
	var menu: MainMenu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await snap("main_menu")
	check(menu.title_label.get_global_rect().position.x > 0, "Main menu title is inside viewport")
	menu.queue_free()
	await process_frame
	var player: LevelPlayer = load("res://scenes/ui/LevelPlayer.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.load_level_data(SaveManager.load_level("custom_level_relay"))
	player.base_tick_duration = 0.001
	await click(player.toolbar.type_buttons[2])
	var variant := player.toolbar.current_variant
	await click(player.toolbar.type_buttons[2])
	check(player.toolbar.current_variant == variant, "Repeated tool selection preserves appearance")
	check(player.toolbar.description_label.text.contains("推动"), "Selected tool explains its function")
	player._try_place_block(Vector2i(-11, -6))
	player.clear_button.pressed.emit()
	await process_frame
	check(player.clear_confirm.visible and player.world.has_block(Vector2i(-11,-6)), "Clear opens confirmation without deleting")
	await snap("clear_confirmation")
	player.clear_confirm.hide()
	check(player.world.has_block(Vector2i(-11,-6)), "Cancel preserves construction")
	player.clear_confirm.confirmed.emit()
	check(not player.world.has_block(Vector2i(-11,-6)), "Confirm clears player blocks")
	check(player.world.has_block(Vector2i(-11,-7)), "Clear preserves preset blocks")
	player.toolbar.select_type(2)
	player._try_place_block(Vector2i(-11,-6))
	player.selected_blocks.append(player.world.get_block(Vector2i(-11,-6)))
	player.step_single_tick()
	while player.is_animating_tick: await process_frame
	check(not player.toolbar.editing_enabled and player.toolbar.group_button.disabled, "Simulation locks all construction controls")
	var block := player.world.get_block(Vector2i(-11,-6))
	var direction := block.direction
	var rotate := InputEventKey.new()
	rotate.keycode = KEY_E
	rotate.pressed = true
	player._unhandled_input(rotate)
	check(block.direction == direction, "Keyboard cannot rotate paused simulation blocks")
	check(player.status_label.text.contains("重置"), "Pause explains how to resume editing")
	await snap("paused_state")
	player.reset_simulation()
	check(player.toolbar.editing_enabled and player.world.has_block(Vector2i(-11,-6)), "Reset restores editing and preserves build")
	player.camera.position = Vector2(9999, 9999)
	player.frame_board()
	check(player.camera.position.length() < 2000 and player.camera.zoom.x > 0, "Overview recovers a lost camera")
	player.show_help()
	await process_frame
	check(player.help_dialog.visible and not player.is_simulating, "Help opens with simulation paused")
	check(player._mouse_over_interface(), "Open modal suppresses board placement preview")
	await snap("help")
	player.help_dialog.hide()
	player.queue_free()
	await process_frame
	var manager: LevelManager = load("res://scenes/ui/LevelManager.tscn").instantiate()
	root.add_child(manager)
	await process_frame
	manager.delete_level_btn.pressed.emit()
	check(manager.delete_confirm.visible, "Deleting a level requires confirmation")
	manager.delete_confirm.hide()
	await snap("level_manager")
	manager.queue_free()
	await process_frame
	var editor: LevelEditor = load("res://scenes/ui/LevelEditor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.clear_level_btn.pressed.emit()
	check(editor.clear_confirm.visible, "Editor clear requires confirmation")
	editor.clear_confirm.hide()
	await snap("level_editor")
	check(editor.toolbar.type_buttons.size() == 11, "Editor retains every block type")
	check(editor.toolbar.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "Editor toolbar fits viewport")
	check(editor.toolbar.type_buttons[10].get_global_rect().end.x <= root.get_visible_rect().size.x, "All editor block buttons fit horizontally")
	editor.queue_free()
	await process_frame
	print("UX CHECKS: ", checks, "; FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
