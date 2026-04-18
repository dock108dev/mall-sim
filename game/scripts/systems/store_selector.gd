## Weighted store selection for mall-level customer distribution.
class_name StoreSelector
extends RefCounted

const MAX_CUSTOMERS_SMALL: int = 5
const MAX_CUSTOMERS_MEDIUM: int = 8
const TREND_BOOST: float = 1.3

var _reputation_system: ReputationSystem = null
var _trend_system: TrendSystem = null
var _store_customer_counts: Dictionary = {}


func initialize(
	reputation_system: ReputationSystem,
	trend_system: TrendSystem = null
) -> void:
	_reputation_system = reputation_system
	_trend_system = trend_system


## Updates external customer count reference for capacity checks.
func set_store_counts(counts: Dictionary) -> void:
	_store_customer_counts = counts


## Selects a store using weighted random, excluding specified store.
func select_store(exclude_store: String = "") -> String:
	var weights: Dictionary = calculate_store_weights()
	if not exclude_store.is_empty():
		weights.erase(exclude_store)
	return _weighted_pick(weights)


## Calculates selection weights for each owned store with capacity.
func calculate_store_weights() -> Dictionary:
	var weights: Dictionary = {}
	for store_id: StringName in GameManager.get_owned_store_ids():
		var store_key: String = String(store_id)
		if not _has_capacity(store_key):
			continue
		var weight: float = _get_store_weight(store_key)
		if weight > 0.0:
			weights[store_key] = weight
	return weights


func _weighted_pick(weights: Dictionary) -> String:
	if weights.is_empty():
		return ""
	var total_weight: float = 0.0
	for store_id: String in weights:
		total_weight += weights[store_id] as float
	if total_weight <= 0.0:
		return ""
	var roll: float = randf() * total_weight
	var accumulated: float = 0.0
	for store_id: String in weights:
		accumulated += weights[store_id] as float
		if roll <= accumulated:
			return store_id
	return weights.keys().back() as String


func _get_store_weight(store_id: String) -> float:
	var base_traffic: float = _get_base_foot_traffic(store_id)
	var rep_mult: float = _get_reputation_multiplier(store_id)
	var trend_mult: float = _get_trend_multiplier(store_id)
	return base_traffic * rep_mult * trend_mult


func _get_base_foot_traffic(store_id: String) -> float:
	if not GameManager.data_loader:
		return 0.5
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(store_id)
	)
	if store_def:
		return store_def.base_foot_traffic
	return 0.5


func _get_reputation_multiplier(store_id: String) -> float:
	if not _reputation_system:
		return 1.0
	return _reputation_system.get_customer_multiplier(store_id)


func _get_trend_multiplier(store_id: String) -> float:
	if not _trend_system:
		return 1.0
	var trending: Array = []
	if _trend_system.has_method("get_trending_categories"):
		trending = _trend_system.get_trending_categories()
	if trending.is_empty():
		return 1.0
	if not GameManager.data_loader:
		return 1.0
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(store_id)
	)
	if not store_def:
		return 1.0
	for category: Variant in trending:
		if str(category) in store_def.allowed_categories:
			return TREND_BOOST
	return 1.0


func _has_capacity(store_id: String) -> bool:
	var current: int = (
		_store_customer_counts.get(store_id, 0) as int
	)
	var cap: int = get_store_cap(store_id)
	return current < cap


## Returns the per-store customer cap based on store size.
func get_store_cap(store_id: String) -> int:
	if not GameManager.data_loader:
		return MAX_CUSTOMERS_SMALL
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(store_id)
	)
	if not store_def:
		return MAX_CUSTOMERS_SMALL
	if store_def.size_category == "medium":
		return MAX_CUSTOMERS_MEDIUM
	if store_def.size_category == "large":
		return MAX_CUSTOMERS_MEDIUM
	return MAX_CUSTOMERS_SMALL
