## Spawns and pools ShopperAI instances for the active store interior.
class_name NPCSpawnerSystem
extends Node

const SHOPPER_AI_SCENE: PackedScene = preload(
	"res://game/scenes/characters/shopper_ai.tscn"
)
const DEFAULT_POOL_SIZE: int = 10
const DEFAULT_STORE_CAPACITY: int = 8
const MEDIUM_STORE_CAPACITY: int = 12
const LARGE_STORE_CAPACITY: int = 16
const NPC_CONTAINER_NAME: StringName = &"npc_container"

@export var pool_size: int = DEFAULT_POOL_SIZE

var npc_factory: Callable
var _inventory_system: InventorySystem = null
var _pool: Array[ShopperAI] = []
var _active_npcs: Array[ShopperAI] = []
var _active_store_id: StringName = &""
var _active_store_scene: Node3D = null
var _active_npc_container: Node3D = null
var _signals_connected: bool = false


func initialize(inventory_system: InventorySystem = null) -> void:
	_inventory_system = inventory_system
	if not npc_factory.is_valid():
		npc_factory = _default_npc_factory
	_prewarm_pool()
	_connect_signals()


func get_active_count() -> int:
	return _active_npcs.size()


func get_pooled_count() -> int:
	return _pool.size()


func _ready() -> void:
	if not npc_factory.is_valid():
		npc_factory = _default_npc_factory
	_prewarm_pool()


func _connect_signals() -> void:
	if _signals_connected:
		return
	_safe_connect(EventBus.spawn_npc_requested, _on_spawn_npc_requested)
	_safe_connect(EventBus.customer_spawned, _on_customer_spawned)
	_safe_connect(EventBus.active_store_changed, _on_active_store_changed)
	_signals_connected = true


func spawn_npc(archetype_id: StringName, entry_position: Vector3) -> Node:
	_refresh_store_bindings()
	if _active_npc_container == null:
		push_warning("NPCSpawnerSystem: no active npc_container for store spawn")
		return null
	if _active_npcs.size() >= _get_store_capacity():
		push_warning(
			"NPCSpawnerSystem: store '%s' is at NPC capacity" % _active_store_id
		)
		return null
	var npc: ShopperAI = _acquire_npc()
	if npc == null:
		push_error("NPCSpawnerSystem: failed to acquire ShopperAI")
		return null
	var personality: PersonalityData = _build_personality(archetype_id)
	npc.configure_for_store_spawn(entry_position, archetype_id, personality)
	if npc.get_parent() != _active_npc_container:
		if npc.get_parent():
			npc.get_parent().remove_child(npc)
		_active_npc_container.add_child(npc)
	_active_npcs.append(npc)
	return npc


func despawn_npc(npc: Node) -> void:
	var shopper: ShopperAI = npc as ShopperAI
	if shopper == null:
		push_warning("NPCSpawnerSystem: despawn_npc expects a ShopperAI")
		return
	var active_index: int = _active_npcs.find(shopper)
	if active_index == -1:
		return
	_active_npcs.remove_at(active_index)
	shopper.reset_for_pool()
	if shopper.get_parent():
		shopper.get_parent().remove_child(shopper)
	add_child(shopper)
	_pool.append(shopper)
	EventBus.npc_despawned.emit(StringName(str(shopper.get_instance_id())))


func _on_spawn_npc_requested(
	archetype_id: StringName,
	entry_position: Vector3
) -> void:
	var npc: Node = spawn_npc(archetype_id, entry_position)
	if npc != null:
		EventBus.customer_spawned.emit(npc)


func _on_customer_spawned(customer: Node) -> void:
	if customer is ShopperAI:
		return
	var archetype_id: StringName = &"window_browser"
	if customer and customer.has_method("get_customer_data"):
		var customer_data: Dictionary = customer.get_customer_data()
		archetype_id = StringName(
			str(customer_data.get("archetype_id", archetype_id))
		)
	var npc: Node = spawn_npc(archetype_id, Vector3.ZERO)
	if npc != null:
		EventBus.customer_spawned.emit(npc)


