## Integration test: NPCSpawnerSystem + CustomerSystem spawn-to-queue pipeline.
## Validates that day phase transitions drive spawning state, customer_spawned
## produces active NPCSpawnerSystem entries, and QueueSystem enqueues customers
## that reach checkout.
extends GutTest

const CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)
const TEST_STORE_ID: StringName = &"test_npc_store"

var _npc_spawner: NPCSpawnerSystem
var _customer_system: CustomerSystem
var _queue: QueueSystem
var _test_store_root: Node = null

var _customer_entered_count: int = 0
var _queue_size_last: int = 0


func before_each() -> void:
	_customer_entered_count = 0
	_queue_size_last = 0
	_test_store_root = null

	_npc_spawner = NPCSpawnerSystem.new()
	add_child_autofree(_npc_spawner)
	_npc_spawner.initialize()

	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)
	_customer_system.initialize()

	_queue = QueueSystem.new()
	add_child_autofree(_queue)
	_queue.initialize()
	_queue.setup_queue_positions(Vector3.ZERO, Vector3(0.0, 0.0, 5.0))

	EventBus.customer_entered.connect(_on_customer_entered)
	EventBus.queue_changed.connect(_on_queue_changed)


func after_each() -> void:
	_safe_disconnect(EventBus.customer_entered, _on_customer_entered)
	_safe_disconnect(EventBus.queue_changed, _on_queue_changed)
	if _test_store_root and is_instance_valid(_test_store_root):
		_test_store_root.queue_free()
		_test_store_root = null


# ── Scenario A — Morning spawn wave ──────────────────────────────────────────


func test_scenario_a_morning_phase_updates_archetype_weights() -> void:
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MORNING_RAMP)

	assert_eq(
		_customer_system._current_archetype_weights,
		ShopperArchetypeConfig.WEIGHTS_MORNING,
		"MORNING_RAMP phase should set WEIGHTS_MORNING archetype weights"
	)


func test_scenario_a_customer_spawned_registers_npc_in_active_list() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MORNING_RAMP)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	assert_gt(
		_npc_spawner.get_active_count(), 0,
		"NPCSpawnerSystem should have ≥1 active NPC after customer_spawned in MORNING phase"
	)


func test_scenario_a_spawned_npc_enters_browsing_state() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MORNING_RAMP)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	assert_gt(
		_npc_spawner.get_active_count(), 0,
		"Precondition: at least one active NPC must exist"
	)

	var found_browsing: bool = false
	for npc: Node in _npc_spawner._active_customer_npcs.keys():
		var typed: CustomerNPC = npc as CustomerNPC
		if typed and is_instance_valid(typed):
			if typed.get_visit_state() == CustomerNPC.CustomerVisitState.BROWSING:
				found_browsing = true
				break
	assert_true(
		found_browsing,
		"At least one active NPC should be in BROWSING state after spawn"
	)


func test_scenario_a_multiple_spawns_match_signal_count() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MORNING_RAMP)

	var spawn_count: int = 3
	for i: int in range(spawn_count):
		var dummy: Node = Node.new()
		add_child_autofree(dummy)
		EventBus.customer_spawned.emit(dummy)

	# Active count is capped by CustomerNavConfig.max_concurrent_customers (4).
	# With 3 spawns and a cap of 4, all 3 should be active.
	assert_eq(
		_npc_spawner.get_active_count(), spawn_count,
		"Active NPC count should match number of customer_spawned signals when under cap"
	)


func test_scenario_a_customer_reaching_checkout_enqueues_in_queue_system() -> void:
	var customer: Customer = CUSTOMER_SCENE.instantiate() as Customer
	add_child_autofree(customer)

	EventBus.customer_reached_checkout.emit(customer)

	assert_eq(
		_queue.get_queue_size(), 1,
		"QueueSystem should hold 1 customer after customer_reached_checkout"
	)


func test_scenario_a_queue_changed_signal_fires_on_enqueue() -> void:
	watch_signals(EventBus)
	var customer: Customer = CUSTOMER_SCENE.instantiate() as Customer
	add_child_autofree(customer)

	EventBus.customer_reached_checkout.emit(customer)

	assert_signal_emitted(
		EventBus, "queue_changed",
		"queue_changed should fire when a customer is enqueued"
	)
	assert_eq(
		_queue_size_last, 1,
		"queue_changed payload should report queue size of 1"
	)


# ── Scenario B — CLOSING phase stops spawning and drains customers ────────────


