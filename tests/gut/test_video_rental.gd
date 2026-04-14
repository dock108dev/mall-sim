## Tests VideoRental controller: initialization, stub methods, and lifecycle.
extends GutTest


var _controller: VideoRental


func before_each() -> void:
	_controller = VideoRental.new()
	add_child_autofree(_controller)


func test_store_id_constant() -> void:
	assert_eq(
		VideoRental.STORE_ID, &"video_rental",
		"STORE_ID should be video_rental"
	)


func test_store_type_set_in_ready() -> void:
	assert_eq(
		_controller.store_type, "video_rental",
		"store_type should be set to STORE_ID in _ready"
	)


func test_extends_store_controller() -> void:
	assert_true(
		_controller is StoreController,
		"VideoRental should extend StoreController"
	)


func test_initialize_creates_empty_rentals() -> void:
	_controller.initialize()
	assert_eq(
		_controller._active_rentals.size(), 0,
		"_active_rentals should be empty after initialize"
	)


func test_initialize_idempotent() -> void:
	_controller.initialize()
	_controller._active_rentals["test_item"] = 5
	_controller.initialize()
	assert_true(
		_controller._active_rentals.has("test_item"),
		"Second initialize should not reset state"
	)


func test_rent_item_stub_returns_false() -> void:
	var result: bool = _controller.rent_item(&"some_item", Node.new())
	assert_false(result, "rent_item stub should return false")


func test_get_rental_status_default_available() -> void:
	_controller.initialize()
	var status: StringName = _controller.get_rental_status(&"any_item")
	assert_eq(
		status, &"available",
		"get_rental_status should return available by default"
	)


func test_get_rental_status_rented() -> void:
	_controller.initialize()
	_controller._active_rentals["rented_item"] = 5
	var status: StringName = _controller.get_rental_status(&"rented_item")
	assert_eq(
		status, &"rented",
		"get_rental_status should return rented for tracked items"
	)


func test_check_overdue_rentals_no_crash() -> void:
	_controller.initialize()
	_controller._check_overdue_rentals()
	assert_true(true, "_check_overdue_rentals stub should not crash")


func test_process_daily_returns_no_crash() -> void:
	_controller.initialize()
	_controller._process_daily_returns()
	assert_true(true, "_process_daily_returns stub should not crash")


func test_save_data_round_trip() -> void:
	_controller.initialize()
	_controller._active_rentals["test_tape"] = 3
	var saved: Dictionary = _controller.get_save_data()
	_controller._active_rentals.clear()
	_controller.load_save_data(saved)
	assert_true(
		_controller._active_rentals.has("test_tape"),
		"Rental state should survive save/load round trip"
	)


func test_load_save_data_empty() -> void:
	_controller.initialize()
	_controller._active_rentals["old"] = 1
	_controller.load_save_data({})
	assert_eq(
		_controller._active_rentals.size(), 0,
		"load_save_data with empty dict should clear rentals"
	)


func test_activation_on_store_change() -> void:
	EventBus.active_store_changed.emit(&"video_rental")
	assert_true(
		_controller.is_active(),
		"Controller should activate on matching store ID"
	)


func test_no_null_errors_without_inventory() -> void:
	_controller.initialize()
	EventBus.store_entered.emit(&"video_rental")
	assert_true(true, "Store entry without inventory should not crash")
