## Integration test: StaffManager shift lifecycle — day_started spawns StaffNPCs,
## day_ended despawns them, fire_staff removes an NPC immediately mid-day.
extends GutTest

const STORE_ID: String = "test_shift_store"
const CASHIER_ID: String = "test_shift_cashier_001"
const GREETER_ID: String = "test_shift_greeter_001"

var _cashier_def: StaffDefinition = null
var _greeter_def: StaffDefinition = null
var _store_root: Node = null
var _original_store_id: StringName = &""


func before_each() -> void:
	_original_store_id = GameManager.current_store_id
	GameManager.current_store_id = STORE_ID

	_store_root = _build_store_root_with_config()
	get_tree().current_scene.add_child(_store_root)

	_cashier_def = _make_staff(CASHIER_ID, StaffDefinition.StaffRole.CASHIER)
	_greeter_def = _make_staff(GREETER_ID, StaffDefinition.StaffRole.GREETER)
	StaffManager._candidate_pool.append(_cashier_def)
	StaffManager._candidate_pool.append(_greeter_def)
	StaffManager.hire_candidate(CASHIER_ID, STORE_ID)
	StaffManager.hire_candidate(GREETER_ID, STORE_ID)


func after_each() -> void:
	StaffManager._despawn_all_npcs_immediate()

	if StaffManager._staff_registry.has(CASHIER_ID):
		StaffManager._staff_registry.erase(CASHIER_ID)
	if StaffManager._staff_registry.has(GREETER_ID):
		StaffManager._staff_registry.erase(GREETER_ID)
	StaffManager._candidate_pool.erase(_cashier_def)
	StaffManager._candidate_pool.erase(_greeter_def)

	GameManager.current_store_id = _original_store_id

	if _store_root and is_instance_valid(_store_root):
		_store_root.queue_free()
		_store_root = null


# ── Scenario A — day_started spawns assigned staff NPCs ──────────────────────


func test_scenario_a_two_staff_npc_children_added_after_day_started() -> void:
	EventBus.day_started.emit(1)

	assert_eq(
		_count_staff_npcs(_store_root),
		2,
		"Exactly 2 StaffNPC children should be added to the store scene after day_started"
	)


func test_scenario_a_active_npcs_size_is_two_after_day_started() -> void:
	EventBus.day_started.emit(1)

	assert_eq(
		StaffManager._active_npcs.size(),
		2,
		"StaffManager._active_npcs should contain 2 entries after day_started"
	)


func test_scenario_a_cashier_role_is_present() -> void:
	EventBus.day_started.emit(1)

	var found: Array = [false]
	for npc: Node in StaffManager._active_npcs.values():
		var typed: StaffNPC = npc as StaffNPC
		if typed and typed._role == StaffDefinition.StaffRole.CASHIER:
			found[0] = true
			break
	assert_true(
		found[0],
		"One active StaffNPC should have role CASHIER after day_started"
	)


func test_scenario_a_greeter_role_is_present() -> void:
	EventBus.day_started.emit(1)

	var found: Array = [false]
	for npc: Node in StaffManager._active_npcs.values():
		var typed: StaffNPC = npc as StaffNPC
		if typed and typed._role == StaffDefinition.StaffRole.GREETER:
			found[0] = true
			break
	assert_true(
		found[0],
		"One active StaffNPC should have role GREETER after day_started"
	)


# ── Scenario B — day_ended despawns all staff NPCs ────────────────────────────


func test_scenario_b_active_npcs_cleared_immediately_after_day_ended() -> void:
	EventBus.day_started.emit(1)
	assert_eq(
		StaffManager._active_npcs.size(), 2,
		"Precondition: 2 NPCs must be active before day_ended"
	)

	EventBus.day_ended.emit(1)

	assert_eq(
		StaffManager._active_npcs.size(),
		0,
		"StaffManager._active_npcs should be empty immediately after day_ended"
	)


## end_shift() uses a 1-second tween before queue_free; this test awaits 1.5 s.
func test_scenario_b_staff_npc_nodes_freed_after_day_ended_tween() -> void:
	EventBus.day_started.emit(1)

	EventBus.day_ended.emit(1)

	await get_tree().create_timer(1.5).timeout

	assert_eq(
		_count_staff_npcs(_store_root),
		0,
		"No StaffNPC children should remain in the store scene 1.5 s after day_ended"
	)