func test_scenario_b_evening_phase_updates_archetype_weights() -> void:
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	assert_eq(
		_customer_system._current_archetype_weights,
		ShopperArchetypeConfig.WEIGHTS_EVENING,
		"EVENING phase should set WEIGHTS_EVENING archetype weights"
	)


func test_scenario_b_spawning_disabled_queues_overflow_not_active() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)

	# Seed one active NPC.
	var first: Node = Node.new()
	add_child_autofree(first)
	EventBus.customer_spawned.emit(first)
	var count_before: int = _npc_spawner.get_active_count()

	# Disable spawning (mirrors store-closing build-mode entry or explicit signal).
	EventBus.customer_spawning_disabled.emit()

	# A new customer_spawned while disabled should enter the spawn queue only.
	var second: Node = Node.new()
	add_child_autofree(second)
	EventBus.customer_spawned.emit(second)

	assert_eq(
		_npc_spawner.get_active_count(), count_before,
		"Active count must not increase while spawning is disabled"
	)
	assert_gt(
		_npc_spawner.get_queue_count(), 0,
		"Spawn queue should grow when spawning is disabled"
	)


func test_scenario_b_customer_left_removes_browsing_npc_from_active_list() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	var count_before: int = _npc_spawner.get_active_count()
	assert_gt(count_before, 0, "Precondition: at least one NPC must be active")

	EventBus.customer_left.emit({})

	assert_lt(
		_npc_spawner.get_active_count(), count_before,
		"Active count should decrease after customer_left removes a BROWSING NPC"
	)


func test_scenario_b_store_exited_despawns_all_npcs() -> void:
	_setup_test_store()
	EventBus.store_entered.emit(TEST_STORE_ID)

	# Spawn two NPCs.
	for i: int in range(2):
		var dummy: Node = Node.new()
		add_child_autofree(dummy)
		EventBus.customer_spawned.emit(dummy)

	assert_gt(
		_npc_spawner.get_active_count(), 0,
		"Precondition: NPCs should be active before store_exited"
	)

	EventBus.store_exited.emit(TEST_STORE_ID)

	assert_eq(
		_npc_spawner.get_active_count(), 0,
		"All NPCs should be despawned immediately after store_exited"
	)
	assert_eq(
		_npc_spawner.get_queue_count(), 0,
		"Spawn queue should be cleared after store_exited"
	)


# ── Scenario C — No active store guard ───────────────────────────────────────


func test_scenario_c_day_phase_change_alone_spawns_zero_npcs() -> void:
	# No store_entered — NPCSpawnerSystem has no store root.
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MORNING_RAMP)

	assert_eq(
		_npc_spawner.get_active_count(), 0,
		"Phase change alone must not create NPCs without a store being entered"
	)


func test_scenario_c_npc_spawner_has_empty_store_id_before_store_entered() -> void:
	assert_eq(
		_npc_spawner._current_store_id, &"",
		"NPCSpawnerSystem should have no active store before store_entered"
	)

	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MORNING_RAMP)

	assert_eq(
		_npc_spawner._current_store_id, &"",
		"day_phase_changed must not assign a store to NPCSpawnerSystem"
	)


func test_scenario_c_queue_empty_without_checkout_signals() -> void:
	# No store, no customers, no customer_reached_checkout.
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MORNING_RAMP)

	assert_eq(
		_queue.get_queue_size(), 0,
		"QueueSystem should remain empty when no checkout signals are emitted"
	)


func test_scenario_c_archetype_weights_update_even_without_store() -> void:
	# Phase change still updates CustomerSystem state regardless of active store.
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MORNING_RAMP)

	assert_eq(
		_customer_system._current_archetype_weights,
		ShopperArchetypeConfig.WEIGHTS_MORNING,
		"CustomerSystem archetype weights should update even with no active store"
	)
	assert_eq(
		_npc_spawner.get_active_count(), 0,
		"No NPCs should be active — customer_spawned was never emitted"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _setup_test_store() -> void:
	var root: Node = Node.new()
	root.name = "test_npc_store"
	var nav_config: CustomerNavConfig = CustomerNavConfig.new()
	nav_config.max_concurrent_customers = 4
	root.add_child(nav_config)
	get_tree().current_scene.add_child(root)
	_test_store_root = root


func _on_customer_entered(_data: Dictionary) -> void:
	_customer_entered_count += 1


func _on_queue_changed(queue_size: int) -> void:
	_queue_size_last = queue_size


func _safe_disconnect(sig: Signal, handler: Callable) -> void:
	if sig.is_connected(handler):
		sig.disconnect(handler)
