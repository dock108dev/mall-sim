## Calculates dynamic market values using rarity, condition, trend, season, and event multipliers.
class_name MarketValueSystem
extends Node


const RARITY_MULTIPLIERS: Dictionary = {
	"common": 1.0,
	"uncommon": 1.3,
	"rare": 1.8,
	"very_rare": 2.5,
	"legendary": 4.0,
}

const CONDITION_MULTIPLIERS: Dictionary = {
	"mint": 1.0,
	"near_mint": 0.85,
	"good": 0.75,
	"fair": 0.5,
	"poor": 0.3,
	"damaged": 0.15,
}

const CACHE_LIFETIME_HOURS: int = 1
const MINIMUM_ITEM_PRICE: float = 0.01

var _inventory_system: InventorySystem = null
var _market_event_system: MarketEventSystem = null
var _seasonal_event_system: SeasonalEventSystem = null
var _testing_system: TestingSystem = null
var _cache: Dictionary = {}
var _cache_hour: int = -1
var _current_day: int = 1
var _calendar_seasonal_multipliers: Dictionary = {}
## Per-category trend multipliers updated via EventBus.trend_updated.
var _trend_multipliers: Dictionary = {}
## Per-store price caps. 0.0 means no cap. Missing key means unknown store.
var _store_price_caps: Dictionary = {}


func initialize(
	inventory: InventorySystem,
	market_event: MarketEventSystem,
	seasonal_event: SeasonalEventSystem,
) -> void:
	_inventory_system = inventory
	_market_event_system = market_event
	_seasonal_event_system = seasonal_event
	EventBus.trend_updated.connect(_on_trend_updated)
	EventBus.trend_changed.connect(_on_trend_changed)
	EventBus.trend_shifted.connect(_on_trend_shifted)
	EventBus.market_event_started.connect(_on_market_event_changed)
	EventBus.market_event_ended.connect(_on_market_event_changed)
	EventBus.tournament_event_started.connect(
		_on_tournament_event_changed
	)
	EventBus.tournament_event_ended.connect(
		_on_tournament_event_changed
	)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.item_test_completed.connect(_on_item_test_completed)
	EventBus.seasonal_multipliers_updated.connect(
		_on_seasonal_multipliers_updated
	)


func get_market_value(item_id: StringName) -> float:
	if _cache.has(item_id):
		return _cache[item_id] as float

	var item: ItemInstance = _find_item(item_id)
	if not item:
		push_error("MarketValueSystem: unknown item_id: %s" % item_id)
		return 0.0

	var value: float = calculate_item_value(item)
	_cache[item_id] = value
	return value


## Returns shelf price for an item in a store: base_price × trend × difficulty price_modifier.
## Applies MINIMUM_ITEM_PRICE floor and per-store price cap when the store is registered.
## Returns 0.0 with push_warning for unknown item_id.
## Returns uncapped price with push_warning for unknown store_id.
func get_item_price(store_id: StringName, item_id: StringName) -> float:
	var item: ItemInstance = _find_item(item_id)
	if not item or not item.definition:
		push_warning(
			"MarketValueSystem: unknown item_id for get_item_price: %s" % item_id
		)
		return 0.0
	var base: float = item.definition.base_price
	var category: StringName = StringName(item.definition.category)
	var trend: float = _trend_multipliers.get(category, 1.0) as float
	var difficulty: float = DifficultySystem.get_modifier(&"price_modifier")
	var result: float = maxf(base * trend * difficulty, MINIMUM_ITEM_PRICE)
	if not _store_price_caps.has(store_id):
		push_warning(
			"MarketValueSystem: unknown store_id for get_item_price: %s" % store_id
		)
		return result
	var cap: float = _store_price_caps.get(store_id, 0.0) as float
	if cap > 0.0:
		result = minf(result, cap)
	return result


## Registers a per-store price cap used by get_item_price.
## A cap of 0.0 means no upper limit applies for this store.
func register_store_price_cap(store_id: StringName, price_cap: float) -> void:
	_store_price_caps[store_id] = price_cap


