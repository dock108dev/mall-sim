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


func test_customer_purchased_increments_served_today() -> void:
	_hud._customers_served_today_count = 0
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_a", 12.0, &"c1"
	)
	assert_eq(_hud._customers_served_today_count, 1)


func test_customer_purchased_accumulates_served_today() -> void:
	_hud._customers_served_today_count = 0
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_a", 12.0, &"c1"
	)
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_b", 5.0, &"c2"
	)
	assert_eq(
		_hud._customers_served_today_count, 2,
		"each customer_purchased must add one served-today increment"
	)


func test_day_started_resets_customers_served_today() -> void:
	_hud._customers_served_today_count = 5
	EventBus.day_started.emit(3)
	assert_eq(
		_hud._customers_served_today_count, 0,
		"day_started must reset the cumulative customers-served-today counter"
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
	_hud._customers_served_today_count = 0
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_a", 12.0, &"c1"
	)
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
	# Project window is 1920x1080 (project.godot). 1600 keeps a safety margin
	# while allowing room for the unambiguous metric labels in TopBar.
	assert_lt(
		combined_min.x, 1600.0,
		"TopBar combined min width must fit within 1600px (target 1920x1080)"
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


func test_day_started_resets_customers_label_text() -> void:
	_hud._customers_served_today_count = 5
	EventBus.day_started.emit(2)
	var label: Label = _hud.get_node("TopBar/CustomersLabel")
	assert_string_contains(
		label.text, "0",
		"CustomersLabel must reflect the day-reset count"
	)


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
