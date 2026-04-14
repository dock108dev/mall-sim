## Tests NPCSpawnerSystem customer NPC spawning, despawning, and queue logic.
extends GutTest


var _system: NPCSpawnerSystem
var _nav_config: CustomerNavConfig
var _store_root: Node3D
var _spawned_signals: Array[Node] = []


func before_each() -> void:
	_spawned_signals.clear()

	_store_root = Node3D.new()
	_store_root.name = "test_store"
	add_child_autofree(_store_root)

	_nav_config = CustomerNavConfig.new()
	_nav_config.name = "CustomerNavConfig"
	_nav_config.max_concurrent_customers = 2
	_store_root.add_child(_nav_config)

	var entry := Marker3D.new()
	entry.position = Vector3(0.0, 0.0, 0.0)
	_nav_config.add_child(entry)
	_nav_config.entry_point = entry

	var wp1 := Marker3D.new()
	wp1.position = Vector3(1.0, 0.0, 0.0)
	_nav_config.add_child(wp1)
	_nav_config.browse_waypoints = [wp1]

	var checkout := Marker3D.new()
	checkout.position = Vector3(3.0, 0.0, 0.0)
	_nav_config.add_child(checkout)
	_nav_config.checkout_approach = checkout

	var exit_marker := Marker3D.new()
	exit_marker.position = Vector3(0.0, 0.0, 5.0)
	_nav_config.add_child(exit_marker)
	_nav_config.exit_point = exit_marker

	_system = NPCSpawnerSystem.new()
	add_child_autofree(_system)
	_system.initialize()
	_system._current_store_root = _store_root
	_system._current_nav_config = _nav_config


func after_each() -> void:
	_spawned_signals.clear()


func test_spawn_creates_valid_node_reference() -> void:
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(
		_system.get_active_count(), 1,
		"Should have 1 active NPC after spawn signal"
	)
	var npcs: Array = _system._active_customer_npcs.keys()
	assert_eq(npcs.size(), 1, "Should track exactly one NPC")
	assert_true(
		is_instance_valid(npcs[0]),
		"Tracked NPC should be a valid node reference"
	)


func test_active_npcs_tracked_in_dictionary() -> void:
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(
		_system.get_active_count(), 1,
		"Active NPC should be tracked in dictionary"
	)


func test_max_concurrent_spawn_is_noop() -> void:
	var d1 := Node.new()
	var d2 := Node.new()
	var d3 := Node.new()
	add_child_autofree(d1)
	add_child_autofree(d2)
	add_child_autofree(d3)
	EventBus.customer_spawned.emit(d1)
	EventBus.customer_spawned.emit(d2)
	EventBus.customer_spawned.emit(d3)
	assert_eq(
		_system.get_active_count(), 2,
		"Should not exceed max_concurrent_customers"
	)
	assert_eq(
		_system.get_queue_count(), 1,
		"Excess spawn should be queued, not spawned"
	)


func test_store_exited_frees_all_and_resets_count() -> void:
	var d1 := Node.new()
	var d2 := Node.new()
	add_child_autofree(d1)
	add_child_autofree(d2)
	EventBus.customer_spawned.emit(d1)
	EventBus.customer_spawned.emit(d2)
	assert_eq(_system.get_active_count(), 2)
	EventBus.store_exited.emit(&"test_store")
	assert_eq(
		_system.get_active_count(), 0,
		"All NPCs should be cleared on store_exited"
	)


func test_store_exited_clears_queue() -> void:
	var d1 := Node.new()
	var d2 := Node.new()
	var d3 := Node.new()
	add_child_autofree(d1)
	add_child_autofree(d2)
	add_child_autofree(d3)
	EventBus.customer_spawned.emit(d1)
	EventBus.customer_spawned.emit(d2)
	EventBus.customer_spawned.emit(d3)
	EventBus.store_exited.emit(&"test_store")
	assert_eq(
		_system.get_queue_count(), 0,
		"Queue should be cleared on store_exited"
	)


