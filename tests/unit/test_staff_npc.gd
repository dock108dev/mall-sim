## Unit tests for StaffNPC initialization, state transitions, and role behaviors.
extends GutTest


var _npc: StaffNPC
var _config: StoreStaffConfig
var _register_marker: Marker3D
var _backroom_marker: Marker3D
var _greeter_marker: Marker3D
var _break_marker: Marker3D


func before_each() -> void:
	_register_marker = Marker3D.new()
	_register_marker.position = Vector3(2.0, 0.0, 0.0)
	add_child_autofree(_register_marker)

	_backroom_marker = Marker3D.new()
	_backroom_marker.position = Vector3(-2.0, 0.0, 3.0)
	add_child_autofree(_backroom_marker)

	_greeter_marker = Marker3D.new()
	_greeter_marker.position = Vector3(0.0, 0.0, -3.0)
	add_child_autofree(_greeter_marker)

	_break_marker = Marker3D.new()
	_break_marker.position = Vector3(0.0, 0.0, 5.0)
	add_child_autofree(_break_marker)

	_config = StoreStaffConfig.new()
	_config.register_points = [_register_marker]
	_config.backroom_point = _backroom_marker
	_config.greeter_point = _greeter_marker
	_config.break_point = _break_marker
	add_child_autofree(_config)

	var scene: PackedScene = load(
		"res://game/scenes/characters/staff_npc.tscn"
	)
	_npc = scene.instantiate() as StaffNPC
	add_child_autofree(_npc)


func _make_staff_def(
	role: StaffDefinition.StaffRole,
	morale: float = 0.65
) -> StaffDefinition:
	var def := StaffDefinition.new()
	def.staff_id = "test_staff_1"
	def.display_name = "Test Staffer"
	def.role = role
	def.skill_level = 1
	def.morale = morale
	def.assigned_store_id = "test_store"
	return def


func test_initialize_stores_role_cashier() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.CASHIER
	)
	_npc.initialize(def, _config)
	assert_eq(
		_npc._role, StaffDefinition.StaffRole.CASHIER,
		"Role should be CASHIER after initialize"
	)


func test_initialize_stores_role_stocker() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.STOCKER
	)
	_npc.initialize(def, _config)
	assert_eq(
		_npc._role, StaffDefinition.StaffRole.STOCKER,
		"Role should be STOCKER after initialize"
	)


func test_initialize_stores_role_greeter() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.GREETER
	)
	_npc.initialize(def, _config)
	assert_eq(
		_npc._role, StaffDefinition.StaffRole.GREETER,
		"Role should be GREETER after initialize"
	)


func test_initialize_stores_morale() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.CASHIER, 0.8
	)
	_npc.initialize(def, _config)
	assert_almost_eq(
		_npc._morale, 0.8, 0.01,
		"Morale should match staff definition"
	)


func test_begin_shift_transitions_to_walking() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.CASHIER
	)
	_npc.initialize(def, _config)
	_npc.begin_shift()
	assert_eq(
		_npc.current_state, StaffNPC.State.WALKING,
		"begin_shift should transition to WALKING"
	)


func test_begin_shift_without_initialize_warns() -> void:
	_npc.begin_shift()
	assert_eq(
		_npc.current_state, StaffNPC.State.SHIFT_START,
		"State should remain SHIFT_START without initialization"
	)


func test_play_role_idle_cashier() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.CASHIER
	)
	_npc.initialize(def, _config)
	_npc.play_role_idle()
	assert_eq(
		_npc.current_state, StaffNPC.State.IDLE_AT_REGISTER,
		"play_role_idle should put cashier in IDLE_AT_REGISTER"
	)


func test_play_role_idle_stocker() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.STOCKER
	)
	_npc.initialize(def, _config)
	_npc.play_role_idle()
	assert_eq(
		_npc.current_state, StaffNPC.State.IDLE_IN_BACKROOM,
		"play_role_idle should put stocker in IDLE_IN_BACKROOM"
	)


func test_play_role_idle_greeter() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.GREETER
	)
	_npc.initialize(def, _config)
	_npc.play_role_idle()
	assert_eq(
		_npc.current_state, StaffNPC.State.IDLE_AT_ENTRANCE,
		"play_role_idle should put greeter in IDLE_AT_ENTRANCE"
	)


func test_notify_customer_at_register_transitions_cashier() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.CASHIER
	)
	_npc.initialize(def, _config)
	_npc.play_role_idle()
	_npc.notify_customer_at_register()
	assert_eq(
		_npc.current_state, StaffNPC.State.PROCESSING_CUSTOMER,
		"Cashier should transition to PROCESSING_CUSTOMER"
	)


func test_notify_customer_checkout_done_returns_to_idle() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.CASHIER
	)
	_npc.initialize(def, _config)
	_npc.play_role_idle()
	_npc.notify_customer_at_register()
	_npc.notify_customer_checkout_done()
	assert_eq(
		_npc.current_state, StaffNPC.State.IDLE_AT_REGISTER,
		"Cashier should return to IDLE_AT_REGISTER after checkout"
	)


func test_notify_customer_ignored_for_non_cashier() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.STOCKER
	)
	_npc.initialize(def, _config)
	_npc.play_role_idle()
	_npc.notify_customer_at_register()
	assert_eq(
		_npc.current_state, StaffNPC.State.IDLE_IN_BACKROOM,
		"Non-cashier should ignore customer register notifications"
	)


func test_end_shift_transitions_to_shift_end() -> void:
	var def: StaffDefinition = _make_staff_def(
		StaffDefinition.StaffRole.CASHIER
	)
	_npc.initialize(def, _config)
	_npc.play_role_idle()
	_npc.end_shift()
	assert_eq(
		_npc.current_state, StaffNPC.State.SHIFT_END,
		"end_shift should transition to SHIFT_END"
	)


func test_config_get_marker_for_role_cashier() -> void:
	var marker: Marker3D = _config.get_marker_for_role(
		StaffDefinition.StaffRole.CASHIER
	)
	assert_eq(
		marker, _register_marker,
		"CASHIER marker should be register point"
	)


func test_config_get_marker_for_role_stocker() -> void:
	var marker: Marker3D = _config.get_marker_for_role(
		StaffDefinition.StaffRole.STOCKER
	)
	assert_eq(
		marker, _backroom_marker,
		"STOCKER marker should be backroom point"
	)


func test_config_get_marker_for_role_greeter() -> void:
	var marker: Marker3D = _config.get_marker_for_role(
		StaffDefinition.StaffRole.GREETER
	)
	assert_eq(
		marker, _greeter_marker,
		"GREETER marker should be greeter point"
	)


func test_config_missing_marker_falls_back_to_break() -> void:
	_config.greeter_point = null
	var marker: Marker3D = _config.get_marker_for_role(
		StaffDefinition.StaffRole.GREETER
	)
	assert_eq(
		marker, _break_marker,
		"Missing role marker should fall back to break_point"
	)
