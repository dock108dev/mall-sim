## Tests ReputationSystem autoload — per-store scores, tiers, decay, save/load.
extends GutTest


const STORE_A: String = "sports_memorabilia"
const STORE_B: String = "retro_games"
var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)
	_rep.initialize_store(STORE_A)
	_rep.initialize_store(STORE_B)


# --- Default score ---


func test_new_store_starts_at_50() -> void:
	assert_eq(
		_rep.get_reputation(STORE_A), 50.0,
		"New store should start at 50.0 reputation"
	)


func test_uninitialized_store_returns_default() -> void:
	assert_eq(
		_rep.get_reputation("unknown_store"), 50.0,
		"Uninitialized store should return DEFAULT_REPUTATION"
	)


# --- add_reputation clamps and emits ---


func test_add_reputation_increases_score() -> void:
	_rep.add_reputation(STORE_A, 10.0)
	assert_eq(
		_rep.get_reputation(STORE_A), 60.0,
		"Score should increase by delta"
	)


func test_add_reputation_clamps_to_100() -> void:
	_rep.add_reputation(STORE_A, 200.0)
	assert_eq(
		_rep.get_reputation(STORE_A), 100.0,
		"Score should clamp to MAX_REPUTATION"
	)


func test_add_reputation_clamps_to_0() -> void:
	_rep.add_reputation(STORE_A, -200.0)
	assert_eq(
		_rep.get_reputation(STORE_A), 0.0,
		"Score should clamp to MIN_REPUTATION"
	)


func test_add_reputation_emits_signal() -> void:
	watch_signals(EventBus)
	_rep.add_reputation(STORE_A, 5.0)
	assert_signal_emitted(EventBus, "reputation_changed")


# --- Per-store isolation ---


func test_stores_have_independent_scores() -> void:
	_rep.add_reputation(STORE_A, 20.0)
	assert_eq(_rep.get_reputation(STORE_A), 70.0)
	assert_eq(
		_rep.get_reputation(STORE_B), 50.0,
		"Store B should be unaffected"
	)


# --- Tier thresholds ---


func test_tier_notorious_below_26() -> void:
	_rep.add_reputation(STORE_A, -50.0)
	assert_eq(
		_rep.get_tier(STORE_A),
		ReputationSystemSingleton.ReputationTier.NOTORIOUS,
		"Score 0 should be Notorious"
	)


func test_tier_unremarkable_at_26() -> void:
	_rep.add_reputation(STORE_A, -25.0)
	assert_eq(
		_rep.get_tier(STORE_A),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Score 25 should be Local Favorite"
	)


func test_tier_reputable_at_51() -> void:
	assert_eq(
		_rep.get_tier(STORE_A),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Score 50 should be Destination Shop"
	)


func test_tier_legendary_at_76() -> void:
	_rep.add_reputation(STORE_A, 30.0)
	assert_eq(
		_rep.get_tier(STORE_A),
		ReputationSystemSingleton.ReputationTier.LEGENDARY,
		"Score 80 should be Legendary"
	)


# --- Global reputation ---


func test_global_reputation_is_average() -> void:
	_rep.add_reputation(STORE_A, 10.0)
	_rep.add_reputation(STORE_B, -10.0)
	assert_eq(
		_rep.get_global_reputation(), 50.0,
		"Global rep should be average of store scores"
	)


func test_global_reputation_empty_returns_default() -> void:
	var fresh: ReputationSystem = ReputationSystem.new()
	add_child_autofree(fresh)
	assert_eq(
		fresh.get_global_reputation(), 50.0,
		"Empty system should return DEFAULT_REPUTATION"
	)


# --- Daily decay ---


func test_daily_decay_reduces_scores_above_50() -> void:
	_rep.add_reputation(STORE_A, 20.0)
	_rep._on_day_ended(1)
	assert_almost_eq(
		_rep.get_reputation(STORE_A), 69.7, 0.01,
		"Score above 50 should decay by 0.3"
	)


func test_daily_decay_does_not_reduce_below_50() -> void:
	_rep._on_day_ended(1)
	assert_eq(
		_rep.get_reputation(STORE_A), 50.0,
		"Score at 50 should not decay"
	)


