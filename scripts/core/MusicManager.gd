class_name MusicManager
extends Node

## Background Music Manager with seamless head-tail loop crossfade
## and smooth track-to-track crossfade.

enum Mode {
	AMBIENT, # The_Eccentric_Carpenter.mp3 (Menu, LevelSelect, LevelEditor build, LevelPlayer build)
	RUNNING  # Saturday_Morning_Architect.mp3 (Machine running / simulation, including paused)
}

static var instance: MusicManager

const AMBIENT_STREAM_PATH := "res://assets/music/The_Eccentric_Carpenter.mp3"
const RUNNING_STREAM_PATH := "res://assets/music/Saturday_Morning_Architect.mp3"

const LOOP_CROSSFADE_DURATION := 4.0 # Seconds for head-tail loop crossfade
const TRACK_CROSSFADE_DURATION := 1.2 # Seconds for transitioning between tracks

class LoopedTrack:
	var name: String
	var stream: AudioStream
	var stream_length: float = 0.0
	var player_a: AudioStreamPlayer
	var player_b: AudioStreamPlayer
	var active_player: AudioStreamPlayer
	var fade_player: AudioStreamPlayer
	var is_loop_crossfading: bool = false
	var loop_fade_progress: float = 0.0
	var virtual_playback_pos: float = 0.0
	var last_hw_pos: float = -1.0

	var target_volume: float = 0.0
	var current_volume: float = 0.0
	var is_running_track: bool = false
	var master_volume: float = 1.0

	func _init(p_parent: Node, p_name: String, p_stream_path: String, p_is_running: bool) -> void:
		name = p_name
		is_running_track = p_is_running
		stream = load(p_stream_path)
		if stream != null:
			stream_length = stream.get_length()

		player_a = AudioStreamPlayer.new()
		player_a.name = p_name + "_A"
		player_a.stream = stream
		player_a.bus = "Master"
		p_parent.add_child(player_a)

		player_b = AudioStreamPlayer.new()
		player_b.name = p_name + "_B"
		player_b.stream = stream
		player_b.bus = "Master"
		p_parent.add_child(player_b)

		active_player = player_a
		fade_player = player_b

		player_a.finished.connect(_on_player_finished.bind(player_a))
		player_b.finished.connect(_on_player_finished.bind(player_b))

		_set_player_volume(player_a, 0.0)
		_set_player_volume(player_b, 0.0)

	func _on_player_finished(player: AudioStreamPlayer) -> void:
		if is_loop_crossfading and player == active_player:
			_complete_loop_crossfade()

	func start(from_beginning: bool = true) -> void:
		if from_beginning or not active_player.playing:
			active_player.stop()
			fade_player.stop()
			is_loop_crossfading = false
			loop_fade_progress = 0.0
			virtual_playback_pos = 0.0
			last_hw_pos = -1.0
			active_player.play(0.0)
		active_player.stream_paused = false
		if is_loop_crossfading:
			fade_player.stream_paused = false

	func pause() -> void:
		active_player.stream_paused = true
		fade_player.stream_paused = true

	func stop() -> void:
		active_player.stop()
		fade_player.stop()
		is_loop_crossfading = false
		loop_fade_progress = 0.0
		virtual_playback_pos = 0.0
		last_hw_pos = -1.0

	func is_playing() -> bool:
		return active_player.playing or fade_player.playing

	func update(delta: float) -> void:
		# 1. Update track-level volume crossfade
		if current_volume < target_volume:
			current_volume = minf(target_volume, current_volume + delta / TRACK_CROSSFADE_DURATION)
		elif current_volume > target_volume:
			current_volume = maxf(target_volume, current_volume - delta / TRACK_CROSSFADE_DURATION)
			if current_volume <= 0.0001 and target_volume == 0.0:
				if is_running_track:
					stop()
				else:
					pause()

		if not active_player.playing and not fade_player.playing:
			return

		# 2. Track playback position
		if active_player.playing and not active_player.stream_paused:
			var hw_pos := active_player.get_playback_position()
			if hw_pos > 0.0 and last_hw_pos >= 0.0 and hw_pos > last_hw_pos:
				virtual_playback_pos += (hw_pos - last_hw_pos)
				last_hw_pos = hw_pos
			else:
				if hw_pos > 0.0 and last_hw_pos < 0.0:
					last_hw_pos = hw_pos
				virtual_playback_pos += delta

		# 3. Check for head-tail loop crossfade trigger
		var trigger_time := stream_length - LOOP_CROSSFADE_DURATION
		if trigger_time > 0.0 and not is_loop_crossfading and virtual_playback_pos >= trigger_time:
			is_loop_crossfading = true
			loop_fade_progress = 0.0
			fade_player.play(0.0)

		# 4. Process loop crossfade progress
		var active_weight := 1.0
		var fade_weight := 0.0

		if is_loop_crossfading:
			loop_fade_progress += delta / LOOP_CROSSFADE_DURATION
			var p := clampf(loop_fade_progress, 0.0, 1.0)
			# Equal-power crossfade curves
			active_weight = cos(p * (PI * 0.5))
			fade_weight = sin(p * (PI * 0.5))

			if loop_fade_progress >= 1.0:
				_complete_loop_crossfade()
				active_weight = 1.0
				fade_weight = 0.0

		_set_player_volume(active_player, active_weight * current_volume * master_volume)
		_set_player_volume(fade_player, fade_weight * current_volume * master_volume)

	func _complete_loop_crossfade() -> void:
		active_player.stop()
		var temp := active_player
		active_player = fade_player
		fade_player = temp
		is_loop_crossfading = false
		loop_fade_progress = 0.0
		virtual_playback_pos = LOOP_CROSSFADE_DURATION
		last_hw_pos = -1.0

	func _set_player_volume(player: AudioStreamPlayer, gain: float) -> void:
		if gain <= 0.0001:
			player.volume_db = -80.0
		else:
			player.volume_db = linear_to_db(gain)

var ambient_track: LoopedTrack
var running_track: LoopedTrack
var current_mode: Mode = Mode.AMBIENT

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

	ambient_track = LoopedTrack.new(self, "Ambient", AMBIENT_STREAM_PATH, false)
	running_track = LoopedTrack.new(self, "Running", RUNNING_STREAM_PATH, true)

	# Start initial ambient track
	ambient_track.target_volume = 1.0
	ambient_track.current_volume = 1.0 # Immediate for game launch
	ambient_track.start(true)

	running_track.target_volume = 0.0
	running_track.current_volume = 0.0

func _process(delta: float) -> void:
	if ambient_track != null:
		ambient_track.update(delta)
	if running_track != null:
		running_track.update(delta)

func play_ambient_track() -> void:
	current_mode = Mode.AMBIENT
	if ambient_track != null:
		ambient_track.target_volume = 1.0
		if not ambient_track.is_playing() or ambient_track.active_player.stream_paused:
			ambient_track.start(false)
	if running_track != null:
		running_track.target_volume = 0.0

func play_running_track() -> void:
	current_mode = Mode.RUNNING
	if running_track != null:
		running_track.target_volume = 1.0
		if not running_track.is_playing():
			running_track.start(true)
	if ambient_track != null:
		ambient_track.target_volume = 0.0

# Static helpers for global access anywhere in GDScript
static func play_ambient() -> void:
	if instance != null:
		instance.play_ambient_track()

static func play_running() -> void:
	if instance != null:
		instance.play_running_track()

static func get_mode() -> Mode:
	if instance != null:
		return instance.current_mode
	return Mode.AMBIENT
