## Unit tests for NPCSpawnerSystem — initial state, spawn via customer_spawned signal,
## pool ceiling, spawning disabled/enabled, store_exited despawn, customer_left removal,
## MAX_CUSTOMERS hard cap, peak/off-peak timer intervals, profile distribution, and despawn.
extends GutTest

var _system: NPCSpawnerSystem


func before_each() -> void:
	_system = NPCSpawnerSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func after_each() -> void:
	EventBus.hour_changed.emit(0)


# --- Initial state ---


func test_initial_active_count_is_zero() -> void:
	assert_eq(
		_system.get_active_count(), 0,
		"get_active_count() must return 0 on initialization"
	)


func test_initial_queue_count_is_zero() -> void:
	assert_eq(
		_system.get_queue_count(), 0,
		"get_queue_count() must return 0 on initialization"
	)


func test_initial_active_npcs_dict_is_empty() -> void:
	assert_eq(
		_system._active_customer_npcs.size(), 0,
		"_active_customer_npcs dict must be empty on initialization"
	)


# --- Spawn via EventBus.customer_spawned ---


func test_customer_spawned_signal_increases_active_count() -> void:
	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	assert_eq(
		_system.get_active_count(), 1,
		"customer_spawned signal must instantiate a CustomerNPC and increment active count to 1"
	)


func test_customer_spawned_creates_character_body_child() -> void:
	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)
	var has_character_body: bool = false
	for child: Node in _system.get_children():
		if child is CharacterBody3D:
			has_character_body = true
			break
	assert_true(
		has_character_body,
		"customer_spawned must create a CharacterBody3D child node in the spawner"
	)


func test_two_customer_spawned_signals_create_two_npcs() -> void:
	var dummy_a: Node = Node.new()
	var dummy_b: Node = Node.new()
	add_child_autofree(dummy_a)
	add_child_autofree(dummy_b)
	EventBus.customer_spawned.emit(dummy_a)
	EventBus.customer_spawned.emit(dummy_b)
	assert_eq(
		_system.get_active_count(), 2,
		"two customer_spawned signals must produce two active NPCs"
	)


# --- Pool ceiling ---


func test_pool_ceiling_routes_overflow_to_spawn_queue() -> void:
	var nav: CustomerNavConfig = CustomerNavConfig.new()
	nav.max_concurrent_customers = 1
	add_child_autofree(nav)
	_system._current_nav_config = nav

	var dummy_a: Node = Node.new()
	add_child_autofree(dummy_a)
	EventBus.customer_spawned.emit(dummy_a)

	assert_eq(
		_system.get_active_count(), 1,
		"first spawn must bring active count to pool ceiling of 1"
	)

	var dummy_b: Node = Node.new()
	add_child_autofree(dummy_b)
	EventBus.customer_spawned.emit(dummy_b)

	assert_eq(
		_system.get_active_count(), 1,
		"active count must remain at ceiling after overflow attempt"
	)
	assert_eq(
		_system.get_queue_count(), 1,
		"overflow spawn must be appended to the spawn queue"
	)


func test_pool_ceiling_active_count_unchanged_after_overflow() -> void:
	var nav: CustomerNavConfig = CustomerNavConfig.new()
	nav.max_concurrent_customers = 2
	add_child_autofree(nav)
	_system._current_nav_config = nav

	for _i: int in range(2):
		var dummy: Node = Node.new()
		add_child_autofree(dummy)
		EventBus.customer_spawned.emit(dummy)

	var extra: Node = Node.new()
	add_child_autofree(extra)
	EventBus.customer_spawned.emit(extra)

	assert_eq(
		_system.get_active_count(), 2,
		"active count must stay at MAX after repeated overflow attempts"
	)


# --- Spawning disabled ---


func test_spawning_disabled_signal_sets_flag() -> void:
	EventBus.customer_spawning_disabled.emit()
	assert_true(
		_system._spawning_disabled,
		"customer_spawning_disabled signal must set _spawning_disabled to true"
	)


