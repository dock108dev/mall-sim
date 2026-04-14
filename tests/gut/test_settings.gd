## Tests Settings autoload: load/save, volume setters, reset, defaults.
extends GutTest


var _settings: Node


func before_each() -> void:
	_settings = Node.new()
	_settings.set_script(
		preload("res://game/autoload/settings.gd")
	)
	add_child_autofree(_settings)


func test_default_master_volume() -> void:
	assert_almost_eq(
		_settings.master_volume, 1.0, 0.001,
		"Default master_volume should be 1.0"
	)


func test_default_music_volume() -> void:
	assert_almost_eq(
		_settings.music_volume, 0.8, 0.001,
		"Default music_volume should be 0.8"
	)


func test_default_sfx_volume() -> void:
	assert_almost_eq(
		_settings.sfx_volume, 1.0, 0.001,
		"Default sfx_volume should be 1.0"
	)


func test_default_fullscreen() -> void:
	assert_true(
		_settings.fullscreen,
		"Default fullscreen should be true"
	)


func test_default_vsync() -> void:
	assert_true(
		_settings.vsync,
		"Default vsync should be true"
	)


func test_default_ui_scale() -> void:
	assert_almost_eq(
		_settings.ui_scale, 1.0, 0.001,
		"Default ui_scale should be 1.0"
	)


func test_set_master_volume_clamps_high() -> void:
	_settings.set_master_volume(2.0)
	assert_almost_eq(
		_settings.master_volume, 1.0, 0.001,
		"set_master_volume should clamp values above 1.0"
	)


func test_set_master_volume_clamps_low() -> void:
	_settings.set_master_volume(-0.5)
	assert_almost_eq(
		_settings.master_volume, 0.0, 0.001,
		"set_master_volume should clamp values below 0.0"
	)


func test_set_master_volume_updates_bus() -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		pending("Master bus not available in test runner")
		return
	_settings.set_master_volume(0.5)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	var expected_db: float = linear_to_db(0.5)
	assert_almost_eq(
		actual_db, expected_db, 0.01,
		"set_master_volume should set Master bus volume"
	)


func test_set_music_volume_clamps() -> void:
	_settings.set_music_volume(1.5)
	assert_almost_eq(
		_settings.music_volume, 1.0, 0.001,
		"set_music_volume should clamp to 1.0"
	)


func test_set_sfx_volume_clamps() -> void:
	_settings.set_sfx_volume(-1.0)
	assert_almost_eq(
		_settings.sfx_volume, 0.0, 0.001,
		"set_sfx_volume should clamp to 0.0"
	)


func test_set_sfx_volume_updates_bus() -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0:
		pending("SFX bus not available in test runner")
		return
	_settings.set_sfx_volume(0.3)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	var expected_db: float = linear_to_db(0.3)
	assert_almost_eq(
		actual_db, expected_db, 0.01,
		"set_sfx_volume should set SFX bus volume"
	)


func test_reset_to_defaults_restores_values() -> void:
	_settings.master_volume = 0.3
	_settings.music_volume = 0.1
	_settings.sfx_volume = 0.2
	_settings.ui_scale = 1.5
	_settings.fullscreen = false
	_settings.vsync = false
	_settings.reset_to_defaults()
	assert_almost_eq(
		_settings.master_volume, 1.0, 0.001,
		"reset_to_defaults should restore master_volume"
	)
	assert_almost_eq(
		_settings.music_volume, 0.8, 0.001,
		"reset_to_defaults should restore music_volume"
	)
	assert_almost_eq(
		_settings.sfx_volume, 1.0, 0.001,
		"reset_to_defaults should restore sfx_volume"
	)
	assert_almost_eq(
		_settings.ui_scale, 1.0, 0.001,
		"reset_to_defaults should restore ui_scale"
	)
	assert_true(
		_settings.fullscreen,
		"reset_to_defaults should restore fullscreen"
	)
	assert_true(
		_settings.vsync,
		"reset_to_defaults should restore vsync"
	)


func test_reset_to_defaults_restores_locale() -> void:
	_settings.locale = "es"
	_settings.colorblind_mode = true
	_settings.font_size = Settings.FontSize.LARGE
	_settings.reset_to_defaults()
	assert_eq(
		_settings.locale, "en",
		"reset_to_defaults should restore locale"
	)
	assert_false(
		_settings.colorblind_mode,
		"reset_to_defaults should restore colorblind_mode"
	)
	assert_eq(
		_settings.font_size, Settings.FontSize.MEDIUM,
		"reset_to_defaults should restore font_size"
	)


func test_load_missing_file_uses_defaults() -> void:
	_settings.master_volume = 0.1
	_settings.load_settings()
	assert_almost_eq(
		_settings.master_volume, 1.0, 0.001,
		"load_settings with missing file should keep defaults"
	)


