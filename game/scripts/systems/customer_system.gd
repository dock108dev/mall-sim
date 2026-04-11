## Manages active customer NPCs within the currently viewed store.
class_name CustomerSystem
extends Node

const MAX_CUSTOMERS_SMALL: int = 5
const MAX_CUSTOMERS_MEDIUM: int = 8
const CUSTOMER_SCENE_PATH: String = (
	"res://game/scenes/characters/customer.tscn"
)
const POOL_SIZE: int = 12
## Maximum active customers used for stagger offset distribution.
const STAGGER_SLOTS: int = 8

var _active_customers: Array[Customer] = []
var _customer_pool: Array[Customer] = []
var _customer_scene: PackedScene = null
var _store_controller: StoreController = null
var _inventory_system: InventorySystem = null
var _reputation_system: ReputationSystem = null
var _performance_manager: PerformanceManager = null
var _store_id: String = ""
var _max_customers: int = MAX_CUSTOMERS_SMALL
var _next_stagger_index: int = 0


func initialize(
	store_controller: StoreController = null,
	inventory_system: InventorySystem = null,
	reputation_system: ReputationSystem = null
) -> void:
	_despawn_all_customers()
	clear_pool()

	_store_controller = store_controller
	_inventory_system = inventory_system
	_reputation_system = reputation_system

	_customer_scene = load(CUSTOMER_SCENE_PATH) as PackedScene
	if not _customer_scene:
		push_error("CustomerSystem: failed to load customer scene")
		return

	if not EventBus.day_ended.is_connected(_on_day_ended):
		EventBus.day_ended.connect(_on_day_ended)
	if not EventBus.reputation_changed.is_connected(
		_on_reputation_changed
	):
		EventBus.reputation_changed.connect(_on_reputation_changed)


## Sets the performance manager reference for NPC profiling.
func set_performance_manager(manager: PerformanceManager) -> void:
	_performance_manager = manager


func _physics_process(_delta: float) -> void:
	if not _performance_manager or _active_customers.is_empty():
		return
	var total_script: float = 0.0
	var total_nav: float = 0.0
	var total_anim: float = 0.0
	for customer: Customer in _active_customers:
		total_script += customer.last_script_time_ms
		total_nav += customer.last_nav_time_ms
		total_anim += customer.last_anim_time_ms
	_performance_manager.record_npc_frame(
		total_script, total_nav, total_anim,
		_active_customers.size()
	)


## Spawns a customer with the given profile for the specified store.
func spawn_customer(
	profile: CustomerProfile, store_id: String = ""
) -> void:
	if _active_customers.size() >= _max_customers:
		push_warning(
			"CustomerSystem: max customers reached, ignoring spawn"
		)
		return

	var customer: Customer = _acquire_customer()
	if not customer:
		push_error(
			"CustomerSystem: failed to acquire customer from pool"
		)
		return

	var spawn_pos: Vector3 = _get_spawn_position()
	customer.global_position = spawn_pos
	if not customer.is_inside_tree():
		add_child(customer)
	customer.visible = true
	customer.set_physics_process(true)
	customer.set_process(true)
	customer.stagger_offset = (
		float(_next_stagger_index) / float(STAGGER_SLOTS)
	)
	_next_stagger_index = (
		(_next_stagger_index + 1) % STAGGER_SLOTS
	)
	var budget_mult: float = 1.0
	if _reputation_system:
		budget_mult = _reputation_system.get_budget_multiplier()
	customer.initialize(
		profile, _store_controller, _inventory_system, budget_mult
	)
	customer.despawn_requested.connect(_on_customer_despawn_requested)
	_active_customers.append(customer)

	var used_store_id: String = store_id
	if used_store_id.is_empty():
		used_store_id = _store_id

	var customer_data: Dictionary = {
		"customer_id": customer.get_instance_id(),
		"profile_id": profile.id,
		"profile_name": profile.name,
		"store_id": used_store_id,
	}
	EventBus.customer_entered.emit(customer_data)


