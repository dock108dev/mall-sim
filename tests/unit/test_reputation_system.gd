## Unit tests for ReputationSystem tier thresholds, event adjustments, and decay.
extends GutTest


var _rep: ReputationSystem


func before_each() -> void:
	GameManager.current_store_id = &"default"
	_rep = ReputationSystem.new()
	_rep.auto_connect_bus = true
	add_child_autofree(_rep)
	_rep._scores[ReputationSystemSingleton.DEFAULT_EVENT_STORE_ID] = 0.0
	_rep._tiers[ReputationSystemSingleton.DEFAULT_EVENT_STORE_ID] = (
		ReputationSystemSingleton.ReputationTier.NOTORIOUS
	)


func after_each() -> void:
	GameManager.current_store_id = &""


func test_initial_reputation_is_zero() -> void:
	assert_almost_eq(
		_rep.get_reputation(), 0.0, 0.01,
		"Fresh global reputation should start at zero"
	)


func test_add_reputation_event_increases_score() -> void:
	_rep.add_reputation_event("positive_sale", 10.0)
	assert_almost_eq(
		_rep.get_reputation(), 10.0, 0.01,
		"Reputation event magnitude should increase the score"
	)


func test_reputation_tier_upgrades_at_threshold() -> void:
	watch_signals(EventBus)
	_rep.add_reputation_event("positive_sale", 25.0)

	assert_eq(
		int(_rep.get_tier()),
		1,
		"Crossing the first threshold should advance to tier 1"
	)
	assert_signal_emitted(
		EventBus, "reputation_tier_changed",
		"Tier upgrade should emit reputation_tier_changed"
	)
	var params: Array = get_signal_parameters(
		EventBus, "reputation_tier_changed"
	)
	assert_eq(params[2] as int, 1, "Signal should carry new_tier = 1")


func test_reputation_tier_does_not_downgrade_immediately() -> void:
	_rep.add_reputation_event("positive_sale", 51.0)
	assert_eq(int(_rep.get_tier()), 2, "Setup should reach tier 2")

	_rep.add_reputation_event("bad_experience", -60.0)

	assert_lt(
		_rep.get_reputation(), 26.0,
		"Setup should bring score below the first threshold"
	)
	assert_eq(
		int(_rep.get_tier()), 2,
		"Event-driven tiers should not downgrade mid-day"
	)


func test_daily_decay_reduces_score() -> void:
	_rep.add_reputation_event("positive_sale", 80.0)
	var before: float = _rep.get_reputation()

	EventBus.day_ended.emit(1)

	assert_lt(
		_rep.get_reputation(), before,
		"Day end should apply reputation decay"
	)


func test_max_tier_is_4() -> void:
	_rep.add_reputation_event("legendary_run", 9999.0)
	assert_true(
		int(_rep.get_tier()) <= 4,
		"Reputation tier should never exceed 4"
	)


func test_serialize_deserialize_preserves_tier_and_score() -> void:
	_rep.add_reputation_event("positive_sale", 51.0)
	var expected_score: float = _rep.get_reputation()
	var expected_tier: int = int(_rep.get_tier())
	var data: Dictionary = _rep.get_save_data()

	var fresh: ReputationSystem = ReputationSystem.new()
	fresh.auto_connect_bus = false
	add_child_autofree(fresh)
	fresh.load_state(data)

	assert_eq(int(fresh.get_tier()), expected_tier, "Tier should survive load")
	assert_almost_eq(
		fresh.get_reputation(), expected_score, 0.01,
		"Score should survive load"
	)
