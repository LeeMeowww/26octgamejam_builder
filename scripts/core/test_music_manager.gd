extends SceneTree

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
	call_deferred("run_tests")

func run_tests() -> void:
	print("=== RUNNING MUSIC MANAGER & CROSSFADE TESTS ===")

	# 1. Test instantiation and initial state
	var mm: Node = load("res://scripts/core/MusicManager.gd").new()
	root.add_child(mm)
	await process_frame

	check(mm.ambient_track != null, "Ambient track initialized")
	check(mm.running_track != null, "Running track initialized")
	check(mm.ambient_track.stream != null, "Ambient audio stream loaded")
	check(mm.running_track.stream != null, "Running audio stream loaded")
	check(mm.ambient_track.stream_length > 100.0, "Ambient stream length is valid (~118s)")
	check(mm.running_track.stream_length > 100.0, "Running stream length is valid (~115s)")

	check(mm.current_mode == 0, "Default mode is AMBIENT")
	check(mm.ambient_track.target_volume == 1.0, "Ambient target volume is 1.0")
	check(mm.running_track.target_volume == 0.0, "Running target volume is 0.0")

	# 2. Test switching to RUNNING
	mm.play_running_track()
	check(mm.current_mode == 1, "Mode switched to RUNNING")
	check(mm.running_track.target_volume == 1.0, "Running target volume is 1.0")
	check(mm.ambient_track.target_volume == 0.0, "Ambient target volume is 0.0")

	# Simulate 0.175 seconds (halfway through 0.35s track crossfade)
	mm._process(0.175)
	check(mm.running_track.current_volume > 0.35 and mm.running_track.current_volume < 0.65, "Running track volume crossfading in (approx 0.5)")
	check(mm.ambient_track.current_volume > 0.35 and mm.ambient_track.current_volume < 0.65, "Ambient track volume crossfading out (approx 0.5)")

	# Complete crossfade (another 0.25s)
	mm._process(0.25)
	check(mm.running_track.current_volume == 1.0, "Running track volume fully faded in (1.0)")
	check(mm.ambient_track.current_volume <= 0.001, "Ambient track volume fully faded out (0.0)")

	# 3. Test pausing simulation behavior
	# When paused during simulation, Saturday should KEEP playing (mode stays RUNNING)
	check(mm.current_mode == 1, "Pausing preserves RUNNING mode")
	check(mm.running_track.target_volume == 1.0, "Running track maintains 1.0 target during pause")

	# 4. Test switching back to AMBIENT (e.g. after R reset)
	mm.play_ambient_track()
	check(mm.current_mode == 0, "Reset restores AMBIENT mode")
	check(mm.ambient_track.target_volume == 1.0, "Ambient target volume is 1.0")
	check(mm.running_track.target_volume == 0.0, "Running target volume is 0.0")

	# Advance process by full transition duration (0.8s)
	mm._process(0.9)
	check(mm.ambient_track.current_volume == 1.0, "Ambient track fully faded in")
	check(mm.running_track.current_volume <= 0.001, "Running track fully faded out and stopped")

	# 5. Test Head-Tail Looping Crossfade Mechanics
	print("\n--- Testing Head-Tail Loop Crossfade ---")
	var track = mm.ambient_track
	track.start(true)
	track.current_volume = 1.0
	track.target_volume = 1.0

	var trig: float = track.stream_length - 4.0
	# Fast-forward virtual playback pos to just before loop crossfade trigger
	track.virtual_playback_pos = trig - 0.5
	track.update(0.1)
	check(not track.is_loop_crossfading, "Not yet crossfading before trigger time")

	# Advance into trigger zone
	track.update(0.5)
	check(track.is_loop_crossfading, "Loop crossfade started at trigger time (stream_length - 4.0s)")
	check(track.fade_player.playing, "Secondary player started playing from 0.0 for crossfade")

	# Check intermediate crossfade volume balance
	track.update(2.0)
	# At p = 0.5: active_weight = cos(PI/4) ≈ 0.707, fade_weight = sin(PI/4) ≈ 0.707
	check(track.loop_fade_progress >= 0.49 and track.loop_fade_progress <= 0.65, "Loop fade progress advanced to ~0.5")
	# Check both players have sound during crossfade
	check(track.active_player.volume_db > -10.0 and track.fade_player.volume_db > -10.0, "Both voices audible during head-tail crossfade")

	# Advance past completion of loop crossfade
	var prev_active: AudioStreamPlayer = track.active_player
	var prev_fade: AudioStreamPlayer = track.fade_player
	track.update(2.5)
	check(not track.is_loop_crossfading, "Loop crossfade ended after crossfade duration")
	check(track.active_player == prev_fade, "Secondary player promoted to active player")
	check(track.fade_player == prev_active, "Old active player demoted to secondary player")
	check(not track.fade_player.playing, "Old active player stopped")
	check(track.active_player.playing, "New active player continuing playback")

	mm.queue_free()
	await process_frame

	print("\n=== MUSIC MANAGER TEST RESULTS: %d passed, %d failed ===" % [passed, failed])
	quit(0 if failed == 0 else 1)