# ── Scenario C — no StoreStaffConfig → no crash, push_warning emitted ─────────


## Renames the StoreStaffConfig so _find_store_staff_config still locates the
## parent node as the store root, but get_node_or_null("StoreStaffConfig") fails,
## triggering StaffManager's push_warning path.
func test_scenario_c_no_staff_npcs_spawned_without_named_config() -> void:
	var config: StoreStaffConfig = _store_root.get_node(
		"StoreStaffConfig"
	) as StoreStaffConfig
	config.name = "MisnamedConfig"

	EventBus.day_started.emit(2)

	assert_eq(
		_count_staff_npcs(_store_root),
		0,
		"No StaffNPC nodes should be spawned when StoreStaffConfig is absent from store root"
	)


func test_scenario_c_active_npcs_empty_without_named_config() -> void:
	var config: StoreStaffConfig = _store_root.get_node(
		"StoreStaffConfig"
	) as StoreStaffConfig
	config.name = "MisnamedConfig"

	EventBus.day_started.emit(2)

	assert_eq(
		StaffManager._active_npcs.size(),
		0,
		"StaffManager._active_npcs should remain empty when StoreStaffConfig is absent"
	)


## GDScript's push_warning() is a built-in and cannot be directly intercepted
## by GUT spy. The above tests verify the guarded code path (0 NPCs spawned),
## which is the observable effect of the warning branch.
func test_scenario_c_push_warning_assertion() -> void:
	pending(
		"push_warning() is a Godot built-in with no signal; "
		+ "observable effect (0 NPCs spawned) is asserted in the other Scenario C tests"
	)


# ── Scenario D — mid-day fire despawns NPC immediately ────────────────────────


func test_scenario_d_fired_cashier_npc_count_drops_to_one() -> void:
	EventBus.day_started.emit(1)
	assert_eq(
		StaffManager._active_npcs.size(), 2,
		"Precondition: 2 NPCs must be active before firing"
	)

	StaffManager.fire_staff(CASHIER_ID)
	await get_tree().process_frame

	assert_eq(
		_count_staff_npcs(_store_root),
		1,
		"Only 1 StaffNPC should remain in the store scene after firing the CASHIER"
	)


func test_scenario_d_active_npcs_size_is_one_after_fire() -> void:
	EventBus.day_started.emit(1)
	assert_eq(
		StaffManager._active_npcs.size(), 2,
		"Precondition: 2 NPCs must be active before firing"
	)

	StaffManager.fire_staff(CASHIER_ID)

	assert_eq(
		StaffManager._active_npcs.size(),
		1,
		"StaffManager._active_npcs should contain only 1 entry (GREETER) after CASHIER is fired"
	)


func test_scenario_d_greeter_npc_remains_active_after_cashier_fired() -> void:
	EventBus.day_started.emit(1)

	StaffManager.fire_staff(CASHIER_ID)

	assert_true(
		StaffManager._active_npcs.has(GREETER_ID),
		"The GREETER's NPC should remain active after only the CASHIER is fired"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _build_store_root_with_config() -> Node:
	var root: Node = Node.new()
	root.name = "TestShiftStore"

	var config: StoreStaffConfig = StoreStaffConfig.new()
	config.name = "StoreStaffConfig"
	config.max_staff = 2

	var register_marker: Marker3D = Marker3D.new()
	config.register_points.append(register_marker)
	config.add_child(register_marker)

	var greeter_marker: Marker3D = Marker3D.new()
	config.greeter_point = greeter_marker
	config.add_child(greeter_marker)

	root.add_child(config)
	return root


func _make_staff(
	staff_id: String, role: StaffDefinition.StaffRole
) -> StaffDefinition:
	var def: StaffDefinition = StaffDefinition.new()
	def.staff_id = staff_id
	def.display_name = "Test Staff %s" % staff_id
	def.role = role
	def.skill_level = 1
	def.morale = StaffDefinition.DEFAULT_MORALE
	def.daily_wage = 0.0
	return def


func _count_staff_npcs(parent: Node) -> int:
	if not parent or not is_instance_valid(parent):
		return 0
	var count: Array = [0]
	for child: Node in parent.get_children():
		if child is StaffNPC:
			count[0] += 1
	return count
