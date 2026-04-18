## GUT unit tests for Settings autoload persistence, defaults, and signals.
extends GutTest


const SettingsScript: GDScript = preload(
	"res://game/autoload/settings.gd"
)

var _settings: Node
var _temp_path: String


func before_each() -> void:
	_temp_path = "user://test_settings_%d.cfg" % Time.get_ticks_msec()
	_settings = SettingsScript.new()
	_settings.settings_path = _temp_path
	add_child_autofree(_settings)


func after_each() -> void:
	if FileAccess.file_exists(_temp_path):
		DirAccess.remove_absolute(_temp_path)


# -- Write/read round-trip ------------------------------------------------

func test_round_trip_master_volume() -> void:
	_settings.set_preference(&"master_volume", 0.7)
	_settings.save_settings()
	var s2: Node = _create_loaded_settings()
	assert_almost_eq(
		s2.get_preference(&"master_volume") as float, 0.7, 0.01,
		"master_volume should survive save/load round-trip"
	)


func test_round_trip_music_volume() -> void:
	_settings.set_preference(&"music_volume", 0.3)
	_settings.save_settings()
	var s2: Node = _create_loaded_settings()
	assert_almost_eq(
		s2.get_preference(&"music_volume") as float, 0.3, 0.01,
		"music_volume should survive save/load round-trip"
	)


func test_round_trip_sfx_volume() -> void:
	_settings.set_preference(&"sfx_volume", 0.5)
	_settings.save_settings()
	var s2: Node = _create_loaded_settings()
	assert_almost_eq(
		s2.get_preference(&"sfx_volume") as float, 0.5, 0.01,
		"sfx_volume should survive save/load round-trip"
	)


func test_round_trip_display_mode() -> void:
	_settings.set_preference(&"display_mode", 0)
	_settings.save_settings()
	var s2: Node = _create_loaded_settings()
	assert_eq(
		s2.get_preference(&"display_mode") as int, 0,
		"display_mode should survive save/load round-trip"
	)


func test_round_trip_control_scheme() -> void:
	_settings.set_preference(&"control_scheme", 2)
	_settings.save_settings()
	var s2: Node = _create_loaded_settings()
	assert_eq(
		s2.get_preference(&"control_scheme") as int, 2,
		"control_scheme should survive save/load round-trip"
	)


# -- Default fallbacks ----------------------------------------------------

func test_default_master_volume_when_no_cfg() -> void:
	var fresh: Node = SettingsScript.new()
	fresh.settings_path = "user://nonexistent_test_settings.cfg"
	add_child_autofree(fresh)
	assert_almost_eq(
		fresh.get_preference(&"master_volume") as float, 1.0, 0.01,
		"master_volume default should be 1.0 when no cfg exists"
	)


func test_default_music_volume_when_no_cfg() -> void:
	var fresh: Node = SettingsScript.new()
	fresh.settings_path = "user://nonexistent_test_settings.cfg"
	add_child_autofree(fresh)
	assert_almost_eq(
		fresh.get_preference(&"music_volume") as float, 0.8, 0.01,
		"music_volume default should be 0.8 when no cfg exists"
	)


func test_missing_key_returns_typed_default() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", 0.5)
	config.save(_temp_path)
	var s2: Node = _create_loaded_settings()
	assert_almost_eq(
		s2.get_preference(&"sfx_volume") as float, 1.0, 0.01,
		"Missing sfx_volume key should return default 1.0"
	)
	assert_eq(
		s2.get_preference(&"display_mode") as int, 1,
		"Missing display_mode key should return default 1"
	)


# -- preference_changed signal contract -----------------------------------

func test_preference_changed_emits_on_new_value() -> void:
	watch_signals(_settings)
	_settings.set_preference(&"master_volume", 0.4)
	assert_signal_emitted(
		_settings, "preference_changed",
		"preference_changed should emit when value changes"
	)
	var params: Array = get_signal_parameters(
		_settings, "preference_changed"
	)
	assert_eq(
		params[0] as StringName, &"master_volume",
		"Signal key should be master_volume"
	)
	assert_almost_eq(
		params[1] as float, 0.4, 0.01,
		"Signal value should be the new value"
	)


func test_preference_changed_not_emitted_on_same_value() -> void:
	_settings.set_preference(&"sfx_volume", 0.6)
	watch_signals(_settings)
	_settings.set_preference(&"sfx_volume", 0.6)
	assert_signal_not_emitted(
		_settings, "preference_changed",
		"preference_changed should not emit when value is unchanged"
	)


func test_preference_changed_emits_exactly_once() -> void:
	watch_signals(_settings)
	_settings.set_preference(&"music_volume", 0.2)
	assert_signal_emit_count(
		_settings, "preference_changed", 1,
		"preference_changed should emit exactly once per change"
	)


# -- Type safety ----------------------------------------------------------

func test_float_to_int_key_rejected() -> void:
	_settings.set_preference(&"display_mode", 0)
	var before: int = _settings.get_preference(&"display_mode") as int
	_settings.set_preference(&"display_mode", 1.5)
	assert_eq(
		_settings.get_preference(&"display_mode") as int, before,
		"Float to int key should leave preference unchanged"
	)


