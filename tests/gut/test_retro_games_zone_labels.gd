## Verifies retro_games.tscn ships Day-1 zone-readability labels:
##   - the four primary zones (Shelves, Checkout, Exit/Mall, Backroom)
##     each have a Label3D in the "zone_label" group
##   - labels sit above slot height (Y >= 2.0) so they do not occlude
##     interactable slot zones beneath them
##   - the Day-1 navigation labels (Used Shelves + Checkout) carry a
##     pixel_size large enough to remain legible from the entrance approach
##     and use wording that aligns with the Day-1 objective steps
##   - the group acts as a bulk-hide handle so a future polish pass can
##     toggle all zone markers off in one call
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const ZONE_GROUP: StringName = &"zone_label"
const REQUIRED_KEYWORDS: Array[String] = [
	"shelves", "checkout", "exit", "backroom",
]
const MIN_LABEL_HEIGHT: float = 2.0
# The Day-1 labels must remain legible from across the room (~17m from the
# entrance). pixel_size 0.005 produced 0.18m letters at 36pt — sub-1° at
# entrance distance and unreadable on first approach. The current floor of
# 0.007 keeps letter angular size above 1° from anywhere a player can stand.
const MIN_DAY1_NAV_PIXEL_SIZE: float = 0.007
const SHELVES_LABEL_PATH: String = "ZoneLabels/ShelvesLabel"
const CHECKOUT_LABEL_PATH: String = "ZoneLabels/CheckoutLabel"

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


func _zone_labels() -> Array[Label3D]:
	var result: Array[Label3D] = []
	if _root == null:
		return result
	for node: Node in get_tree().get_nodes_in_group(ZONE_GROUP):
		if node is Label3D and _root.is_ancestor_of(node):
			result.append(node)
	return result


func test_each_required_zone_has_a_label() -> void:
	var labels: Array[Label3D] = _zone_labels()
	for keyword: String in REQUIRED_KEYWORDS:
		var matched: bool = false
		for label: Label3D in labels:
			if label.text.to_lower().contains(keyword):
				matched = true
				break
		assert_true(
			matched,
			"Expected a Label3D in group '%s' whose text contains '%s'"
			% [ZONE_GROUP, keyword],
		)


func test_zone_labels_clear_slot_height() -> void:
	for label: Label3D in _zone_labels():
		var y: float = label.global_position.y
		assert_gte(
			y, MIN_LABEL_HEIGHT,
			(
				"Zone label '%s' at Y=%.2f must sit at Y >= %.2f so it does "
				+ "not occlude interactable slot zones (slots top at Y≈1.6)"
			) % [label.text, y, MIN_LABEL_HEIGHT],
		)


func test_day1_nav_labels_match_objective_wording() -> void:
	# AC: zone label text exactly matches wording in objectives.json so the
	# spatial label and the tutorial instruction line up.
	var shelves: Label3D = _root.get_node_or_null(SHELVES_LABEL_PATH) as Label3D
	assert_not_null(shelves, "ZoneLabels/ShelvesLabel must exist")
	var checkout: Label3D = _root.get_node_or_null(CHECKOUT_LABEL_PATH) as Label3D
	assert_not_null(checkout, "ZoneLabels/CheckoutLabel must exist")
	var stock_text: String = _objective_step_text("stock_item")
	var checkout_text: String = _objective_step_text("customer_at_checkout")
	if shelves != null:
		assert_true(
			stock_text.to_lower().contains(shelves.text.to_lower()),
			(
				"ShelvesLabel text '%s' must appear in objectives.json "
				+ "stock_item.text '%s'"
			) % [shelves.text, stock_text],
		)
	if checkout != null:
		assert_true(
			checkout_text.to_lower().contains(checkout.text.to_lower()),
			(
				"CheckoutLabel text '%s' must appear in objectives.json "
				+ "customer_at_checkout.text '%s'"
			) % [checkout.text, checkout_text],
		)


func test_day1_nav_labels_meet_pixel_size_floor() -> void:
	# AC: readable from 3m approach. pixel_size below the floor pushed the
	# letter angular size below 1° at the typical 15m+ entrance-approach view,
	# making the label illegible until the player was already next to the
	# zone.
	for path: String in [SHELVES_LABEL_PATH, CHECKOUT_LABEL_PATH]:
		var label: Label3D = _root.get_node_or_null(path) as Label3D
		assert_not_null(label, "%s must exist" % path)
		if label == null:
			continue
		assert_gte(
			label.pixel_size, MIN_DAY1_NAV_PIXEL_SIZE,
			(
				"%s pixel_size=%.4f must be >= %.4f so letters remain legible "
				+ "on entrance approach (~17m line-of-sight)."
			) % [path, label.pixel_size, MIN_DAY1_NAV_PIXEL_SIZE],
		)


func _objective_step_text(step_id: String) -> String:
	var path: String = "res://game/content/objectives.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "objectives.json must open")
	if file == null:
		return ""
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		fail_test("objectives.json must parse as a Dictionary")
		return ""
	var dict: Dictionary = parsed
	var entries: Array = dict.get("objectives", []) as Array
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var day_entry: Dictionary = entry
		if int(day_entry.get("day", 0)) != 1:
			continue
		var steps: Array = day_entry.get("steps", []) as Array
		for step: Variant in steps:
			if not step is Dictionary:
				continue
			var step_dict: Dictionary = step
			if String(step_dict.get("id", "")) == step_id:
				return String(step_dict.get("text", ""))
	fail_test("objectives.json has no Day-1 step '%s'" % step_id)
	return ""


func test_zone_labels_bulk_hide_via_group() -> void:
	var labels: Array[Label3D] = _zone_labels()
	assert_gte(
		labels.size(), 4,
		"Expected at least 4 zone labels (Shelves, Checkout, Exit, Backroom)",
	)
	for label: Label3D in labels:
		label.visible = true
	get_tree().call_group(ZONE_GROUP, "set_visible", false)
	for label: Label3D in labels:
		assert_false(
			label.visible,
			"Zone label '%s' must hide via call_group('%s', 'set_visible', false)"
			% [label.text, ZONE_GROUP],
		)
