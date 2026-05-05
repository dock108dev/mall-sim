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

## Annual-sports decay constants. Step-function: when a newer edition exists
## in the catalog the active rate / fresh floor apply (a 1-year-old title hits
## ~70% of base price); otherwise the standard year-over-year rate / old floor.
## Editions older than COLLECTIBLE_AGE_THRESHOLD years receive a nostalgia
## recovery bump.
const ANNUAL_SPORTS_RATE_STANDARD: float = 0.18
const ANNUAL_SPORTS_RATE_ACTIVE: float = 0.30
const ANNUAL_SPORTS_FLOOR_FRESH: float = 0.40
const ANNUAL_SPORTS_FLOOR_OLD: float = 0.15
const COLLECTIBLE_AGE_THRESHOLD: int = 5
const COLLECTIBLE_RECOVERY_MULT: float = 1.35
const DAYS_PER_YEAR: int = 365

var _inventory_system: InventorySystem = null
var _market_event_system: MarketEventSystem = null
var _seasonal_event_system: SeasonalEventSystem = null
var _testing_system: TestingSystem = null
var _cache: Dictionary = {}
var _cache_hour: int = -1
var _current_day: int = 1
var _current_year: int = 1
var _calendar_seasonal_multipliers: Dictionary = {}
## Per-category trend multipliers updated via EventBus.trend_updated.
var _trend_multipliers: Dictionary = {}
## Per-store price caps. 0.0 means no cap. Missing key means unknown store.
var _store_price_caps: Dictionary = {}
## series (StringName) → most-recent edition_year (int) seen in the catalog.
## Drives `_new_edition_released_this_year` for the annual_sports profile.
var _latest_edition_year: Dictionary = {}


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
	_hydrate_edition_registry()


