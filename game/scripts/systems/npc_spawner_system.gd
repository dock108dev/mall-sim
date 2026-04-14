## Spawns and manages CustomerNPC instances within the active store.
class_name NPCSpawnerSystem
extends Node

const CUSTOMER_NPC_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer_npc.tscn"
)
const MAX_CUSTOMERS: int = 20
const PEAK_SPAWN_INTERVAL: float = 3.0
const OFF_PEAK_SPAWN_INTERVAL: float = 6.0

var npc_factory: Callable
var _active_customer_npcs: Dictionary = {}
var _spawn_queue: Array[Dictionary] = []
var _current_nav_config: CustomerNavConfig = null
var _current_store_root: Node = null
var _checkout_pending: Dictionary = {}
var _inventory_system: InventorySystem = null
var _current_store_id: StringName = &""
var _spawning_disabled: bool = false
var _spawn_timer: Timer = null


func initialize(inventory_system: InventorySystem = null) -> void:
	_inventory_system = inventory_system
	if not npc_factory.is_valid():
		npc_factory = _default_npc_factory
	_connect_signals()
	_setup_spawn_timer()


func get_active_count() -> int:
	return _active_customer_npcs.size()


func get_queue_count() -> int:
	return _spawn_queue.size()


func get_nav_config(store_root: Node) -> CustomerNavConfig:
	for child: Node in store_root.get_children():
		if child is CustomerNavConfig:
			return child as CustomerNavConfig
	push_warning(
		"NPCSpawnerSystem: No CustomerNavConfig in store '%s'"
		% store_root.name
	)
	return null


