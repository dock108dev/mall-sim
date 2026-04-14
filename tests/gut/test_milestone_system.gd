## GUT tests for MilestoneSystem — progress tracking, signals, idempotency, save/load.
extends GutTest


var _progression: ProgressionSystem
var _economy: EconomySystem
var _reputation: ReputationSystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)
	_progression.initialize(_economy, _reputation)


# --- increment_progress increases running total ---


func test_increment_progress_increases_revenue_total() -> void:
	_progression.increment_progress("first_hundred", 40.0)
	assert_almost_eq(
		_progression.get_progress("first_hundred"), 40.0, 0.01,
		"Revenue should be 40 after incrementing by 40"
	)

	_progression.increment_progress("first_hundred", 30.0)
	assert_almost_eq(
		_progression.get_progress("first_hundred"), 70.0, 0.01,
		"Revenue should be 70 after incrementing by 30 more"
	)


func test_increment_progress_increases_items_sold_total() -> void:
	_progression.increment_progress("steady_seller", 3.0)
	assert_almost_eq(
		_progression.get_progress("steady_seller"), 3.0, 0.01,
		"Items sold should be 3 after incrementing by 3"
	)


func test_increment_progress_increases_days_total() -> void:
	_progression.increment_progress("getting_started", 2.0)
	assert_almost_eq(
		_progression.get_progress("getting_started"), 2.0, 0.01,
		"Days should be 2 after incrementing by 2"
	)


func test_increment_progress_increases_reputation_total() -> void:
	_progression.increment_progress("local_name", 5.0)
	assert_almost_eq(
		_progression.get_progress("local_name"), 5.0, 0.01,
		"Reputation should be 5 after incrementing by 5"
	)


# --- milestone_completed fires when threshold crossed ---


func test_milestone_completed_fires_at_threshold() -> void:
	var signal_fired: Array = [false]
	var received_id: Array = [""]
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		signal_fired[0] = true
		received_id[0] = id
	EventBus.milestone_completed.connect(on_milestone)

	_progression.increment_progress("first_sale", 1.0)

	assert_true(signal_fired[0], "milestone_completed should fire")
	assert_eq(received_id[0], "first_sale", "ID should be first_sale")

	EventBus.milestone_completed.disconnect(on_milestone)