## Removes a customer from active duty and returns it to the pool.
func despawn_customer(customer_node: Node) -> void:
	if not customer_node:
		push_warning("CustomerSystem: tried to despawn null customer")
		return

	var customer: Customer = customer_node as Customer
	if not customer:
		push_warning("CustomerSystem: node is not a Customer")
		return

	var customer_data: Dictionary = {
		"customer_id": customer.get_instance_id(),
		"profile_id": customer.profile.id if customer.profile else "",
		"profile_name": (
			customer.profile.name if customer.profile else ""
		),
		"store_id": _store_id,
	}

	if customer.despawn_requested.is_connected(
		_on_customer_despawn_requested
	):
		customer.despawn_requested.disconnect(
			_on_customer_despawn_requested
		)
	_active_customers.erase(customer)
	_release_customer(customer)
	EventBus.customer_left.emit(customer_data)


## Returns the list of currently active customers.
func get_active_customers() -> Array[Customer]:
	return _active_customers


## Returns the number of currently active customers.
func get_active_customer_count() -> int:
	return _active_customers.size()


## Sets the store controller reference for customer navigation.
func set_store_controller(controller: StoreController) -> void:
	_store_controller = controller


## Sets the inventory system reference for customer item evaluation.
func set_inventory_system(system: InventorySystem) -> void:
	_inventory_system = system


## Sets the reputation system reference for tier-based scaling.
func set_reputation_system(system: ReputationSystem) -> void:
	_reputation_system = system
	_update_max_customers()


## Sets the current store id and adjusts per-store customer cap.
func set_store_id(store_id: String) -> void:
	_store_id = store_id
	_update_max_customers()


## Sets the per-store customer cap based on store size and reputation tier.
func _update_max_customers() -> void:
	if not GameManager.data_loader or _store_id.is_empty():
		_max_customers = MAX_CUSTOMERS_SMALL
		return
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(_store_id)
	)
	if not store_def:
		_max_customers = MAX_CUSTOMERS_SMALL
		return
	var size_cat: String = store_def.size_category
	if _reputation_system:
		_max_customers = _reputation_system.get_max_customers(size_cat)
	elif size_cat == "medium" or size_cat == "large":
		_max_customers = MAX_CUSTOMERS_MEDIUM
	else:
		_max_customers = MAX_CUSTOMERS_SMALL


func _get_spawn_position() -> Vector3:
	if not _store_controller:
		return Vector3.ZERO
	var entry: Area3D = _store_controller.get_entry_area()
	if entry:
		return entry.global_position
	return Vector3.ZERO


func _on_customer_despawn_requested(customer: Customer) -> void:
	despawn_customer(customer)


func _on_reputation_changed(
	_old_value: float, _new_value: float
) -> void:
	_update_max_customers()


func _on_day_ended(_day: int) -> void:
	_despawn_all_customers()


## Removes all active customers at once (e.g. end of day).
func _despawn_all_customers() -> void:
	var to_remove: Array[Customer] = _active_customers.duplicate()
	for customer: Customer in to_remove:
		despawn_customer(customer)


## Acquires a customer node from the pool or creates a new one.
func _acquire_customer() -> Customer:
	if not _customer_pool.is_empty():
		return _customer_pool.pop_back()
	if not _customer_scene:
		return null
	return _customer_scene.instantiate() as Customer


## Frees all pooled customer nodes and clears the pool array.
func clear_pool() -> void:
	for customer: Customer in _customer_pool:
		if is_instance_valid(customer):
			customer.queue_free()
	_customer_pool.clear()


## Returns a customer node to the pool for reuse.
func _release_customer(customer: Customer) -> void:
	customer.visible = false
	customer.set_physics_process(false)
	customer.set_process(false)
	if _customer_pool.size() < POOL_SIZE:
		_customer_pool.append(customer)
	else:
		customer.queue_free()
