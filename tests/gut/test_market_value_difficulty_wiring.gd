## Tests that DifficultySystem modifiers apply to MarketValueSystem pricing.
extends GutTest


var _system: MarketValueSystem
var _inventory: InventorySystem
var _trend: TrendSystem
var _saved_tier: StringName


func _create_item(
	overrides: Dictionary = {}, condition: String = "mint"
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = overrides.get("id", "test_item")
	def.name = overrides.get("name", "Test Item")
	def.base_price = overrides.get("base_price", 10.0)
	def.rarity = overrides.get("rarity", "common")
	def.category = overrides.get("category", "trading_cards")
	def.tags = overrides.get("tags", PackedStringArray())
	def.store_type = overrides.get("store_type", "retro_games")
	return ItemInstance.create_from_definition(def, condition)


func before_each() -> void:
	_saved_tier = DifficultySystem.get_current_tier_id()
	DifficultySystem.set_tier(&"normal")

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_trend = TrendSystem.new()
	add_child_autofree(_trend)

	_system = MarketValueSystem.new()
	add_child_autofree(_system)
	_system.initialize(_inventory, _trend, null, null)


func after_each() -> void:
	DifficultySystem.set_tier(_saved_tier)


# --- market_floor_multiplier ---

func test_normal_floor_does_not_alter_healthy_price() -> void:
	# mint common: 10.0 * 1.0 * 1.0 = 10.0; floor = 10.0 * 0.5 * 1.0 = 5.0
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "common"}, "mint")
	var value: float = _system.calculate_item_value(item)
	assert_almost_eq(value, 10.0, 0.001, "Normal: computed value above floor is unchanged")


func test_easy_floor_raises_collapsed_price() -> void:
	DifficultySystem.set_tier(&"easy")
	# damaged common: 10.0 * (1.0 * 0.90) * 0.15 = 1.35; floor = 10.0 * 0.5 * 1.10 = 5.5
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "common"}, "damaged")
	var value: float = _system.calculate_item_value(item)
	assert_almost_eq(
		value, 5.5, 0.001,
		"Easy: damaged price should be floored to base * 0.5 * 1.10 = 5.5"
	)


func test_hard_floor_raises_collapsed_price_less_than_easy() -> void:
	DifficultySystem.set_tier(&"hard")
	# damaged common: 10.0 * (1.0 * 1.20) * 0.15 = 1.80; floor = 10.0 * 0.5 * 0.85 = 4.25
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "common"}, "damaged")
	var value: float = _system.calculate_item_value(item)
	assert_almost_eq(
		value, 4.25, 0.001,
		"Hard: damaged price should be floored to base * 0.5 * 0.85 = 4.25"
	)


func test_easy_floor_higher_than_hard_floor() -> void:
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "common"}, "damaged")
	DifficultySystem.set_tier(&"easy")
	var easy_value: float = _system.calculate_item_value(item)
	DifficultySystem.set_tier(&"hard")
	var hard_value: float = _system.calculate_item_value(item)
	assert_true(
		easy_value > hard_value,
		"Easy floor (5.5) must be higher than Hard floor (4.25)"
	)


# --- rarity_scale_multiplier ---

func test_normal_rarity_scale_unchanged() -> void:
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "rare"}, "mint")
	var value: float = _system.calculate_item_value(item)
	assert_almost_eq(value, 10.0 * 1.8 * 1.0, 0.001, "Normal: rarity_scale=1.0 is no change")


func test_easy_rarity_scale_is_0_90() -> void:
	DifficultySystem.set_tier(&"easy")
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "rare"}, "mint")
	var value: float = _system.calculate_item_value(item)
	# floor = 10.0 * 0.5 * 1.10 = 5.5; computed = 10.0 * (1.8 * 0.90) * 1.0 = 16.2
	assert_almost_eq(
		value, 10.0 * 1.8 * 0.90, 0.001,
		"Easy: rarity_scale=0.90 applied to rare item"
	)


func test_hard_rarity_scale_is_1_20() -> void:
	DifficultySystem.set_tier(&"hard")
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "rare"}, "mint")
	var value: float = _system.calculate_item_value(item)
	# floor = 10.0 * 0.5 * 0.85 = 4.25; computed = 10.0 * (1.8 * 1.20) * 1.0 = 21.6
	assert_almost_eq(
		value, 10.0 * 1.8 * 1.20, 0.001,
		"Hard: rarity_scale=1.20 applied to rare item"
	)


