## ISSUE-005: Scene clarity pass — every active store scene must visually
## communicate its identity. Asserts: bounded floor + walls (back/left/right),
## a Label3D sign whose text matches the parody name, and ≥3 Label3D-labeled
## fixtures (counter, register, shelves). Catches "brown void" regressions
## where a store ships with floor-only scaffolding.
extends GutTest


const STORES: Array = [
	{
		"id": &"retro_games",
		"path": "res://game/scenes/stores/retro_games.tscn",
		"sign_name": "Retro Games",
	},
	{
		"id": &"pocket_creatures",
		"path": "res://game/scenes/stores/pocket_creatures.tscn",
		"sign_name": "PocketCreatures",
	},
	{
		"id": &"video_rental",
		"path": "res://game/scenes/stores/video_rental.tscn",
		"sign_name": "Video Rental",
	},
	{
		"id": &"consumer_electronics",
		"path": "res://game/scenes/stores/consumer_electronics.tscn",
		"sign_name": "Consumer Electronics",
	},
	{
		"id": &"sports_memorabilia",
		"path": "res://game/scenes/stores/sports_memorabilia.tscn",
		"sign_name": "Sports Memorabilia",
	},
]


func _instantiate(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, "PackedScene must load: %s" % path)
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	add_child_autofree(root)
	return root


func _find_descendant_of_type(root: Node, type_name: String) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_class(type_name):
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _has_node_named_containing(root: Node, needle: String) -> bool:
	var stack: Array = [root]
	var lower: String = needle.to_lower()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name.to_lower().findn(lower) != -1:
			return true
		for c in n.get_children():
			stack.append(c)
	return false


func test_every_active_store_has_floor_and_walls() -> void:
	for store in STORES:
		var root: Node = _instantiate(store["path"])
		assert_not_null(root, "scene must instantiate: %s" % store["id"])
		if root == null:
			continue
		assert_true(_has_node_named_containing(root, "floor"),
			"%s must have a Floor node (no brown void)" % store["id"])
		assert_true(_has_node_named_containing(root, "backwall"),
			"%s must have a BackWall node" % store["id"])
		assert_true(_has_node_named_containing(root, "leftwall"),
			"%s must have a LeftWall node" % store["id"])
		assert_true(_has_node_named_containing(root, "rightwall"),
			"%s must have a RightWall node" % store["id"])


func test_every_active_store_has_sign_with_parody_name() -> void:
	for store in STORES:
		var root: Node = _instantiate(store["path"])
		if root == null:
			continue
		var labels: Array = _find_descendant_of_type(root, "Label3D")
		var found: bool = false
		var expected: String = String(store["sign_name"]).to_lower()
		for l in labels:
			if String(l.text).to_lower().findn(expected) != -1:
				found = true
				break
		assert_true(found,
			"%s must have a Label3D whose text contains the parody name '%s'"
				% [store["id"], store["sign_name"]])


func _count_labeled_fixtures(root: Node) -> int:
	# A "labeled fixture" is either an Interactable carrying a non-empty
	# display_name (the in-world hover label players actually see), or a
	# MeshInstance3D/Area3D with a Label3D child (visible signage on the
	# fixture itself).
	var stack: Array = [root]
	var count: int = 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var counted: bool = false
		if "display_name" in n:
			var dn: Variant = n.get("display_name")
			if dn != null and String(dn) != "":
				count += 1
				counted = true
		if not counted and (n.is_class("MeshInstance3D") or n.is_class("Area3D")):
			for c in n.get_children():
				if c.is_class("Label3D"):
					count += 1
					break
		for c in n.get_children():
			stack.append(c)
	return count


func test_every_active_store_has_three_labeled_fixtures() -> void:
	for store in STORES:
		var root: Node = _instantiate(store["path"])
		if root == null:
			continue
		var n_fixtures: int = _count_labeled_fixtures(root)
		assert_gte(n_fixtures, 3,
			"%s must have ≥3 labeled fixtures (Interactable.display_name or fixture-attached Label3D); found %d"
				% [store["id"], n_fixtures])
