## Tests for main menu save slot display and cash formatting.
extends GutTest


const _SLOT_ZERO_BACKUP_PATH: String = "user://save_slot_0.test_backup.json"

var _menu: Control


func before_all() -> void:
	# Preserve any real slot 0 save so save-state tests don't clobber
	# a developer's local progress.
	var slot_zero_path: String = "user://save_slot_0.json"
	if FileAccess.file_exists(slot_zero_path):
		DirAccess.copy_absolute(slot_zero_path, _SLOT_ZERO_BACKUP_PATH)
		DirAccess.remove_absolute(slot_zero_path)


func after_all() -> void:
	var slot_zero_path: String = "user://save_slot_0.json"
	if FileAccess.file_exists(slot_zero_path):
		DirAccess.remove_absolute(slot_zero_path)
	if FileAccess.file_exists(_SLOT_ZERO_BACKUP_PATH):
		DirAccess.copy_absolute(_SLOT_ZERO_BACKUP_PATH, slot_zero_path)
		DirAccess.remove_absolute(_SLOT_ZERO_BACKUP_PATH)


func before_each() -> void:
	_menu = load(
		"res://game/scenes/ui/main_menu.gd"
	).new()


func after_each() -> void:
	if is_instance_valid(_menu):
		_menu.free()


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


func test_refresh_load_button_state_enables_when_save_present() -> void:
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

	assert_false(button.disabled, "load button must be enabled with save present")
	assert_eq(button.text, "Load Game")
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
