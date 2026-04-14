## Tests EconomySystem wiring to EventBus.customer_purchased signal.
extends GutTest


var _economy: EconomySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)


func test_customer_purchased_increases_cash() -> void:
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_001", 42.50, &"cust_1"
	)
	assert_almost_eq(
		_economy.get_cash(), 542.50, 0.01,
		"Cash should increase by exact price amount"
	)


func test_multiple_consecutive_purchases_accumulate() -> void:
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_a", 10.0, &"cust_1"
	)
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_b", 20.0, &"cust_2"
	)
	EventBus.customer_purchased.emit(
		&"pocket_creatures", &"item_c", 30.0, &"cust_3"
	)
	assert_almost_eq(
		_economy.get_cash(), 560.0, 0.01,
		"Multiple purchases should accumulate correctly"
	)


func test_customer_purchased_records_store_revenue() -> void:
	EventBus.customer_purchased.emit(
		&"video_rental", &"item_x", 15.0, &"cust_5"
	)
	assert_almost_eq(
		_economy.get_store_daily_revenue("video_rental"), 15.0, 0.01,
		"Store revenue should be recorded for the store_id"
	)


func test_customer_purchased_zero_price_ignored() -> void:
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_z", 0.0, &"cust_6"
	)
	assert_almost_eq(
		_economy.get_cash(), 500.0, 0.01,
		"Zero price purchase should not change cash"
	)


func test_customer_purchased_negative_price_ignored() -> void:
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_z", -5.0, &"cust_7"
	)
	assert_almost_eq(
		_economy.get_cash(), 500.0, 0.01,
		"Negative price purchase should not change cash"
	)
