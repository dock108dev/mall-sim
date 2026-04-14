## GUT unit tests for TrendSystem: multiplier calculation, signal emission, expiry, and multi-category independence.
extends GutTest


var _system: TrendSystem
var _trend_changed_hot: Array = []
var _trend_changed_cold: Array = []


func before_each() -> void:
	_trend_changed_hot = []
	_trend_changed_cold = []
	_system = TrendSystem.new()
	add_child_autofree(_system)
	EventBus.trend_changed.connect(_on_trend_changed)


func after_each() -> void:
	if EventBus.trend_changed.is_connected(_on_trend_changed):
		EventBus.trend_changed.disconnect(_on_trend_changed)


func _on_trend_changed(hot: Array, cold: Array) -> void:
	_trend_changed_hot = hot.duplicate()
	_trend_changed_cold = cold.duplicate()


func _make_item(category: String, tags: PackedStringArray = []) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_item_%s" % category
	def.category = category
	def.base_price = 10.0
	def.tags = tags
	return ItemInstance.create_from_definition(def, "good")


func _inject_trend(
	category: String,
	trend_type: TrendSystem.TrendType,
	multiplier: float,
) -> void:
	_system._active_trends.append({
		"target_type": "category",
		"target": category,
		"trend_type": trend_type,
		"multiplier": multiplier,
		"announced_day": 0,
		"active_day": 0,
		"end_day": 9999,
		"fade_end_day": 10001,
	})


# --- Signal emission ---

func test_create_trend_emits_signal() -> void:
	_inject_trend("electronics", TrendSystem.TrendType.HOT, 1.8)
	_system._emit_trend_changed()
	assert_true(
		_trend_changed_hot.has("electronics"),
		"trend_changed should list electronics in hot array"
	)
	assert_eq(_trend_changed_cold.size(), 0, "Cold list should be empty")


func test_cold_trend_emits_in_cold_list() -> void:
	_inject_trend("sports", TrendSystem.TrendType.COLD, 0.6)
	_system._emit_trend_changed()
	assert_true(
		_trend_changed_cold.has("sports"),
		"trend_changed should list sports in cold array"
	)
	assert_eq(_trend_changed_hot.size(), 0, "Hot list should be empty")


# --- Multiplier retrieval ---

func test_trend_multiplier_returned_by_get_multiplier() -> void:
	_inject_trend("electronics", TrendSystem.TrendType.HOT, 1.8)
	var item: ItemInstance = _make_item("electronics")
	var mult: float = _system.get_trend_multiplier(item)
	assert_almost_eq(mult, 1.8, 0.001, "Hot trend multiplier should be 1.8")


func test_cold_state_returns_multiplier_below_one() -> void:
	_inject_trend("sports", TrendSystem.TrendType.COLD, 0.6)
	var item: ItemInstance = _make_item("sports")
	var mult: float = _system.get_trend_multiplier(item)
	assert_true(mult < 1.0, "Cold trend multiplier should be below 1.0")
	assert_almost_eq(mult, 0.6, 0.001, "Cold trend multiplier should be 0.6")


func test_neutral_category_returns_one() -> void:
	var item: ItemInstance = _make_item("no_trend_category")
	var mult: float = _system.get_trend_multiplier(item)
	assert_almost_eq(mult, 1.0, 0.001, "Category with no trend should return 1.0")


func test_no_multiplier_for_uncovered_category() -> void:
	_inject_trend("electronics", TrendSystem.TrendType.HOT, 1.9)
	var other_item: ItemInstance = _make_item("retro_games")
	var mult: float = _system.get_trend_multiplier(other_item)
	assert_almost_eq(mult, 1.0, 0.001, "Trend for category A must not affect category B")


# --- Expiry ---

func test_trend_expires_after_duration() -> void:
	# Use an explicit future day so we control when it expires.
	_system._active_trends.append({
		"target_type": "category",
		"target": "vintage",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 2.0,
		"announced_day": 0,
		"active_day": 0,
		"end_day": 5,
		"fade_end_day": 5,
	})
	var item: ItemInstance = _make_item("vintage")
	assert_true(
		_system._active_trends.size() == 1,
		"Trend should be present before expiry"
	)
	# Simulate day advancing past fade_end_day.
	_system._remove_expired_trends(5)
	assert_eq(_system._active_trends.size(), 0, "Expired trend should be removed")
	var mult_after: float = _system.get_trend_multiplier(item)
	assert_almost_eq(mult_after, 1.0, 0.001, "Expired trend should yield multiplier 1.0")


