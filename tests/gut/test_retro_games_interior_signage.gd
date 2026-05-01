## Verifies retro_games.tscn ships interior zone signage that aids
## readability from the overhead camera:
##   - CHECKOUT, TESTING, and category (GAMES) zone labels are present
##   - a RETRO GAMES interior banner brands the back wall
##   - all signs sit above slot height (Y >= 2.0) so they never block
##     interactable shelf zones
##   - signs do not attach to fixtures slated for removal (ExtraShelf,
##     BackroomDivider)
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const MIN_SIGN_HEIGHT: float = 2.0

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


func _find_visible_label(path: String, label: String) -> Label3D:
	var node: Label3D = _root.get_node_or_null(path) as Label3D
	assert_not_null(node, "%s (%s) must exist" % [path, label])
	if node == null:
		return null
	# Walk ancestors to confirm none hide the label.
	var cursor: Node = node
	while cursor != null and cursor != _root:
		if cursor is Node3D and not (cursor as Node3D).visible:
			fail_test(
				"%s (%s) is hidden by ancestor %s.visible=false"
				% [path, label, cursor.get_path()],
			)
			return null
		cursor = cursor.get_parent()
	return node


# ── Three zone labels visible: checkout, wall shelves, testing zone ─────────

func test_checkout_zone_label_visible() -> void:
	var sign: Label3D = _find_visible_label(
		"Checkout/Register/CheckoutSign", "CHECKOUT zone sign"
	)
	if sign == null:
		return
	assert_string_contains(
		sign.text.to_lower(), "checkout",
		"Checkout sign text should contain 'checkout'",
	)


func test_wall_shelf_zone_label_visible() -> void:
	var sign: Label3D = _find_visible_label(
		"InteriorSignage/GamesSign", "GAMES category sign"
	)
	if sign == null:
		return
	assert_string_contains(
		sign.text.to_lower(), "games",
		"Wall shelf category sign should mention games",
	)


func test_testing_zone_label_visible() -> void:
	var sign: Label3D = _find_visible_label(
		"crt_demo_area/ComingSoonLabel", "TESTING zone sign"
	)
	if sign == null:
		return
	var text: String = sign.text.to_lower()
	assert_true(
		text.contains("testing") or text.contains("try"),
		"Testing zone sign should mention testing/try-it; got %s" % sign.text,
	)


# ── Store name branding on at least one interior-facing surface ─────────────

func test_retro_games_interior_branding_present() -> void:
	var banner: Label3D = _find_visible_label(
		"InteriorSignage/StoreNameBanner", "RETRO GAMES interior banner"
	)
	if banner == null:
		return
	var text: String = banner.text.to_lower()
	assert_true(
		text.contains("retro") and text.contains("games"),
		"Interior banner should brand the store; got %s" % banner.text,
	)


# ── Sign placement: Y >= 2.0 to clear interactable slot zones ───────────────
# Wall-mounted zone signs share airspace with the cart racks (slot tops at
# Y≈1.6) and the checkout impulse slots, so they must sit above 2.0. The
# testing-zone "Coming Soon" notice is intentionally placed on the CRT prop
# at viewer height — it has no slot zones beneath it and is excluded.

func test_wall_mounted_zone_signs_clear_slot_height() -> void:
	var paths: Array[String] = [
		"Checkout/Register/CheckoutSign",
		"InteriorSignage/StoreNameBanner",
		"InteriorSignage/GamesSign",
	]
	for path: String in paths:
		var sign: Label3D = _root.get_node_or_null(path) as Label3D
		if sign == null:
			continue
		var y: float = sign.global_position.y
		assert_gte(
			y, MIN_SIGN_HEIGHT,
			(
				"%s at Y=%.2f must sit at Y >= %.2f so it does not occlude "
				+ "interactable slot zones (slots top at Y≈1.6)"
			) % [path, y, MIN_SIGN_HEIGHT],
		)


# ── Signs must not attach to fixtures slated for removal ────────────────────

func test_no_signs_attached_to_removed_fixtures() -> void:
	# ExtraShelf was removed in a sibling pass; if it is gone, there can be
	# nothing under it. BackroomDivider may also be removed/repositioned.
	# Walk every Label3D under the store root and assert its path does not
	# descend from one of the removed/placeholder nodes.
	var forbidden: Array[String] = ["ExtraShelf", "BackroomDivider"]
	for label: Label3D in _gather_labels(_root):
		var path: String = str(_root.get_path_to(label))
		for ancestor: String in forbidden:
			assert_false(
				path.contains(ancestor),
				(
					"Label3D '%s' is attached under '%s' which is being "
					+ "removed/reworked; relocate it onto a stable parent"
				) % [path, ancestor],
			)


func _gather_labels(node: Node) -> Array[Label3D]:
	var result: Array[Label3D] = []
	if node is Label3D:
		result.append(node as Label3D)
	for child: Node in node.get_children():
		result.append_array(_gather_labels(child))
	return result
