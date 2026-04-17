## Focused regression tests for NPCSpawnerSystem EventBus compatibility.
extends GutTest


var _spawner: NPCSpawnerSystem
var _store_root: Node3D
var _store_definition: StoreDefinition


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_store_root = Node3D.new()
	_store_root.name = "compat_store"
	var container := Node3D.new()
	container.name = "npc_container"
	_store_root.add_child(container)
	add_child_autofree(_store_root)
	_store_definition = StoreDefinition.new()
	_store_definition.id = "compat_store"
	ContentRegistry.register(&"compat_store", _store_definition, "store")
	ContentRegistry.register_entry({"id": "compat_store"}, "store")
	ContentRegistry.register_entry(
		{"id": "impulse_buyer", "personality_type": "IMPULSE_BUYER"},
		"personality_data"
	)
	_spawner = NPCSpawnerSystem.new()
	add_child_autofree(_spawner)
	_spawner.initialize(null)
	EventBus.active_store_changed.emit(&"compat_store")


func after_each() -> void:
	ContentRegistry.clear_for_testing()


func test_spawn_request_uses_eventbus_only() -> void:
	EventBus.spawn_npc_requested.emit(&"impulse_buyer", Vector3(1.0, 0.0, 2.0))
	assert_eq(_spawner.get_active_count(), 1)


func test_legacy_customer_spawned_input_ignores_shopper_output() -> void:
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(_spawner.get_active_count(), 1)
	var active_before: int = _spawner.get_active_count()
	var shopper := _spawner.spawn_npc(&"impulse_buyer", Vector3.ZERO) as ShopperAI
	EventBus.customer_spawned.emit(shopper)
	assert_eq(_spawner.get_active_count(), active_before + 1)


func test_active_store_change_clears_scene_bindings() -> void:
	_spawner.spawn_npc(&"impulse_buyer", Vector3.ZERO)
	EventBus.active_store_changed.emit(&"")
	assert_eq(_spawner.get_active_count(), 0)
	assert_null(_spawner._active_store_scene)
	assert_null(_spawner._active_npc_container)
