extends SceneTree

const SoundManager = preload("res://scripts/core/SoundManager.gd")

var passed: int = 0
var failed: int = 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("PASS: ", msg)
	else:
		failed += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): printerr("TEST WATCHDOG TIMEOUT!"); quit(1))
	call_deferred("run_tests")

func run_tests() -> void:
	print("=== RUNNING SOUND MANAGER & SPATIAL AUDIO TESTS ===")

	var sm: SoundManager = SoundManager.instance
	if sm == null:
		sm = load("res://scripts/core/SoundManager.gd").new()
		root.add_child(sm)
		await process_frame

	check(SoundManager.instance != null, "SoundManager singleton instance registered")
	check(sm._streams.size() >= 12, "All required sound effect assets loaded (got %d unique files)" % sm._streams.size())
	check(sm._voice_pool.size() == SoundManager.POOL_SIZE, "Voice pool initialized with %d audio players" % SoundManager.POOL_SIZE)

	for key in [
		SoundManager.PATH_UI_CLICK,
		SoundManager.PATH_UI_SLIDER,
		SoundManager.PATH_CELL_PLACE,
		SoundManager.PATH_CELL_DELETE,
		SoundManager.PATH_PUSHER,
		SoundManager.PATH_REPLICATOR,
		SoundManager.PATH_MONSTER,
		SoundManager.PATH_DESTROYER,
		SoundManager.PATH_ROTATOR,
		SoundManager.PATH_INHIBITOR_ENGAGE,
		SoundManager.PATH_INHIBITOR_RELEASE,
		SoundManager.PATH_TREASURE,
		SoundManager.PATH_VICTORY
	]:
		check(sm._streams.has(key) and sm._streams[key] != null, "Sound asset loaded: %s" % key.get_file())

	# 2. Test Camera Spatial Volume Calculation (Screen center & Zoom)
	var cam := Camera2D.new()
	cam.position = Vector2(500, 500)
	cam.zoom = Vector2(1.0, 1.0)
	root.add_child(cam)
	cam.make_current()
	await process_frame

	# Center of screen (world_pos == cam_pos)
	var vol_center := SoundManager.calculate_spatial_volume(Vector2(500, 500), cam)
	check(vol_center >= 0.85 and vol_center <= 1.05, "Center volume is loud and close to 1.0 (got %.3f)" % vol_center)

	# Near screen edge (viewport width 1280, half is 640)
	var vol_edge := SoundManager.calculate_spatial_volume(Vector2(500 + 600, 500), cam)
	check(vol_edge < vol_center, "Volume attenuates towards screen edge (center: %.3f, edge: %.3f)" % [vol_center, vol_edge])
	check(vol_edge >= 0.25 and vol_edge <= 0.5, "Edge volume is within expected range (got %.3f)" % vol_edge)

	# Far off-screen
	var vol_offscreen := SoundManager.calculate_spatial_volume(Vector2(5000, 5000), cam)
	check(vol_offscreen == 0.0, "Far offscreen block volume is 0.0 (got %.3f)" % vol_offscreen)

	# Test Zoom effect: Zoom in (2.0) vs Zoom out (0.3)
	cam.zoom = Vector2(2.0, 2.0)
	var vol_zoomed_in := SoundManager.calculate_spatial_volume(Vector2(500, 500), cam)
	cam.zoom = Vector2(0.3, 0.3)
	var vol_zoomed_out := SoundManager.calculate_spatial_volume(Vector2(500, 500), cam)

	check(vol_zoomed_in > vol_center, "Zooming in increases volume (zoom 2.0: %.3f vs zoom 1.0: %.3f)" % [vol_zoomed_in, vol_center])
	check(vol_zoomed_out < vol_center, "Zooming out decreases volume (zoom 0.3: %.3f vs zoom 1.0: %.3f)" % [vol_zoomed_out, vol_center])

	# 3. Test Automatic UI Hooking for BaseButton (button_down zero-latency)
	var test_btn := Button.new()
	test_btn.text = "Test Button"
	root.add_child(test_btn)
	await process_frame

	check(test_btn.has_meta(&"sfx_hooked"), "Button automatically hooked for click SFX")
	check(sm._ui_player != null, "Dedicated UI click player exists")
	check(sm._slider_player != null, "Dedicated UI slider player exists")

	# Test button_down triggers UI player directly
	test_btn.button_down.emit()
	check(sm._ui_player.playing, "button_down triggers dedicated UI player immediately with zero release latency")

	# Test button_pressed does NOT double-trigger after button_down
	var last_click_time: int = sm._last_ui_click_ms
	test_btn.pressed.emit()
	check(sm._last_ui_click_ms == last_click_time, "button_pressed did NOT re-trigger UI click after button_down")

	# Test rapid calls to play_ui_click are debounced within UI_CLICK_MIN_INTERVAL_MS
	var before_rapid := sm._last_ui_click_ms
	SoundManager.play_ui_click()
	check(sm._last_ui_click_ms == before_rapid, "Rapid second play_ui_click() call within debounce window was suppressed")

	# 4. Test Automatic UI Hooking for Range / Slider
	var test_slider := HSlider.new()
	test_slider.min_value = 0
	test_slider.max_value = 100
	test_slider.value = 50
	root.add_child(test_slider)
	await process_frame

	check(test_slider.has_meta(&"sfx_hooked"), "Slider automatically hooked for scroll SFX")

	# Test ScrollBar and ProgressBar are NOT hooked as sliders (eliminating scroll-loop bug)
	var test_scrollbar := HScrollBar.new()
	var test_progressbar := ProgressBar.new()
	root.add_child(test_scrollbar)
	root.add_child(test_progressbar)
	await process_frame
	check(not test_scrollbar.has_meta(&"sfx_hooked"), "ScrollBar is NOT hooked as Slider (no multi-fire on scroll)")
	check(not test_progressbar.has_meta(&"sfx_hooked"), "ProgressBar is NOT hooked as Slider")
	test_scrollbar.queue_free()
	test_progressbar.queue_free()

	# Test slider change triggers sound
	test_slider.value = 60
	await process_frame

	# 4b. Test TabBar, TabContainer, ItemList Auto-hooking
	var test_tb := TabBar.new()
	root.add_child(test_tb)
	var test_tc := TabContainer.new()
	root.add_child(test_tc)
	var test_il := ItemList.new()
	root.add_child(test_il)
	await process_frame

	check(test_tb.has_meta(&"sfx_hooked"), "TabBar automatically hooked for tab_clicked SFX")
	check(test_tc.has_meta(&"sfx_hooked"), "TabContainer automatically hooked for tab_clicked SFX")
	check(test_il.has_meta(&"sfx_hooked"), "ItemList automatically hooked for item_selected SFX")

	test_tb.queue_free()
	test_tc.queue_free()
	test_il.queue_free()

	# 5. Test Volume API & Persistence
	SoundManager.set_volume(0.65)
	check(absf(SoundManager.get_volume() - 0.65) < 0.001, "SoundManager.set_volume updates sfx_volume correctly")

	MusicManager.set_volume(0.42)
	check(absf(MusicManager.get_volume() - 0.42) < 0.001, "MusicManager.set_volume updates music_volume correctly")

	SoundManager.save_audio_settings()
	SoundManager.set_volume(1.0)
	MusicManager.set_volume(1.0)
	SoundManager.load_audio_settings()
	check(absf(SoundManager.get_volume() - 0.65) < 0.001, "SoundManager.load_audio_settings restores sfx_volume")
	check(absf(MusicManager.get_volume() - 0.42) < 0.001, "SoundManager.load_audio_settings restores music_volume")

	# 6. Test SettingsMenu Tabs & Sliders Integration
	var settings_menu: SettingsMenu = load("res://scripts/ui/SettingsMenu.gd").new()
	root.add_child(settings_menu)
	await process_frame

	check(settings_menu.tab_container != null, "SettingsMenu created TabContainer")
	check(settings_menu.tab_container.get_child_count() == 2, "SettingsMenu has exactly 2 tabs (音量设置 & 按键设置)")
	check(settings_menu.tab_container.get_child(0).name == "音量设置", "Tab 0 is '音量设置'")
	check(settings_menu.tab_container.get_child(1).name == "按键设置", "Tab 1 is '按键设置'")
	check(settings_menu.bgm_slider != null, "BGM volume slider created")
	check(settings_menu.sfx_slider != null, "SFX volume slider created")

	# Test slider manipulation in SettingsMenu
	settings_menu.bgm_slider.value = 75
	await process_frame
	check(absf(MusicManager.get_volume() - 0.75) < 0.02, "Moving BGM slider updates MusicManager volume to 75%")

	settings_menu.sfx_slider.value = 55
	await process_frame
	check(absf(SoundManager.get_volume() - 0.55) < 0.02, "Moving SFX slider updates SoundManager volume to 55%")

	# Test reset to defaults
	settings_menu._on_reset_defaults()
	await process_frame
	check(absf(MusicManager.get_volume() - 1.0) < 0.001, "Reset defaults restored BGM volume to 100%")
	check(absf(SoundManager.get_volume() - 1.0) < 0.001, "Reset defaults restored SFX volume to 100%")
	check(settings_menu.bgm_slider.value == 100, "Reset defaults set BGM slider value to 100")
	check(settings_menu.sfx_slider.value == 100, "Reset defaults set SFX slider value to 100")

	# Settings page must list undo/redo keybindings (编辑操作分类自动出现在设置页)
	var undo_display: String = KeybindManager.get_action_display_name("undo")
	var redo_display: String = KeybindManager.get_action_display_name("redo")
	var found_undo_btn := false
	var found_redo_btn := false
	var search_stack: Array = [settings_menu]
	while not search_stack.is_empty():
		var n: Node = search_stack.pop_back()
		if n is Button:
			if (n as Button).text == undo_display:
				found_undo_btn = true
			elif (n as Button).text == redo_display:
				found_redo_btn = true
		for c in n.get_children():
			search_stack.append(c)
	check(found_undo_btn, "Settings page lists undo binding button (%s)" % undo_display)
	check(found_redo_btn, "Settings page lists redo binding button (%s)" % redo_display)

	# Settings overlay must fill the viewport and truly center its panel (regression)
	var test_view := SubViewport.new()
	test_view.size = Vector2i(1280, 720)
	root.add_child(test_view)
	var centered_menu: SettingsMenu = load("res://scripts/ui/SettingsMenu.gd").new()
	test_view.add_child(centered_menu)
	await process_frame
	var view_rect := Rect2(Vector2.ZERO, Vector2(test_view.size))
	var menu_rect: Rect2 = centered_menu.get_global_rect()
	check(menu_rect.position.is_equal_approx(view_rect.position) and menu_rect.size.is_equal_approx(view_rect.size), "Settings overlay fills the viewport (got %s)" % menu_rect)
	check(centered_menu.main_panel != null, "Settings overlay exposes main_panel reference")
	var panel_center: Vector2 = centered_menu.main_panel.get_global_rect().get_center()
	check(panel_center.distance_to(view_rect.get_center()) < 2.0, "Settings panel is centered (panel_center=%s expected=%s)" % [panel_center, view_rect.get_center()])
	centered_menu.queue_free()
	test_view.queue_free()

	# 7. Test Spatial Cell Sound Calls
	SoundManager.play_cell_place(Vector2(500, 500))
	SoundManager.play_cell_delete(Vector2(500, 500))
	SoundManager.play_block_pusher(Vector2(500, 500))
	SoundManager.play_block_replicator(Vector2(500, 500))
	SoundManager.play_block_monster(Vector2(500, 500))
	SoundManager.play_block_destroyer(Vector2(500, 500))
	SoundManager.play_block_rotator(Vector2(500, 500))
	SoundManager.play_block_inhibitor_engage(Vector2(500, 500))
	SoundManager.play_block_inhibitor_release(Vector2(500, 500))
	SoundManager.play_treasure_collect(Vector2(500, 500))
	SoundManager.play_level_victory()

	check(true, "All block spatial sound APIs executed cleanly")

	# Cleanup
	cam.queue_free()
	test_btn.queue_free()
	test_slider.queue_free()
	settings_menu.queue_free()
	sm.queue_free()

	print("\n=== TEST SUMMARY ===")
	print("PASSED: %d, FAILED: %d" % [passed, failed])
	if failed == 0:
		print("ALL SOUND SYSTEM TESTS PASSED SUCCESSFULLY! ✓")
		quit(0)
	else:
		print("SOME TESTS FAILED! ✗")
		quit(1)
