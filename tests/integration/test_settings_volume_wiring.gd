## Integration test — Settings volume preferences → AudioManager bus volume wiring.
## Verifies: Settings.set_preference(volume_key, value) → preference_changed signal
## → AudioServer bus volume reflects the new value.
extends GutTest

const TEST_PATH: String = "user://settings_volume_wiring_test.cfg"
const DEFAULT_MASTER_VOLUME: float = 1.0
const DB_TOLERANCE: float = 0.01

var _settings: Node
var _audio_mgr: Node


func before_each() -> void:
	_audio_mgr = Node.new()
	_audio_mgr.set_script(preload("res://game/autoload/audio_manager.gd"))
	add_child_autofree(_audio_mgr)

	_settings = Node.new()
	_settings.set_script(preload("res://game/autoload/settings.gd"))
	_settings.settings_path = TEST_PATH
	add_child_autofree(_settings)

	_audio_mgr.initialize()


func after_each() -> void:
	for bus_name: String in ["Master", "Music", "SFX", "Ambient"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, 0.0)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


# ── Boot initialization ───────────────────────────────────────────────────────


func test_boot_persisted_volumes_applied_to_buses() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if master_idx < 0 or music_idx < 0 or sfx_idx < 0:
		pending("Required audio buses not available in test runner")
		return

	var boot_path: String = "user://settings_volume_wiring_boot_test.cfg"
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", 0.5)
	config.set_value("audio", "music_volume", 0.3)
	config.set_value("audio", "sfx_volume", 0.8)
	config.save(boot_path)

	var settings: Node = Node.new()
	settings.set_script(preload("res://game/autoload/settings.gd"))
	settings.settings_path = boot_path
	add_child_autofree(settings)

	assert_almost_eq(
		AudioServer.get_bus_volume_db(master_idx),
		linear_to_db(0.5),
		DB_TOLERANCE,
		"Master bus volume_db must match linear_to_db(0.5) after Settings._ready() with persisted master_volume=0.5"
	)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(music_idx),
		linear_to_db(0.3),
		DB_TOLERANCE,
		"Music bus volume_db must match linear_to_db(0.3) after Settings._ready() with persisted music_volume=0.3"
	)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(sfx_idx),
		linear_to_db(0.8),
		DB_TOLERANCE,
		"SFX bus volume_db must match linear_to_db(0.8) after Settings._ready() with persisted sfx_volume=0.8"
	)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(boot_path))


func test_boot_missing_volume_keys_applies_default_master_volume() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		pending("Master bus not available in test runner")
		return

	var boot_path: String = "user://settings_volume_wiring_nomatch_test.cfg"
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", false)
	config.save(boot_path)

	var settings: Node = Node.new()
	settings.set_script(preload("res://game/autoload/settings.gd"))
	settings.settings_path = boot_path
	add_child_autofree(settings)

	assert_almost_eq(
		AudioServer.get_bus_volume_db(master_idx),
		0.0,
		DB_TOLERANCE,
		"Master bus should be at 0 dB (DEFAULT_MASTER_VOLUME=1.0) when no volume keys are in the config"
	)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(boot_path))


# ── Runtime update per key ────────────────────────────────────────────────────


func test_runtime_master_volume_zero_silences_bus() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		pending("Master bus not available in test runner")
		return

	_settings.set_preference(&"master_volume", 0.0)

	var volume_db: float = AudioServer.get_bus_volume_db(master_idx)
	assert_true(
		volume_db < -60.0,
		"Master bus volume_db must be below -60 dB (silent) when master_volume is set to 0.0"
	)


func test_runtime_master_volume_full_sets_zero_db() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		pending("Master bus not available in test runner")
		return

	_settings.set_preference(&"master_volume", 0.5)
	_settings.set_preference(&"master_volume", 1.0)

	assert_almost_eq(
		AudioServer.get_bus_volume_db(master_idx),
		0.0,
		DB_TOLERANCE,
		"Master bus volume_db should be 0.0 dB when master_volume is set to 1.0"
	)


func test_runtime_music_volume_half_matches_linear_to_db() -> void:
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx < 0:
		pending("Music bus not available in test runner")
		return

	_settings.set_preference(&"music_volume", 0.5)

	assert_almost_eq(
		AudioServer.get_bus_volume_db(music_idx),
		linear_to_db(0.5),
		DB_TOLERANCE,
		"Music bus volume_db should be linear_to_db(0.5) ≈ -6.0 dB when music_volume is set to 0.5"
	)


func test_runtime_sfx_volume_quarter_matches_linear_to_db() -> void:
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		pending("SFX bus not available in test runner")
		return

	_settings.set_preference(&"sfx_volume", 0.25)

	assert_almost_eq(
		AudioServer.get_bus_volume_db(sfx_idx),
		linear_to_db(0.25),
		DB_TOLERANCE,
		"SFX bus volume_db should match linear_to_db(0.25) when sfx_volume is set to 0.25"
	)
