## GUT unit tests for Settings autoload — defaults, round-trips, clamping, and recovery.
extends GutTest


const SettingsScript: GDScript = preload("res://game/autoload/settings.gd")

var _settings: Node
var _temp_path: String


func before_each() -> void:
	_temp_path = "user://test_settings_main_%d.cfg" % Time.get_ticks_msec()
	_settings = SettingsScript.new()
	_settings.settings_path = _temp_path
	add_child_autofree(_settings)


func after_each() -> void:
	if FileAccess.file_exists(_temp_path):
		DirAccess.remove_absolute(_temp_path)


# -- Default values when no config file exists ----------------------------

func test_default_master_volume() -> void:
	var fresh: Node = _fresh_settings("user://no_such_settings_mv.cfg")
	assert_almost_eq(
		fresh.master_volume, 1.0, 0.001,
		"master_volume default should be 1.0"
	)


func test_default_sfx_volume() -> void:
	var fresh: Node = _fresh_settings("user://no_such_settings_sfx.cfg")
	assert_almost_eq(
		fresh.sfx_volume, 1.0, 0.001,
		"sfx_volume default should be 1.0"
	)


func test_default_music_volume() -> void:
	var fresh: Node = _fresh_settings("user://no_such_settings_mus.cfg")
	assert_almost_eq(
		fresh.music_volume, 0.8, 0.001,
		"music_volume default should be 0.8"
	)


func test_default_fullscreen() -> void:
	var fresh: Node = _fresh_settings("user://no_such_settings_fs.cfg")
	assert_true(fresh.fullscreen, "fullscreen default should be true")


# -- Float preference round-trip ------------------------------------------

func test_set_get_master_volume_round_trip() -> void:
	_settings.set_preference(&"master_volume", 0.7)
	assert_almost_eq(
		_settings.get_preference(&"master_volume") as float, 0.7, 0.001,
		"get_preference should return the exact value set for master_volume"
	)


func test_set_get_sfx_volume_round_trip() -> void:
	_settings.set_preference(&"sfx_volume", 0.4)
	assert_almost_eq(
		_settings.get_preference(&"sfx_volume") as float, 0.4, 0.001,
		"get_preference should return the exact value set for sfx_volume"
	)


# -- Bool preference round-trip -------------------------------------------

func test_set_fullscreen_persists_false() -> void:
	_settings.fullscreen = false
	_settings.save_settings()
	var s2: Node = _loaded_settings()
	assert_false(s2.fullscreen, "fullscreen=false should survive save/load")


func test_set_fullscreen_persists_true() -> void:
	_settings.fullscreen = true
	_settings.save_settings()
	var s2: Node = _loaded_settings()
	assert_true(s2.fullscreen, "fullscreen=true should survive save/load")


# -- Volume clamping ------------------------------------------------------

func test_volume_above_one_clamped_to_one() -> void:
	_settings.set_preference(&"master_volume", 1.5)
	assert_almost_eq(
		_settings.get_preference(&"master_volume") as float, 1.0, 0.001,
		"master_volume 1.5 should be clamped to 1.0"
	)


func test_volume_below_zero_clamped_to_zero() -> void:
	_settings.set_preference(&"sfx_volume", -0.3)
	assert_almost_eq(
		_settings.get_preference(&"sfx_volume") as float, 0.0, 0.001,
		"sfx_volume -0.3 should be clamped to 0.0"
	)


func test_volume_at_exact_zero_accepted() -> void:
	_settings.set_preference(&"music_volume", 0.0)
	assert_almost_eq(
		_settings.get_preference(&"music_volume") as float, 0.0, 0.001,
		"music_volume 0.0 should be accepted as-is"
	)


func test_volume_at_exact_one_accepted() -> void:
	_settings.set_preference(&"master_volume", 1.0)
	assert_almost_eq(
		_settings.get_preference(&"master_volume") as float, 1.0, 0.001,
		"master_volume 1.0 should be accepted as-is"
	)


# -- Save / load restores all preferences ---------------------------------

func test_save_load_restores_all_preferences() -> void:
	_settings.set_preference(&"master_volume", 0.6)
	_settings.set_preference(&"music_volume", 0.3)
	_settings.set_preference(&"sfx_volume", 0.9)
	_settings.fullscreen = false
	_settings.save_settings()

	var s2: Node = _loaded_settings()
	assert_almost_eq(
		s2.get_preference(&"master_volume") as float, 0.6, 0.001,
		"master_volume should match after save/load"
	)
	assert_almost_eq(
		s2.get_preference(&"music_volume") as float, 0.3, 0.001,
		"music_volume should match after save/load"
	)
	assert_almost_eq(
		s2.get_preference(&"sfx_volume") as float, 0.9, 0.001,
		"sfx_volume should match after save/load"
	)
	assert_false(s2.fullscreen, "fullscreen should match after save/load")


# -- Missing file does not crash, defaults used ---------------------------

func test_missing_cfg_does_not_crash() -> void:
	var path: String = "user://definitely_absent_%d.cfg" % Time.get_ticks_msec()
	assert_false(FileAccess.file_exists(path), "pre-condition: file must not exist")
	var fresh: Node = _fresh_settings(path)
	assert_not_null(fresh, "Settings node must be non-null after init with missing file")


