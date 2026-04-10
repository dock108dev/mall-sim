## Verifies NavigationAgent3D pathfinding within the sports memorabilia store.
extends Node3D

const STORE_SCENE: PackedScene = preload(
	"res://game/scenes/stores/sports_memorabilia.tscn"
)

var _store: Node3D = null
var _nav_agent: NavigationAgent3D = null
var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	_store = STORE_SCENE.instantiate()
	add_child(_store)
	call_deferred("_run_tests_deferred")


func _run_tests_deferred() -> void:
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 0.5
	add_child(_nav_agent)
	# Wait two frames for NavigationServer to sync
	await get_tree().process_frame
	await get_tree().process_frame
	_run_all_tests()


func _run_all_tests() -> void:
	var entry_pos: Vector3 = _get_entry_position()
	var register_pos: Vector3 = _get_register_position()
	var slot_positions: Array[Dictionary] = _get_all_slot_positions()

	_test_entry_to_slots(entry_pos, slot_positions)
	_test_slots_to_register(slot_positions, register_pos)
	_test_entry_to_register(entry_pos, register_pos)
	_print_summary()


func _test_entry_to_slots(
	entry_pos: Vector3,
	slots: Array[Dictionary]
) -> void:
	for slot_data: Dictionary in slots:
		var slot_pos: Vector3 = slot_data["position"]
		var slot_name: String = slot_data["name"]
		var has_path: bool = _can_navigate(entry_pos, slot_pos)
		if has_path:
			_tests_passed += 1
		else:
			_tests_failed += 1
			push_error(
				"FAIL: No path from entry to slot '%s'" % slot_name
			)


func _test_slots_to_register(
	slots: Array[Dictionary],
	register_pos: Vector3
) -> void:
	for slot_data: Dictionary in slots:
		var slot_pos: Vector3 = slot_data["position"]
		var slot_name: String = slot_data["name"]
		var has_path: bool = _can_navigate(slot_pos, register_pos)
		if has_path:
			_tests_passed += 1
		else:
			_tests_failed += 1
			push_error(
				"FAIL: No path from slot '%s' to register" % slot_name
			)


func _test_entry_to_register(
	entry_pos: Vector3,
	register_pos: Vector3
) -> void:
	var has_path: bool = _can_navigate(entry_pos, register_pos)
	if has_path:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("FAIL: No path from entry to register")


func _can_navigate(from: Vector3, to: Vector3) -> bool:
	var closest_from: Vector3 = (
		NavigationServer3D.map_get_closest_point(
			get_world_3d().navigation_map, from
		)
	)
	var closest_to: Vector3 = (
		NavigationServer3D.map_get_closest_point(
			get_world_3d().navigation_map, to
		)
	)
	var path: PackedVector3Array = (
		NavigationServer3D.map_get_path(
			get_world_3d().navigation_map,
			closest_from,
			closest_to,
			true
		)
	)
	return path.size() >= 2


func _get_entry_position() -> Vector3:
	var entries: Array[Node] = _find_nodes_in_group("entry_area")
	if entries.is_empty():
		push_error("No entry_area found in store scene")
		return Vector3.ZERO
	var entry: Node3D = entries[0] as Node3D
	return entry.global_position


func _get_register_position() -> Vector3:
	var registers: Array[Node] = _find_nodes_in_group("register_area")
	if registers.is_empty():
		push_error("No register_area found in store scene")
		return Vector3.ZERO
	var register: Node3D = registers[0] as Node3D
	return register.global_position


func _get_all_slot_positions() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var fixtures: Array[Node] = _find_nodes_in_group("fixture")
	for fixture: Node in fixtures:
		for child: Node in fixture.get_children():
			if child.has_method("get") and child.get("slot_id") != null:
				var child_3d: Node3D = child as Node3D
				if child_3d:
					slots.append({
						"name": str(child.get("slot_id")),
						"position": child_3d.global_position,
					})
	return slots


func _find_nodes_in_group(group_name: String) -> Array[Node]:
	return get_tree().get_nodes_in_group(group_name)


func _print_summary() -> void:
	var total: int = _tests_passed + _tests_failed
	if _tests_failed == 0:
		push_warning(
			"NAV TEST: All %d tests passed" % total
		)
	else:
		push_error(
			"NAV TEST: %d/%d tests failed" % [_tests_failed, total]
		)