func test_hard_rare_more_expensive_than_normal() -> void:
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "rare"}, "mint")
	DifficultySystem.set_tier(&"normal")
	var normal_value: float = _system.calculate_item_value(item)
	DifficultySystem.set_tier(&"hard")
	var hard_value: float = _system.calculate_item_value(item)
	assert_true(hard_value > normal_value, "Hard rare more expensive due to rarity_scale=1.20")


func test_easy_rare_cheaper_than_normal() -> void:
	var item: ItemInstance = _create_item({"base_price": 10.0, "rarity": "rare"}, "mint")
	DifficultySystem.set_tier(&"normal")
	var normal_value: float = _system.calculate_item_value(item)
	DifficultySystem.set_tier(&"easy")
	var easy_value: float = _system.calculate_item_value(item)
	assert_true(easy_value < normal_value, "Easy rare cheaper due to rarity_scale=0.90")


# --- trend_duration_multiplier ---

func test_normal_trend_active_within_duration() -> void:
	# active_day=1, end_day=6 (duration=5). Normal scale=1.0 → effective_end=6.
	# On day 4 (< effective_end), full multiplier applies.
	var saved_day: int = GameManager.current_day
	GameManager.current_day = 4
	_trend._active_trends.append({
		"target_type": "category",
		"target": "trading_cards",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 2.0,
		"announced_day": 0,
		"active_day": 1,
		"end_day": 6,
		"fade_end_day": 8,
	})
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "trading_cards"}, "mint"
	)
	var value: float = _system.calculate_item_value(item)
	# floor=5.0; computed = 10.0 * 1.0 * 1.0 * 2.0 = 20.0
	assert_almost_eq(value, 20.0, 0.001, "Normal: trend active on day 4 (< end_day 6)")
	GameManager.current_day = saved_day


func test_hard_trend_fades_earlier_than_normal() -> void:
	# active_day=1, end_day=6 (duration=5).
	# Normal scale=1.0 → effective_end=6; on day 6 → fade_progress=0 → mult=2.0
	# Hard scale=0.70 → effective_end=1+round(5*0.70)=1+4=5; on day 6 → fade_progress=(6-5)/(7-5)=0.5 → 1.5
	var saved_day: int = GameManager.current_day
	GameManager.current_day = 6
	var trend: Dictionary = {
		"target_type": "category",
		"target": "trading_cards",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 2.0,
		"announced_day": 0,
		"active_day": 1,
		"end_day": 6,
		"fade_end_day": 8,
	}

	DifficultySystem.set_tier(&"normal")
	_trend._active_trends = [trend.duplicate()]
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "trading_cards"}, "mint"
	)
	var normal_value: float = _system.calculate_item_value(item)

	DifficultySystem.set_tier(&"hard")
	_trend._active_trends = [trend.duplicate()]
	var hard_value: float = _system.calculate_item_value(item)

	# Hard trend has faded further on day 6 than Normal trend
	assert_true(
		hard_value < normal_value,
		"Hard trend fades earlier: day-6 value should be lower than Normal day-6 value"
	)
	GameManager.current_day = saved_day


func test_easy_trend_still_active_past_base_end() -> void:
	# active_day=1, end_day=6 (duration=5).
	# Easy scale=1.40 → effective_end=1+round(5*1.40)=1+7=8; on day 7 → still fully active
	# Normal scale=1.0 → effective_end=6; on day 7 → fade_progress=(7-6)/(8-6)=0.5 → 1.5
	var saved_day: int = GameManager.current_day
	GameManager.current_day = 7
	var trend: Dictionary = {
		"target_type": "category",
		"target": "trading_cards",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 2.0,
		"announced_day": 0,
		"active_day": 1,
		"end_day": 6,
		"fade_end_day": 8,
	}

	DifficultySystem.set_tier(&"normal")
	_trend._active_trends = [trend.duplicate()]
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "trading_cards"}, "mint"
	)
	var normal_value: float = _system.calculate_item_value(item)

	DifficultySystem.set_tier(&"easy")
	_trend._active_trends = [trend.duplicate()]
	var easy_value: float = _system.calculate_item_value(item)

	# Easy trend is still fully active on day 7; Normal trend is mid-fade
	assert_true(
		easy_value > normal_value,
		"Easy trend extends duration: day-7 value should exceed Normal day-7 value"
	)
	GameManager.current_day = saved_day