func get_market_value(item_id: StringName) -> float:
	if _cache.has(item_id):
		return _cache[item_id] as float

	var item: ItemInstance = _find_item(item_id)
	if not item:
		push_warning("MarketValueSystem: unknown item_id: %s" % item_id)
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
	var difficulty: float = DifficultySystemSingleton.get_modifier(&"price_modifier")
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
	var rarity_scale: float = DifficultySystemSingleton.get_modifier(
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
	var floor_mult: float = DifficultySystemSingleton.get_modifier(
		&"market_floor_multiplier"
	)
	# Damaged condition bypasses the 0.5 floor: a severely-worn item can sink
	# below half of base price (its condition multiplier is 0.15).
	if item.condition == "damaged":
		return result
	return maxf(result, base * 0.5 * floor_mult)


## Returns the time-based depreciation/launch modifier.
## Dispatches on `def.decay_profile`:
##   - "annual_sports": step-function on new-edition release in same series.
##   - "standard"/"" (or `electronics` legacy): linear decay from launch_day,
##      gated on `depreciates` + `depreciation_rate` + `launch_day`.
##      Items within launch_spike_days of launch_day get a demand bonus.
##   - any other profile: 1.0 (handled elsewhere or no decay).
func get_time_modifier(
	def: ItemDefinition, current_day: int
) -> float:
	if not def:
		return 1.0
	var profile: String = String(def.decay_profile)
	if profile == "annual_sports":
		return _get_annual_sports_decay(def)
	var supported: bool = (
		profile == "" or profile == "standard" or profile == "electronics"
	)
	var disqualified: bool = (
		not supported
		or not def.depreciates
		or def.depreciation_rate <= 0.0
		or def.launch_day <= 0
		or current_day < def.launch_day
	)
	if disqualified:
		return 1.0

	var days_since_launch: int = current_day - def.launch_day
	var depreciation: float = maxf(
		def.min_value_ratio,
		1.0 - float(days_since_launch) * def.depreciation_rate
	)

	if def.launch_spike_days > 0 and days_since_launch <= def.launch_spike_days:
		depreciation *= def.launch_demand_multiplier

	return depreciation


## Returns the trade-in market factor for `def`. Currently this is the
## time/decay modifier (annual_sports step-function or electronics linear
## decay). Trade-in offers multiply this in alongside the per-condition cut
## so the offered credit reflects current market value, not face value.
func get_trade_in_market_factor(def: ItemDefinition) -> float:
	return get_time_modifier(def, _current_day)


## Step-function decay for annual sports titles. Returns 1.0 for current/future
## editions; applies the active-year rate (with the fresh floor) when a newer
## edition exists in the catalog, otherwise standard yearly decay with a
## collector recovery bump for editions ≥ COLLECTIBLE_AGE_THRESHOLD years old.
func _get_annual_sports_decay(def: ItemDefinition) -> float:
	if def.edition_year <= 0:
		return 1.0
	var age: int = _current_year - def.edition_year
	if age <= 0:
		return 1.0
	var newer_exists: bool = _newer_edition_exists(
		def.edition_series, def.edition_year
	)
	var rate: float = ANNUAL_SPORTS_RATE_ACTIVE if newer_exists else ANNUAL_SPORTS_RATE_STANDARD
	var floor_v: float = ANNUAL_SPORTS_FLOOR_FRESH if newer_exists else ANNUAL_SPORTS_FLOOR_OLD
	var decay: float = maxf(floor_v, 1.0 - float(age) * rate)
	if age >= COLLECTIBLE_AGE_THRESHOLD:
		decay *= COLLECTIBLE_RECOVERY_MULT
	return decay


## Records the most-recent edition year seen for `series`. Idempotent for
## older years so out-of-order item loads converge on the true latest.
## Empty series is ignored (item is not part of a tracked franchise).
func register_edition(series: StringName, year: int) -> void:
	if series.is_empty() or year <= 0:
		return
	var current: int = int(_latest_edition_year.get(series, 0))
	if year > current:
		_latest_edition_year[series] = year
		invalidate_cache()


## Returns true when the catalog contains an edition of `series` strictly
## newer than `edition_year`. Empty series cannot have peers.
func _newer_edition_exists(series: StringName, edition_year: int) -> bool:
	if series.is_empty():
		return false
	var latest: int = int(_latest_edition_year.get(series, 0))
	return latest > edition_year


func _hydrate_edition_registry() -> void:
	if not GameManager.data_loader:
		return
	var all_items: Array[ItemDefinition] = GameManager.data_loader.get_all_items()
	for def: ItemDefinition in all_items:
		if def != null:
			register_edition(def.edition_series, def.edition_year)


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


## Returns a PriceResolver-compatible multiplier array for all factors that
## calculate_item_value() applies. Pass the result to PriceResolver.resolve_for_item()
## to obtain a full audit trace. Only non-identity (≠1.0) market-dynamic entries
## are included; rarity and condition are always present.
func get_item_multipliers(item: ItemInstance) -> Array:
	if not item or not item.definition:
		return []
	var rarity_scale: float = DifficultySystemSingleton.get_modifier(
		&"rarity_scale_multiplier"
	)
	var rarity_raw: float = RARITY_MULTIPLIERS.get(item.definition.rarity, 1.0)
	var rarity_mult: float = rarity_raw * rarity_scale
	var cond_mult: float = CONDITION_MULTIPLIERS.get(item.condition, 0.75)
	var trend_mult: float = _get_trend_multiplier(item)
	var season_mult: float = _get_season_multiplier()
	var calendar_mult: float = _get_calendar_seasonal_multiplier(item)
	var event_mult: float = _get_event_multiplier(item)
	var sport_season_mult: float = _get_sport_season_multiplier(item)
	var tournament_mult: float = _get_tournament_demand_multiplier(item)
	var test_mult: float = _get_test_multiplier(item)
	var time_mod: float = get_time_modifier(item.definition, _current_day)
	var combined_seasonal: float = (
		season_mult * calendar_mult * sport_season_mult * tournament_mult
	)
	var multipliers: Array = []
	multipliers.append({
		"slot": "rarity",
		"label": "Rarity",
		"factor": rarity_mult,
		"detail": "%s ×%.2f difficulty scale" % [item.definition.rarity, rarity_scale],
	})
	multipliers.append({
		"slot": "condition",
		"label": "Condition",
		"factor": cond_mult,
		"detail": item.condition,
	})
	if trend_mult != 1.0:
		multipliers.append({
			"slot": "trend",
			"label": "Trend",
			"factor": trend_mult,
			"detail": "category=%s" % item.definition.category,
		})
	if combined_seasonal != 1.0:
		multipliers.append({
			"slot": "seasonal",
			"label": "Seasonal",
			"factor": combined_seasonal,
			"detail": "season×calendar×sport×tournament",
		})
	if event_mult != 1.0:
		multipliers.append({
			"slot": "event",
			"label": "Market Event",
			"factor": event_mult,
			"detail": "market_event",
		})
	if test_mult != 1.0:
		multipliers.append({
			"slot": "test",
			"label": "Test Result",
			"factor": test_mult,
			"detail": item.test_result if item.tested else "untested",
		})
	if time_mod != 1.0:
		var detail: String = "day=%d" % _current_day
		if String(item.definition.decay_profile) == "annual_sports" \
				and item.definition.edition_year > 0:
			detail = "edition_age=%d yr" % maxi(
				_current_year - item.definition.edition_year, 0
			)
		multipliers.append({
			"slot": "depreciation",
			"label": "Depreciation",
			"factor": time_mod,
			"detail": detail,
		})
	return multipliers


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


# gdlint:disable=max-returns
func _get_test_multiplier(item: ItemInstance) -> float:
	if not item.tested or item.test_result.is_empty():
		return 1.0
	if not _testing_system:
		if item.test_result == "tested_working":
			return 1.25
		if item.test_result == "tested_not_working":
			return 0.4
		return 1.0
	if item.test_result == "tested_working":
		return _testing_system.get_working_multiplier()
	if item.test_result == "tested_not_working":
		return _testing_system.get_not_working_multiplier()
	return 1.0


# gdlint:enable=max-returns
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
	var year: int = 1 + maxi(day - 1, 0) / DAYS_PER_YEAR
	if year != _current_year:
		_current_year = year
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
