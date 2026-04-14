## Tests WarrantyDialog: open/close, display, accept, and decline flows.
extends GutTest


var _dialog: WarrantyDialog


func before_each() -> void:
	_dialog = preload(
		"res://game/scenes/ui/warranty_dialog.tscn"
	).instantiate()
	add_child_autofree(_dialog)


func test_dialog_starts_closed() -> void:
	assert_false(
		_dialog.is_open(),
		"Dialog should start closed"
	)


func test_open_sets_open_state() -> void:
	_dialog.open("item_001", "Test Widget", 100.0, 50.0)
	assert_true(
		_dialog.is_open(),
		"Dialog should be open after open()"
	)


func test_close_sets_closed_state() -> void:
	_dialog.open("item_001", "Test Widget", 100.0, 50.0)
	_dialog.close()
	assert_false(
		_dialog.is_open(),
		"Dialog should be closed after close()"
	)


func test_open_populates_labels() -> void:
	_dialog.open("item_001", "Fancy Speaker", 80.0, 40.0)
	var fee: float = WarrantyManager.calculate_fee(80.0, 0.20)
	assert_string_contains(
		_dialog._item_name_label.text, "Fancy Speaker"
	)
	assert_string_contains(
		_dialog._sale_price_label.text, "80.00"
	)
	assert_string_contains(
		_dialog._warranty_cost_label.text, "%.2f" % fee
	)
	assert_string_contains(
		_dialog._duration_label.text, "30"
	)


func test_accept_emits_signal_and_closes() -> void:
	_dialog.open("item_002", "Widget", 100.0, 50.0)
	watch_signals(_dialog)
	_dialog._on_add_pressed()
	assert_signal_emitted(_dialog, "warranty_accepted")
	assert_false(
		_dialog.is_open(),
		"Dialog should close after accepting"
	)


func test_accept_signal_carries_item_id_and_fee() -> void:
	_dialog.open("item_003", "Widget", 100.0, 50.0)
	watch_signals(_dialog)
	_dialog._on_add_pressed()
	var params: Array = get_signal_parameters(
		_dialog, "warranty_accepted"
	)
	assert_eq(params[0], "item_003")
	var expected_fee: float = WarrantyManager.calculate_fee(
		100.0, WarrantyDialog.DEFAULT_WARRANTY_PERCENT
	)
	assert_almost_eq(params[1], expected_fee, 0.01)


func test_decline_emits_signal_and_closes() -> void:
	_dialog.open("item_004", "Widget", 100.0, 50.0)
	watch_signals(_dialog)
	_dialog._on_decline_pressed()
	assert_signal_emitted(_dialog, "warranty_declined")
	assert_false(
		_dialog.is_open(),
		"Dialog should close after declining"
	)


func test_double_open_is_ignored() -> void:
	_dialog.open("item_001", "Widget A", 100.0, 50.0)
	_dialog.open("item_002", "Widget B", 200.0, 80.0)
	assert_string_contains(
		_dialog._item_name_label.text, "Widget A"
	)


func test_ineligible_price_still_opens() -> void:
	_dialog.open("item_005", "Cheap Item", 20.0, 10.0)
	assert_true(
		_dialog.is_open(),
		"Dialog opens regardless; eligibility checked by caller"
	)