func test_trend_not_removed_before_fade_end() -> void:
	_system._active_trends.append({
		"target_type": "category",
		"target": "vintage",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 2.0,
		"announced_day": 0,
		"active_day": 0,
		"end_day": 5,
		"fade_end_day": 7,
	})
	_system._remove_expired_trends(6)
	assert_eq(
		_system._active_trends.size(), 1,
		"Trend should survive until fade_end_day"
	)


# --- Stacking and clamping ---

func test_trend_stack_cap_prevents_excess_trends() -> void:
	# The system multiplies overlapping trends; verify the result is clamped.
	_inject_trend("comics", TrendSystem.TrendType.HOT, 1.8)
	_inject_trend("comics", TrendSystem.TrendType.HOT, 1.8)
	var item: ItemInstance = _make_item("comics")
	var mult: float = _system.get_trend_multiplier(item)
	assert_true(mult > 1.8, "Two stacked hot trends should compound above a single multiplier")
	assert_true(
		mult <= TrendSystem.TREND_MULT_MAX,
		"Stacked multiplier must not exceed TREND_MULT_MAX"
	)


# --- Multiple categories independent ---

func test_multiple_categories_independent() -> void:
	_inject_trend("trading_cards", TrendSystem.TrendType.HOT, 1.7)
	_inject_trend("vhs_tapes", TrendSystem.TrendType.COLD, 0.5)
	var hot_item: ItemInstance = _make_item("trading_cards")
	var cold_item: ItemInstance = _make_item("vhs_tapes")
	var hot_mult: float = _system.get_trend_multiplier(hot_item)
	var cold_mult: float = _system.get_trend_multiplier(cold_item)
	assert_almost_eq(hot_mult, 1.7, 0.001, "Hot category multiplier should be 1.7")
	assert_almost_eq(cold_mult, 0.5, 0.001, "Cold category multiplier should be 0.5")


func test_hot_trend_does_not_affect_cold_category() -> void:
	_inject_trend("trading_cards", TrendSystem.TrendType.HOT, 1.7)
	var unrelated_item: ItemInstance = _make_item("vhs_tapes")
	var mult: float = _system.get_trend_multiplier(unrelated_item)
	assert_almost_eq(mult, 1.0, 0.001, "Hot trend on A should not change multiplier for B")


# --- Tag-based trends ---

func test_tag_based_trend_applies_to_matching_item() -> void:
	_system._active_trends.append({
		"target_type": "tag",
		"target": "limited_edition",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 2.0,
		"announced_day": 0,
		"active_day": 0,
		"end_day": 9999,
		"fade_end_day": 10001,
	})
	var tags: PackedStringArray = ["limited_edition", "signed"]
	var item: ItemInstance = _make_item("sports", tags)
	var mult: float = _system.get_trend_multiplier(item)
	assert_almost_eq(mult, 2.0, 0.001, "Tag trend should apply when item has matching tag")


func test_tag_based_trend_does_not_affect_untagged_item() -> void:
	_system._active_trends.append({
		"target_type": "tag",
		"target": "limited_edition",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 2.0,
		"announced_day": 0,
		"active_day": 0,
		"end_day": 9999,
		"fade_end_day": 10001,
	})
	var item: ItemInstance = _make_item("sports")
	var mult: float = _system.get_trend_multiplier(item)
	assert_almost_eq(mult, 1.0, 0.001, "Tag trend must not affect items without the tag")


# --- Null safety ---

func test_null_item_returns_one() -> void:
	var mult: float = _system.get_trend_multiplier(null)
	assert_almost_eq(mult, 1.0, 0.001, "Null item should safely return 1.0")


# --- Save / Load roundtrip ---

func test_save_load_roundtrip_preserves_trends() -> void:
	_inject_trend("electronics", TrendSystem.TrendType.HOT, 1.75)
	_inject_trend("sports", TrendSystem.TrendType.COLD, 0.55)
	var save_data: Dictionary = _system.get_save_data()

	var fresh := TrendSystem.new()
	add_child_autofree(fresh)
	fresh.load_save_data(save_data)

	assert_eq(
		fresh._active_trends.size(), 2,
		"Loaded system should have same number of trends"
	)
	var electronics_found: bool = false
	for trend: Dictionary in fresh._active_trends:
		if trend.get("target") == "electronics":
			assert_almost_eq(
				float(trend.get("multiplier", 0.0)), 1.75, 0.001,
				"Loaded electronics multiplier should match saved value"
			)
			electronics_found = true
	assert_true(electronics_found, "Electronics trend should be present after load")
