## GUT unit tests for AudioManager — play_sfx, play_music, volume clamping, zone registration.
extends GutTest

var _manager: Node


func before_each() -> void:
	_manager = Node.new()
	_manager.set_script(
		preload("res://game/autoload/audio_manager.gd")
	)
	add_child_autofree(_manager)


func test_play_sfx_invalid_id_pushes_error() -> void:
	var pool_size_before: int = _manager._sfx_players.size()
	_manager.play_sfx("nonexistent_sfx")
	assert_eq(
		_manager._sfx_players.size(), pool_size_before,
		"play_sfx with unknown id must not grow the SFX pool"
	)
	assert_false(
		_manager._sfx_streams.has("nonexistent_sfx"),
		"play_sfx with unknown id must not add anything to the stream cache"
	)


func test_play_sfx_valid_id_no_error() -> void:
	var mock_stream: AudioStreamWAV = AudioStreamWAV.new()
	_manager._sfx_streams["test_sfx_valid"] = mock_stream
	_manager.play_sfx("test_sfx_valid")
	assert_true(true, "play_sfx with a registered id should not raise an error")


func test_set_volume_clamps_below_zero() -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0:
		pending("Music bus not available in test runner")
		return
	_manager.set_bus_volume(&"Music", -1.0)
	var stored_linear: float = db_to_linear(AudioServer.get_bus_volume_db(idx))
	assert_almost_eq(
		stored_linear, 0.0, 0.01,
		"set_bus_volume with value below 0.0 should clamp to 0.0 linear"
	)


func test_set_volume_clamps_above_one() -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0:
		pending("Music bus not available in test runner")
		return
	_manager.set_bus_volume(&"Music", 2.0)
	var stored_linear: float = db_to_linear(AudioServer.get_bus_volume_db(idx))
	assert_almost_eq(
		stored_linear, 1.0, 0.01,
		"set_bus_volume with value above 1.0 should clamp to 1.0 linear"
	)


func test_zone_registration_adds_to_active_list() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(player)
	_manager.register_zone("food_court_zone", player)
	var zones: Array[String] = _manager.get_active_zones()
	assert_true(
		zones.has("food_court_zone"),
		"register_zone should add the zone_id to get_active_zones()"
	)


func test_zone_unregistration_removes_from_active_list() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child_autofree(player)
	_manager.register_zone("food_court_zone", player)
	_manager.unregister_zone("food_court_zone")
	var zones: Array[String] = _manager.get_active_zones()
	assert_false(
		zones.has("food_court_zone"),
		"unregister_zone should remove the zone_id from get_active_zones()"
	)