func test_revenue_milestone_fires_at_threshold() -> void:
	var completed_ids: Array[String] = []
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		completed_ids.append(id)
	EventBus.milestone_completed.connect(on_milestone)

	_progression.increment_progress("first_hundred", 110.0)

	assert_true(
		completed_ids.has("first_hundred"),
		"first_hundred should fire when revenue >= 100"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


func test_signal_via_item_sold_event() -> void:
	var signal_fired: Array = [false]
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		if id == "first_sale":
			signal_fired[0] = true
	EventBus.milestone_completed.connect(on_milestone)

	EventBus.item_sold.emit("test_item", 25.0, "sports")

	assert_true(
		signal_fired[0],
		"milestone_completed should fire via item_sold event"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


func test_reputation_milestone_fires_on_change() -> void:
	var completed_ids: Array[String] = []
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		completed_ids.append(id)
	EventBus.milestone_completed.connect(on_milestone)

	EventBus.reputation_changed.emit("test_store", 15.0)

	assert_true(
		completed_ids.has("local_name"),
		"local_name should fire when reputation >= 10"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


func test_days_milestone_fires_on_day_ended() -> void:
	var completed_ids: Array[String] = []
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		completed_ids.append(id)
	EventBus.milestone_completed.connect(on_milestone)

	EventBus.day_started.emit(3)
	_reputation.reset()
	EventBus.day_ended.emit(3)

	assert_true(
		completed_ids.has("getting_started"),
		"getting_started should fire at day 3"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


# --- milestone_completed fires exactly once ---


func test_milestone_fires_exactly_once() -> void:
	var fire_count: Array = [0]
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		if id == "first_sale":
			fire_count[0] += 1
	EventBus.milestone_completed.connect(on_milestone)

	_progression.increment_progress("first_sale", 1.0)
	assert_eq(fire_count[0], 1, "first_sale should fire exactly once")

	_progression.increment_progress("first_sale", 1.0)
	assert_eq(
		fire_count[0], 1,
		"first_sale should not fire again on second increment"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


func test_duplicate_via_events_does_not_refire() -> void:
	var fire_count: Array = [0]
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		if id == "first_sale":
			fire_count[0] += 1
	EventBus.milestone_completed.connect(on_milestone)

	EventBus.item_sold.emit("item_a", 25.0, "sports")
	EventBus.item_sold.emit("item_b", 25.0, "sports")

	assert_eq(
		fire_count[0], 1,
		"first_sale should not fire again on second sale"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


# --- get_progress returns running total ---


func test_get_progress_returns_zero_initially() -> void:
	assert_almost_eq(
		_progression.get_progress("first_sale"), 0.0, 0.01,
		"Progress should start at 0"
	)


func test_get_progress_returns_accumulated_value() -> void:
	_progression.increment_progress("first_hundred", 25.0)
	_progression.increment_progress("first_hundred", 35.0)

	assert_almost_eq(
		_progression.get_progress("first_hundred"), 60.0, 0.01,
		"Progress should reflect accumulated increments"
	)


func test_get_progress_via_events() -> void:
	EventBus.item_sold.emit("item_a", 50.0, "sports")
	EventBus.item_sold.emit("item_b", 30.0, "sports")

	assert_almost_eq(
		_progression.get_progress("first_hundred"), 80.0, 0.01,
		"Revenue progress should reflect item_sold events"
	)
	assert_almost_eq(
		_progression.get_progress("first_sale"), 2.0, 0.01,
		"Items sold progress should reflect item_sold events"
	)


# --- is_completed returns true after threshold crossed ---


func test_is_completed_false_before_threshold() -> void:
	assert_false(
		_progression.is_milestone_completed("first_sale"),
		"first_sale should not be completed initially"
	)


func test_is_completed_true_after_threshold() -> void:
	_progression.increment_progress("first_sale", 1.0)

	assert_true(
		_progression.is_milestone_completed("first_sale"),
		"first_sale should be completed after threshold crossed"
	)


func test_is_completed_stays_true() -> void:
	_progression.increment_progress("first_sale", 1.0)
	_progression.increment_progress("first_sale", 5.0)

	assert_true(
		_progression.is_milestone_completed("first_sale"),
		"first_sale should remain completed"
	)


# --- serialize/deserialize round-trip ---


func test_save_load_preserves_completed_state() -> void:
	_progression.increment_progress("first_sale", 1.0)
	assert_true(_progression.is_milestone_completed("first_sale"))

	var save_data: Dictionary = _progression.get_save_data()

	var new_prog: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_prog)
	new_prog.initialize(_economy, _reputation)
	new_prog.load_save_data(save_data)

	assert_true(
		new_prog.is_milestone_completed("first_sale"),
		"Completed state should survive round-trip"
	)


func test_save_load_preserves_running_totals() -> void:
	_progression.increment_progress("first_hundred", 75.0)
	_progression.increment_progress("steady_seller", 5.0)

	var save_data: Dictionary = _progression.get_save_data()

	var new_prog: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_prog)
	new_prog.initialize(_economy, _reputation)
	new_prog.load_save_data(save_data)

	assert_almost_eq(
		new_prog.get_progress("first_hundred"), 75.0, 0.01,
		"Revenue total should survive round-trip"
	)
	assert_almost_eq(
		new_prog.get_progress("steady_seller"), 5.0, 0.01,
		"Items sold total should survive round-trip"
	)


func test_save_load_preserves_unlocked_fixtures() -> void:
	for i: int in range(10):
		EventBus.item_sold.emit("item_%d" % i, 5.0, "sports")

	assert_true(_progression.is_fixture_unlocked("wall_display"))

	var save_data: Dictionary = _progression.get_save_data()

	var new_prog: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_prog)
	new_prog.initialize(_economy, _reputation)
	new_prog.load_save_data(save_data)

	assert_true(
		new_prog.is_fixture_unlocked("wall_display"),
		"Fixture unlock should survive round-trip"
	)


func test_save_load_preserves_supplier_tier() -> void:
	EventBus.day_started.emit(7)
	_reputation.reset()
	EventBus.day_ended.emit(7)

	var save_data: Dictionary = _progression.get_save_data()

	var new_prog: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_prog)
	new_prog.initialize(_economy, _reputation)
	new_prog.load_save_data(save_data)

	assert_eq(
		new_prog.get_unlocked_supplier_tier(),
		_progression.get_unlocked_supplier_tier(),
		"Supplier tier should survive round-trip"
	)


# --- Unknown milestone_id triggers push_error ---


func test_increment_progress_unknown_id_is_noop() -> void:
	var items_before: float = _progression.get_progress("first_sale")

	_progression.increment_progress("nonexistent_milestone", 10.0)

	assert_almost_eq(
		_progression.get_progress("first_sale"), items_before, 0.01,
		"Unknown ID should not change any counters"
	)


func test_get_progress_unknown_id_returns_zero() -> void:
	var result: float = _progression.get_progress("nonexistent_milestone")

	assert_almost_eq(
		result, 0.0, 0.01,
		"Unknown ID should return 0.0"
	)


# --- Reward application ---


func test_cash_reward_adds_to_player_funds() -> void:
	var starting_cash: float = _economy._current_cash

	_progression.increment_progress("first_sale", 1.0)

	var expected_cash: float = starting_cash + 50.0
	assert_almost_eq(
		_economy._current_cash, expected_cash, 0.01,
		"Cash should include $50 first_sale milestone bonus"
	)


func test_fixture_unlock_reward_grants_fixture() -> void:
	assert_false(_progression.is_fixture_unlocked("wall_display"))

	for i: int in range(10):
		_progression.increment_progress("steady_seller", 1.0)

	assert_true(
		_progression.is_fixture_unlocked("wall_display"),
		"wall_display should be unlocked after steady_seller"
	)


func test_duplicate_reward_not_granted_twice() -> void:
	var starting_cash: float = _economy._current_cash

	_progression.increment_progress("first_sale", 1.0)
	var cash_after_first: float = _economy._current_cash

	_progression.increment_progress("first_sale", 1.0)
	var cash_after_second: float = _economy._current_cash

	assert_almost_eq(
		cash_after_first - starting_cash, 50.0, 0.01,
		"First completion should grant $50 bonus"
	)
	assert_almost_eq(
		cash_after_second, cash_after_first, 0.01,
		"Second increment should not re-grant bonus"
	)


# --- Progress fraction helper ---


func test_milestone_progress_fraction() -> void:
	_progression._total_items_sold = 5
	var milestones: Array[Dictionary] = _progression.get_milestones()
	var steady_seller: Dictionary = {}
	for m: Dictionary in milestones:
		if m.get("id", "") == "steady_seller":
			steady_seller = m
			break

	var progress: float = _progression.get_milestone_progress(
		steady_seller
	)
	assert_almost_eq(
		progress, 0.5, 0.01,
		"Progress should be 0.5 when 5/10 items sold"
	)


func test_milestone_progress_clamps_to_one() -> void:
	_progression._total_items_sold = 20
	var milestones: Array[Dictionary] = _progression.get_milestones()
	var steady_seller: Dictionary = {}
	for m: Dictionary in milestones:
		if m.get("id", "") == "steady_seller":
			steady_seller = m
			break

	var progress: float = _progression.get_milestone_progress(
		steady_seller
	)
	assert_almost_eq(
		progress, 1.0, 0.01,
		"Progress should clamp to 1.0 when threshold exceeded"
	)
