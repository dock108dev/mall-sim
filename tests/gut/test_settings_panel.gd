## Tests for ISSUE-328 SettingsPanel: open/close, snapshot/restore, and signal emission.
extends GutTest


var _panel: SettingsPanel
var _settings: Node


func before_each() -> void:
	_settings = Node.new()
	_settings.set_script(preload("res://game/autoload/settings.gd"))
	add_child_autofree(_settings)

	_panel = preload("res://game/scenes/ui/settings_panel.tscn").instantiate()
	add_child_autofree(_panel)


func test_panel_starts_closed() -> void:
	assert_false(_panel.is_open(), "Panel should start closed")


func test_open_sets_is_open() -> void:
	_panel.open()
	assert_true(_panel.is_open(), "open() should set is_open to true")


func test_close_sets_is_closed() -> void:
	_panel.open()
	_panel.close()
	assert_false(_panel.is_open(), "close() should set is_open to false")


func test_double_open_is_idempotent() -> void:
	_panel.open()
	_panel.open()
	assert_true(_panel.is_open(), "Calling open() twice should leave panel open")


func test_double_close_is_idempotent() -> void:
	_panel.close()
	assert_false(_panel.is_open(), "Calling close() when already closed should not error")


func test_settings_saved_signal_emitted_on_save() -> void:
	_panel.open()
	var fired: Array = [false]
	_panel.settings_saved.connect(func() -> void: fired[0] = true)
	_panel._on_apply_pressed()
	assert_true(fired[0], "settings_saved signal should fire when Save is pressed")


func test_save_closes_panel() -> void:
	_panel.open()
	_panel._on_apply_pressed()
	assert_false(_panel.is_open(), "Save should close the panel")


func test_cancel_closes_panel() -> void:
	_panel.open()
	_panel._on_cancel_pressed()
	assert_false(_panel.is_open(), "Cancel should close the panel")


func test_closed_signal_emitted_on_cancel() -> void:
	_panel.open()
	var fired: Array = [false]
	_panel.closed.connect(func() -> void: fired[0] = true, CONNECT_ONE_SHOT)
	_panel._on_cancel_pressed()
	await get_tree().process_frame
	assert_true(fired[0], "closed signal should fire after cancel")


func test_settings_saved_not_emitted_on_cancel() -> void:
	_panel.open()
	var fired: Array = [false]
	_panel.settings_saved.connect(func() -> void: fired[0] = true)
	_panel._on_cancel_pressed()
	assert_false(fired[0], "settings_saved should not fire on Cancel")


func test_snapshot_restores_master_volume_on_cancel() -> void:
	Settings.master_volume = 0.9
	_panel.open()
	Settings.master_volume = 0.1
	_panel._on_cancel_pressed()
	assert_almost_eq(
		Settings.master_volume, 0.9, 0.001,
		"Cancel should restore master_volume to snapshot"
	)


func test_snapshot_restores_sfx_volume_on_cancel() -> void:
	Settings.sfx_volume = 0.7
	_panel.open()
	Settings.sfx_volume = 0.2
	_panel._on_cancel_pressed()
	assert_almost_eq(
		Settings.sfx_volume, 0.7, 0.001,
		"Cancel should restore sfx_volume to snapshot"
	)


func test_reset_defaults_restores_all_values() -> void:
	Settings.master_volume = 0.1
	Settings.music_volume = 0.2
	Settings.sfx_volume = 0.3
	Settings.fullscreen = false
	_panel.open()
	_panel._on_reset_defaults_pressed()
	assert_almost_eq(
		Settings.master_volume, 1.0, 0.001,
		"Reset defaults should restore master_volume"
	)
	assert_almost_eq(
		Settings.music_volume, 0.8, 0.001,
		"Reset defaults should restore music_volume"
	)
	assert_almost_eq(
		Settings.sfx_volume, 1.0, 0.001,
		"Reset defaults should restore sfx_volume"
	)
	assert_true(
		Settings.fullscreen,
		"Reset defaults should restore fullscreen"
	)


func test_panel_has_settings_saved_signal() -> void:
	assert_true(
		_panel.has_signal("settings_saved"),
		"SettingsPanel must declare settings_saved signal"
	)


func test_panel_has_closed_signal() -> void:
	assert_true(
		_panel.has_signal("closed"),
		"SettingsPanel must declare closed signal"
	)


func test_volume_slider_updates_settings_in_realtime() -> void:
	_panel.open()
	_panel._on_master_changed(50.0)
	assert_almost_eq(
		Settings.master_volume, 0.5, 0.001,
		"Moving master slider should update Settings.master_volume immediately"
	)


func test_music_slider_updates_settings_in_realtime() -> void:
	_panel.open()
	_panel._on_music_changed(60.0)
	assert_almost_eq(
		Settings.music_volume, 0.6, 0.001,
		"Moving music slider should update Settings.music_volume immediately"
	)


func test_sfx_slider_updates_settings_in_realtime() -> void:
	_panel.open()
	_panel._on_sfx_changed(30.0)
	assert_almost_eq(
		Settings.sfx_volume, 0.3, 0.001,
		"Moving SFX slider should update Settings.sfx_volume immediately"
	)
