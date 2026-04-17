## Tests NPCSpawnerSystem pooled ShopperAI spawning and active-store integration.
extends GutTest


var _system: NPCSpawnerSystem
var _store_root: Node3D
var _store_definition: StoreDefinition


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_store_root = Node3D.new()
	_store_root.name = "test_store"
	add_child_autofree(_store_root)
	var container := Node3D.new()
	container.name = "npc_container"
	_store_root.add_child(container)

	_store_definition = StoreDefinition.new()
	_store_definition.id = "test_store"
	_store_definition.size_category = "small"
	ContentRegistry.register(&"test_store", _store_definition, "store")
	ContentRegistry.register_entry(
		{
			"id": "test_store",
			"display_name": "Test Store",
			"scene_path": "res://game/scenes/stores/test_store.tscn",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "power_shopper",
			"personality_type": "POWER_SHOPPER",
			"shop_weight": 1.5,
			"impulse_factor": 0.3,
			"min_budget": 80.0,
			"max_budget": 300.0,
		},
		"personality_data"
	)

	_system = NPCSpawnerSystem.new()
	add_child_autofree(_system)
	_system.initialize()
	EventBus.active_store_changed.emit(&"test_store")


func after_each() -> void:
	ContentRegistry.clear_for_testing()


func test_ready_prewarms_default_pool_size() -> void:
	assert_eq(_system.get_pooled_count(), NPCSpawnerSystem.DEFAULT_POOL_SIZE)


func test_spawn_places_configured_shopper_in_active_store_container() -> void:
	var entry_position := Vector3(2.0, 0.0, 4.0)
	var npc: ShopperAI = (
		_system.spawn_npc(&"power_shopper", entry_position) as ShopperAI
	)
	var npc_container: Node3D = _store_root.get_node("npc_container") as Node3D
	assert_not_null(npc)
	assert_eq(npc.get_parent(), npc_container)
	assert_eq(npc.global_position, entry_position)
	assert_eq(npc.archetype_id, &"power_shopper")
	assert_not_null(npc.personality)
	assert_eq(
		npc.personality.personality_type,
		PersonalityData.PersonalityType.POWER_SHOPPER
	)


func test_spawn_request_signal_emits_customer_spawned_after_successful_spawn() -> void:
	var emitted: Array[Node] = []
	var capture := func(customer: Node) -> void:
		if customer is ShopperAI:
			emitted.append(customer)
	EventBus.customer_spawned.connect(capture)
	EventBus.spawn_npc_requested.emit(&"power_shopper", Vector3.ONE)
	EventBus.customer_spawned.disconnect(capture)
	assert_eq(emitted.size(), 1)
	assert_true(emitted[0] is ShopperAI)


func test_despawn_returns_npc_to_pool_without_freeing() -> void:
	var npc: ShopperAI = (
		_system.spawn_npc(&"power_shopper", Vector3.ZERO) as ShopperAI
	)
	var pool_before: int = _system.get_pooled_count()
	_system.despawn_npc(npc)
	assert_true(is_instance_valid(npc))
	assert_eq(_system.get_active_count(), 0)
	assert_eq(_system.get_pooled_count(), pool_before + 1)
	assert_eq(npc.get_parent(), _system)
	assert_false(npc.visible)


func test_active_store_change_despawns_all_active_npcs_and_clears_bindings() -> void:
	_system.spawn_npc(&"power_shopper", Vector3.ZERO)
	_system.spawn_npc(&"power_shopper", Vector3.ONE)
	EventBus.active_store_changed.emit(&"other_store")
	assert_eq(_system.get_active_count(), 0)
	assert_eq(_system._active_store_scene, null)
	assert_eq(_system._active_npc_container, null)


func test_spawn_returns_null_when_store_capacity_reached() -> void:
	for _i: int in range(NPCSpawnerSystem.DEFAULT_STORE_CAPACITY):
		_system.spawn_npc(&"power_shopper", Vector3.ZERO)
	var overflow: Node = _system.spawn_npc(&"power_shopper", Vector3.ONE)
	assert_null(overflow)
	assert_eq(
		_system.get_active_count(),
		NPCSpawnerSystem.DEFAULT_STORE_CAPACITY
	)


func test_pool_exhaustion_still_allows_second_spawn() -> void:
	_system = NPCSpawnerSystem.new()
	add_child_autofree(_system)
	for pooled: ShopperAI in _system._pool:
		if is_instance_valid(pooled):
			pooled.queue_free()
	_system._pool.clear()
	_system.pool_size = 1
	_system.initialize()
	EventBus.active_store_changed.emit(&"test_store")
	var first: Node = _system.spawn_npc(&"power_shopper", Vector3.ZERO)
	var second: Node = _system.spawn_npc(&"power_shopper", Vector3.ONE)
	assert_not_null(first)
	assert_not_null(second)
	assert_eq(_system.get_active_count(), 2)
	assert_eq(_system.get_pooled_count(), 0)