func calculate_item_value(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 0.0

	var base: float = item.definition.base_price
	var rarity_scale: float = DifficultySystem.get_modifier(
		&"rarity_scale_multiplier"
	)
	var rarity_mult: float = RARITY_MULTIPLIERS.get(
		item.definition.rarity, 1.0
	) * rarity_scale
	var cond_mult: float = CONDITION_MULTIPLIERS.get(
		item.condition, 0.75
	)
	var trend_mult: float = _get_trend_multiplier(item)
	var season_mult: float = _get_season_multiplier()
	var calendar_mult: float = _get_calendar_seasonal_multiplier(item)
	var event_mult: float = _get_event_multiplier(item)
	var sport_season_mult: float = _get_sport_season_multiplier(item)
	var tournament_mult: float = _get_tournament_demand_multiplier(
		item
	)

	var test_mult: float = _get_test_multiplier(item)
	var time_mod: float = get_time_modifier(item.definition, _current_day)

	var result: float = (
		base * rarity_mult * cond_mult * trend_mult
		* season_mult * calendar_mult * event_mult
		* sport_season_mult * tournament_mult * test_mult
		* time_mod
	)
	var floor_mult: float = DifficultySystem.get_modifier(
		&"market_floor_multiplier"
	)
	return maxf(result, base * 0.5 * floor_mult)


## Returns the time-based depreciation/launch modifier for an electronics item.
## Formula: max(min_value_ratio, 1.0 - (current_day - launch_day) * rate).
## Items within launch_spike_days of launch_day get a demand bonus.
func get_time_modifier(
	def: ItemDefinition, current_day: int
) -> float:
	if not def or not def.depreciates:
		return 1.0
	if def.depreciation_rate <= 0.0:
		return 1.0
	if def.launch_day <= 0:
		return 1.0

	var days_since_launch: int = current_day - def.launch_day
	if days_since_launch < 0:
		return 1.0

	var depreciation: float = maxf(
		def.min_value_ratio,
		1.0 - float(days_since_launch) * def.depreciation_rate
	)

	if def.launch_spike_days > 0 and days_since_launch <= def.launch_spike_days:
		depreciation *= def.launch_demand_multiplier

	return depreciation


func set_testing_system(system: TestingSystem) -> void:
	_testing_system = system


func invalidate_cache() -> void:
	_cache.clear()


func get_save_data() -> Dictionary:
	return {
		"cache_hour": _cache_hour,
		"current_day": _current_day,
	}


func load_save_data(data: Dictionary) -> void:
	_cache_hour = int(data.get("cache_hour", -1))
	_current_day = int(data.get("current_day", 1))
	_cache.clear()


func _get_trend_multiplier(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 1.0
	var category: StringName = StringName(item.definition.category)
	return _trend_multipliers.get(category, 1.0) as float


func _get_base_price(item: ItemInstance) -> float:
	var rarity_mult: float = RARITY_MULTIPLIERS.get(
		item.definition.rarity, 1.0
	) as float
	return item.definition.base_price * rarity_mult


func _get_condition_modifier(item: ItemInstance) -> float:
	return CONDITION_MULTIPLIERS.get(item.condition, 0.75) as float


func _get_season_multiplier() -> float:
	if not _seasonal_event_system:
		return 1.0
	return _seasonal_event_system.get_spending_multiplier()


func _get_sport_season_multiplier(item: ItemInstance) -> float:
	if not _seasonal_event_system:
		return 1.0
	return _seasonal_event_system.get_sport_season_multiplier(item)


func _get_test_multiplier(item: ItemInstance) -> float:
	if not item.tested or item.test_result.is_empty():
		return 1.0
	if not _testing_system:
		if item.test_result == "tested_working":
			return 1.25
		elif item.test_result == "tested_not_working":
			return 0.4
		return 1.0
	if item.test_result == "tested_working":
		return _testing_system.get_working_multiplier()
	elif item.test_result == "tested_not_working":
		return _testing_system.get_not_working_multiplier()
	return 1.0


func _get_calendar_seasonal_multiplier(
	item: ItemInstance
) -> float:
	if _calendar_seasonal_multipliers.is_empty():
		return 1.0
	var store_type: String = item.definition.store_type
	if store_type.is_empty():
		return 1.0
	return float(
		_calendar_seasonal_multipliers.get(store_type, 1.0)
	)


func _get_event_multiplier(item: ItemInstance) -> float:
	if not _market_event_system:
		return 1.0
	return _market_event_system.get_trend_multiplier(item)


func _get_tournament_demand_multiplier(
	item: ItemInstance
) -> float:
	if not _seasonal_event_system:
		return 1.0
	return _seasonal_event_system.get_tournament_demand_multiplier(
		item
	)


func _find_item(item_id: StringName) -> ItemInstance:
	if not _inventory_system:
		return null
	return _inventory_system.get_item(String(item_id))


func _on_trend_updated(category: StringName, multiplier: float) -> void:
	_trend_multipliers[category] = multiplier
	invalidate_cache()


func _on_trend_changed(
	_trending: Array, _cold: Array
) -> void:
	invalidate_cache()


func _on_trend_shifted(
	_category_id: StringName, _new_level: float
) -> void:
	invalidate_cache()


func _on_market_event_changed(_event_id: String) -> void:
	invalidate_cache()


func _on_tournament_event_changed(_event_id: String) -> void:
	invalidate_cache()


func _on_item_test_completed(
	_instance_id: String, _result: String
) -> void:
	invalidate_cache()


func _on_seasonal_multipliers_updated(
	multipliers: Dictionary
) -> void:
	_calendar_seasonal_multipliers = multipliers
	invalidate_cache()


func _on_day_started(day: int) -> void:
	_current_day = day
	invalidate_cache()


func _on_hour_changed(hour: int) -> void:
	if _cache_hour < 0:
		_cache_hour = hour
		return
	var elapsed: int = hour - _cache_hour
	if elapsed < 0:
		elapsed += 24
	if elapsed >= CACHE_LIFETIME_HOURS:
		invalidate_cache()
		_cache_hour = hour
