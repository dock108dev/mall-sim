## ISSUE-006: Live HUD counters — Items Placed, Customers Active, Sales Today.
extends GutTest


var _hud: CanvasLayer
const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)


func before_each() -> void:
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)


func test_items_placed_label_present() -> void:
	var label: Label = _hud.get_node("TopBar/ItemsPlacedLabel")
	assert_not_null(label, "ItemsPlacedLabel must exist in TopBar")


func test_customers_label_present() -> void:
	var label: Label = _hud.get_node("TopBar/CustomersLabel")
	assert_not_null(label, "CustomersLabel must exist in TopBar")


func test_sales_today_label_present() -> void:
	var label: Label = _hud.get_node("TopBar/SalesTodayLabel")
	assert_not_null(label, "SalesTodayLabel must exist in TopBar")


func test_customer_entered_increments_count() -> void:
	_hud._customers_active_count = 0
	EventBus.customer_entered.emit({"customer_id": "c1"})
	assert_eq(_hud._customers_active_count, 1)


func test_customer_left_decrements_count() -> void:
	_hud._customers_active_count = 2
	EventBus.customer_left.emit({"customer_id": "c1"})
	assert_eq(_hud._customers_active_count, 1)


func test_customer_count_floored_at_zero() -> void:
	_hud._customers_active_count = 0
	EventBus.customer_left.emit({"customer_id": "stray"})
	assert_eq(
		_hud._customers_active_count, 0,
		"customer_left must never push count below zero"
	)


func test_item_sold_increments_sales_today() -> void:
	_hud._sales_today_count = 0
	EventBus.item_sold.emit("item_a", 12.0, "category")
	EventBus.item_sold.emit("item_b", 5.0, "category")
	assert_eq(_hud._sales_today_count, 2)


func test_day_started_resets_sales_today() -> void:
	_hud._sales_today_count = 7
	EventBus.day_started.emit(3)
	assert_eq(_hud._sales_today_count, 0)


func test_customer_label_text_updates() -> void:
	_hud._customers_active_count = 0
	EventBus.customer_entered.emit({"customer_id": "c1"})
	var label: Label = _hud.get_node("TopBar/CustomersLabel")
	assert_string_contains(label.text, "1")


func test_sales_label_text_updates() -> void:
	_hud._sales_today_count = 0
	EventBus.item_sold.emit("item_a", 9.99, "music")
	var label: Label = _hud.get_node("TopBar/SalesTodayLabel")
	assert_string_contains(label.text, "1")


func test_sales_label_resets_text_on_day_started() -> void:
	_hud._sales_today_count = 5
	EventBus.day_started.emit(2)
	var label: Label = _hud.get_node("TopBar/SalesTodayLabel")
	assert_string_contains(label.text, "0")


func test_top_bar_within_minimum_viewport_width() -> void:
	var top_bar: HBoxContainer = _hud.get_node("TopBar")
	# Force layout pass so combined min size is computed.
	top_bar.queue_sort()
	await get_tree().process_frame
	var combined_min: Vector2 = top_bar.get_combined_minimum_size()
	assert_lt(
		combined_min.x, 1280.0,
		"TopBar combined min width must fit within 1280px viewport"
	)


func test_inventory_changed_handler_runs_without_system() -> void:
	# In test scope GameManager.get_inventory_system() returns null;
	# handler must early-return without erroring.
	EventBus.inventory_changed.emit()
	assert_eq(_hud._items_placed_count, 0)


func test_items_placed_label_text_updates_on_display_call() -> void:
	_hud._update_items_placed_display(1)
	var label: Label = _hud.get_node("TopBar/ItemsPlacedLabel")
	assert_string_contains(label.text, "1")


func test_items_placed_display_zero_produces_valid_text() -> void:
	_hud._update_items_placed_display(0)
	var label: Label = _hud.get_node("TopBar/ItemsPlacedLabel")
	assert_false(label.text.is_empty(), "ItemsPlacedLabel must not be empty")
	assert_false(
		label.text.to_lower().contains("null"),
		"ItemsPlacedLabel must not contain 'null'"
	)
	assert_string_contains(label.text, "0")


func test_customers_display_zero_produces_valid_text() -> void:
	_hud._update_customers_display(0)
	var label: Label = _hud.get_node("TopBar/CustomersLabel")
	assert_false(label.text.is_empty(), "CustomersLabel must not be empty")
	assert_false(
		label.text.to_lower().contains("null"),
		"CustomersLabel must not contain 'null'"
	)
	assert_string_contains(label.text, "0")


func test_sales_today_display_zero_produces_valid_text() -> void:
	_hud._update_sales_today_display(0)
	var label: Label = _hud.get_node("TopBar/SalesTodayLabel")
	assert_false(label.text.is_empty(), "SalesTodayLabel must not be empty")
	assert_false(
		label.text.to_lower().contains("null"),
		"SalesTodayLabel must not contain 'null'"
	)
	assert_string_contains(label.text, "0")


func test_customer_left_decrements_label_text() -> void:
	_hud._customers_active_count = 3
	EventBus.customer_left.emit({"customer_id": "c2"})
	var label: Label = _hud.get_node("TopBar/CustomersLabel")
	assert_string_contains(label.text, "2")


func test_item_sold_signal_connectable_with_checkout_signature() -> void:
	# Verifies item_sold accepts (String, float, String) — matching the
	# signature emitted by checkout_system.gd:_execute_sale.
	var calls: Array[int] = [0]
	var cb: Callable = (
		func(_id: String, _price: float, _cat: String) -> void: calls[0] += 1
	)
	EventBus.item_sold.connect(cb)
	EventBus.item_sold.emit("cart_001", 25.0, "cartridge")
	EventBus.item_sold.disconnect(cb)
	assert_eq(calls[0], 1, "item_sold must fire once with checkout_system signature")
