## Tests for main menu save slot display and cash formatting.
extends GutTest


const _SLOT_PATHS: Array[String] = [
	"user://save_slot_0.json",
	"user://save_slot_1.json",
	"user://save_slot_2.json",
	"user://save_slot_3.json",
]

var _menu: Control
var _backup_paths: Dictionary = {}


func before_all() -> void:
	# Preserve any real saves so save-state tests don't clobber
	# a developer's local progress.
	for slot: int in range(_SLOT_PATHS.size()):
		var slot_path: String = _SLOT_PATHS[slot]
		var backup_path: String = "user://save_slot_%d.test_backup.json" % slot
		if FileAccess.file_exists(slot_path):
			DirAccess.copy_absolute(slot_path, backup_path)
			DirAccess.remove_absolute(slot_path)
			_backup_paths[slot_path] = backup_path


func after_all() -> void:
	for slot_path: String in _SLOT_PATHS:
		if FileAccess.file_exists(slot_path):
			DirAccess.remove_absolute(slot_path)
		if _backup_paths.has(slot_path):
			var backup_path: String = str(_backup_paths[slot_path])
			if FileAccess.file_exists(backup_path):
				DirAccess.copy_absolute(backup_path, slot_path)
				DirAccess.remove_absolute(backup_path)


func before_each() -> void:
	InputFocus._reset_for_tests()
	for slot_path: String in _SLOT_PATHS:
		if FileAccess.file_exists(slot_path):
			DirAccess.remove_absolute(slot_path)
	_menu = load(
		"res://game/scenes/ui/main_menu.gd"
	).new()


func after_each() -> void:
	if is_instance_valid(_menu):
		_menu.free()
	InputFocus._reset_for_tests()


