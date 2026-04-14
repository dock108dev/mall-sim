## Tests CheckoutPanel: item population, totals, pending state,
## transaction handling, receipt display, and error display.
extends GutTest


var _panel: CheckoutPanel
var _single_item: Array[Dictionary]
var _multi_items: Array[Dictionary]


func before_each() -> void:
	_panel = preload(
		"res://game/scenes/ui/checkout_panel.tscn"
	).instantiate()
	add_child_autofree(_panel)

	_single_item = [{
		"item_name": "Test Card",
		"condition": "Near Mint",
		"price": 25.50,
	}]
	_multi_items = [
		{
			"item_name": "Test Card",
			"condition": "Near Mint",
			"price": 25.50,
		},
		{
			"item_name": "Vintage Console",
			"condition": "Good",
			"price": 120.00,
		},
	]


# --- Open / Close ---


func test_panel_starts_closed() -> void:
	assert_false(
		_panel.is_open(),
		"Panel should start closed"
	)


func test_show_checkout_opens_panel() -> void:
	_panel.show_checkout(_single_item)
	assert_true(
		_panel.is_open(),
		"Panel should be open after show_checkout"
	)


func test_hide_checkout_closes_panel() -> void:
	_panel.show_checkout(_single_item)
	_panel.hide_checkout(true)
	assert_false(
		_panel.is_open(),
		"Panel should be closed after hide_checkout"
	)


func test_hide_noop_when_closed() -> void:
	_panel.hide_checkout(true)
	assert_false(
		_panel.is_open(),
		"hide_checkout on closed panel should be safe"
	)


# --- Item list population ---


func test_single_item_populates_list() -> void:
	_panel.show_checkout(_single_item)
	await get_tree().process_frame
	var list: VBoxContainer = _panel._item_list
	assert_eq(
		list.get_child_count(), 1,
		"Should have 1 item row"
	)


func test_multi_items_populate_list() -> void:
	_panel.show_checkout(_multi_items)
	await get_tree().process_frame
	var list: VBoxContainer = _panel._item_list
	assert_eq(
		list.get_child_count(), 2,
		"Should have 2 item rows"
	)


# --- Totals ---


func test_subtotal_single_item() -> void:
	_panel.show_checkout(_single_item)
	assert_eq(
		_panel._subtotal, 25.50,
		"Subtotal should equal single item price"
	)


func test_subtotal_multi_items() -> void:
	_panel.show_checkout(_multi_items)
	assert_almost_eq(
		_panel._subtotal, 145.50, 0.01,
		"Subtotal should sum all item prices"
	)


func test_total_without_discount() -> void:
	_panel.show_checkout(_single_item)
	assert_eq(
		_panel._total, 25.50,
		"Total should equal subtotal with no discount"
	)


func test_total_with_discount() -> void:
	_panel.show_checkout(_multi_items, 10.0)
	assert_almost_eq(
		_panel._total, 135.50, 0.01,
		"Total should be subtotal minus discount"
	)


func test_discount_row_hidden_when_zero() -> void:
	_panel.show_checkout(_single_item, 0.0)
	assert_false(
		_panel._discount_row.visible,
		"Discount row should be hidden with zero discount"
	)


func test_discount_row_visible_when_nonzero() -> void:
	_panel.show_checkout(_single_item, 5.0)
	assert_true(
		_panel._discount_row.visible,
		"Discount row should be visible with nonzero discount"
	)


func test_total_floor_at_zero() -> void:
	_panel.show_checkout(_single_item, 999.0)
	assert_eq(
		_panel._total, 0.0,
		"Total should not go below zero"
	)


# --- Pending state ---


func test_confirm_sets_pending() -> void:
	_panel.show_checkout(_single_item)
	_panel._on_confirm_pressed()
	assert_true(
		_panel._is_pending,
		"Panel should be pending after confirm"
	)
	assert_true(
		_panel._confirm_button.disabled,
		"Confirm button should be disabled while pending"
	)
	assert_true(
		_panel._cancel_button.disabled,
		"Cancel button should be disabled while pending"
	)


func test_confirm_emits_sale_accepted() -> void:
	_panel.show_checkout(_single_item)
	watch_signals(_panel)
	_panel._on_confirm_pressed()
	assert_signal_emitted(
		_panel, "sale_accepted",
		"Should emit sale_accepted on confirm"
	)


func test_cancel_emits_sale_declined() -> void:
	_panel.show_checkout(_single_item)
	watch_signals(_panel)
	_panel._on_cancel_pressed()
	assert_signal_emitted(
		_panel, "sale_declined",
		"Should emit sale_declined on cancel"
	)


func test_confirm_blocked_while_pending() -> void:
	_panel.show_checkout(_single_item)
	watch_signals(_panel)
	_panel._on_confirm_pressed()
	_panel._on_confirm_pressed()
	assert_signal_emit_count(
		_panel, "sale_accepted", 1,
		"Should not emit twice while pending"
	)


# --- Transaction completed ---


func test_success_shows_receipt() -> void:
	_panel.show_checkout(_single_item)
	_panel._on_confirm_pressed()
	_panel._on_transaction_completed(25.50, true, "")
	assert_true(
		_panel._showing_receipt,
		"Should be showing receipt on success"
	)
	assert_true(
		_panel._receipt_section.visible,
		"Receipt section should be visible"
	)
	assert_false(
		_panel._confirm_button.visible,
		"Confirm button should be hidden during receipt"
	)


func test_failure_shows_error() -> void:
	_panel.show_checkout(_single_item)
	_panel._on_confirm_pressed()
	_panel._on_transaction_completed(
		0.0, false, "Insufficient funds"
	)
	assert_true(
		_panel._error_label.visible,
		"Error label should be visible on failure"
	)
	assert_string_contains(
		_panel._error_label.text, "Insufficient funds"
	)
	assert_false(
		_panel._cancel_button.disabled,
		"Cancel button should re-enable on failure"
	)


func test_transaction_ignored_when_not_pending() -> void:
	_panel.show_checkout(_single_item)
	_panel._on_transaction_completed(25.50, true, "")
	assert_false(
		_panel._showing_receipt,
		"Should ignore transaction when not pending"
	)


func test_transaction_ignored_when_closed() -> void:
	_panel._on_transaction_completed(25.50, true, "")
	assert_false(
		_panel._showing_receipt,
		"Should ignore transaction when panel is closed"
	)


# --- Warranty stubs ---


func test_warranty_offered_returns_false() -> void:
	assert_false(
		_panel.is_warranty_offered(),
		"Warranty should always be false on new panel"
	)


func test_warranty_fee_returns_zero() -> void:
	assert_eq(
		_panel.get_warranty_fee(), 0.0,
		"Warranty fee should always be zero"
	)


# --- Price formatting ---


func test_format_price_two_decimals() -> void:
	var result: String = CheckoutPanel._format_price(25.5)
	assert_eq(
		result, "$25.50",
		"Should format with currency symbol and 2 decimals"
	)


func test_format_price_zero() -> void:
	var result: String = CheckoutPanel._format_price(0.0)
	assert_eq(result, "$0.00", "Should format zero correctly")


# --- is_showing_receipt ---


func test_is_showing_receipt_default_false() -> void:
	assert_false(
		_panel.is_showing_receipt(),
		"Should not show receipt by default"
	)


func test_is_showing_receipt_after_success() -> void:
	_panel.show_checkout(_single_item)
	_panel._on_confirm_pressed()
	_panel._on_transaction_completed(25.50, true, "")
	assert_true(
		_panel.is_showing_receipt(),
		"Should show receipt after successful transaction"
	)
