## Integration test: Settings persistence round-trip with AudioManager volume sync.
extends GutTest


const TEST_PATH: String = "user://settings_test.cfg"

var _settings: Node
var _audio_mgr: Node


func before_each() -> void:
	_settings = Node.new()
	_settings.set_script(
		preload("res://game/autoload/settings.gd")
	)
	_settings.settings_path = TEST_PATH
	add_child_autofree(_settings)

	_audio_mgr = Node.new()
	_audio_mgr.set_script(
		preload("res://game/autoload/audio_manager.gd")
	)
	add_child_autofree(_audio_mgr)


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(TEST_PATH)
		)


func test_music_volume_persists_across_session() -> void:
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx < 0:
		pending("Music bus not available in test runner")
		return

	_settings.set_music_volume(0.6)
	assert_almost_eq(
		_audio_mgr.get_music_volume(), 0.6, 0.01,
		"AudioManager should reflect Settings music volume immediately"
	)

	_settings.save_settings()
	_settings.music_volume = 1.0
	_settings.set_music_volume(1.0)

	_settings.load_settings()
	assert_almost_eq(
		_settings.music_volume, 0.6, 0.001,
		"Settings.music_volume should be 0.6 after reload"
	)
	assert_almost_eq(
		_audio_mgr.get_music_volume(), 0.6, 0.01,
		"AudioManager music volume should match after Settings reload"
	)


func test_sfx_and_music_persist_independently() -> void:
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var music_idx: int = AudioServer.get_bus_index("Music")
	if sfx_idx < 0 or music_idx < 0:
		pending("SFX or Music bus not available in test runner")
		return

	_settings.set_sfx_volume(0.3)
	_settings.set_music_volume(0.8)
	_settings.save_settings()

	_settings.sfx_volume = 1.0
	_settings.music_volume = 1.0
	_settings.set_sfx_volume(1.0)
	_settings.set_music_volume(1.0)

	_settings.load_settings()
	assert_almost_eq(
		_settings.sfx_volume, 0.3, 0.001,
		"sfx_volume should be 0.3 after reload"
	)
	assert_almost_eq(
		_settings.music_volume, 0.8, 0.001,
		"music_volume should be 0.8 after reload"
	)
	assert_almost_eq(
		_audio_mgr.get_sfx_volume(), 0.3, 0.01,
		"AudioManager SFX volume should match persisted value"
	)
	assert_almost_eq(
		_audio_mgr.get_music_volume(), 0.8, 0.01,
		"AudioManager music volume should match persisted value"
	)


func test_missing_settings_file_returns_defaults() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(TEST_PATH)
		)

	var fresh: Node = Node.new()
	fresh.set_script(
		preload("res://game/autoload/settings.gd")
	)
	fresh.settings_path = TEST_PATH
	add_child_autofree(fresh)

	assert_almost_eq(
		fresh.music_volume, 0.8, 0.001,
		"music_volume should be default 0.8 when file is missing"
	)
	assert_almost_eq(
		fresh.sfx_volume, 1.0, 0.001,
		"sfx_volume should be default 1.0 when file is missing"
	)
	assert_almost_eq(
		fresh.master_volume, 1.0, 0.001,
		"master_volume should be default 1.0 when file is missing"
	)
	assert_almost_eq(
		fresh.ambient_volume, 0.8, 0.001,
		"ambient_volume should be default 0.8 when file is missing"
	)
