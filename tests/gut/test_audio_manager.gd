## Tests AudioManager: BGM control, volume, zone registration, SFX.
extends GutTest


var _manager: Node


func before_each() -> void:
	_manager = Node.new()
	_manager.set_script(
		preload("res://game/autoload/audio_manager.gd")
	)
	add_child_autofree(_manager)


func test_play_bgm_sets_current_track() -> void:
	_manager.play_bgm("menu_music")
	assert_eq(
		_manager._current_track_name, "menu_music",
		"play_bgm should set _current_track_name"
	)


func test_play_bgm_same_track_is_noop() -> void:
	_manager.play_bgm("menu_music")
	var player_before: AudioStreamPlayer = _manager._active_music_player
	_manager.play_bgm("menu_music")
	assert_eq(
		_manager._active_music_player, player_before,
		"play_bgm with same track should not switch players"
	)


func test_stop_bgm_clears_track_name() -> void:
	_manager.play_bgm("menu_music")
	_manager.stop_bgm()
	assert_eq(
		_manager._current_track_name, "",
		"stop_bgm should clear _current_track_name"
	)


func test_stop_bgm_when_no_track_is_noop() -> void:
	_manager.stop_bgm()
	assert_eq(
		_manager._current_track_name, "",
		"stop_bgm with no track should remain empty"
	)


func test_set_music_volume_updates_bus() -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0:
		pending("Music bus not available in test runner")
		return
	_manager.set_music_volume(0.5)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	var expected_db: float = linear_to_db(0.5)
	assert_almost_eq(
		actual_db, expected_db, 0.01,
		"set_music_volume should set Music bus volume"
	)


func test_set_ambience_volume_updates_bus() -> void:
	var idx: int = AudioServer.get_bus_index("Ambience")
	if idx < 0:
		pending("Ambience bus not available in test runner")
		return
	_manager.set_ambience_volume(0.7)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	var expected_db: float = linear_to_db(0.7)
	assert_almost_eq(
		actual_db, expected_db, 0.01,
		"set_ambience_volume should set Ambience bus volume"
	)


func test_set_sfx_volume_updates_bus() -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0:
		pending("SFX bus not available in test runner")
		return
	_manager.set_sfx_volume(0.3)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	var expected_db: float = linear_to_db(0.3)
	assert_almost_eq(
		actual_db, expected_db, 0.01,
		"set_sfx_volume should set SFX bus volume"
	)


func test_set_volume_clamps_to_range() -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0:
		pending("Music bus not available in test runner")
		return
	_manager.set_music_volume(2.0)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(
		actual_db, 0.0, 0.01,
		"Volume above 1.0 should clamp to 1.0 (0 dB)"
	)


func test_register_zone_stores_player() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(player)
	_manager.register_zone("food_court", player)
	assert_true(
		_manager._zone_players.has("food_court"),
		"register_zone should store the player"
	)
	assert_eq(
		_manager._zone_players["food_court"], player,
		"register_zone should map zone_id to the player"
	)


func test_register_zone_rejects_empty_id() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(player)
	_manager.register_zone("", player)
	assert_eq(
		_manager._zone_players.size(), 0,
		"register_zone should reject empty zone_id"
	)


func test_register_zone_rejects_null_player() -> void:
	_manager.register_zone("food_court", null)
	assert_false(
		_manager._zone_players.has("food_court"),
		"register_zone should reject null player"
	)


func test_enter_zone_unregistered_no_crash() -> void:
	_manager.enter_zone("nonexistent")
	assert_true(true, "enter_zone with unknown zone should not crash")


func test_exit_zone_unregistered_no_crash() -> void:
	_manager.exit_zone("nonexistent")
	assert_true(true, "exit_zone with unknown zone should not crash")


func test_sfx_pool_size() -> void:
	assert_eq(
		_manager._sfx_players.size(), 8,
		"SFX pool should have 8 players"
	)


func test_sfx_players_use_sfx_bus() -> void:
	for player: AudioStreamPlayer in _manager._sfx_players:
		assert_eq(
			player.bus, "SFX",
			"All SFX players should use the SFX bus"
		)


func test_music_players_use_music_bus() -> void:
	assert_eq(
		_manager._music_player_a.bus, "Music",
		"Music player A should use Music bus"
	)
	assert_eq(
		_manager._music_player_b.bus, "Music",
		"Music player B should use Music bus"
	)


func test_ambient_players_use_ambient_bus() -> void:
	assert_eq(
		_manager._ambient_player_a.bus, "Ambience",
		"Ambient player A should use Ambience bus"
	)
	assert_eq(
		_manager._ambient_player_b.bus, "Ambience",
		"Ambient player B should use Ambience bus"
	)


func test_play_bgm_unknown_track_warns() -> void:
	_manager.play_bgm("nonexistent_track_xyz")
	assert_eq(
		_manager._current_track_name, "",
		"Unknown track should not change current track"
	)


func test_play_sfx_unknown_name_warns() -> void:
	_manager.play_sfx("nonexistent_sfx_xyz")
	assert_true(true, "Unknown SFX name should warn but not crash")


func test_play_sfx_stream_null_warns() -> void:
	_manager.play_sfx_stream(null)
	assert_true(true, "Null stream should warn but not crash")


func test_play_sfx_stream_api_assigns_stream() -> void:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	_manager.play_sfx(stream, -3.0)
	var found: bool = false
	for player: AudioStreamPlayer in _manager._sfx_players:
		if player.stream == stream and is_equal_approx(player.volume_db, -3.0):
			found = true
			break
	assert_true(
		found,
		"play_sfx(AudioStream, volume_db) should play one-shot streams on the SFX pool"
	)


func test_set_bus_volume_updates_bus() -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		pending("Master bus not available in test runner")
		return
	_manager.set_bus_volume(&"Master", 0.6)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	var expected_db: float = linear_to_db(0.6)
	assert_almost_eq(
		actual_db, expected_db, 0.01,
		"set_bus_volume should set the named bus volume"
	)


func test_set_bus_volume_clamps() -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		pending("Master bus not available in test runner")
		return
	_manager.set_bus_volume(&"Master", 5.0)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(
		actual_db, 0.0, 0.01,
		"set_bus_volume above 1.0 should clamp to 1.0 (0 dB)"
	)


func test_set_bus_volume_invalid_bus_no_crash() -> void:
	_manager.set_bus_volume(&"NonExistentBus", 0.5)
	assert_true(true, "Invalid bus name should not crash")


func test_crossfade_switches_active_player() -> void:
	_manager.play_bgm("menu_music")
	var first_player: AudioStreamPlayer = _manager._active_music_player

	if _manager._music_streams.has("day_summary_music"):
		_manager.play_bgm("day_summary_music")
		assert_ne(
			_manager._active_music_player, first_player,
			"Crossfade should switch to the other player"
		)
	else:
		pending("day_summary_music not loaded — skipping crossfade test")
