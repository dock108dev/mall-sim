## Tests CustomerNPC state machine, animation fallback, and signal emission.
extends GutTest


var _npc: CustomerNPC
var _nav_config: CustomerNavConfig


func before_each() -> void:
	_nav_config = CustomerNavConfig.new()
	add_child_autofree(_nav_config)

	var wp1 := Marker3D.new()
	wp1.position = Vector3(1.0, 0.0, 0.0)
	_nav_config.add_child(wp1)
	var wp2 := Marker3D.new()
	wp2.position = Vector3(2.0, 0.0, 0.0)
	_nav_config.add_child(wp2)
	_nav_config.browse_waypoints = [wp1, wp2]

	var checkout := Marker3D.new()
	checkout.position = Vector3(3.0, 0.0, 0.0)
	_nav_config.add_child(checkout)
	_nav_config.checkout_approach = checkout

	var exit_marker := Marker3D.new()
	exit_marker.position = Vector3(0.0, 0.0, 5.0)
	_nav_config.add_child(exit_marker)
	_nav_config.exit_point = exit_marker

	var entry := Marker3D.new()
	entry.position = Vector3(0.0, 0.0, 0.0)
	_nav_config.add_child(entry)
	_nav_config.entry_point = entry

	_npc = preload(
		"res://game/scenes/characters/customer_npc.tscn"
	).instantiate()
	add_child_autofree(_npc)


func test_initial_state_is_idle_after_initialize() -> void:
	_npc.initialize({}, _nav_config)
	assert_eq(
		_npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.IDLE,
		"State should be IDLE after initialize"
	)


func test_begin_visit_transitions_to_browsing() -> void:
	_npc.initialize({}, _nav_config)
	_npc.begin_visit()
	assert_eq(
		_npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.BROWSING,
		"State should be BROWSING after begin_visit"
	)


func test_send_to_checkout_transitions_to_approaching() -> void:
	_npc.initialize({}, _nav_config)
	_npc.begin_visit()
	_npc.send_to_checkout()
	assert_eq(
		_npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.APPROACHING_CHECKOUT,
		"State should be APPROACHING_CHECKOUT after send_to_checkout"
	)


func test_begin_leave_transitions_to_leaving() -> void:
	_npc.initialize({}, _nav_config)
	_npc.begin_visit()
	_npc.begin_leave()
	assert_eq(
		_npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.LEAVING,
		"State should be LEAVING after begin_leave"
	)


func test_enum_has_all_required_values() -> void:
	assert_eq(CustomerNPC.CustomerVisitState.IDLE, 0)
	assert_eq(CustomerNPC.CustomerVisitState.BROWSING, 1)
	assert_eq(CustomerNPC.CustomerVisitState.APPROACHING_CHECKOUT, 2)
	assert_eq(CustomerNPC.CustomerVisitState.WAITING_IN_QUEUE, 3)
	assert_eq(CustomerNPC.CustomerVisitState.LEAVING, 4)


func test_all_animations_created() -> void:
	var expected: Array[String] = [
		"idle_stand", "idle_browse", "pick_up_item", "place_item",
		"idle_wait", "walk", "exit_walk",
	]
	var player: AnimationPlayer = _npc.get_node("AnimationPlayer")
	var lib: AnimationLibrary = player.get_animation_library("")
	for anim_name: String in expected:
		assert_true(
			lib.has_animation(anim_name),
			"Animation '%s' should exist" % anim_name
		)


func test_missing_animation_falls_back_to_idle_stand() -> void:
	var player: AnimationPlayer = _npc.get_node("AnimationPlayer")
	var lib: AnimationLibrary = player.get_animation_library("")
	lib.remove_animation("walk")
	_npc.initialize({}, _nav_config)
	_npc.send_to_checkout()
	assert_eq(
		player.current_animation, "idle_stand",
		"Should fall back to idle_stand when walk is missing"
	)


func test_begin_visit_without_initialize_warns() -> void:
	_npc.begin_visit()
	assert_eq(
		_npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.IDLE,
		"State should remain IDLE when not initialized"
	)


func test_nav_config_stored_on_initialize() -> void:
	_npc.initialize({"test": true}, _nav_config)
	_npc.begin_visit()
	var nav_agent: NavigationAgent3D = _npc.get_node("NavigationAgent3D")
	assert_eq(
		nav_agent.target_position,
		Vector3(1.0, 0.0, 0.0),
		"First browse waypoint should be navigation target"
	)