func test_store_exited_resets_store_state() -> void:
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	EventBus.store_exited.emit(&"test_store")
	assert_null(
		_system._current_nav_config,
		"Nav config should be null after store exit"
	)
	assert_null(
		_system._current_store_root,
		"Store root should be null after store exit"
	)
	assert_eq(
		_system._current_store_id, &"",
		"Store ID should be empty after store exit"
	)


func test_spawn_config_from_nav_config_not_hardcoded() -> void:
	var alt_store := Node3D.new()
	alt_store.name = "alt_store"
	add_child_autofree(alt_store)

	var alt_nav := CustomerNavConfig.new()
	alt_nav.max_concurrent_customers = 5
	alt_store.add_child(alt_nav)

	var alt_entry := Marker3D.new()
	alt_nav.add_child(alt_entry)
	alt_nav.entry_point = alt_entry

	_system._current_store_root = alt_store
	_system._current_nav_config = alt_nav

	for i: int in range(6):
		var d := Node.new()
		add_child_autofree(d)
		EventBus.customer_spawned.emit(d)

	assert_eq(
		_system.get_active_count(), 5,
		"Max should be 5 from alt store nav config"
	)
	assert_eq(
		_system.get_queue_count(), 1,
		"6th spawn should be queued with max=5"
	)


func test_get_nav_config_returns_config() -> void:
	var config: CustomerNavConfig = _system.get_nav_config(_store_root)
	assert_not_null(config, "Should find CustomerNavConfig in store root")
	assert_eq(
		config.max_concurrent_customers, 2,
		"Should return the correct nav config"
	)


func test_get_nav_config_missing_returns_null() -> void:
	var empty_root := Node3D.new()
	empty_root.name = "empty_store"
	add_child_autofree(empty_root)
	var config: CustomerNavConfig = _system.get_nav_config(empty_root)
	assert_null(
		config,
		"Should return null when no CustomerNavConfig found"
	)


func test_spawn_without_nav_config_still_works() -> void:
	_system._current_nav_config = null
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(
		_system.get_active_count(), 1,
		"Should spawn NPC even without nav config"
	)


func test_spawn_without_store_root_uses_self_as_parent() -> void:
	_system._current_store_root = null
	_system._current_nav_config = null
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(
		_system.get_active_count(), 1,
		"Should spawn NPC using self as parent when no store root"
	)


func test_queued_spawn_processes_after_leave() -> void:
	var d1 := Node.new()
	var d2 := Node.new()
	var d3 := Node.new()
	add_child_autofree(d1)
	add_child_autofree(d2)
	add_child_autofree(d3)
	EventBus.customer_spawned.emit(d1)
	EventBus.customer_spawned.emit(d2)
	EventBus.customer_spawned.emit(d3)
	assert_eq(_system.get_active_count(), 2)
	assert_eq(_system.get_queue_count(), 1)
	EventBus.customer_left.emit({})
	assert_eq(
		_system.get_queue_count(), 0,
		"Queue should drain after a customer leaves"
	)


func test_checkout_handoff_triggers_leave() -> void:
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	var npcs: Array = _system._active_customer_npcs.keys()
	assert_eq(npcs.size(), 1)
	var npc: Node = npcs[0]
	EventBus.customer_reached_checkout.emit(npc)
	assert_true(
		_system._checkout_pending.has(npc),
		"NPC should be in checkout pending"
	)
	EventBus.transaction_completed.emit(10.0, true, "")
	assert_false(
		_system._checkout_pending.has(npc),
		"NPC should be removed from checkout pending after transaction"
	)


func test_spawning_disabled_queues_instead() -> void:
	EventBus.customer_spawning_disabled.emit()
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(
		_system.get_active_count(), 0,
		"Should not spawn when spawning is disabled"
	)
	assert_eq(
		_system.get_queue_count(), 1,
		"Should queue when spawning is disabled"
	)


func test_spawning_enabled_drains_queue() -> void:
	EventBus.customer_spawning_disabled.emit()
	var dummy := Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(_system.get_queue_count(), 1)
	EventBus.customer_spawning_enabled.emit()
	assert_eq(
		_system.get_queue_count(), 0,
		"Queue should drain when spawning is re-enabled"
	)
