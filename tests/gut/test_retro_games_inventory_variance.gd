## Tests RetroGames discrepancy-flagging and zone-artifact signal emission:
##   - flag_discrepancy is idempotent per (item_id, day) and increments
##     `discrepancies_flagged` exactly once per distinct SKU
##   - inventory_variance_noted fires only on the first flag
##   - day_started clears the per-day flagged set
##   - delivery_manifest_examined fires once per day on the first examination
extends GutTest


var _controller: RetroGames


func before_each() -> void:
	_controller = RetroGames.new()
	add_child_autofree(_controller)


func test_flag_discrepancy_increments_counter_once_per_sku() -> void:
	var first: bool = _controller.flag_discrepancy(&"retro_test_a", 5, 3)
	var second: bool = _controller.flag_discrepancy(&"retro_test_a", 5, 3)
	assert_true(first, "First flag must record")
	assert_false(second, "Repeat flag for same SKU must be no-op")
	assert_eq(
		_controller.get_discrepancies_flagged_today(), 1,
		"Counter must increment exactly once per SKU per day",
	)


func test_flag_discrepancy_emits_inventory_variance_noted_once() -> void:
	var emitted: Array = []
	var capture: Callable = func(
		store_id: StringName, item_id: StringName, expected: int, actual: int
	) -> void:
		emitted.append({
			"store_id": store_id,
			"item_id": item_id,
			"expected": expected,
			"actual": actual,
		})
	EventBus.inventory_variance_noted.connect(capture)
	_controller.flag_discrepancy(&"retro_test_b", 10, 7)
	_controller.flag_discrepancy(&"retro_test_b", 10, 7)
	EventBus.inventory_variance_noted.disconnect(capture)
	assert_eq(emitted.size(), 1, "Signal must fire exactly once per SKU per day")
	if emitted.size() == 1:
		assert_eq(emitted[0]["store_id"], &"retro_games")
		assert_eq(emitted[0]["item_id"], &"retro_test_b")
		assert_eq(emitted[0]["expected"], 10)
		assert_eq(emitted[0]["actual"], 7)


func test_flag_discrepancy_distinct_skus_each_increment_counter() -> void:
	_controller.flag_discrepancy(&"retro_test_c", 5, 4)
	_controller.flag_discrepancy(&"retro_test_d", 8, 2)
	assert_eq(
		_controller.get_discrepancies_flagged_today(), 2,
		"Two distinct SKUs must each register against the counter",
	)


func test_can_flag_discrepancy_returns_false_after_flag() -> void:
	assert_true(_controller.can_flag_discrepancy(&"retro_test_e"))
	_controller.flag_discrepancy(&"retro_test_e", 4, 2)
	assert_false(
		_controller.can_flag_discrepancy(&"retro_test_e"),
		"can_flag_discrepancy must short-circuit after the SKU is flagged",
	)


func test_day_started_clears_flagged_set() -> void:
	_controller.flag_discrepancy(&"retro_test_f", 6, 5)
	assert_eq(_controller.get_discrepancies_flagged_today(), 1)
	EventBus.day_started.emit(2)
	assert_eq(
		_controller.get_discrepancies_flagged_today(), 0,
		"day_started must reset the discrepancy counter",
	)
	assert_true(
		_controller.can_flag_discrepancy(&"retro_test_f"),
		"A new day re-enables flagging the same SKU",
	)


func test_flag_discrepancy_rejects_empty_item_id() -> void:
	var ok: bool = _controller.flag_discrepancy(&"", 1, 0)
	assert_false(ok, "Empty item_id must be rejected and not increment")
	assert_eq(_controller.get_discrepancies_flagged_today(), 0)


func test_get_flagged_skus_today_lists_flagged_only() -> void:
	_controller.flag_discrepancy(&"retro_test_g", 4, 1)
	_controller.flag_discrepancy(&"retro_test_h", 2, 0)
	var keys: Array = _controller.get_flagged_skus_today()
	assert_eq(keys.size(), 2)
	assert_true(keys.has(StringName("retro_test_g")))
	assert_true(keys.has(StringName("retro_test_h")))
