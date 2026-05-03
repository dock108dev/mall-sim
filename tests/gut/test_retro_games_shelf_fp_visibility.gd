## Pins the first-person eye-level visibility contract for shelf slots in
## retro_games.tscn: every authored slot must sit inside the FP camera cone
## (camera at Y=1.7m on store_player_body), a stocked slot must spawn a
## visible Node3D mesh child via the place_item path, and removing the item
## must free that mesh. Covers shelf state visibility for the FP entry.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

# Camera eye height authored in store_player_body.tscn — slots above this
# would clip the upper edge of the view at standing distance, slots below
# 0.4m read as floor litter rather than merchandise.
const FP_EYE_HEIGHT_Y: float = 1.7
const SLOT_MIN_Y: float = 0.4
const SLOT_MAX_Y: float = FP_EYE_HEIGHT_Y - 0.05

const FIXTURE_NAMES: Array = [
	"CartRackLeft",
	"CartRackRight",
	"GlassCase",
	"ConsoleShelf",
	"AccessoriesBin",
]

var _root: Node3D = null


func before_all() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene must load")
	if scene:
		_root = scene.instantiate() as Node3D
		add_child(_root)


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


func _collect_shelf_slots() -> Array:
	var slots: Array = []
	for fixture_name: String in FIXTURE_NAMES:
		var fixture: Node = _root.get_node_or_null(fixture_name)
		if fixture == null:
			continue
		for child: Node in fixture.get_children():
			if child is ShelfSlot:
				slots.append({"fixture": fixture_name, "slot": child})
	return slots


func test_every_shelf_slot_sits_inside_fp_eye_cone() -> void:
	var slots: Array = _collect_shelf_slots()
	assert_gt(
		slots.size(), 0,
		"Expected at least one ShelfSlot across known retro_games fixtures",
	)
	for entry: Dictionary in slots:
		var fixture_name: String = entry["fixture"]
		var slot: ShelfSlot = entry["slot"]
		var world_y: float = slot.global_position.y
		assert_between(
			world_y,
			SLOT_MIN_Y,
			SLOT_MAX_Y,
			(
				"%s/%s world Y (%.3f) must lie in the FP eye-level cone "
				+ "[%.2f..%.2f] so the slot is visible from a standing "
				+ "first-person camera at %.2f m"
			) % [
				fixture_name, slot.name, world_y,
				SLOT_MIN_Y, SLOT_MAX_Y, FP_EYE_HEIGHT_Y,
			],
		)


func test_glass_case_slots_are_below_eye_height() -> void:
	# The glass case is a low display island — items sitting on its top must
	# read from above when the player stands next to it.
	var case_node: Node = _root.get_node_or_null("GlassCase")
	assert_not_null(case_node, "GlassCase must exist")
	if case_node == null:
		return
	var found: bool = false
	for child: Node in case_node.get_children():
		if not (child is ShelfSlot):
			continue
		found = true
		var world_y: float = (child as ShelfSlot).global_position.y
		assert_lt(
			world_y, FP_EYE_HEIGHT_Y,
			(
				"GlassCase/%s world Y (%.3f) must sit below FP eye height "
				+ "(%.2f) so the showcase reads from above"
			) % [child.name, world_y, FP_EYE_HEIGHT_Y],
		)
	assert_true(found, "GlassCase must contain at least one ShelfSlot child")


func test_place_item_spawns_visible_mesh_node() -> void:
	var slot: ShelfSlot = ShelfSlot.new()
	slot.slot_id = "fp_vis_place_01"
	add_child_autofree(slot)

	var ok: bool = slot.place_item("inst_fp_vis_01", "cartridge")
	assert_true(ok, "place_item must succeed on an empty slot")

	var spawned: Node3D = _find_first_node3d_non_marker(slot)
	assert_not_null(
		spawned,
		"place_item must add a Node3D mesh child for the stocked product",
	)
	if spawned:
		assert_true(
			spawned.visible,
			"Spawned product mesh must default to visible so the stocked "
			+ "state reads from FP eye level",
		)


func test_remove_item_frees_spawned_mesh_node() -> void:
	var slot: ShelfSlot = ShelfSlot.new()
	slot.slot_id = "fp_vis_remove_01"
	add_child_autofree(slot)

	slot.place_item("inst_fp_vis_02", "cartridge")
	var spawned_before: Node3D = _find_first_node3d_non_marker(slot)
	assert_not_null(spawned_before, "pre-condition: stocked mesh must exist")

	slot.remove_item()
	# queue_free is deferred — flush so the child detach is observable.
	await get_tree().process_frame

	var spawned_after: Node3D = _find_first_node3d_non_marker(slot)
	assert_null(
		spawned_after,
		"remove_item must free the spawned mesh so selling visually empties "
		+ "the slot",
	)


# ── Helpers ───────────────────────────────────────────────────────────────────

# Spawned product roots use the `PlaceholderProp*` naming convention shared by
# every entry in `ShelfSlot.CATEGORY_SCENES`; matching on that prefix avoids
# false hits on the slot's own scene-authored children (`PlaceholderMesh`,
# `CollisionShape3D`) and on the `InteractionArea` Area3D that the base
# `Interactable._ready` injects.
func _find_first_node3d_non_marker(slot: Node) -> Node3D:
	for child: Node in slot.get_children():
		if not (child is Node3D):
			continue
		if String(child.name).begins_with("PlaceholderProp"):
			return child as Node3D
	return null
