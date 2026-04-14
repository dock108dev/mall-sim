## Verifies NavigationAgent3D pathfinding within the sports memorabilia store.
extends GutTest

const STORE_SCENE: PackedScene = preload(
	"res://game/scenes/stores/sports_memorabilia.tscn"
)

var _store: Node3D = null
var _nav_agent: NavigationAgent3D = null


func before_all() -> void:
	_store = STORE_SCENE.instantiate()
	add_child(_store)
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 0.5
	add_child(_nav_agent)
	await get_tree().process_frame
	await get_tree().process_frame


func after_all() -> void:
	if _nav_agent:
		_nav_agent.queue_free()
	if _store:
		_store.queue_free()


func test_entry_to_register() -> void:
	var entry_pos: Vector3 = _get_entry_position()
	var register_pos: Vector3 = _get_register_position()
	var has_path: bool = _can_navigate(entry_pos, register_pos)
	assert_true(has_path, "Path exists from entry to register")


func test_entry_to_slots() -> void:
	var entry_pos: Vector3 = _get_entry_position()
	var slots: Array[Dictionary] = _get_all_slot_positions()
	for slot_data: Dictionary in slots:
		var slot_pos: Vector3 = slot_data["position"]
		var slot_name: String = slot_data["name"]
		var has_path: bool = _can_navigate(entry_pos, slot_pos)
		assert_true(
			has_path,
			"Path exists from entry to slot '%s'" % slot_name
		)


func test_slots_to_register() -> void:
	var register_pos: Vector3 = _get_register_position()
	var slots: Array[Dictionary] = _get_all_slot_positions()
	for slot_data: Dictionary in slots:
		var slot_pos: Vector3 = slot_data["position"]
		var slot_name: String = slot_data["name"]
		var has_path: bool = _can_navigate(slot_pos, register_pos)
		assert_true(
			has_path,
			"Path exists from slot '%s' to register" % slot_name
		)


func _can_navigate(from: Vector3, to: Vector3) -> bool:
	var closest_from: Vector3 = (
		NavigationServer3D.map_get_closest_point(
			get_tree().root.get_world_3d().navigation_map, from
		)
	)
	var closest_to: Vector3 = (
		NavigationServer3D.map_get_closest_point(
			get_tree().root.get_world_3d().navigation_map, to
		)
	)
	var path: PackedVector3Array = (
		NavigationServer3D.map_get_path(
			get_tree().root.get_world_3d().navigation_map,
			closest_from,
			closest_to,
			true
		)
	)
	return path.size() >= 2


func _get_entry_position() -> Vector3:
	var entries: Array[Node] = get_tree().get_nodes_in_group("entry_area")
	if entries.is_empty():
		push_error("No entry_area found in store scene")
		return Vector3.ZERO
	var entry: Node3D = entries[0] as Node3D
	return entry.global_position


func _get_register_position() -> Vector3:
	var registers: Array[Node] = get_tree().get_nodes_in_group(
		"register_area"
	)
	if registers.is_empty():
		push_error("No register_area found in store scene")
		return Vector3.ZERO
	var register: Node3D = registers[0] as Node3D
	return register.global_position


func _get_all_slot_positions() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var fixtures: Array[Node] = get_tree().get_nodes_in_group("fixture")
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
