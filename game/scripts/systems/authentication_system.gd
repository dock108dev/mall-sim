## Manages item authentication for the sports memorabilia store.
class_name AuthenticationSystem
extends RefCounted

const STORE_TYPE: String = "sports"
const DEFAULT_THRESHOLD: float = 100.0
const DEFAULT_FEE: float = 25.0
const DEFAULT_MULTIPLIER: float = 2.0
const SUSPICIOUS_PRICE_MULTIPLIER: float = 0.5

var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null
var _value_threshold: float = DEFAULT_THRESHOLD
var _auth_fee: float = DEFAULT_FEE
var _auth_multiplier: float = DEFAULT_MULTIPLIER
var _authenticated_canonical_ids: Dictionary = {}


## Initializes system references and loads config from ContentRegistry.
func initialize(
	inventory: InventorySystem, economy: EconomySystem
) -> void:
	_inventory_system = inventory
	_economy_system = economy
	_load_config()
	if not EventBus.price_set.is_connected(_on_price_set):
		EventBus.price_set.connect(_on_price_set)


## Returns the configured authentication fee.
func get_auth_fee() -> float:
	return _auth_fee


## Returns the configured value threshold.
func get_value_threshold() -> float:
	return _value_threshold


## Returns the configured authentication multiplier.
func get_auth_multiplier() -> float:
	return _auth_multiplier


## Returns true if the item can be authenticated.
func can_authenticate(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if item.definition.store_type != STORE_TYPE:
		return false
	if item.authentication_status == "authenticated":
		return false
	if item.authentication_status == "suspicious":
		return false
	return true


## Returns true if the item needs authentication at the given price.
func needs_authentication(
	item: ItemInstance, listing_price: float
) -> bool:
	if not can_authenticate(item):
		return false
	if listing_price <= _value_threshold:
		return false
	return true


## Authenticates a canonical content item and emits the adjusted sale price.
func request_authentication(item_id: Variant) -> bool:
	var canonical: StringName = _resolve_canonical_item_id(item_id)
	if canonical.is_empty():
		return false
	if _authenticated_canonical_ids.has(canonical):
		return false

	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return false

	var base_price: float = float(entry.get("base_price", 0.0))
	var final_price: float = base_price
	if _is_suspicious_entry(entry):
		final_price *= SUSPICIOUS_PRICE_MULTIPLIER

	_authenticated_canonical_ids[canonical] = true
	EventBus.authentication_completed.emit(
		canonical, true, final_price
	)
	return true


## Rejects a canonical content item and emits the rejection signal.
func reject_authentication(item_id: Variant) -> bool:
	var canonical: StringName = _resolve_canonical_item_id(item_id)
	if canonical.is_empty():
		return false
	EventBus.authentication_rejected.emit(canonical)
	return true


## Authenticates the item immediately. Returns true on success.
func authenticate(instance_id: String) -> bool:
	if not _inventory_system or not _economy_system:
		# §F-13: failure is signaled via authentication_completed(false) on EventBus;
		# push_warning is supplementary log evidence.
		push_warning("AuthenticationSystem: systems not initialized")
		EventBus.authentication_completed.emit(
			instance_id, false, "System not ready"
		)
		return false

	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_authenticate(item):
		# §F-13: same — EventBus carries the failure to UI.
		push_warning(
			"AuthenticationSystem: item '%s' not eligible"
			% instance_id
		)
		EventBus.authentication_completed.emit(
			instance_id, false, "Item not eligible for authentication"
		)
		return false

	if not _economy_system.deduct_cash(
		_auth_fee, "Authentication: %s" % item.definition.item_name
	):
		EventBus.authentication_completed.emit(
			instance_id, false,
			"Insufficient funds ($%.2f required)" % _auth_fee
		)
		return false

	item.authentication_status = "authenticated"
	EventBus.authentication_started.emit(instance_id, _auth_fee)
	EventBus.authentication_completed.emit(
		instance_id, true,
		"%s authenticated successfully" % item.definition.item_name
	)
	EventBus.notification_requested.emit(
		"Authenticated: %s (%.1fx value multiplier)"
		% [item.definition.item_name, _auth_multiplier]
	)
	return true


func get_save_data() -> Dictionary:
	var authenticated_ids: Array[String] = []
	for canonical_id: Variant in _authenticated_canonical_ids.keys():
		authenticated_ids.append(String(canonical_id))
	return {
		"authenticated_canonical_ids": authenticated_ids,
	}


func load_save_data(data: Dictionary) -> void:
	_authenticated_canonical_ids.clear()
	var saved_ids: Variant = data.get("authenticated_canonical_ids", [])
	if saved_ids is not Array:
		# §F-27: wrong type in save data means authentication history is lost for
		# this load; push_warning surfaces the regression in logs.
		push_warning(
			"AuthenticationSystem: expected Array for authenticated_canonical_ids, got %s — authentication history reset"
			% type_string(typeof(saved_ids))
		)
		return
	for saved_id: Variant in saved_ids:
		var canonical_id: String = str(saved_id)
		if canonical_id.is_empty():
			continue
		_authenticated_canonical_ids[StringName(canonical_id)] = true


func _load_config() -> void:
	if not ContentRegistry.exists(STORE_TYPE):
		return
	var entry: Dictionary = ContentRegistry.get_entry(
		StringName(STORE_TYPE)
	)
	if entry.is_empty():
		return
	var config: Variant = entry.get("authentication_config", {})
	if config is not Dictionary:
		# §F-15: authentication_config key exists but is the wrong type — likely
		# a content-authoring error. Log and fall back to compile-time defaults.
		push_warning(
			"AuthenticationSystem: authentication_config for '%s' is %s, not Dictionary — using defaults"
			% [STORE_TYPE, type_string(typeof(config))]
		)
		return
	var auth_config: Dictionary = config as Dictionary
	_value_threshold = float(
		auth_config.get("value_threshold", DEFAULT_THRESHOLD)
	)
	_auth_fee = float(
		auth_config.get("auth_fee", DEFAULT_FEE)
	)
	_auth_multiplier = float(
		auth_config.get("auth_multiplier", DEFAULT_MULTIPLIER)
	)


func _on_price_set(item_id: String, price: float) -> void:
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(item_id)
	if not item:
		return
	if needs_authentication(item, price):
		EventBus.authentication_dialog_requested.emit(item_id)


func _resolve_canonical_item_id(item_id: Variant) -> StringName:
	var raw_id: String = String(item_id)
	if raw_id.is_empty():
		return &""
	var canonical: StringName = ContentRegistry.resolve(raw_id)
	if canonical.is_empty():
		return &""
	return canonical


func _is_suspicious_entry(entry: Dictionary) -> bool:
	# Three content schema generations: "suspicious" (v1), "is_suspicious" (v2),
	# "suspicious_chance >= 1.0" (v3 probability encoding). All must be checked
	# until legacy content is migrated.
	if bool(entry.get("suspicious", false)):
		return true
	if bool(entry.get("is_suspicious", false)):
		return true
	return float(entry.get("suspicious_chance", 0.0)) >= 1.0
