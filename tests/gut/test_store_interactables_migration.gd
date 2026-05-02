## ISSUE-003: ensures every clickable Area3D in active store scenes uses the
## shared `Interactable` component (directly or via a subclass such as
## `ShelfSlot`). The raycast in `interaction_ray.gd` hits anything on
## `Interactable.INTERACTABLE_LAYER`, so an Area3D on that bit without the
## component would fire no scoped EventBus signal — the exact failure mode
## this issue fixes.
extends GutTest


const _SCENES: Array[String] = [
	"res://game/scenes/stores/retro_games.tscn",
	"res://game/scenes/stores/pocket_creatures.tscn",
]


func _collect_interactable_areas(node: Node, out: Array[Area3D]) -> void:
	if node is Area3D:
		var area := node as Area3D
		if (area.collision_layer & Interactable.INTERACTABLE_LAYER) != 0:
			out.append(area)
	for child: Node in node.get_children():
		_collect_interactable_areas(child, out)


func _area_is_covered(area: Area3D) -> bool:
	# The area is either an Interactable itself, or is the InteractionArea
	# child created by its owning Interactable parent.
	if area is Interactable:
		return true
	var current: Node = area.get_parent()
	while current != null:
		if current is Interactable:
			return true
		current = current.get_parent()
	return false


func test_every_clickable_area_is_interactable() -> void:
	for scene_path: String in _SCENES:
		var packed: PackedScene = load(scene_path) as PackedScene
		assert_not_null(packed, "Store scene should load: %s" % scene_path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		add_child_autofree(root)

		var areas: Array[Area3D] = []
		_collect_interactable_areas(root, areas)
		assert_gt(
			areas.size(), 0,
			"Scene %s should register at least one interactable Area3D" % scene_path
		)

		var uncovered: Array[String] = []
		for area: Area3D in areas:
			if not _area_is_covered(area):
				uncovered.append(String(area.get_path()))
		assert_eq(
			uncovered.size(), 0,
			"Scene %s has clickable Area3D nodes missing Interactable: %s"
				% [scene_path, ", ".join(uncovered)]
		)


func test_every_interactable_has_identity_after_ready() -> void:
	for scene_path: String in _SCENES:
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		add_child_autofree(root)

		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child: Node in node.get_children():
				stack.append(child)
			if not (node is Interactable):
				continue
			var it := node as Interactable
			assert_ne(
				it.display_name.strip_edges(), "",
				"Interactable %s should expose a display_name" % it.get_path()
			)
			assert_ne(
				String(it.resolve_interactable_id()), "",
				"Interactable %s should resolve a non-empty id" % it.get_path()
			)
			assert_not_null(
				it.get_interaction_area(),
				"Interactable %s should expose an InteractionArea"
					% it.get_path()
			)