func test_save_and_load_roundtrip() -> void:
	_settings.master_volume = 0.42
	_settings.music_volume = 0.33
	_settings.sfx_volume = 0.77
	_settings.fullscreen = false
	_settings.vsync = false
	_settings.ui_scale = 1.25
	_settings.save_settings()

	var fresh: Node = Node.new()
	fresh.set_script(
		preload("res://game/autoload/settings.gd")
	)
	add_child_autofree(fresh)
	fresh.load_settings()

	assert_almost_eq(
		fresh.master_volume, 0.42, 0.001,
		"Roundtrip master_volume"
	)
	assert_almost_eq(
		fresh.music_volume, 0.33, 0.001,
		"Roundtrip music_volume"
	)
	assert_almost_eq(
		fresh.sfx_volume, 0.77, 0.001,
		"Roundtrip sfx_volume"
	)
	assert_eq(
		fresh.fullscreen, false,
		"Roundtrip fullscreen"
	)
	assert_eq(
		fresh.vsync, false,
		"Roundtrip vsync"
	)
	assert_almost_eq(
		fresh.ui_scale, 1.25, 0.001,
		"Roundtrip ui_scale"
	)


func test_set_preference_updates_master_volume() -> void:
	_settings.set_preference(&"master_volume", 0.5)
	assert_almost_eq(
		_settings.master_volume, 0.5, 0.001,
		"set_preference should update master_volume"
	)


func test_set_preference_updates_music_volume() -> void:
	_settings.set_preference(&"music_volume", 0.3)
	assert_almost_eq(
		_settings.music_volume, 0.3, 0.001,
		"set_preference should update music_volume"
	)


func test_set_preference_updates_sfx_volume() -> void:
	_settings.set_preference(&"sfx_volume", 0.7)
	assert_almost_eq(
		_settings.sfx_volume, 0.7, 0.001,
		"set_preference should update sfx_volume"
	)


func test_set_preference_clamps_volume() -> void:
	_settings.set_preference(&"master_volume", 2.0)
	assert_almost_eq(
		_settings.master_volume, 1.0, 0.001,
		"set_preference should clamp volume above 1.0"
	)
	_settings.set_preference(&"master_volume", -1.0)
	assert_almost_eq(
		_settings.master_volume, 0.0, 0.001,
		"set_preference should clamp volume below 0.0"
	)


func test_set_preference_emits_signal() -> void:
	var received_key: Array = [&""]
	var received_value: Array = [-1.0]
	_settings.preference_changed.connect(
		func(key: StringName, value: Variant) -> void:
			received_key[0] = key
			received_value[0] = value as float
	)
	_settings.set_preference(&"sfx_volume", 0.42)
	assert_eq(
		received_key[0], &"sfx_volume",
		"preference_changed should emit with correct key"
	)
	assert_almost_eq(
		received_value[0], 0.42, 0.001,
		"preference_changed should emit with correct value"
	)


func test_set_preference_unknown_key_no_signal() -> void:
	var signal_fired: Array = [false]
	_settings.preference_changed.connect(
		func(_key: StringName, _value: Variant) -> void:
			signal_fired[0] = true
	)
	_settings.set_preference(&"unknown_key", 1.0)
	assert_false(
		signal_fired[0],
		"Unknown key should not emit preference_changed"
	)


func test_volume_bus_map_has_three_entries() -> void:
	assert_eq(
		_settings.VOLUME_BUS_MAP.size(), 3,
		"VOLUME_BUS_MAP should map 3 volume keys to buses"
	)


func test_apply_settings_is_idempotent() -> void:
	_settings.set_master_volume(0.5)
	_settings.apply_settings()
	_settings.apply_settings()
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		pending("Master bus not available in test runner")
		return
	var expected_db: float = linear_to_db(0.5)
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(
		actual_db, expected_db, 0.01,
		"apply_settings called twice should produce same result"
	)


func test_default_locale_is_en() -> void:
	assert_eq(
		_settings.locale, "en",
		"Default locale should be 'en'"
	)


func test_apply_locale_preference_sets_translation_server() -> void:
	_settings.locale = "es"
	_settings._apply_locale_preference()
	assert_eq(
		TranslationServer.get_locale(), "es",
		"_apply_locale_preference should set TranslationServer locale"
	)
	_settings.locale = "en"
	_settings._apply_locale_preference()


func test_apply_locale_preference_empty_string_fallback() -> void:
	_settings.locale = ""
	_settings._apply_locale_preference()
	assert_eq(
		_settings.locale, "en",
		"Empty locale should fall back to 'en'"
	)
	assert_eq(
		TranslationServer.get_locale(), "en",
		"TranslationServer should use 'en' for empty locale"
	)


func test_set_preference_language_updates_locale() -> void:
	_settings.set_preference(&"language", "es")
	assert_eq(
		_settings.locale, "es",
		"set_preference language should update locale"
	)
	_settings.set_preference(&"language", "en")


func test_set_preference_language_updates_translation_server() -> void:
	_settings.set_preference(&"language", "es")
	assert_eq(
		TranslationServer.get_locale(), "es",
		"set_preference language should update TranslationServer"
	)
	_settings.set_preference(&"language", "en")


func test_get_preference_language_returns_locale() -> void:
	_settings.locale = "fr"
	assert_eq(
		_settings.get_preference(&"language"), "fr",
		"get_preference language should return current locale"
	)


func test_set_preference_language_emits_signal() -> void:
	var received_key: Array = [&""]
	var received_value: Array = [""]
	_settings.preference_changed.connect(
		func(key: StringName, value: Variant) -> void:
			received_key[0] = key
			received_value[0] = value as String
	)
	_settings.set_preference(&"language", "es")
	assert_eq(
		received_key[0], &"language",
		"preference_changed should emit with 'language' key"
	)
	assert_eq(
		received_value[0], "es",
		"preference_changed should emit with locale value"
	)
	_settings.set_preference(&"language", "en")