func test_menu_scene_smoke_shows_front_door_state() -> void:
	var scene: PackedScene = load("res://game/scenes/ui/main_menu.tscn")
	assert_not_null(scene, "main_menu.tscn must load")
	if scene == null:
		return
	var menu: Control = scene.instantiate() as Control
	assert_not_null(menu, "main menu scene must instantiate as Control")
	if menu == null:
		return
	add_child(menu)
	await get_tree().process_frame

	var title: Label = menu.get_node("VBox/Title") as Label
	var play_button: Button = menu.get_node("VBox/PlayButton") as Button
	var load_button: Button = menu.get_node("VBox/LoadButton") as Button
	var version_label: Label = menu.get_node("VersionLabel") as Label
	var dialog: ConfirmationDialog = (
		menu.get_node("NewGameConfirmDialog") as ConfirmationDialog
	)

	assert_eq(title.text, "SHELF LIFE")
	assert_eq(play_button.text, "New Game")
	assert_true(load_button.disabled)
	assert_eq(load_button.text, "No Save Found")
	assert_eq(
		version_label.text,
		"v%s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	)
	assert_eq(version_label.anchor_left, 1.0)
	assert_eq(version_label.anchor_top, 1.0)
	assert_true(dialog.dialog_text.contains("resets your current run"))
	assert_true(dialog.dialog_text.contains("Cancel"))
	assert_eq(dialog.ok_button_text, "Reset Run")
	assert_eq(dialog.cancel_button_text, "Cancel")

	menu.free()


func test_format_cash_under_thousand() -> void:
	var result: String = _menu._format_cash(500.0)
	assert_eq(result, "500")


func test_format_cash_exact_thousand() -> void:
	var result: String = _menu._format_cash(1000.0)
	assert_eq(result, "1,000")


func test_format_cash_over_thousand() -> void:
	var result: String = _menu._format_cash(2500.0)
	assert_eq(result, "2,500")


func test_format_cash_large_amount() -> void:
	var result: String = _menu._format_cash(15750.0)
	assert_eq(result, "15,750")


func test_format_cash_zero() -> void:
	var result: String = _menu._format_cash(0.0)
	assert_eq(result, "0")


func test_has_any_saves_returns_false_when_no_saves() -> void:
	var result: bool = _menu._has_any_saves()
	assert_typeof(result, TYPE_BOOL)
	assert_false(result, "test fixture should start with no save files")


func test_format_slot_info_empty_data() -> void:
	var result: String = _menu._format_slot_info({})
	assert_eq(result, tr("MENU_SAVED_GAME"))


func test_format_slot_info_with_metadata() -> void:
	var data: Dictionary = {
		"metadata": {
			"day_number": 5,
			"timestamp": "2026-04-12T10:00:00",
			"store_type": "",
		},
		"economy": {
			"player_cash": 2500.0,
		},
	}
	var result: String = _menu._format_slot_info(data)
	assert_true(result.contains("$2,500"))


func test_format_slot_info_with_save_metadata() -> void:
	var data: Dictionary = {
		"save_metadata": {
			"day_number": 7,
			"timestamp": "2026-04-12T10:00:00",
			"store_name": "Champions Corner",
			"active_store_id": "sports",
			"cash": 4321.75,
		},
		"economy": {
			"player_cash": 1.0,
		},
	}
	var result: String = _menu._format_slot_info(data)
	assert_true(result.contains(tr("MENU_DAY") % 7))
	assert_true(result.contains("Champions Corner"))
	assert_true(result.contains("$4,321"))
	assert_true(result.contains("2026-04-12"))


func test_format_slot_info_includes_zero_cash_from_save_metadata() -> void:
	var data: Dictionary = {
		"save_metadata": {
			"day_number": 1,
			"timestamp": "2026-04-12T10:00:00",
			"store_name": "Champions Corner",
			"cash": 0.0,
		},
	}
	var result: String = _menu._format_slot_info(data)
	assert_true(result.contains("$0"))


func test_format_slot_info_falls_back_to_legacy_current_cash() -> void:
	var data: Dictionary = {
		"metadata": {
			"day_number": 5,
			"timestamp": "2026-04-12T10:00:00",
			"store_type": "",
		},
		"economy": {
			"current_cash": 1750.0,
		},
	}
	var result: String = _menu._format_slot_info(data)
	assert_true(result.contains("$1,750"))


func test_slot_zero_save_exists_returns_false_when_absent() -> void:
	var slot_zero_path: String = _menu.SLOT_PATHS.get(0, "")
	if FileAccess.file_exists(slot_zero_path):
		var err: Error = DirAccess.remove_absolute(slot_zero_path)
		assert_eq(err, OK, "test setup must remove pre-existing slot 0 file")
	assert_false(_menu._slot_zero_save_exists())


func test_refresh_load_button_state_disables_when_no_save() -> void:
	var slot_zero_path: String = _menu.SLOT_PATHS.get(0, "")
	if FileAccess.file_exists(slot_zero_path):
		var err: Error = DirAccess.remove_absolute(slot_zero_path)
		assert_eq(err, OK, "test setup must remove pre-existing slot 0 file")

	var button := Button.new()
	button.text = "Load Game"
	button.disabled = false
	_menu._load_button = button
	_menu._refresh_load_button_state()

	assert_true(button.disabled, "load button must be disabled with no save")
	assert_eq(button.text, "No Save Found")
	button.free()


func test_refresh_load_button_state_disables_load_when_save_present() -> void:
	var slot_zero_path: String = _menu.SLOT_PATHS.get(0, "")
	var pre_existing: bool = FileAccess.file_exists(slot_zero_path)
	if not pre_existing:
		var file: FileAccess = FileAccess.open(slot_zero_path, FileAccess.WRITE)
		assert_not_null(file, "test setup must create a slot 0 sentinel file")
		file.store_string("{}")
		file.flush()
		file.close()

	var button := Button.new()
	button.text = "No Save Found"
	button.disabled = true
	_menu._load_button = button
	_menu._refresh_load_button_state()

	assert_true(
		button.disabled,
		"load button must stay disabled while beta load is unavailable"
	)
	assert_eq(button.text, "Load Game - Coming Soon")
	button.free()

	if not pre_existing and FileAccess.file_exists(slot_zero_path):
		DirAccess.remove_absolute(slot_zero_path)


func test_on_load_pressed_no_op_when_no_save() -> void:
	var slot_zero_path: String = _menu.SLOT_PATHS.get(0, "")
	if FileAccess.file_exists(slot_zero_path):
		var err: Error = DirAccess.remove_absolute(slot_zero_path)
		assert_eq(err, OK, "test setup must remove pre-existing slot 0 file")
	_menu._load_panel_visible = false
	_menu._on_load_pressed()
	assert_false(
		_menu._load_panel_visible,
		"load panel must not open when no save exists"
	)


func test_on_load_pressed_no_op_when_beta_load_is_unavailable() -> void:
	var slot_zero_path: String = _menu.SLOT_PATHS.get(0, "")
	var pre_existing: bool = FileAccess.file_exists(slot_zero_path)
	if not pre_existing:
		var file: FileAccess = FileAccess.open(slot_zero_path, FileAccess.WRITE)
		assert_not_null(file, "test setup must create a slot 0 sentinel file")
		file.store_string("{}")
		file.flush()
		file.close()

	_menu._load_panel_visible = false
	_menu._on_load_pressed()
	assert_false(
		_menu._load_panel_visible,
		"load panel must not open while beta load is unavailable"
	)

	if not pre_existing and FileAccess.file_exists(slot_zero_path):
		DirAccess.remove_absolute(slot_zero_path)
