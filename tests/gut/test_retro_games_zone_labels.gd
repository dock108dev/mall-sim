## Verifies retro_games.tscn ships Day-1 zone-readability labels:
##   - the four primary zones (Shelves, Checkout, Exit/Mall, Backroom)
##     each have a Label3D in the "zone_label" group
##   - labels sit above slot height (Y >= 2.0) so they do not occlude
##     interactable slot zones beneath them
##   - the group acts as a bulk-hide handle so a future polish pass can
##     toggle all zone markers off in one call
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const ZONE_GROUP: StringName = &"zone_label"
const REQUIRED_KEYWORDS: Array[String] = [
	"shelves", "checkout", "exit", "backroom",
]
const MIN_LABEL_HEIGHT: float = 2.0

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
