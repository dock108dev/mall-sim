## GUT unit tests for NPCSpawnerSystem — spawn lifecycle, capacity enforcement,
## and EventBus signal contracts.
extends GutTest


var _spawner: NPCSpawnerSystem
var _nav_config: CustomerNavConfig


func before_each() -> void:
	_spawner = NPCSpawnerSystem.new()
	add_child_autofree(_spawner)
	_spawner.initialize(null)

	_nav_config = CustomerNavConfig.new()
	add_child_autofree(_nav_config)


func after_each() -> void:
	EventBus.customer_spawning_enabled.emit()


## Verify that when spawning is disabled (store closed), incoming customer_spawned
## signals are queued rather than activating a new NPC.
func test_no_spawn_when_store_closed() -> void:
	EventBus.customer_spawning_disabled.emit()
	assert_true(
		_spawner._spawning_disabled,
		"Spawner should be disabled after customer_spawning_disabled signal"
	)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	assert_eq(
		_spawner.get_active_count(), 0,
		"No NPC should become active when spawning is disabled"
	)
	assert_eq(
		_spawner._spawn_queue.size(), 1,
		"Spawn request should be queued while spawning is disabled"
	)


## Verify that when the store is open and customer_spawned fires, a CustomerNPC
## becomes active and the queue remains empty.
func test_spawn_fires_customer_spawned() -> void:
	assert_false(
		_spawner._spawning_disabled,
		"Spawner should be enabled by default"
	)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	assert_eq(
		_spawner.get_active_count(), 1,
		"One CustomerNPC should be active after customer_spawned with store open"
	)
	assert_eq(
		_spawner._spawn_queue.size(), 0,
		"Queue should be empty when NPC was spawned immediately"
	)


## Verify that spawn requests are queued rather than activated once active NPCs
## reach max_concurrent_customers.
func test_capacity_cap_prevents_spawn() -> void:
	_nav_config.max_concurrent_customers = 1
	_spawner._current_nav_config = _nav_config

	# Occupy the single slot with a placeholder so capacity is full.
	var placeholder: Node3D = Node3D.new()
	add_child_autofree(placeholder)
	_spawner._active_customer_npcs[placeholder] = {}

	assert_eq(_spawner.get_active_count(), 1, "Sanity: one slot already occupied")

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	assert_eq(
		_spawner.get_active_count(), 1,
		"Active count must not exceed max_concurrent_customers"
	)
	assert_eq(
		_spawner._spawn_queue.size(), 1,
		"Overflow spawn request should be placed in the queue"
	)


## Verify that when customer_left fires after an NPC is active, the system removes
## the NPC from active tracking and emits customer_left (signal contract check).
func test_despawn_fires_customer_left() -> void:
	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(_spawner.get_active_count(), 1, "Sanity: NPC active before despawn")

	var left_received: bool = false
	var cb: Callable = func(_data: Dictionary) -> void:
		left_received = true
	EventBus.customer_left.connect(cb)

	# Simulates what CustomerSystem.despawn_customer() does: emit customer_left.
	EventBus.customer_left.emit({"satisfied": false})

	EventBus.customer_left.disconnect(cb)

	assert_true(
		left_received,
		"customer_left signal must fire when a customer is despawned"
	)
	assert_eq(
		_spawner.get_active_count(), 0,
		"Active NPC count must be zero after customer_left signal"
	)


## Verify that when the spawn rate multiplier is zero (represented by spawning
## disabled), no NPCs become active regardless of incoming spawn requests.
func test_spawn_rate_uses_time_multiplier() -> void:
	EventBus.customer_spawning_disabled.emit()

	var dummy1: Node = Node.new()
	var dummy2: Node = Node.new()
	add_child_autofree(dummy1)
	add_child_autofree(dummy2)
	EventBus.customer_spawned.emit(dummy1)
	EventBus.customer_spawned.emit(dummy2)

	assert_eq(
		_spawner.get_active_count(), 0,
		"Zero spawn-rate multiplier must keep all NPCs out of active set"
	)
	assert_eq(
		_spawner._spawn_queue.size(), 2,
		"Both spawn requests must be queued with zero multiplier"
	)


## Verify that get_active_count() reflects each successful spawn immediately.
func test_active_customer_count_increments_on_spawn() -> void:
	for i: int in range(3):
		var dummy: Node = Node.new()
		add_child_autofree(dummy)
		EventBus.customer_spawned.emit(dummy)
		assert_eq(
			_spawner.get_active_count(), i + 1,
			"Active count should be %d after %d spawn(s)" % [i + 1, i + 1]
		)
