## Tests for ProgressionSystem milestone unlock, reward application, and idempotency.
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
	_reputation.initialize()

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)
	_progression.initialize(_economy, _reputation)


# --- Milestone unlock fires signal with correct data ---


func test_first_sale_milestone_fires_signal() -> void:
	var signal_fired: bool = false
	var received_id: String = ""
	var received_name: String = ""
	var received_desc: String = ""
	var on_milestone: Callable = func(
		id: String, mname: String, desc: String
	) -> void:
		signal_fired = true
		received_id = id
		received_name = mname
		received_desc = desc
	EventBus.milestone_completed.connect(on_milestone)

	EventBus.item_sold.emit("test_item", 25.0, "sports")

	assert_true(signal_fired, "milestone_completed should fire after first sale")
	assert_eq(received_id, "first_sale", "Milestone ID should be first_sale")
	assert_eq(
		received_name, "First Sale!",
		"Milestone name should match definition"
	)
	assert_true(
		received_desc.length() > 0,
		"Reward description should not be empty"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


func test_revenue_milestone_fires_at_threshold() -> void:
	var completed_ids: Array[String] = []
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		completed_ids.append(id)
	EventBus.milestone_completed.connect(on_milestone)

	EventBus.item_sold.emit("item_a", 50.0, "sports")
	EventBus.item_sold.emit("item_b", 55.0, "sports")

	assert_true(
		completed_ids.has("first_hundred"),
		"first_hundred milestone should fire when revenue >= 100"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


func test_reputation_milestone_fires_on_change() -> void:
	var completed_ids: Array[String] = []
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		completed_ids.append(id)
	EventBus.milestone_completed.connect(on_milestone)

	EventBus.reputation_changed.emit(0.0, 15.0)

	assert_true(
		completed_ids.has("local_name"),
		"local_name milestone should fire when reputation >= 10"
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
	_reputation._score = 0.0
	EventBus.day_ended.emit(3)

	assert_true(
		completed_ids.has("getting_started"),
		"getting_started milestone should fire at day 3"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


func test_items_sold_milestone_fires_at_threshold() -> void:
	var completed_ids: Array[String] = []
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		completed_ids.append(id)
	EventBus.milestone_completed.connect(on_milestone)

	for i: int in range(10):
		EventBus.item_sold.emit("item_%d" % i, 5.0, "sports")

	assert_true(
		completed_ids.has("steady_seller"),
		"steady_seller milestone should fire after 10 items sold"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


# --- Reward application ---


func test_cash_reward_adds_to_player_funds() -> void:
	var starting_cash: float = _economy._current_cash

	EventBus.item_sold.emit("test_item", 25.0, "sports")

	var expected_cash: float = starting_cash + 25.0 + 50.0
	assert_almost_eq(
		_economy._current_cash, expected_cash, 0.01,
		"Cash should include sale revenue + $50 first_sale milestone bonus"
	)


func test_fixture_unlock_reward_grants_fixture() -> void:
	assert_false(
		_progression.is_fixture_unlocked("wall_display"),
		"wall_display should not be unlocked initially"
	)

	for i: int in range(10):
		EventBus.item_sold.emit("item_%d" % i, 5.0, "sports")

	assert_true(
		_progression.is_fixture_unlocked("wall_display"),
		"wall_display should be unlocked after steady_seller milestone"
	)


func test_supplier_tier_reward_grants_tier() -> void:
	assert_eq(
		_progression.get_unlocked_supplier_tier(), 0,
		"Supplier tier should start at 0"
	)

	EventBus.day_started.emit(7)
	_reputation._score = 0.0
	EventBus.day_ended.emit(7)

	assert_eq(
		_progression.get_unlocked_supplier_tier(), 1,
		"Supplier tier should be 1 after week_one milestone"
	)


func test_store_slot_reward_grants_slot() -> void:
	assert_eq(
		_progression.get_unlocked_store_slots(), 1,
		"Store slots should start at 1"
	)

	_progression._total_revenue = 999.0
	EventBus.item_sold.emit("big_sale", 50.0, "sports")

	var slots: int = _progression.get_unlocked_store_slots()
	assert_true(
		slots > 1,
		"Store slots should increase after big_earner milestone"
	)


# --- Idempotency: duplicate milestone does not re-fire or re-grant ---


func test_duplicate_milestone_does_not_fire_signal_again() -> void:
	var first_sale_fire_count: int = 0
	var on_milestone: Callable = func(
		id: String, _mname: String, _desc: String
	) -> void:
		if id == "first_sale":
			first_sale_fire_count += 1
	EventBus.milestone_completed.connect(on_milestone)

	EventBus.item_sold.emit("item_a", 25.0, "sports")
	assert_eq(
		first_sale_fire_count, 1,
		"first_sale should fire exactly once on first sale"
	)

	EventBus.item_sold.emit("item_b", 25.0, "sports")
	assert_eq(
		first_sale_fire_count, 1,
		"first_sale should not fire again on second sale"
	)
	assert_true(
		_progression.is_milestone_completed("first_sale"),
		"first_sale should remain completed"
	)

	EventBus.milestone_completed.disconnect(on_milestone)


func test_duplicate_milestone_does_not_grant_reward_twice() -> void:
	var starting_cash: float = _economy._current_cash

	EventBus.item_sold.emit("item_a", 25.0, "sports")
	var cash_after_first: float = _economy._current_cash

	EventBus.item_sold.emit("item_b", 25.0, "sports")
	var cash_after_second: float = _economy._current_cash

	var first_sale_bonus: float = cash_after_first - starting_cash - 25.0
	var second_sale_delta: float = cash_after_second - cash_after_first

	assert_almost_eq(
		first_sale_bonus, 50.0, 0.01,
		"First sale should grant $50 milestone bonus"
	)
	assert_true(
		second_sale_delta < 75.0,
		"Second sale should not re-grant the $50 first_sale bonus"
	)


func test_completed_milestone_stays_completed_across_evaluations() -> void:
	EventBus.item_sold.emit("item_a", 25.0, "sports")
	assert_true(
		_progression.is_milestone_completed("first_sale"),
		"first_sale should be completed"
	)

	EventBus.day_started.emit(1)
	_reputation._score = 0.0
	EventBus.day_ended.emit(1)

	assert_true(
		_progression.is_milestone_completed("first_sale"),
		"first_sale should still be completed after day_ended evaluation"
	)


# --- Progress tracking ---


func test_milestone_progress_returns_correct_fraction() -> void:
	_progression._total_items_sold = 5
	var milestones: Array[Dictionary] = _progression.get_milestones()
	var steady_seller: Dictionary = {}
	for m: Dictionary in milestones:
		if m.get("id", "") == "steady_seller":
			steady_seller = m
			break

	assert_true(
		steady_seller.size() > 0,
		"steady_seller milestone should exist in definitions"
	)

	var progress: float = _progression.get_milestone_progress(steady_seller)
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

	var progress: float = _progression.get_milestone_progress(steady_seller)
	assert_almost_eq(
		progress, 1.0, 0.01,
		"Progress should clamp to 1.0 when threshold exceeded"
	)


# --- Save/load round-trip ---


func test_save_and_load_preserves_completed_milestones() -> void:
	EventBus.item_sold.emit("item_a", 25.0, "sports")
	assert_true(
		_progression.is_milestone_completed("first_sale"),
		"first_sale should be completed before save"
	)

	var save_data: Dictionary = _progression.get_save_data()

	var new_progression: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_progression)
	new_progression.initialize(_economy, _reputation)
	new_progression.load_save_data(save_data)

	assert_true(
		new_progression.is_milestone_completed("first_sale"),
		"first_sale should be completed after load"
	)
	assert_almost_eq(
		new_progression.get_total_revenue(), _progression.get_total_revenue(),
		0.01,
		"Total revenue should be preserved after load"
	)
	assert_eq(
		new_progression.get_total_items_sold(),
		_progression.get_total_items_sold(),
		"Total items sold should be preserved after load"
	)


func test_save_and_load_preserves_unlocked_fixtures() -> void:
	for i: int in range(10):
		EventBus.item_sold.emit("item_%d" % i, 5.0, "sports")

	assert_true(
		_progression.is_fixture_unlocked("wall_display"),
		"wall_display should be unlocked before save"
	)

	var save_data: Dictionary = _progression.get_save_data()

	var new_progression: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_progression)
	new_progression.initialize(_economy, _reputation)
	new_progression.load_save_data(save_data)

	assert_true(
		new_progression.is_fixture_unlocked("wall_display"),
		"wall_display should still be unlocked after load"
	)
