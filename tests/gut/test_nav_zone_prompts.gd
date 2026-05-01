## Verifies nav zone interaction prompts use action-specific verbs (not the
## generic "Go to") and that the InteractionRay action label uses an em-dash
## separator. Nav zone teleport behavior lives in test_nav_zone_navigation.gd.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const _InteractionRayScript: GDScript = preload(
	"res://game/scripts/player/interaction_ray.gd"
)

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


func test_no_nav_zone_uses_go_to_prompt() -> void:
	if not is_instance_valid(_root):
		return
	var nav_zones: Array[Node] = get_tree().get_nodes_in_group(&"nav_zone")
	assert_gt(nav_zones.size(), 0, "Scene should declare at least one nav_zone")
	for zone: Node in nav_zones:
		if not (zone is Interactable):
			continue
		var prompt: String = (zone as Interactable).prompt_text.strip_edges()
		assert_ne(
			prompt.to_lower(),
			"go to",
			"Nav zone '%s' must use action-specific prompt, not 'Go to'" % zone.name
		)
		assert_false(
			prompt.is_empty(),
			"Nav zone '%s' must declare an action verb in prompt_text" % zone.name
		)


func test_nav_zone_prompts_match_expected_action_verbs() -> void:
	if not is_instance_valid(_root):
		return
	var expected: Dictionary = {
		"ZoneEntrance": "enter mall",
		"ZoneShelf": "stock games",
		"ZoneDisplayTable": "stock item",
		"ZoneBackroom": "open backstock",
	}
	var nav_zones_root: Node = _root.get_node_or_null("NavZones")
	assert_not_null(nav_zones_root, "retro_games.tscn must contain NavZones node")
	if nav_zones_root == null:
		return
	for zone_name: String in expected.keys():
		var zone: Node = nav_zones_root.get_node_or_null(zone_name)
		assert_not_null(zone, "NavZones must contain %s" % zone_name)
		if zone == null:
			continue
		var actual: String = (zone as Interactable).prompt_text.strip_edges().to_lower()
		assert_eq(
			actual,
			str(expected[zone_name]),
			"%s prompt_text should be '%s'" % [zone_name, expected[zone_name]]
		)


func test_action_label_uses_em_dash_separator() -> void:
	var ray: Node = Node.new()
	ray.set_script(_InteractionRayScript)
	add_child_autofree(ray)

	var target := Interactable.new()
	target.prompt_text = "Stock Games"
	target.display_name = "Shelf Area"
	add_child_autofree(target)

	ray._set_hovered_target(target)
	assert_eq(
		ray.get_hovered_action_label(),
		"Shelf Area — Press E to stock games",
		"Action label must use em-dash separator and lowercased verb"
	)


func test_action_label_does_not_use_slash_separator() -> void:
	var ray: Node = Node.new()
	ray.set_script(_InteractionRayScript)
	add_child_autofree(ray)

	var target := Interactable.new()
	target.prompt_text = "Open Backstock"
	target.display_name = "Backroom"
	add_child_autofree(target)

	ray._set_hovered_target(target)
	var label: String = ray.get_hovered_action_label()
	assert_false(
		label.contains(" / "),
		"Action label must not contain ' / ' separator (em-dash format only)"
	)
