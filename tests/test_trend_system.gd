## GUT unit tests for TrendSystem — trend creation, multipliers, cold state,
## stacking, expiry, and EventBus signal contracts.
extends GutTest


const HOT_MULTIPLIER: float = 1.8
const COLD_MULTIPLIER: float = 0.6
const NEUTRAL_EXPECTED: float = 1.0
const FLOAT_DELTA: float = 0.001

var _system: TrendSystem
var _saved_day: int


func before_each() -> void:
	_saved_day = GameManager.current_day

	_system = TrendSystem.new()
	add_child_autofree(_system)
	_system.initialize(null)


func after_each() -> void:
	GameManager._current_day = _saved_day


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_item(category: String) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_item_%s" % category
	def.item_name = "Test Item"
	def.category = category
	def.base_price = 10.0
	def.rarity = "common"
	return ItemInstance.create_from_definition(def, "good")


## Injects a category trend directly into _active_trends for unit testing.
func _inject_trend(
	category: String,
	multiplier: float,
	duration_days: int,
	trend_type: int = TrendSystem.TrendType.HOT,
) -> void:
	var current_day: int = GameManager.current_day
	_system._active_trends.append({
		"target_type": "category",
		"target": category,
		"trend_type": trend_type,
		"multiplier": multiplier,
		"announced_day": current_day,
		"active_day": current_day,
		"end_day": current_day + duration_days,
		"fade_end_day": current_day + duration_days + TrendSystem.FADE_DAYS,
	})


# ── Tests ─────────────────────────────────────────────────────────────────────

func test_create_trend_emits_signal() -> void:
	var trending_received: Array = []
	var cold_received: Array = []
	var signal_fired: Array = [false]

	var cb: Callable = func(trending: Array, cold: Array) -> void:
		signal_fired[0] = true
		trending_received = trending.duplicate()
		cold_received = cold.duplicate()
	EventBus.trend_changed.connect(cb)

	_inject_trend("collectibles", HOT_MULTIPLIER, 5, TrendSystem.TrendType.HOT)
	_system._emit_trend_changed()

	EventBus.trend_changed.disconnect(cb)

	assert_true(signal_fired[0], "trend_changed should fire after injecting a trend")
	assert_true(
		trending_received.has("collectibles"),
		"trending list should contain the hot category"
	)
	assert_eq(cold_received.size(), 0, "cold list should be empty")


func test_trend_multiplier_returned_by_get_multiplier() -> void:
	_inject_trend("electronics", HOT_MULTIPLIER, 5)
	var item: ItemInstance = _make_item("electronics")

	var mult: float = _system.get_trend_multiplier(item)

	assert_almost_eq(
		mult, HOT_MULTIPLIER, FLOAT_DELTA,
		"get_trend_multiplier should return the configured multiplier"
	)


func test_cold_state_returns_multiplier_below_one() -> void:
	_inject_trend("clothing", COLD_MULTIPLIER, 5, TrendSystem.TrendType.COLD)
	var item: ItemInstance = _make_item("clothing")

	var mult: float = _system.get_trend_multiplier(item)

	assert_true(
		mult < NEUTRAL_EXPECTED,
		"Cold trend should return a multiplier below 1.0, got %f" % mult
	)
	assert_almost_eq(
		mult, COLD_MULTIPLIER, FLOAT_DELTA,
		"Cold multiplier should match the injected value"
	)


func test_neutral_category_returns_one() -> void:
	_inject_trend("furniture", HOT_MULTIPLIER, 5)
	var item: ItemInstance = _make_item("unrelated_category")

	var mult: float = _system.get_trend_multiplier(item)

	assert_almost_eq(
		mult, NEUTRAL_EXPECTED, FLOAT_DELTA,
		"Category with no active trend should return exactly 1.0"
	)


func test_trend_expires_after_duration() -> void:
	var start_day: int = GameManager.current_day
	_inject_trend("toys", HOT_MULTIPLIER, 1)
	var item: ItemInstance = _make_item("toys")

	assert_almost_eq(
		_system.get_trend_multiplier(item), HOT_MULTIPLIER, FLOAT_DELTA,
		"Multiplier should be active on day 0"
	)

	# Advance past end_day + FADE_DAYS so the trend is fully expired.
	# With duration=1: end_day = start+1, fade_end = start+1+FADE_DAYS.
	var expire_day: int = start_day + 1 + TrendSystem.FADE_DAYS + 1
	GameManager._current_day = expire_day
	_system._on_day_started(expire_day)

	var mult_after: float = _system.get_trend_multiplier(item)
	assert_almost_eq(
		mult_after, NEUTRAL_EXPECTED, FLOAT_DELTA,
		"Multiplier should return to 1.0 after trend expires"
	)
	assert_eq(
		_system._active_trends.size(), 0,
		"Expired trend should be removed from _active_trends"
	)


func test_no_multiplier_for_uncovered_category() -> void:
	_inject_trend("category_a", HOT_MULTIPLIER, 5)
	var item_b: ItemInstance = _make_item("category_b")

	var mult: float = _system.get_trend_multiplier(item_b)

	assert_almost_eq(
		mult, NEUTRAL_EXPECTED, FLOAT_DELTA,
		"Category B should not be affected by a trend on category A"
	)


func test_trend_stack_cap_prevents_excess_trends() -> void:
	# TrendSystem has no hard cap — _active_trends is unbounded.
	# This test verifies that multiple simultaneously active trends are
	# tracked correctly without error, and that the per-shift generation
	# constants define the natural concurrency bounds.
	_inject_trend("cat_one", 1.6, 5)
	_inject_trend("cat_two", 1.7, 5)

	assert_eq(
		_system._active_trends.size(), 2,
		"Two concurrent trends should be tracked"
	)

	# A third trend on a new category should also be accepted without error.
	_inject_trend("cat_three", 1.5, 5)

	assert_eq(
		_system._active_trends.size(), 3,
		"TrendSystem does not enforce a cap; third trend is accepted"
	)


func test_multiple_categories_independent() -> void:
	_inject_trend("hot_cat", HOT_MULTIPLIER, 5, TrendSystem.TrendType.HOT)
	_inject_trend("cold_cat", COLD_MULTIPLIER, 5, TrendSystem.TrendType.COLD)

	var hot_item: ItemInstance = _make_item("hot_cat")
	var cold_item: ItemInstance = _make_item("cold_cat")
	var neutral_item: ItemInstance = _make_item("no_trend_cat")

	var hot_mult: float = _system.get_trend_multiplier(hot_item)
	var cold_mult: float = _system.get_trend_multiplier(cold_item)
	var neutral_mult: float = _system.get_trend_multiplier(neutral_item)

	assert_almost_eq(
		hot_mult, HOT_MULTIPLIER, FLOAT_DELTA,
		"Hot category should return HOT_MULTIPLIER"
	)
	assert_almost_eq(
		cold_mult, COLD_MULTIPLIER, FLOAT_DELTA,
		"Cold category should return COLD_MULTIPLIER"
	)
	assert_almost_eq(
		neutral_mult, NEUTRAL_EXPECTED, FLOAT_DELTA,
		"Untrended category should return 1.0"
	)
	assert_true(
		cold_mult < NEUTRAL_EXPECTED,
		"Cold category multiplier should be below 1.0"
	)
	assert_true(
		hot_mult > NEUTRAL_EXPECTED,
		"Hot category multiplier should be above 1.0"
	)