func test_spawning_enabled_signal_clears_flag() -> void:
	_system._spawning_disabled = true
	EventBus.customer_spawning_enabled.emit()
	assert_false(
		_system._spawning_disabled,
		"customer_spawning_enabled signal must clear _spawning_disabled to false"
	)


func test_customer_spawned_while_disabled_adds_to_queue() -> void:
	EventBus.customer_spawning_disabled.emit()

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	assert_eq(
		_system.get_queue_count(), 1,
		"customer_spawned while spawning is disabled must add to spawn queue"
	)


func test_customer_spawned_while_disabled_does_not_increase_active_count() -> void:
	EventBus.customer_spawning_disabled.emit()

	var dummy: Node = Node.new()
	add_child_autofree(dummy)
	EventBus.customer_spawned.emit(dummy)

	assert_eq(
		_system.get_active_count(), 0,
		"customer_spawned while spawning is disabled must not increase active count"
	)


# --- store_exited despawns all NPCs ---


func test_store_exited_clears_all_active_npcs() -> void:
	var npc: CustomerNPC = _make_customer_npc()
	_system._active_customer_npcs[npc] = {}

	assert_eq(
		_system.get_active_count(), 1,
		"precondition: one NPC active before store_exited"
	)

	EventBus.store_exited.emit(&"test_store")

	assert_eq(
		_system.get_active_count(), 0,
		"store_exited must clear all active NPCs; get_active_count() must return 0"
	)


func test_store_exited_clears_spawn_queue() -> void:
	_system._spawn_queue.append({})
	_system._spawn_queue.append({})

	EventBus.store_exited.emit(&"test_store")

	assert_eq(
		_system.get_queue_count(), 0,
		"store_exited must clear the spawn queue"
	)


func test_store_exited_resets_current_store_id() -> void:
	_system._current_store_id = &"retro_games"

	EventBus.store_exited.emit(&"retro_games")

	assert_eq(
		_system._current_store_id, &"",
		"store_exited must reset _current_store_id to empty StringName"
	)


func test_store_exited_resets_nav_config() -> void:
	var nav: CustomerNavConfig = CustomerNavConfig.new()
	add_child_autofree(nav)
	_system._current_nav_config = nav

	EventBus.store_exited.emit(&"test_store")

	assert_null(
		_system._current_nav_config,
		"store_exited must set _current_nav_config to null"
	)


# --- customer_left removes a specific NPC ---


func test_customer_left_removes_browsing_npc_from_active_pool() -> void:
	var npc: CustomerNPC = _make_customer_npc()
	_system._active_customer_npcs[npc] = {}

	assert_eq(
		_system.get_active_count(), 1,
		"precondition: one active NPC before customer_left"
	)

	EventBus.customer_left.emit({})

	assert_eq(
		_system.get_active_count(), 0,
		"customer_left must remove the browsing NPC from the active pool"
	)


func test_customer_left_does_not_remove_non_browsing_npc() -> void:
	var npc: CustomerNPC = _make_customer_npc()
	# Transition to APPROACHING_CHECKOUT — no longer in BROWSING state.
	npc.send_to_checkout()
	_system._active_customer_npcs[npc] = {}

	EventBus.customer_left.emit({})

	assert_eq(
		_system.get_active_count(), 1,
		"customer_left must not remove an NPC that is not in BROWSING state"
	)


func test_customer_left_on_empty_pool_does_not_crash() -> void:
	EventBus.customer_left.emit({})
	assert_eq(
		_system.get_active_count(), 0,
		"customer_left on an empty active pool must complete without error"
	)


# --- MAX_CUSTOMERS hard cap ---


