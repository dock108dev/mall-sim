## Verifies that retro_games.tscn ships debug-only geometry hidden by default
## so a missed _ready() / NavZoneInteractable._apply_debug_visibility() call
## cannot leak debug visuals into normal gameplay.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"


func _instantiate_without_tree() -> Node3D:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene must load")
	if scene == null:
		return null
	# instantiate() builds the node tree but does NOT add it to the SceneTree,
	# so @onready vars and _ready() have not yet executed and visibility values
	# reflect what is saved in the .tscn file.
	return scene.instantiate() as Node3D


func test_no_billboard_debug_labels_in_scene() -> void:
	var root: Node3D = _instantiate_without_tree()
	if root == null:
		return
	assert_null(
		root.get_node_or_null("DebugLabels"),
		"DebugLabels Node3D must not exist — giant floating world labels are removed"
	)
	root.free()


func test_slot_placeholder_meshes_visible_false_in_scene() -> void:
	var root: Node3D = _instantiate_without_tree()
	if root == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_named(root, "PlaceholderMesh", meshes)
	assert_gt(meshes.size(), 0, "Scene must contain PlaceholderMesh slot markers")
	for mesh: MeshInstance3D in meshes:
		assert_false(
			mesh.visible,
			"%s must default to visible=false; placement mode opts in" % mesh.name
		)
	root.free()


func test_nav_zone_debug_meshes_visible_false_in_scene() -> void:
	var root: Node3D = _instantiate_without_tree()
	if root == null:
		return
	var nav_zones: Node = root.get_node_or_null("NavZones")
	assert_not_null(nav_zones, "NavZones container must exist")
	if nav_zones == null:
		root.free()
		return
	var found: int = 0
	for zone: Node in nav_zones.get_children():
		var debug_mesh: MeshInstance3D = zone.get_node_or_null("DebugMesh") as MeshInstance3D
		if debug_mesh == null:
			continue
		found += 1
		assert_false(
			debug_mesh.visible,
			"NavZones/%s/DebugMesh must default to visible=false in the scene file" % zone.name
		)
	assert_gt(found, 0, "At least one NavZones/*/DebugMesh node must exist")
	root.free()


func test_debug_visuals_show_in_debug_build_after_ready() -> void:
	# The runtime opt-in path: when each NavZone enters the tree in a debug
	# build (which the test environment is), NavZoneInteractable._ready() runs
	# _apply_debug_visibility() and flips its MeshInstance3D children
	# (the DebugMesh) to visible=true.
	if not OS.is_debug_build():
		return
	var root: Node3D = _instantiate_without_tree()
	if root == null:
		return
	add_child(root)
	var nav_zones: Node = root.get_node_or_null("NavZones")
	if nav_zones:
		for zone: Node in nav_zones.get_children():
			var dm: MeshInstance3D = zone.get_node_or_null("DebugMesh") as MeshInstance3D
			if dm:
				assert_true(
					dm.visible,
					"NavZones/%s/DebugMesh must be visible after _ready in a debug build"
					% zone.name
				)
	root.queue_free()


func _collect_named(node: Node, target_name: String, out: Array[MeshInstance3D]) -> void:
	if node.name == target_name and node is MeshInstance3D:
		out.append(node)
	for child: Node in node.get_children():
		_collect_named(child, target_name, out)
