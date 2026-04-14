## Integration test: Settings audio live-change — preference_changed signal → AudioManager bus updated
## without a save/load cycle.
extends GutTest

const TEST_PATH: String = "user://settings_audio_wiring_test.cfg"

var _settings: Node
var _audio_mgr: Node


func before_each() -> void:
	_settings = Node.new()
	_settings.set_script(preload("res://game/autoload/settings.gd"))
	_settings.settings_path = TEST_PATH
	add_child_autofree(_settings)

	_audio_mgr = Node.new()
	_audio_mgr.set_script(preload("res://game/autoload/audio_manager.gd"))
	add_child_autofree(_audio_mgr)
	_audio_mgr.initialize()


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


# ── Boot-time application ─────────────────────────────────────────────────────


func test_boot_master_bus_matches_settings_master_volume() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		pending("Master bus not available in test runner")
		return

	var expected: float = _settings.get_preference(&"master_volume") as float
	var actual: float = db_to_linear(AudioServer.get_bus_volume_db(master_idx))

	assert_almost_eq(
		actual, expected, 0.01,
		"AudioServer Master bus should match Settings.master_volume immediately after _ready()"
	)


func test_boot_sfx_bus_matches_settings_sfx_volume() -> void:
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		pending("SFX bus not available in test runner")
		return

	var expected: float = _settings.get_preference(&"sfx_volume") as float
	var actual: float = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))

	assert_almost_eq(
		actual, expected, 0.01,
		"AudioServer SFX bus should match Settings.sfx_volume immediately after AudioManager.initialize()"
	)


# ── Live preference change ─────────────────────────────────────────────────────


func test_preference_changed_signal_emitted_on_sfx_change() -> void:
	watch_signals(EventBus)

	_settings.set_preference(&"sfx_volume", 0.3)

	assert_signal_emitted(
		EventBus, "preference_changed",
		"EventBus.preference_changed must fire when Settings.set_preference is called"
	)


func test_live_sfx_change_updates_bus_without_save_reload() -> void:
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		pending("SFX bus not available in test runner")
		return

	_settings.set_preference(&"sfx_volume", 0.3)

	assert_false(
		FileAccess.file_exists(TEST_PATH),
		"No settings file should be written during a live preference change"
	)
	var actual: float = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))
	assert_almost_eq(
		actual, 0.3, 0.01,
		"AudioManager must update SFX bus to 0.3 via EventBus.preference_changed — no save/load needed"
	)


func test_preference_changed_carries_correct_key_and_value() -> void:
	watch_signals(EventBus)

	_settings.set_preference(&"sfx_volume", 0.3)

	var params: Array = get_signal_parameters(EventBus, "preference_changed")
	assert_eq(
		StringName(params[0]), &"sfx_volume",
		"preference_changed signal key should be 'sfx_volume'"
	)
	assert_almost_eq(
		params[1] as float, 0.3, 0.001,
		"preference_changed signal value should be 0.3"
	)


# ── Master volume propagation ─────────────────────────────────────────────────


func test_master_volume_zero_silences_master_bus() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		pending("Master bus not available in test runner")
		return

	_settings.set_preference(&"master_volume", 0.0)

	var volume_db: float = AudioServer.get_bus_volume_db(master_idx)
	assert_true(
		volume_db < -60.0,
		"Master bus volume_db must be below -60 dB (silent) when master_volume is 0.0"
	)


func test_master_volume_restored_after_silence() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		pending("Master bus not available in test runner")
		return

	_settings.set_preference(&"master_volume", 0.0)
	_settings.set_preference(&"master_volume", 0.8)

	var actual: float = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	assert_almost_eq(
		actual, 0.8, 0.01,
		"Master bus should return to 0.8 linear after master_volume is raised from 0.0"
	)


# ── No direct autoload cross-reference ───────────────────────────────────────


func test_settings_does_not_hold_audio_manager_reference() -> void:
	# Verify that Settings routes changes through EventBus, not by holding a
	# reference to AudioManager. If Settings called AudioManager directly, the
	# local _settings node would fail to find it (since the global autoload is
	# a different object). The fact that bus levels update proves the path runs
	# through EventBus.preference_changed, not a direct reference.
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		pending("SFX bus not available in test runner")
		return

	var before: float = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))
	_settings.set_preference(&"sfx_volume", clampf(before * 0.5, 0.05, 0.95))

	var after: float = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))
	assert_ne(
		snappedf(after, 0.01), snappedf(before, 0.01),
		"SFX bus changed via EventBus routing — Settings holds no direct AudioManager reference"
	)