func _on_active_store_changed(store_id: StringName) -> void:
	_despawn_all_active()
	_clear_store_bindings()
	_active_store_id = store_id
	if not store_id.is_empty():
		_refresh_store_bindings()


func _prewarm_pool() -> void:
	while _pool.size() < maxi(pool_size, 0):
		var shopper: ShopperAI = _instantiate_npc()
		if shopper == null:
			return
		shopper.reset_for_pool()
		_pool.append(shopper)


func _instantiate_npc() -> ShopperAI:
	var shopper: ShopperAI = null
	if npc_factory.is_valid():
		shopper = npc_factory.call() as ShopperAI
	if shopper == null:
		shopper = SHOPPER_AI_SCENE.instantiate() as ShopperAI
	if shopper == null:
		return null
	shopper.set_emit_spawn_signal_on_ready(false)
	add_child(shopper)
	return shopper


func _acquire_npc() -> ShopperAI:
	if not _pool.is_empty():
		return _pool.pop_back()
	return _instantiate_npc()


func _build_personality(archetype_id: StringName) -> PersonalityData:
	var entry: Dictionary = {}
	var raw_id: String = String(archetype_id)
	if not raw_id.is_empty() and ContentRegistry.exists(raw_id):
		var canonical: StringName = ContentRegistry.resolve(raw_id)
		entry = ContentRegistry.get_entry(canonical).duplicate(true)
	if entry.is_empty():
		entry = {
			"id": raw_id,
			"personality_type": raw_id.to_upper(),
		}
	elif not entry.has("personality_type"):
		entry["personality_type"] = raw_id.to_upper()
	return PersonalityData.from_dictionary(entry)


func _get_store_capacity() -> int:
	if _active_store_id.is_empty():
		return DEFAULT_STORE_CAPACITY
	var store_def: StoreDefinition = ContentRegistry.get_store_definition(
		_active_store_id
	)
	if store_def == null:
		return DEFAULT_STORE_CAPACITY
	match store_def.size_category:
		"large":
			return LARGE_STORE_CAPACITY
		"medium":
			return MEDIUM_STORE_CAPACITY
		_:
			return DEFAULT_STORE_CAPACITY


func _refresh_store_bindings() -> void:
	if _active_store_id.is_empty():
		return
	if _active_store_scene and is_instance_valid(_active_store_scene):
		if _active_npc_container and is_instance_valid(_active_npc_container):
			return
	_active_store_scene = _find_store_scene(_active_store_id)
	_active_npc_container = _ensure_npc_container(_active_store_scene)


func _clear_store_bindings() -> void:
	_active_store_scene = null
	_active_npc_container = null


func _ensure_npc_container(store_scene: Node3D) -> Node3D:
	if store_scene == null:
		return null
	var container: Node3D = store_scene.find_child(
		String(NPC_CONTAINER_NAME), true, false
	) as Node3D
	if container != null:
		return container
	container = Node3D.new()
	container.name = String(NPC_CONTAINER_NAME)
	store_scene.add_child(container)
	return container


func _find_store_scene(store_id: StringName) -> Node3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return _search_for_store(tree.root, store_id)


func _search_for_store(node: Node, store_id: StringName) -> Node3D:
	if node is Node3D and node.name.to_snake_case() == String(store_id):
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _search_for_store(child, store_id)
		if found != null:
			return found
	return null


func _despawn_all_active() -> void:
	var active_copy: Array[ShopperAI] = _active_npcs.duplicate()
	for npc: ShopperAI in active_copy:
		if is_instance_valid(npc):
			despawn_npc(npc)
		else:
			_active_npcs.erase(npc)


func _default_npc_factory() -> ShopperAI:
	return SHOPPER_AI_SCENE.instantiate() as ShopperAI


func _safe_connect(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)
