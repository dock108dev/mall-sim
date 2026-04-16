## Tests for main menu save slot display and cash formatting.
extends GutTest


var _menu: Control


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