func test_daily_decay_does_not_reduce_below_50_from_low() -> void:
	_rep.add_reputation(STORE_A, -10.0)
	_rep._on_day_ended(1)
	assert_eq(
		_rep.get_reputation(STORE_A), 40.0,
		"Score below 50 should not decay"
	)


# --- Save/load ---


func test_save_load_round_trip() -> void:
	_rep.add_reputation(STORE_A, 25.0)
	_rep.add_reputation(STORE_B, -10.0)

	var save_data: Dictionary = _rep.get_save_data()

	var loaded: ReputationSystem = ReputationSystem.new()
	add_child_autofree(loaded)
	loaded.load_save_data(save_data)

	assert_eq(
		loaded.get_reputation(STORE_A), 75.0,
		"Store A score should survive save/load"
	)
	assert_eq(
		loaded.get_reputation(STORE_B), 40.0,
		"Store B score should survive save/load"
	)


# --- EventBus integration helpers ---


func test_item_price_set_then_customer_purchase_applies_fair_sale_delta() -> void:
	_rep._on_item_price_set(&"sports_memorabilia", &"item_a", 12.0, 1.2)
	_rep._on_customer_purchased(
		&"sports_memorabilia", &"item_a", 12.0, &"customer_a"
	)
	assert_almost_eq(
		_rep.get_reputation(STORE_A),
		50.0 + ReputationSystemSingleton.REP_FAIR_SALE,
		0.01,
		"Fair sale markup should add REP_FAIR_SALE"
	)


func test_overpriced_customer_purchase_applies_overpriced_delta() -> void:
	_rep._on_item_price_set(&"sports_memorabilia", &"item_b", 19.0, 1.9)
	_rep._on_customer_purchased(
		&"sports_memorabilia", &"item_b", 19.0, &"customer_b"
	)
	assert_almost_eq(
		_rep.get_reputation(STORE_A),
		50.0 + ReputationSystemSingleton.REP_OVERPRICED_SALE,
		0.01,
		"Overpriced sale markup should add REP_OVERPRICED_SALE"
	)


func test_haggle_completed_uses_signal_store_id() -> void:
	_rep._on_haggle_completed(
		&"retro_games", &"item_c", 15.0, 20.0, true, 1
	)
	assert_almost_eq(
		_rep.get_reputation(STORE_B),
		50.0 + ReputationSystemSingleton.REP_HAGGLE_ACCEPTED,
		0.01,
		"Accepted haggle should apply to the emitted store_id"
	)
	assert_eq(
		_rep.get_reputation(STORE_A),
		50.0,
		"Accepted haggle should not affect another store"
	)


func test_global_reputation_uses_owned_store_ids_when_present() -> void:
	_rep._on_lease_completed(&"sports_memorabilia", true, "")
	_rep.add_reputation(STORE_A, 10.0)
	_rep.add_reputation(STORE_B, -10.0)
	assert_eq(
		_rep.get_global_reputation(),
		60.0,
		"Global reputation should average owned stores when ownership is known"
	)


# --- modify_reputation alias ---


func test_modify_reputation_works_as_alias() -> void:
	_rep.modify_reputation(STORE_A, 5.0)
	assert_eq(
		_rep.get_reputation(STORE_A), 55.0,
		"modify_reputation should work as alias for add_reputation"
	)


# --- Tier name ---


func test_tier_name_notorious() -> void:
	_rep.add_reputation(STORE_A, -50.0)
	assert_eq(_rep.get_tier_name(STORE_A), "Unknown")


func test_tier_name_unremarkable() -> void:
	_rep.add_reputation(STORE_A, -25.0)
	assert_eq(_rep.get_tier_name(STORE_A), "Local Favorite")


func test_tier_name_reputable() -> void:
	assert_eq(_rep.get_tier_name(STORE_A), "Destination Shop")


func test_tier_name_legendary() -> void:
	_rep.add_reputation(STORE_A, 30.0)
	assert_eq(_rep.get_tier_name(STORE_A), "Legendary")


# --- customer_left_mall satisfaction wiring ---


