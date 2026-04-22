## Manages store upgrade purchases, persistence, and effect application.
class_name StoreUpgradeSystem
extends Node


var _data_loader: DataLoader
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem
var _catalog: Dictionary = {}

## store_id -> Array[String] of purchased upgrade ids.
var _purchased_upgrades: Dictionary = {}


func initialize(
	data_loader: DataLoader,
	economy: EconomySystem,
	reputation: ReputationSystem,
) -> void:
	_data_loader = data_loader
	_economy_system = economy
	_reputation_system = reputation
	_load_catalog_from_registry()


## Returns all upgrades available for a given store type.
func get_upgrades_for_store(
	store_type: String
) -> Array[UpgradeDefinition]:
	if _catalog.is_empty():
		_load_catalog_from_registry()
	var normalized_store_type: String = _normalize_store_id(store_type)
	var result: Array[UpgradeDefinition] = []
	for upgrade: UpgradeDefinition in _catalog.values():
		if upgrade.is_universal():
			result.append(upgrade)
			continue
		if _normalize_store_id(upgrade.store_type) == normalized_store_type:
			result.append(upgrade)
	return result


## Returns true if the given upgrade has been purchased for the store.
func is_purchased(store_id: String, upgrade_id: String) -> bool:
	var sid: String = _normalize_store_id(store_id)
	var purchased: Array = _purchased_upgrades.get(sid, [])
	return upgrade_id in purchased


## Returns all purchased upgrade ids for a store.
func get_purchased_ids(store_id: String) -> Array:
	return _purchased_upgrades.get(_normalize_store_id(store_id), [])


## Returns true if the player can afford the upgrade and meets rep.
# gdlint:disable=max-returns
func can_purchase(
	store_id: String, upgrade_id: String
) -> bool:
	if is_purchased(store_id, upgrade_id):
		return false
	var upgrade: UpgradeDefinition = _get_upgrade(upgrade_id)
	if not upgrade:
		return false
	if not _upgrade_applies_to_store(upgrade, store_id):
		return false
	if not _economy_system:
		return false
	if _economy_system.get_cash() < upgrade.cost:
		return false
	if not _reputation_system:
		return false
	if _reputation_system.get_reputation(store_id) < upgrade.rep_required:
		return false
	return true


## Attempts to purchase an upgrade. Returns true on success.
# gdlint:enable=max-returns
func purchase_upgrade(
	store_id: String, upgrade_id: String
) -> bool:
	if not can_purchase(store_id, upgrade_id):
		return false
	var upgrade: UpgradeDefinition = _get_upgrade(upgrade_id)
	if not upgrade:
		return false
	var reason: String = "Upgrade: %s" % upgrade.display_name
	if not _economy_system.deduct_cash(upgrade.cost, reason):
		return false
	var sid: String = _normalize_store_id(store_id)
	if not _purchased_upgrades.has(sid):
		_purchased_upgrades[sid] = []
	(_purchased_upgrades[sid] as Array).append(upgrade_id)
	EventBus.upgrade_purchased.emit(
		StringName(sid), upgrade_id
	)
	EventBus.store_upgrade_effect_applied.emit(
		StringName(sid),
		upgrade_id,
		upgrade.effect_type,
		upgrade.effect_value
	)
	return true


## Returns the cumulative effect value for a given effect type on a store.
func get_effect_value(
	store_id: String, effect_type: String
) -> float:
	var sid: String = _normalize_store_id(store_id)
	var purchased: Array = _purchased_upgrades.get(sid, [])
	var total: float = _get_effect_default(effect_type)
	for uid: Variant in purchased:
		var upgrade: UpgradeDefinition = _get_upgrade(str(uid))
		if not upgrade:
			continue
		if upgrade.effect_type != effect_type:
			continue
		total = _combine_effect(total, upgrade.effect_value, effect_type)
	return total


## Returns the additive slot bonus for a store.
func get_slot_bonus(store_id: String) -> int:
	return int(get_effect_value(store_id, "slot_bonus"))


## Returns the price multiplier for a store.
func get_price_multiplier(store_id: String) -> float:
	return get_effect_value(store_id, "price_bonus")


## Returns the traffic multiplier for a store.
func get_traffic_multiplier(store_id: String) -> float:
	return get_effect_value(store_id, "traffic_bonus")


## Returns the additive backroom capacity bonus for a store.
func get_capacity_bonus(store_id: String) -> int:
	return int(get_effect_value(store_id, "capacity_bonus"))


## Returns the decay reduction multiplier for a store.
func get_decay_multiplier(store_id: String) -> float:
	return get_effect_value(store_id, "decay_reduction")


## Returns the additive floor size increase for a store.
func get_floor_size_bonus(store_id: String) -> int:
	return int(get_effect_value(store_id, "floor_size_increase"))


func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for store_id: String in _purchased_upgrades:
		var ids: Array = _purchased_upgrades[store_id]
		var serialized: Array[String] = []
		for uid: Variant in ids:
			serialized.append(str(uid))
		data[store_id] = serialized
	return {"purchased_upgrades": data}


func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_purchased_upgrades = {}
	var saved: Variant = data.get("purchased_upgrades", {})
	if saved is not Dictionary:
		return
	for store_id: String in saved:
		var ids: Variant = saved[store_id]
		if ids is not Array:
			continue
		var restored: Array = []
		for uid: Variant in ids:
			restored.append(str(uid))
		_purchased_upgrades[_normalize_store_id(store_id)] = restored


func _get_upgrade(upgrade_id: String) -> UpgradeDefinition:
	if _catalog.is_empty():
		_load_catalog_from_registry()
	var canonical: String = upgrade_id
	if ContentRegistry.exists(upgrade_id):
		canonical = String(ContentRegistry.resolve(upgrade_id))
	var upgrade: UpgradeDefinition = (
		_catalog.get(canonical) as UpgradeDefinition
	)
	if upgrade:
		return upgrade
	if _data_loader:
		return _data_loader.get_upgrade(canonical)
	push_error("StoreUpgradeSystem: upgrade not found: %s" % upgrade_id)
	return null


func _load_catalog_from_registry() -> void:
	_catalog.clear()
	for id: StringName in ContentRegistry.get_all_ids("upgrade"):
		var upgrade: UpgradeDefinition = (
			ContentRegistry.get_upgrade_definition(id)
		)
		if upgrade:
			_catalog[String(id)] = upgrade
	if _catalog.is_empty() and _data_loader:
		for upgrade: UpgradeDefinition in _data_loader.get_all_upgrades():
			_catalog[upgrade.id] = upgrade


func _upgrade_applies_to_store(
	upgrade: UpgradeDefinition,
	store_id: String
) -> bool:
	if upgrade.is_universal():
		return true
	return (
		_normalize_store_id(upgrade.store_type)
		== _normalize_store_id(store_id)
	)


func _normalize_store_id(raw_store_id: String) -> String:
	if raw_store_id.is_empty():
		return ""
	if ContentRegistry.exists(raw_store_id):
		return String(ContentRegistry.resolve(raw_store_id))
	return raw_store_id


func _get_effect_default(effect_type: String) -> float:
	match effect_type:
		"slot_bonus", "capacity_bonus", "floor_size_increase":
			return 0.0
		"price_bonus", "traffic_bonus", "decay_reduction":
			return 1.0
	return 0.0


func _combine_effect(
	current: float, value: float, effect_type: String
) -> float:
	match effect_type:
		"slot_bonus", "capacity_bonus", "floor_size_increase":
			return current + value
		"price_bonus", "traffic_bonus":
			return current * value
		"decay_reduction":
			return current * value
	return current + value