func test_spawn_respects_capacity_cap() -> void:
	for _i: int in range(NPCSpawnerSystem.MAX_CUSTOMERS):
		var npc: CustomerNPC = _make_customer_npc()
		_system._active_customer_npcs[npc] = {}
	_system._spawn_queue.append({})

	_system._try_spawn()

	assert_eq(
		_system.get_active_count(),
		NPCSpawnerSystem.MAX_CUSTOMERS,
		"active_count must not exceed MAX_CUSTOMERS after _try_spawn() at capacity"
	)
	assert_eq(
		_system.get_queue_count(), 1,
		"queue item must remain when MAX_CUSTOMERS cap blocks the spawn"
	)


# --- Spawn timer intervals ---


func test_peak_spawn_interval() -> void:
	EventBus.hour_changed.emit(13)
	assert_almost_eq(
		_system._spawn_timer.wait_time,
		NPCSpawnerSystem.PEAK_SPAWN_INTERVAL,
		0.001,
		"spawn timer wait_time must equal PEAK_SPAWN_INTERVAL (3.0 s) during peak hours"
	)


func test_off_peak_spawn_interval() -> void:
	EventBus.hour_changed.emit(3)
	assert_almost_eq(
		_system._spawn_timer.wait_time,
		NPCSpawnerSystem.OFF_PEAK_SPAWN_INTERVAL,
		0.001,
		"spawn timer wait_time must equal OFF_PEAK_SPAWN_INTERVAL (6.0 s) outside peak hours"
	)


# --- Profile distribution ---


func test_profile_distribution() -> void:
	var profile_counts: Dictionary = {}
	var all_types: Array[int] = [
		PersonalityData.PersonalityType.POWER_SHOPPER,
		PersonalityData.PersonalityType.WINDOW_BROWSER,
		PersonalityData.PersonalityType.FOOD_COURT_CAMPER,
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY,
		PersonalityData.PersonalityType.RELUCTANT_COMPANION,
		PersonalityData.PersonalityType.IMPULSE_BUYER,
		PersonalityData.PersonalityType.SPEED_RUNNER,
		PersonalityData.PersonalityType.TEEN_PACK_MEMBER,
	]

	_system.npc_factory = func(customer_def: Dictionary) -> CustomerNPC:
		var p_type: int = customer_def.get("profile_type", 0) as int
		profile_counts[p_type] = profile_counts.get(p_type, 0) + 1
		return (
			preload("res://game/scenes/characters/customer_npc.tscn")
			.instantiate() as CustomerNPC
		)

	for i: int in range(100):
		var profile_type: int = all_types[i % all_types.size()]
		_system._spawn_customer_npc({"profile_type": profile_type})

	for p_type: int in all_types:
		var count: int = profile_counts.get(p_type, 0) as int
		assert_true(
			count >= 5 and count <= 35,
			"profile type %d must appear 5–35 times across 100 spawns; got %d" % [
				p_type, count
			]
		)


# --- Despawn cleanup ---


func test_despawn_cleanup() -> void:
	var npc: CustomerNPC = _make_customer_npc()
	_system._active_customer_npcs[npc] = {}
	var expected_id: StringName = StringName(str(npc.get_instance_id()))

	var emitted_ids: Array[StringName] = []
	var capture: Callable = func(npc_id: StringName) -> void:
		emitted_ids.append(npc_id)
	EventBus.npc_despawned.connect(capture)

	_system._despawn_npc(npc)

	EventBus.npc_despawned.disconnect(capture)

	assert_true(
		emitted_ids.has(expected_id),
		"npc_despawned must be emitted with the NPC's instance id"
	)
	assert_false(
		_system._active_customer_npcs.has(npc),
		"NPC must be removed from _active_customer_npcs after _despawn_npc()"
	)


# --- Helpers ---


func _make_customer_npc() -> CustomerNPC:
	var npc: CustomerNPC = (
		preload("res://game/scenes/characters/customer_npc.tscn").instantiate()
		as CustomerNPC
	)
	add_child_autofree(npc)
	npc.initialize({}, null)
	npc.begin_visit()
	return npc
