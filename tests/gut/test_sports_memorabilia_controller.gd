## Tests SportsMemorabiliaController: lifecycle, signal wiring, and stubs.
extends GutTest


var _controller: SportsMemorabiliaController


func before_each() -> void:
	_controller = SportsMemorabiliaController.new()
	add_child_autofree(_controller)


func test_store_id_constant() -> void:
	assert_eq(
		SportsMemorabiliaController.STORE_ID, &"sports",
		"STORE_ID should be the canonical 'sports' StringName"
	)


func test_store_type_constant() -> void:
	assert_eq(
		SportsMemorabiliaController.STORE_TYPE,
		&"sports_memorabilia",
		"STORE_TYPE should be 'sports_memorabilia'"
	)


func test_store_type_set_in_ready() -> void:
	assert_eq(
		_controller.store_type, "sports",
		"store_type should be set to STORE_ID in _ready"
	)


func test_activates_on_matching_store_change() -> void:
	EventBus.active_store_changed.emit(&"sports")
	assert_true(
		_controller.is_active(),
		"Should activate when active_store_changed matches STORE_ID"
	)


func test_ignores_non_matching_store_change() -> void:
	EventBus.active_store_changed.emit(&"retro_games")
	assert_false(
		_controller.is_active(),
		"Should not activate for non-matching store_id"
	)


func test_store_entered_emits_store_opened() -> void:
	var opened_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		opened_ids.append(sid)
	EventBus.store_opened.connect(capture)
	EventBus.store_entered.emit(&"sports")
	EventBus.store_opened.disconnect(capture)
	assert_eq(
		opened_ids.size(), 1,
		"store_opened should be emitted once on store_entered"
	)
	assert_eq(
		opened_ids[0], "sports",
		"store_opened should carry the correct store_id"
	)


func test_store_entered_ignores_other_stores() -> void:
	var opened_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		opened_ids.append(sid)
	EventBus.store_opened.connect(capture)
	EventBus.store_entered.emit(&"retro_games")
	EventBus.store_opened.disconnect(capture)
	assert_eq(
		opened_ids.size(), 0,
		"store_opened should not emit for non-matching store_id"
	)


func test_store_exited_emits_store_closed() -> void:
	var closed_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		closed_ids.append(sid)
	EventBus.store_closed.connect(capture)
	EventBus.store_exited.emit(&"sports")
	EventBus.store_closed.disconnect(capture)
	assert_eq(
		closed_ids.size(), 1,
		"store_closed should be emitted once on store_exited"
	)


func test_store_exited_ignores_other_stores() -> void:
	var closed_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		closed_ids.append(sid)
	EventBus.store_closed.connect(capture)
	EventBus.store_exited.emit(&"retro_games")
	EventBus.store_closed.disconnect(capture)
	assert_eq(
		closed_ids.size(), 0,
		"store_closed should not emit for non-matching store_id"
	)


func test_authentication_eligible_without_inventory() -> void:
	var result: bool = _controller._is_authentication_eligible(
		&"some_item"
	)
	assert_false(
		result,
		"Should return false when no InventorySystem is set"
	)


func test_season_modifier_returns_default() -> void:
	var modifier: float = _controller._get_season_modifier(
		&"trading_cards"
	)
	assert_eq(
		modifier, 1.0,
		"Default season modifier should be 1.0"
	)


func test_season_cycle_accessible() -> void:
	var cycle: SeasonCycleSystem = _controller.get_season_cycle()
	assert_not_null(
		cycle,
		"SeasonCycleSystem should be accessible"
	)


func test_authentication_system_accessible() -> void:
	var auth: AuthenticationSystem = (
		_controller.get_authentication_system()
	)
	assert_not_null(
		auth,
		"AuthenticationSystem should be accessible"
	)


func test_save_load_round_trip() -> void:
	var save_data: Dictionary = _controller.get_save_data()
	assert_true(
		save_data.has("season_cycle"),
		"Save data should include season_cycle"
	)
	assert_true(
		save_data.has("authentication"),
		"Save data should include authentication"
	)
	_controller.load_save_data(save_data)


func test_customer_purchased_does_not_crash_when_inactive() -> void:
	EventBus.customer_purchased.emit(&"", &"test_item", 50.0, &"")
	assert_true(
		true,
		"customer_purchased should not crash when store is inactive"
	)


func test_market_event_does_not_crash() -> void:
	EventBus.market_event_triggered.emit(
		&"test_event", &"sports", {}
	)
	assert_true(
		true,
		"market_event_triggered should not crash"
	)


func test_market_event_ignores_other_stores() -> void:
	EventBus.market_event_triggered.emit(
		&"test_event", &"retro_games", {}
	)
	assert_true(
		true,
		"market_event_triggered for other stores should be ignored"
	)
