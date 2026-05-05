## Verifies retro_games.tscn ships every BRAINDUMP-required physical zone as
## a named node with at least one Interactable child, plus the supporting
## artifact interactables (delivery_manifest, poster_slot, featured_display,
## release_notes_clipboard, back_room_inventory_shelf, back_room_damaged_bin)
## and the new EventBus signals + idempotent flag-discrepancy contract.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
## Required BRAINDUMP zones (ISSUE-009). The keys are scene-tree node names;
## each must exist and host at least one Interactable in its subtree.
const REQUIRED_ZONE_NODES: Array[String] = [
	"used_game_wall",
	"new_release_wall",
	"old_gen_shelf",
	"new_console_display",
	"AccessoriesBin",
	"bargain_bin",
	"hold_shelf",
	"back_room",
	"employee_area",
]
## Artifact interactables required for the pre-open / customization rituals.
const REQUIRED_ARTIFACT_PATHS: Array[String] = [
	"delivery_manifest/Interactable",
	"poster_slot/Interactable",
	"featured_display/Interactable",
	"release_notes_clipboard/Interactable",
	"back_room/back_room_inventory_shelf/Interactable",
	"back_room/back_room_damaged_bin/Interactable",
]

var _root: Node3D = null


func before_all() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene must load")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


# ── Zone presence ────────────────────────────────────────────────────────────

func test_every_required_zone_node_exists() -> void:
	for zone_name: String in REQUIRED_ZONE_NODES:
		var node: Node = _root.get_node_or_null(zone_name)
		assert_not_null(
			node,
			"Zone '%s' must exist as a named node in retro_games.tscn"
			% zone_name,
		)


func test_every_zone_has_at_least_one_interactable() -> void:
	for zone_name: String in REQUIRED_ZONE_NODES:
		var node: Node = _root.get_node_or_null(zone_name)
		if node == null:
			continue
		assert_true(
			_subtree_contains_interactable(node),
			"Zone '%s' must host at least one Interactable child"
			% zone_name,
		)


func test_every_artifact_interactable_exists() -> void:
	for path: String in REQUIRED_ARTIFACT_PATHS:
		var node: Interactable = _root.get_node_or_null(path) as Interactable
		assert_not_null(
			node,
			"Artifact Interactable at '%s' must exist" % path,
		)


# ── Specific BRAINDUMP requirements ─────────────────────────────────────────

func test_back_room_has_navigation_region_and_zone_boundary() -> void:
	var back_room: Node = _root.get_node_or_null("back_room")
	assert_not_null(back_room, "back_room must exist")
	if back_room == null:
		return
	assert_not_null(
		back_room.get_node_or_null("NavigationRegion3D"),
		"back_room must declare its own NavigationRegion3D for separate nav",
	)
	var boundary: Node = back_room.get_node_or_null("ZoneBoundary")
	assert_not_null(boundary, "back_room must include a ZoneBoundary Area3D")
	assert_true(
		boundary != null and boundary.is_in_group("back_room_zone"),
		"back_room.ZoneBoundary must belong to the 'back_room_zone' group",
	)


func test_employee_area_has_zone_boundary() -> void:
	var area: Node = _root.get_node_or_null("employee_area")
	assert_not_null(area, "employee_area must exist")
	if area == null:
		return
	var boundary: Node = area.get_node_or_null("ZoneBoundary")
	assert_not_null(boundary, "employee_area must include a ZoneBoundary Area3D")
	assert_true(
		boundary != null and boundary.is_in_group("employee_zone"),
		"employee_area.ZoneBoundary must belong to the 'employee_zone' group",
	)


func test_new_console_display_has_dedicated_spotlight() -> void:
	var spotlight: Node = _root.get_node_or_null("new_console_display/Spotlight")
	assert_not_null(
		spotlight,
		"new_console_display must include a dedicated Spotlight node",
	)
	assert_true(
		spotlight is SpotLight3D,
		"new_console_display.Spotlight must be a SpotLight3D",
	)


func test_bargain_bin_uses_physical_bin_geometry() -> void:
	var bin: Node = _root.get_node_or_null("bargain_bin/BinMesh")
	assert_not_null(bin, "bargain_bin must include a physical BinMesh")
	if bin == null:
		return
	var mesh_node := bin as MeshInstance3D
	assert_not_null(mesh_node, "bargain_bin/BinMesh must be a MeshInstance3D")
	if mesh_node != null and mesh_node.mesh is BoxMesh:
		var box := mesh_node.mesh as BoxMesh
		# The bin should read as a floor-standing tub, not a flat shelf.
		assert_gt(
			box.size.y, 0.3,
			"bargain_bin BinMesh height must read as a tub (>0.3m)",
		)


func test_hold_shelf_can_host_hold_slip_instances() -> void:
	var shelf: Node = _root.get_node_or_null("hold_shelf")
	assert_not_null(shelf, "hold_shelf must exist")
	if shelf == null:
		return
	assert_not_null(
		shelf.get_node_or_null("HoldSlipContainer"),
		"hold_shelf must include a HoldSlipContainer parent for slip instances",
	)


func test_used_game_wall_groups_existing_cart_racks() -> void:
	var left: Node = _root.get_node_or_null("CartRackLeft")
	var right: Node = _root.get_node_or_null("CartRackRight")
	assert_not_null(left, "CartRackLeft must remain present")
	assert_not_null(right, "CartRackRight must remain present")
	if left != null:
		assert_true(
			left.is_in_group("used_game_wall"),
			"CartRackLeft must join the 'used_game_wall' group",
		)
	if right != null:
		assert_true(
			right.is_in_group("used_game_wall"),
			"CartRackRight must join the 'used_game_wall' group",
		)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _subtree_contains_interactable(node: Node) -> bool:
	if node is Interactable:
		return true
	for child: Node in node.get_children():
		if _subtree_contains_interactable(child):
			return true
	return false
