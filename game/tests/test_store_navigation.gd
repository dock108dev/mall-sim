## Verifies the sports memorabilia store's navigation mesh scene is wired up
## so that entry/register/slot regions exist. Full NavigationServer pathfinding
## requires a rendering server (not available in headless CI), so this test
## validates scene composition instead of runtime path queries.
extends GutTest

const STORE_SCENE: PackedScene = preload(
	"res://game/scenes/stores/sports_memorabilia.tscn"
)


func _find_first_node(root: Node, type: String) -> Node:
	if root.get_class() == type:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_first_node(child, type)
		if found:
			return found
	return null


func _collect_nodes_in_group(root: Node, group: StringName) -> Array[Node]:
	var result: Array[Node] = []
	if root.is_in_group(group):
		result.append(root)
	for child: Node in root.get_children():
		result.append_array(_collect_nodes_in_group(child, group))
	return result


func test_entry_to_register() -> void:
	var store: Node3D = STORE_SCENE.instantiate() as Node3D
	add_child_autofree(store)
	var entries: Array[Node] = _collect_nodes_in_group(store, &"entry_area")
	var registers: Array[Node] = _collect_nodes_in_group(store, &"register_area")
	assert_gt(entries.size(), 0, "Store scene should contain an entry_area")
	assert_gt(registers.size(), 0, "Store scene should contain a register_area")


func test_entry_to_slots() -> void:
	var store: Node3D = STORE_SCENE.instantiate() as Node3D
	add_child_autofree(store)
	var entries: Array[Node] = _collect_nodes_in_group(store, &"entry_area")
	var fixtures: Array[Node] = _collect_nodes_in_group(store, &"fixture")
	assert_gt(entries.size(), 0, "Store scene should contain an entry_area")
	assert_gt(fixtures.size(), 0, "Store scene should contain fixtures with slots")


func test_slots_to_register() -> void:
	var store: Node3D = STORE_SCENE.instantiate() as Node3D
	add_child_autofree(store)
	var registers: Array[Node] = _collect_nodes_in_group(store, &"register_area")
	var fixtures: Array[Node] = _collect_nodes_in_group(store, &"fixture")
	var nav_region: Node = _find_first_node(store, "NavigationRegion3D")
	assert_gt(registers.size(), 0, "Store scene should contain a register_area")
	assert_gt(fixtures.size(), 0, "Store scene should contain fixtures")
	assert_not_null(
		nav_region,
		"Store scene should contain a NavigationRegion3D for pathfinding"
	)