func test_null_to_any_key_rejected() -> void:
	_settings.set_preference(&"master_volume", 0.5)
	var before: float = _settings.get_preference(
		&"master_volume"
	) as float
	_settings.set_preference(&"master_volume", null)
	assert_almost_eq(
		_settings.get_preference(&"master_volume") as float,
		before, 0.01,
		"Null value should leave preference unchanged"
	)


func test_null_to_int_key_rejected() -> void:
	var before: int = _settings.get_preference(
		&"control_scheme"
	) as int
	_settings.set_preference(&"control_scheme", null)
	assert_eq(
		_settings.get_preference(&"control_scheme") as int, before,
		"Null value should leave int preference unchanged"
	)


func test_invalid_persisted_types_fall_back_to_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", "loud")
	config.set_value("audio", "music_volume", true)
	config.set_value("audio", "sfx_volume", "1.0")
	config.set_value("audio", "ambient_volume", "quiet")
	config.set_value("display", "fullscreen", "yes")
	config.set_value("display", "vsync", 1)
	config.set_value("display", "resolution_x", "wide")
	config.set_value("display", "resolution_y", -10)
	config.set_value("display", "ui_scale", "huge")
	config.set_value("display", "font_size", "large")
	config.set_value("display", "colorblind_mode", 1)
	config.set_value("locale", "language", 7)
	config.set_value("preferences", "display_mode", "windowed")
	config.set_value("preferences", "control_scheme", "keyboard")
	config.save(_temp_path)

	var s2: Node = _create_loaded_settings()

	assert_almost_eq(
		s2.get_preference(&"master_volume") as float, 1.0, 0.01,
		"Invalid master_volume type should fall back to default"
	)
	assert_almost_eq(
		s2.get_preference(&"music_volume") as float, 0.8, 0.01,
		"Invalid music_volume type should fall back to default"
	)
	assert_almost_eq(
		s2.get_preference(&"sfx_volume") as float, 1.0, 0.01,
		"Stringified sfx_volume should not be trusted from config"
	)
	assert_almost_eq(
		s2.ambient_volume, 0.8, 0.01,
		"Invalid ambient_volume type should fall back to default"
	)
	assert_true(s2.fullscreen, "Invalid fullscreen type should fall back to default")
	assert_true(s2.vsync, "Invalid vsync type should fall back to default")
	assert_eq(
		s2.resolution, Vector2i(1920, 1080),
		"Invalid persisted resolution should fall back to default"
	)
	assert_almost_eq(
		s2.ui_scale, 1.0, 0.01,
		"Invalid ui_scale type should fall back to default"
	)
	assert_eq(
		s2.font_size, Settings.FontSize.MEDIUM,
		"Invalid font_size type should fall back to default"
	)
	assert_false(
		s2.colorblind_mode,
		"Invalid colorblind_mode type should fall back to default"
	)
	assert_eq(
		s2.locale, "en",
		"Invalid persisted locale type should fall back to default"
	)
	assert_eq(
		s2.get_preference(&"display_mode") as int, 1,
		"Invalid display_mode type should fall back to default"
	)
	assert_eq(
		s2.get_preference(&"control_scheme") as int, 0,
		"Invalid control_scheme type should fall back to default"
	)


func test_oversized_settings_file_is_rejected() -> void:
	var file: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	assert_not_null(file, "Precondition: oversized settings file should be writable")
	if file == null:
		return
	file.store_string("x".repeat(Settings.MAX_SETTINGS_FILE_BYTES + 1))
	file.close()

	var s2: Node = _create_loaded_settings()

	assert_almost_eq(
		s2.get_preference(&"master_volume") as float, 1.0, 0.01,
		"Oversized settings file should leave defaults intact"
	)
	assert_eq(
		s2.locale, "en",
		"Oversized settings file should not override locale"
	)


func test_failed_parse_reload_resets_mutated_state_to_defaults() -> void:
	_settings.set_preference(&"master_volume", 0.25)
	_settings.set_preference(&"language", "es")
	var file: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	assert_not_null(file, "Precondition: corrupt settings file should be writable")
	if file == null:
		return
	file.store_string("[audio\nmaster_volume = broken")
	file.close()

	_settings.load_settings()

	assert_almost_eq(
		_settings.get_preference(&"master_volume") as float, 1.0, 0.01,
		"Parse failure should restore default master_volume instead of keeping stale state"
	)
	assert_eq(
		_settings.locale, "en",
		"Parse failure should restore default locale instead of keeping stale state"
	)


func test_oversized_reload_resets_mutated_state_to_defaults() -> void:
	_settings.set_preference(&"music_volume", 0.15)
	_settings.set_preference(&"language", "es")
	var file: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	assert_not_null(file, "Precondition: oversized settings file should be writable")
	if file == null:
		return
	file.store_string("x".repeat(Settings.MAX_SETTINGS_FILE_BYTES + 1))
	file.close()

	_settings.load_settings()

	assert_almost_eq(
		_settings.get_preference(&"music_volume") as float, 0.8, 0.01,
		"Oversized reload should restore default music_volume instead of keeping stale state"
	)
	assert_eq(
		_settings.locale, "en",
		"Oversized reload should restore default locale instead of keeping stale state"
	)


# -- Helpers --------------------------------------------------------------

func _create_loaded_settings() -> Node:
	var s: Node = SettingsScript.new()
	s.settings_path = _temp_path
	add_child_autofree(s)
	return s