func test_send_to_checkout_sets_nav_target() -> void:
	_npc.initialize({}, _nav_config)
	_npc.send_to_checkout()
	var nav_agent: NavigationAgent3D = _npc.get_node("NavigationAgent3D")
	assert_eq(
		nav_agent.target_position,
		Vector3(3.0, 0.0, 0.0),
		"Checkout approach position should be navigation target"
	)


func test_begin_leave_sets_nav_target() -> void:
	_npc.initialize({}, _nav_config)
	_npc.begin_leave()
	var nav_agent: NavigationAgent3D = _npc.get_node("NavigationAgent3D")
	assert_eq(
		nav_agent.target_position,
		Vector3(0.0, 0.0, 5.0),
		"Exit position should be navigation target"
	)


func test_scene_has_required_children() -> void:
	assert_not_null(
		_npc.get_node("CollisionShape3D"),
		"Should have CollisionShape3D"
	)
	assert_not_null(
		_npc.get_node("MeshInstance3D"),
		"Should have MeshInstance3D"
	)
	assert_not_null(
		_npc.get_node("AnimationPlayer"),
		"Should have AnimationPlayer"
	)
	assert_not_null(
		_npc.get_node("NavigationAgent3D"),
		"Should have NavigationAgent3D"
	)


func test_browse_timer_initialized_on_setup() -> void:
	_npc.initialize({}, _nav_config)
	var timer: float = _npc._browse_timer
	assert_true(
		timer >= CustomerNPC.BROWSE_DURATION_MIN
		and timer <= CustomerNPC.BROWSE_DURATION_MAX,
		"Browse timer should be between min and max duration"
	)


func test_high_purchase_intent_transitions_to_checkout() -> void:
	var customer_def: Dictionary = {
		"purchase_intent": 1.0,
		"interest_category": "",
		"budget": 100.0,
	}
	_npc.initialize(customer_def, _nav_config)
	_npc.begin_visit()
	_npc._browse_timer = 0.0
	_npc._physics_process(0.016)
	var state: CustomerNPC.CustomerVisitState = _npc.get_visit_state()
	assert_true(
		state == CustomerNPC.CustomerVisitState.APPROACHING_CHECKOUT
		or state == CustomerNPC.CustomerVisitState.WAITING_IN_QUEUE,
		"NPC with purchase_intent=1.0 should approach checkout"
	)


func test_zero_purchase_intent_transitions_to_leave() -> void:
	var customer_def: Dictionary = {
		"purchase_intent": 0.0,
		"interest_category": "",
		"budget": 100.0,
	}
	_npc.initialize(customer_def, _nav_config)
	_npc.begin_visit()
	_npc._browse_timer = 0.0
	_npc._physics_process(0.016)
	assert_eq(
		_npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.LEAVING,
		"NPC with purchase_intent=0.0 should leave"
	)


func test_duplicate_timer_ignored_in_checkout_state() -> void:
	var customer_def: Dictionary = {
		"purchase_intent": 1.0,
		"interest_category": "",
		"budget": 100.0,
	}
	_npc.initialize(customer_def, _nav_config)
	_npc.send_to_checkout()
	var prev_state: CustomerNPC.CustomerVisitState = (
		_npc.get_visit_state()
	)
	_npc._on_browse_timer_timeout()
	assert_eq(
		_npc.get_visit_state(),
		prev_state,
		"Timer firing in APPROACHING_CHECKOUT should be ignored"
	)


func test_no_matching_stock_forces_leave() -> void:
	var inv_system := InventorySystem.new()
	add_child_autofree(inv_system)
	var customer_def: Dictionary = {
		"purchase_intent": 1.0,
		"interest_category": "nonexistent_category",
		"budget": 100.0,
	}
	_npc.initialize(
		customer_def, _nav_config, inv_system, &"test_store"
	)
	_npc.begin_visit()
	_npc._browse_timer = 0.0
	_npc._physics_process(0.016)
	assert_eq(
		_npc.get_visit_state(),
		CustomerNPC.CustomerVisitState.LEAVING,
		"NPC should leave when no stock matches interest_category"
	)
