## Static helpers for market value and demand/drift calculations.
## Extracted from EconomySystem to keep that class under 500 lines.
class_name EconomyValueCalculator
extends Object

const MAX_MARKET_VALUE: float = 1000.0
const APPRECIATION_RATE: float = 0.002
const APPRECIATION_CAP: float = 1.5
const DEPRECIATION_RATE: float = 0.008
const DEPRECIATION_FLOOR: float = 0.1
const DRIFT_DEFAULT: float = 1.0
const DRIFT_MIN: float = 0.85
const DRIFT_MAX: float = 1.15
const DRIFT_MEAN_REVERSION: float = 0.1
const DRIFT_VOLATILITY: Dictionary = {
	"common": 0.01,
	"uncommon": 0.02,
	"rare": 0.03,
	"very_rare": 0.05,
	"legendary": 0.07,
}
const DEFAULT_DEMAND: float = 1.0
const DEMAND_STEP: float = 0.1
const DEMAND_CAP: float = 1.5
const DEMAND_FLOOR: float = 0.3
const HIGH_SALES_RATIO: float = 3.0
const LOW_SALES_RATIO: float = 0.5
const SALES_HISTORY_DAYS: int = 5


## Calculates market value with all multipliers applied.
static func calculate_market_value(
	item: ItemInstance,
	demand_modifiers: Dictionary,
	drift_factors: Dictionary,
	trend_system: TrendSystem,
	market_event_system: MarketEventSystem,
	meta_shift_system: MetaShiftSystem,
	season_cycle_system: SeasonCycleSystem
) -> float:
	if not item or not item.definition:
		return 0.0
	if item.authentication_status == "fake":
		return 0.50
	var base: float = item.definition.base_price
	var cond_mult: float = ItemInstance.CONDITION_MULTIPLIERS.get(
		item.condition, 1.0
	)
	var rarity_mult: float = ItemInstance.calculate_effective_rarity(
		base, item.definition.rarity
	)
	var demand: float = demand_modifiers.get(
		item.definition.category, DEFAULT_DEMAND
	)
	var drift: float = drift_factors.get(item.definition.id, DRIFT_DEFAULT)
	var time_mult: float = calc_time_multiplier(item)
	var trend: float = get_trend_multiplier(item, trend_system)
	var market_event: float = get_market_event_multiplier(
		item, market_event_system
	)
	var meta_shift: float = get_meta_shift_multiplier(item, meta_shift_system)
	var season: float = get_season_multiplier(item, season_cycle_system)
	var auth: float = get_authentication_multiplier(item)
	var value: float = (
		base * cond_mult * rarity_mult
		* demand * drift * time_mult * trend * market_event
		* meta_shift * season * auth
	)
	return minf(value, MAX_MARKET_VALUE)


static func get_trend_multiplier(
	item: ItemInstance, trend_system: TrendSystem
) -> float:
	if not trend_system:
		return 1.0
	return trend_system.get_trend_multiplier(item)


static func get_market_event_multiplier(
	item: ItemInstance, market_event_system: MarketEventSystem
) -> float:
	if not market_event_system:
		return 1.0
	return market_event_system.get_trend_multiplier(item)


static func get_meta_shift_multiplier(
	item: ItemInstance, meta_shift_system: MetaShiftSystem
) -> float:
	if not meta_shift_system:
		return 1.0
	return meta_shift_system.get_meta_shift_multiplier(item)


static func get_authentication_multiplier(item: ItemInstance) -> float:
	if item.authentication_status == "authenticated":
		return get_auth_multiplier_from_config()
	return 1.0


static func get_auth_multiplier_from_config() -> float:
	var entry: Dictionary = ContentRegistry.get_entry(&"sports")
	if entry.is_empty():
		return 2.0
	var config: Variant = entry.get("authentication_config", {})
	if config is not Dictionary:
		return 2.0
	return float((config as Dictionary).get("auth_multiplier", 2.0))


static func get_season_multiplier(
	item: ItemInstance, season_cycle_system: SeasonCycleSystem
) -> float:
	if not season_cycle_system:
		return 1.0
	return season_cycle_system.get_season_multiplier(item)


static func calc_time_multiplier(item: ItemInstance) -> float:
	var current_day: int = GameManager.current_day
	var days_owned: int = maxi(0, current_day - item.acquired_day)
	if item.definition.appreciates:
		return minf(
			1.0 + float(days_owned) * APPRECIATION_RATE,
			APPRECIATION_CAP
		)
	if item.definition.depreciates:
		return maxf(
			DEPRECIATION_FLOOR,
			1.0 - float(days_owned) * DEPRECIATION_RATE
		)
	return 1.0


## Updates demand modifiers based on recent sales history vs shelf supply.
static func update_demand_modifiers(
	sales_history: Array[Dictionary],
	shelf_supply: Dictionary,
	demand_modifiers: Dictionary
) -> void:
	var total_sales_by_cat: Dictionary = {}
	for day_sales: Dictionary in sales_history:
		for cat: String in day_sales:
			var prev: int = total_sales_by_cat.get(cat, 0) as int
			total_sales_by_cat[cat] = prev + (day_sales[cat] as int)

	var all_categories: Dictionary = total_sales_by_cat.duplicate()
	for cat: String in shelf_supply:
		all_categories[cat] = true

	for cat: String in all_categories:
		var total_sales: int = total_sales_by_cat.get(cat, 0) as int
		var supply: int = shelf_supply.get(cat, 0) as int
		var current_demand: float = demand_modifiers.get(
			cat, DEFAULT_DEMAND
		)
		if supply <= 0:
			continue
		var sales_ratio: float = float(total_sales) / float(supply)
		if sales_ratio > HIGH_SALES_RATIO:
			current_demand = minf(current_demand + DEMAND_STEP, DEMAND_CAP)
		elif sales_ratio < LOW_SALES_RATIO:
			current_demand = maxf(current_demand - DEMAND_STEP, DEMAND_FLOOR)
		demand_modifiers[cat] = current_demand


## Applies random walk with mean reversion to item drift factors.
static func update_drift_factors(
	all_items: Array[ItemDefinition],
	drift_factors: Dictionary
) -> void:
	for item_def: ItemDefinition in all_items:
		var current: float = drift_factors.get(item_def.id, DRIFT_DEFAULT)
		var volatility: float = DRIFT_VOLATILITY.get(item_def.rarity, 0.01)
		var reversion: float = (
			DRIFT_DEFAULT - current
		) * DRIFT_MEAN_REVERSION
		var noise: float = randf_range(-volatility, volatility)
		var new_drift: float = clampf(
			current + reversion + noise, DRIFT_MIN, DRIFT_MAX
		)
		drift_factors[item_def.id] = new_drift
