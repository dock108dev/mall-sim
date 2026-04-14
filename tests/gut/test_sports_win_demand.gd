## Tests for sports_win market event demand hooks in SportsMemorabiliaController.
extends GutTest


var _controller: SportsMemorabiliaController


func before_each() -> void:
	_controller = SportsMemorabiliaController.new()
	add_child_autofree(_controller)


func after_each() -> void:
	if _controller._market_event_connected:
		_controller._disconnect_market_event_signals()


func test_season_boost_inactive_by_default() -> void:
	assert_false(
		_controller._season_boost_active,
		"Season boost should be inactive by default"
	)


func test_default_season_boost_value() -> void:
	assert_almost_eq(
		_controller._season_boost_value, 1.5, 0.001,
		"Default season boost should be 1.5"
	)


func test_get_demand_multiplier_returns_one_when_inactive() -> void:
	var mult: float = _controller.get_demand_multiplier(
		&"memorabilia"
	)
	assert_almost_eq(
		mult, 1.0, 0.001,
		"Should return 1.0 when boost is inactive"
	)


func test_get_demand_multiplier_memorabilia_when_active() -> void:
	_controller._season_boost_active = true
	var mult: float = _controller.get_demand_multiplier(
		&"memorabilia"
	)
	assert_almost_eq(
		mult, 1.5, 0.001,
		"memorabilia category should get the boost"
	)


func test_get_demand_multiplier_autograph_when_active() -> void:
	_controller._season_boost_active = true
	var mult: float = _controller.get_demand_multiplier(
		&"autograph"
	)
	assert_almost_eq(
		mult, 1.5, 0.001,
		"autograph category should get the boost"
	)


func test_get_demand_multiplier_other_category_unaffected() -> void:
	_controller._season_boost_active = true
	var mult: float = _controller.get_demand_multiplier(
		&"trading_cards"
	)
	assert_almost_eq(
		mult, 1.0, 0.001,
		"Non-boosted categories should return 1.0"
	)


func test_get_demand_multiplier_sealed_packs_unaffected() -> void:
	_controller._season_boost_active = true
	var mult: float = _controller.get_demand_multiplier(
		&"sealed_packs"
	)
	assert_almost_eq(
		mult, 1.0, 0.001,
		"sealed_packs should not receive the boost"
	)


func test_custom_boost_value_applied() -> void:
	_controller._season_boost_value = 2.0
	_controller._season_boost_active = true
	var mult: float = _controller.get_demand_multiplier(
		&"memorabilia"
	)
	assert_almost_eq(
		mult, 2.0, 0.001,
		"Custom boost value should be applied"
	)


func test_connect_signals_on_store_entered() -> void:
	assert_false(
		_controller._market_event_connected,
		"Should not be connected before store entered"
	)
	EventBus.store_entered.emit(&"sports")
	assert_true(
		_controller._market_event_connected,
		"Should connect market event signals on store entered"
	)


func test_disconnect_signals_on_store_exited() -> void:
	EventBus.store_entered.emit(&"sports")
	assert_true(_controller._market_event_connected)
	EventBus.store_exited.emit(&"sports")
	assert_false(
		_controller._market_event_connected,
		"Should disconnect market event signals on store exited"
	)


func test_no_duplicate_connections() -> void:
	EventBus.store_entered.emit(&"sports")
	EventBus.store_entered.emit(&"sports")
	assert_true(
		_controller._market_event_connected,
		"Should still be connected after double entry"
	)
	EventBus.store_exited.emit(&"sports")
	assert_false(
		_controller._market_event_connected,
		"Single disconnect should clean up"
	)


func test_enter_exit_enter_cycle() -> void:
	EventBus.store_entered.emit(&"sports")
	assert_true(_controller._market_event_connected)
	EventBus.store_exited.emit(&"sports")
	assert_false(_controller._market_event_connected)
	EventBus.store_entered.emit(&"sports")
	assert_true(
		_controller._market_event_connected,
		"Should reconnect after exit/enter cycle"
	)


func test_other_store_enter_does_not_connect() -> void:
	EventBus.store_entered.emit(&"retro_games")
	assert_false(
		_controller._market_event_connected,
		"Should not connect for non-matching store"
	)


func test_other_store_exit_does_not_disconnect() -> void:
	EventBus.store_entered.emit(&"sports")
	EventBus.store_exited.emit(&"retro_games")
	assert_true(
		_controller._market_event_connected,
		"Should not disconnect for non-matching store"
	)


func test_save_data_includes_boost_state() -> void:
	_controller._season_boost_active = true
	var data: Dictionary = _controller.get_save_data()
	assert_true(
		data.has("season_boost_active"),
		"Save data should include season_boost_active"
	)
	assert_true(
		data["season_boost_active"] as bool,
		"season_boost_active should be true in save data"
	)


func test_load_data_restores_boost_state() -> void:
	var data: Dictionary = {
		"season_cycle": {},
		"season_boost_active": true,
	}
	_controller.load_save_data(data)
	assert_true(
		_controller._season_boost_active,
		"load_save_data should restore season_boost_active"
	)


func test_load_data_defaults_boost_to_false() -> void:
	_controller._season_boost_active = true
	var data: Dictionary = {"season_cycle": {}}
	_controller.load_save_data(data)
	assert_false(
		_controller._season_boost_active,
		"Missing key should default to false"
	)
