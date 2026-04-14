## Unit tests for StoreBleedAudio — spatial bleed player lifecycle, phase gating,
## and graceful handling of missing audio resources.
extends GutTest

const BleedAudioScript: GDScript = preload(
	"res://game/scripts/audio/store_bleed_audio.gd"
)


func _make_bleed_node() -> Node3D:
	var node: Node3D = Node3D.new()
	node.set_script(BleedAudioScript)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "AudioStreamPlayer3D"
	node.add_child(player)
	add_child_autofree(node)
	return node


# --- initial state ---

func test_player_not_playing_on_ready() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	assert_false(player.playing, "Player must not be playing immediately after _ready")


# --- _configure_player applies export vars ---

func test_configure_player_sets_music_bus() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	assert_eq(player.bus, "Music", "AudioStreamPlayer3D bus should be set to Music")


func test_configure_player_sets_inverse_square_attenuation() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	assert_eq(
		player.attenuation_model,
		AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE,
		"Attenuation model should be INVERSE_SQUARE_DISTANCE"
	)


func test_configure_player_sets_max_db_from_export() -> void:
	var node: Node3D = _make_bleed_node()
	node.max_db = 82.0
	node._configure_player()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	assert_eq(player.max_db, 82.0, "max_db should match the exported value")


func test_configure_player_sets_unit_size_from_export() -> void:
	var node: Node3D = _make_bleed_node()
	node.unit_size = 5.0
	node._configure_player()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	assert_eq(player.unit_size, 5.0, "unit_size should match the exported value")


# --- phase gating ---

func test_set_open_true_plays_when_stream_assigned() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	player.stream = stream
	node._set_open(true)
	assert_true(player.playing, "Player should start playing when opened with a valid stream")


func test_set_open_false_stops_playing_player() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	player.stream = stream
	node._set_open(true)
	node._set_open(false)
	assert_false(player.playing, "Player should stop when closed")


func test_set_open_no_stream_does_not_play() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	node._set_open(true)
	assert_false(player.playing, "Player must not play when no stream is assigned")


func test_set_open_true_twice_is_noop() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	player.stream = stream
	node._set_open(true)
	node._set_open(true)
	assert_true(player.playing, "Calling _set_open(true) twice should not break playback")


func test_on_day_phase_changed_pre_open_stops_audio() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	player.stream = stream
	node._set_open(true)
	node._on_day_phase_changed(0)  # PRE_OPEN_PHASE = 0
	assert_false(player.playing, "PRE_OPEN phase should stop bleed audio")


func test_on_day_phase_changed_non_pre_open_starts_audio() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	player.stream = stream
	node._on_day_phase_changed(1)  # MORNING_RAMP = 1
	assert_true(player.playing, "Non-PRE_OPEN phase should start bleed audio")


func test_on_day_ended_stops_audio() -> void:
	var node: Node3D = _make_bleed_node()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	player.stream = stream
	node._set_open(true)
	node._on_day_ended(1)
	assert_false(player.playing, "day_ended should stop bleed audio")


# --- missing resource guard ---

func test_load_stream_empty_path_does_not_crash() -> void:
	var node: Node3D = _make_bleed_node()
	node.music_path = ""
	node._load_stream()
	assert_true(true, "Empty music_path should be a no-op without crashing")


func test_load_stream_missing_path_does_not_crash() -> void:
	var node: Node3D = _make_bleed_node()
	node.music_path = "res://nonexistent_track.wav"
	node._load_stream()
	assert_true(true, "Missing music_path should emit push_warning and not crash")


func test_load_stream_missing_path_leaves_stream_null() -> void:
	var node: Node3D = _make_bleed_node()
	node.music_path = "res://nonexistent_track.wav"
	node._load_stream()
	var player: AudioStreamPlayer3D = node.get_node("AudioStreamPlayer3D")
	assert_null(player.stream, "Player stream should remain null when music_path is missing")