func test_satisfied_customer_adds_reputation() -> void:
	GameManager.current_store_id = &"sports_memorabilia"
	var before: float = _rep.get_reputation(STORE_A)
	_rep._on_customer_left_mall(null, true)
	assert_eq(
		_rep.get_reputation(STORE_A),
		before + ReputationSystemSingleton.SATISFACTION_GAIN,
		"Satisfied customer should add SATISFACTION_GAIN"
	)
	GameManager.current_store_id = &""


func test_dissatisfied_customer_removes_reputation() -> void:
	GameManager.current_store_id = &"sports_memorabilia"
	var before: float = _rep.get_reputation(STORE_A)
	_rep._on_customer_left_mall(null, false)
	assert_eq(
		_rep.get_reputation(STORE_A),
		before + ReputationSystemSingleton.DISSATISFACTION_LOSS,
		"Dissatisfied customer should subtract DISSATISFACTION_LOSS"
	)
	GameManager.current_store_id = &""


func test_customer_left_mall_skips_when_no_active_store() -> void:
	GameManager.current_store_id = &""
	var before_a: float = _rep.get_reputation(STORE_A)
	var before_b: float = _rep.get_reputation(STORE_B)
	_rep._on_customer_left_mall(null, true)
	assert_eq(
		_rep.get_reputation(STORE_A), before_a,
		"No store should change when active_store_id is empty"
	)
	assert_eq(
		_rep.get_reputation(STORE_B), before_b,
		"No store should change when active_store_id is empty"
	)


# --- Tier change toasts ---


func test_tier_up_emits_toast_requested() -> void:
	_rep.add_reputation(STORE_A, -1.0)
	watch_signals(EventBus)
	_rep.add_reputation(STORE_A, 1.0)
	assert_signal_emitted(
		EventBus, "toast_requested",
		"Crossing from Local Favorite to Destination Shop should emit toast"
	)


func test_tier_down_emits_toast_requested() -> void:
	watch_signals(EventBus)
	_rep.add_reputation(STORE_A, -1.0)
	assert_signal_emitted(
		EventBus, "toast_requested",
		"Crossing from Destination Shop to Local Favorite should emit toast"
	)


func test_same_tier_score_change_does_not_emit_toast() -> void:
	_rep.add_reputation(STORE_A, 1.0)
	watch_signals(EventBus)
	_rep.add_reputation(STORE_A, 5.0)
	assert_signal_not_emitted(
		EventBus, "toast_requested",
		"Score change within same tier should not emit toast"
	)


func test_tier_up_toast_has_4s_duration() -> void:
	_rep.add_reputation(STORE_A, -1.0)
	watch_signals(EventBus)
	_rep.add_reputation(STORE_A, 1.0)
	var params: Array = get_signal_parameters(
		EventBus, "toast_requested"
	)
	assert_eq(
		params[2], 4.0,
		"Tier-up toast duration should be 4.0"
	)


func test_tier_down_toast_has_5s_duration() -> void:
	watch_signals(EventBus)
	_rep.add_reputation(STORE_A, -1.0)
	var params: Array = get_signal_parameters(
		EventBus, "toast_requested"
	)
	assert_eq(
		params[2], 5.0,
		"Tier-down toast duration should be 5.0"
	)


func test_tier_up_toast_category_is_reputation_up() -> void:
	_rep.add_reputation(STORE_A, -1.0)
	watch_signals(EventBus)
	_rep.add_reputation(STORE_A, 1.0)
	var params: Array = get_signal_parameters(
		EventBus, "toast_requested"
	)
	assert_eq(
		params[1], &"reputation_up",
		"Tier-up toast category should be reputation_up"
	)


func test_tier_down_toast_category_is_reputation_down() -> void:
	watch_signals(EventBus)
	_rep.add_reputation(STORE_A, -1.0)
	var params: Array = get_signal_parameters(
		EventBus, "toast_requested"
	)
	assert_eq(
		params[1], &"reputation_down",
		"Tier-down toast category should be reputation_down"
	)


func test_customer_left_mall_triggers_tier_change_signal() -> void:
	GameManager.current_store_id = &"sports_memorabilia"
	_rep.add_reputation(STORE_A, -24.5)
	watch_signals(EventBus)
	_rep._on_customer_left_mall(null, false)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"Tier-crossing adjustment should emit reputation_changed"
	)
	GameManager.current_store_id = &""