func test_missing_cfg_uses_default_master_volume() -> void:
	var fresh: Node = _fresh_settings(
		"user://missing_defaults_%d.cfg" % Time.get_ticks_msec()
	)
	assert_almost_eq(
		fresh.get_preference(&"master_volume") as float, 1.0, 0.001,
		"master_volume should be default 1.0 when cfg absent"
	)


func test_missing_cfg_uses_default_sfx_volume() -> void:
	var fresh: Node = _fresh_settings(
		"user://missing_defaults2_%d.cfg" % Time.get_ticks_msec()
	)
	assert_almost_eq(
		fresh.get_preference(&"sfx_volume") as float, 1.0, 0.001,
		"sfx_volume should be default 1.0 when cfg absent"
	)


# -- reset_to_defaults restores all keys ----------------------------------

func test_reset_to_defaults_restores_master_volume() -> void:
	_settings.set_preference(&"master_volume", 0.2)
	_settings.reset_to_defaults()
	assert_almost_eq(
		_settings.get_preference(&"master_volume") as float, 1.0, 0.001,
		"master_volume should be 1.0 after reset_to_defaults"
	)


func test_reset_to_defaults_restores_music_volume() -> void:
	_settings.set_preference(&"music_volume", 0.1)
	_settings.reset_to_defaults()
	assert_almost_eq(
		_settings.get_preference(&"music_volume") as float, 0.8, 0.001,
		"music_volume should be 0.8 after reset_to_defaults"
	)


func test_reset_to_defaults_restores_sfx_volume() -> void:
	_settings.set_preference(&"sfx_volume", 0.5)
	_settings.reset_to_defaults()
	assert_almost_eq(
		_settings.get_preference(&"sfx_volume") as float, 1.0, 0.001,
		"sfx_volume should be 1.0 after reset_to_defaults"
	)


func test_reset_to_defaults_restores_fullscreen() -> void:
	_settings.fullscreen = false
	_settings.reset_to_defaults()
	assert_true(
		_settings.fullscreen,
		"fullscreen should be true after reset_to_defaults"
	)


func test_reset_to_defaults_restores_all_simultaneously() -> void:
	_settings.set_preference(&"master_volume", 0.2)
	_settings.set_preference(&"music_volume", 0.1)
	_settings.set_preference(&"sfx_volume", 0.3)
	_settings.fullscreen = false
	_settings.reset_to_defaults()

	assert_almost_eq(
		_settings.get_preference(&"master_volume") as float, 1.0, 0.001,
		"master_volume should be 1.0 after reset"
	)
	assert_almost_eq(
		_settings.get_preference(&"music_volume") as float, 0.8, 0.001,
		"music_volume should be 0.8 after reset"
	)
	assert_almost_eq(
		_settings.get_preference(&"sfx_volume") as float, 1.0, 0.001,
		"sfx_volume should be 1.0 after reset"
	)
	assert_true(
		_settings.fullscreen,
		"fullscreen should be true after reset"
	)


# -- EventBus preference_changed emission (ISSUE-428) ---------------------

func test_set_preference_emits_eventbus_preference_changed() -> void:
	var received_key: String = ""
	var received_value: Variant = null
	var handler: Callable = func(k: String, v: Variant) -> void:
		received_key = k
		received_value = v
	EventBus.preference_changed.connect(handler)
	_settings.set_preference(&"master_volume", 0.5)
	EventBus.preference_changed.disconnect(handler)
	assert_eq(received_key, "master_volume", "EventBus.preference_changed key should be 'master_volume'")
	assert_almost_eq(received_value as float, 0.5, 0.001, "EventBus.preference_changed value should be 0.5")


func test_set_preference_emits_eventbus_for_sfx_volume() -> void:
	var received_key: String = ""
	var handler: Callable = func(k: String, _v: Variant) -> void:
		received_key = k
	EventBus.preference_changed.connect(handler)
	_settings.set_preference(&"sfx_volume", 0.3)
	EventBus.preference_changed.disconnect(handler)
	assert_eq(received_key, "sfx_volume", "EventBus.preference_changed key should be 'sfx_volume'")


func test_set_preference_idempotent_does_not_emit_eventbus() -> void:
	_settings.set_preference(&"master_volume", 0.7)
	var signal_count: int = 0
	var handler: Callable = func(_k: String, _v: Variant) -> void:
		signal_count += 1
	EventBus.preference_changed.connect(handler)
	_settings.set_preference(&"master_volume", 0.7)
	EventBus.preference_changed.disconnect(handler)
	assert_eq(signal_count, 0, "Idempotent set_preference should not emit EventBus.preference_changed")


# -- Helpers --------------------------------------------------------------

func _fresh_settings(path: String) -> Node:
	var s: Node = SettingsScript.new()
	s.settings_path = path
	add_child_autofree(s)
	return s


func _loaded_settings() -> Node:
	var s: Node = SettingsScript.new()
	s.settings_path = _temp_path
	add_child_autofree(s)
	return s