func _connect_signals() -> void:
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.customer_reached_checkout.connect(
		_on_customer_reached_checkout
	)
	EventBus.transaction_completed.connect(_on_transaction_completed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.customer_spawning_disabled.connect(_on_spawning_disabled)
	EventBus.customer_spawning_enabled.connect(_on_spawning_enabled)
	EventBus.hour_changed.connect(_on_hour_changed)


func _on_store_entered(store_id: StringName) -> void:
	_current_store_id = store_id
	var store_root: Node = _find_store_root(store_id)
	if not store_root:
		push_warning(
			"NPCSpawnerSystem: Could not find store root for '%s'"
			% store_id
		)
		_current_store_root = null
		_current_nav_config = null
		return
	_current_store_root = store_root
	_current_nav_config = get_nav_config(store_root)


func _on_spawning_disabled() -> void:
	_spawning_disabled = true


func _on_spawning_enabled() -> void:
	_spawning_disabled = false
	_try_spawn_from_queue()


func _on_hour_changed(_hour: int) -> void:
	_update_timer_interval()


## Attempts one spawn from the queue, enforcing the MAX_CUSTOMERS hard cap.
func _try_spawn() -> void:
	if _spawning_disabled:
		return
	if _active_customer_npcs.size() >= MAX_CUSTOMERS:
		return
	_try_spawn_from_queue()


## Removes npc from the active pool and emits npc_despawned with the NPC's instance id.
func _despawn_npc(npc: CustomerNPC) -> void:
	if not _active_customer_npcs.has(npc):
		return
	var npc_id: StringName = StringName(str(npc.get_instance_id()))
	_active_customer_npcs.erase(npc)
	EventBus.npc_despawned.emit(npc_id)
	if is_instance_valid(npc):
		npc.queue_free()


func _setup_spawn_timer() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.autostart = false
	_spawn_timer.one_shot = false
	add_child(_spawn_timer)
	_update_timer_interval()
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func _update_timer_interval() -> void:
	if not _spawn_timer:
		return
	if DifficultySystem.is_peak_hours():
		_spawn_timer.wait_time = PEAK_SPAWN_INTERVAL
	else:
		_spawn_timer.wait_time = OFF_PEAK_SPAWN_INTERVAL


func _on_spawn_timer_timeout() -> void:
	_try_spawn()
	_update_timer_interval()


func _on_customer_spawned(customer: Node) -> void:
	if _spawning_disabled:
		var customer_def: Dictionary = {}
		if customer.has_method("get_customer_data"):
			customer_def = customer.get_customer_data()
		_spawn_queue.append(customer_def)
		return

	var customer_def: Dictionary = {}
	if customer.has_method("get_customer_data"):
		customer_def = customer.get_customer_data()

	if _current_nav_config:
		var max_customers: int = (
			_current_nav_config.max_concurrent_customers
		)
		if _active_customer_npcs.size() >= max_customers:
			_spawn_queue.append(customer_def)
			return

	var npc: CustomerNPC = _spawn_customer_npc(customer_def)
	if npc:
		_active_customer_npcs[npc] = customer_def


func _on_customer_left(customer_data: Dictionary) -> void:
	var npc_to_remove: CustomerNPC = null
	for npc: Node in _active_customer_npcs.keys():
		if not is_instance_valid(npc):
			npc_to_remove = npc as CustomerNPC
			break
		var typed_npc: CustomerNPC = npc as CustomerNPC
		if not typed_npc:
			continue
		var state: CustomerNPC.CustomerVisitState = (
			typed_npc.get_visit_state()
		)
		if state == CustomerNPC.CustomerVisitState.BROWSING:
			npc_to_remove = typed_npc
			break

	if npc_to_remove:
		if is_instance_valid(npc_to_remove):
			npc_to_remove.begin_leave()
		_active_customer_npcs.erase(npc_to_remove)
		_try_spawn_from_queue()


func _on_store_exited(_store_id: StringName) -> void:
	_despawn_all_immediate()
	_spawn_queue.clear()
	_checkout_pending.clear()
	_current_nav_config = null
	_current_store_root = null
	_current_store_id = &""


func _on_customer_reached_checkout(customer_node: Node) -> void:
	if not _active_customer_npcs.has(customer_node):
		return
	_checkout_pending[customer_node] = true


func _on_transaction_completed(
	_amount: float, _success: bool, _message: String
) -> void:
	var nodes_to_leave: Array[Node] = []
	for npc: Node in _checkout_pending.keys():
		nodes_to_leave.append(npc)
	_checkout_pending.clear()

	for npc: Node in nodes_to_leave:
		if not is_instance_valid(npc):
			_active_customer_npcs.erase(npc)
			_try_spawn_from_queue()
			continue
		var typed_npc: CustomerNPC = npc as CustomerNPC
		if typed_npc:
			typed_npc.begin_leave()
		_active_customer_npcs.erase(npc)
		_try_spawn_from_queue()


func _spawn_customer_npc(customer_def: Dictionary) -> CustomerNPC:
	var npc: CustomerNPC
	if npc_factory.is_valid():
		npc = npc_factory.call(customer_def) as CustomerNPC
	else:
		npc = CUSTOMER_NPC_SCENE.instantiate() as CustomerNPC
	if not npc:
		push_error("NPCSpawnerSystem: Failed to instantiate CustomerNPC")
		return null

	var parent: Node = _current_store_root if _current_store_root else self
	parent.add_child(npc)

	if _current_nav_config:
		npc.global_position = _current_nav_config.get_entry_position()
		npc.initialize(
			customer_def, _current_nav_config,
			_inventory_system, _current_store_id
		)
	else:
		npc.global_position = Vector3.ZERO
		npc.initialize(
			customer_def, null,
			_inventory_system, _current_store_id
		)

	npc.begin_visit()
	return npc


func _despawn_all_immediate() -> void:
	for npc: Node in _active_customer_npcs.keys():
		if is_instance_valid(npc):
			npc.queue_free()
	_active_customer_npcs.clear()


func _try_spawn_from_queue() -> void:
	if _spawning_disabled:
		return
	if _spawn_queue.is_empty():
		return
	if _current_nav_config:
		var max_customers: int = (
			_current_nav_config.max_concurrent_customers
		)
		if _active_customer_npcs.size() >= max_customers:
			return
	var customer_def: Dictionary = _spawn_queue.pop_front()
	var npc: CustomerNPC = _spawn_customer_npc(customer_def)
	if npc:
		_active_customer_npcs[npc] = customer_def


func _default_npc_factory(_customer_def: Dictionary) -> CustomerNPC:
	return CUSTOMER_NPC_SCENE.instantiate() as CustomerNPC


func _find_store_root(store_id: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	var root: Node = tree.current_scene
	if not root:
		return null
	var nodes: Array[Node] = root.get_children()
	for node: Node in nodes:
		if node.name.to_snake_case() == String(store_id):
			return node
		var found: Node = _search_for_store(node, store_id)
		if found:
			return found
	return null


func _search_for_store(
	node: Node, store_id: StringName
) -> Node:
	for child: Node in node.get_children():
		if child.name.to_snake_case() == String(store_id):
			return child
		var found: Node = _search_for_store(child, store_id)
		if found:
			return found
	return null
