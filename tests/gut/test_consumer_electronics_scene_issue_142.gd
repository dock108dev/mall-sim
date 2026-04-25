## Verifies ISSUE-142 Consumer Electronics store scene acceptance criteria.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/consumer_electronics.tscn"
const SCRIPT_PATH: String = (
	"res://game/scripts/stores/electronics_store_controller.gd"
)

var _root: Node3D = null
var _last_interactable: Interactable = null
var _last_interaction_type: int = -1


func before_each() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Consumer Electronics scene should load")
	_root = scene.instantiate() as Node3D
	add_child_autofree(_root)
	EventBus.interactable_interacted.connect(_on_interactable_interacted)


func after_each() -> void:
	if EventBus.interactable_interacted.is_connected(
		_on_interactable_interacted
	):
		EventBus.interactable_interacted.disconnect(_on_interactable_interacted)
	_last_interactable = null
	_last_interaction_type = -1


func test_root_and_required_direct_children_exist() -> void:
	assert_not_null(_root, "Scene should instantiate as Node3D")
	assert_eq(_root.name, "ConsumerElectronics")
	assert_eq(_root.get_script().resource_path, SCRIPT_PATH)

	for child_name: String in [
		"Geometry",
		"DemoKiosks",
		"WallShelving",
		"TestingBench",
		"ServiceCounter",
		"LightingRig",
		"PlayerEntrySpawn",
		"InteractionPoints",
	]:
		assert_not_null(
			_root.get_node_or_null(child_name),
			"Scene should include %s" % child_name
		)


func test_demo_kiosk_row_has_three_emissive_screens() -> void:
	var kiosks: Node3D = _root.get_node("DemoKiosks") as Node3D
	assert_eq(
		kiosks.find_children("Kiosk_*", "Node3D", false, false).size(),
		3,
		"DemoKiosks should contain exactly three kiosks"
	)

	for kiosk_name: String in ["Kiosk_A", "Kiosk_B", "Kiosk_C"]:
		var kiosk: Node3D = kiosks.get_node(kiosk_name) as Node3D
		assert_gt(
			kiosk.global_position.z,
			0.5,
			"%s should stay in the front-center demo row" % kiosk_name
		)

		var screen: MeshInstance3D = kiosk.get_node_or_null(
			"Screen"
		) as MeshInstance3D
		assert_not_null(screen, "%s should include a Screen mesh" % kiosk_name)
		var material := screen.get_surface_override_material(0)
		assert_not_null(
			material,
			"%s screen must have a surface material override" % kiosk_name
		)
		# ISSUE-004 reassigned the kiosk screens to the shared CRT shader so
		# all "old TV" screens read consistently across stores. Either path is
		# acceptable as long as the screen is visibly emissive.
		if material is StandardMaterial3D:
			var standard_material := material as StandardMaterial3D
			assert_true(
				standard_material.emission_enabled,
				"%s StandardMaterial3D screen should have emission enabled"
				% kiosk_name
			)
			assert_gt(
				standard_material.emission_energy_multiplier, 1.0,
				"%s StandardMaterial3D emission should be visible in preview"
				% kiosk_name
			)
		elif material is ShaderMaterial:
			var shader_material := material as ShaderMaterial
			assert_not_null(
				shader_material.shader,
				"%s ShaderMaterial screen must have a shader assigned"
				% kiosk_name
			)
		else:
			assert_true(
				false,
				"%s screen material must be StandardMaterial3D or ShaderMaterial"
				% kiosk_name
			)


func test_wall_shelving_has_left_and_right_three_tier_structure() -> void:
	var shelving: Node3D = _root.get_node("WallShelving") as Node3D

	for shelf_name: String in ["LeftShelf", "RightShelf"]:
		var shelf: Node3D = shelving.get_node_or_null(shelf_name) as Node3D
		assert_not_null(shelf, "%s should exist" % shelf_name)
		for tier_name: String in ["TierBottom", "TierMiddle", "TierTop"]:
			assert_not_null(
				shelf.get_node_or_null(tier_name),
				"%s should include %s" % [shelf_name, tier_name]
			)

	var left_shelf: Node3D = shelving.get_node("LeftShelf") as Node3D
	var right_shelf: Node3D = shelving.get_node("RightShelf") as Node3D
	assert_lt(left_shelf.global_position.x, -3.5)
	assert_gt(right_shelf.global_position.x, 3.5)


func test_testing_bench_and_service_counter_expose_interactables() -> void:
	var testing_interactable: Interactable = _root.get_node_or_null(
		"TestingBench/TestingInteraction"
	) as Interactable
	assert_not_null(
		testing_interactable,
		"TestingBench should expose an Interactable node"
	)
	assert_eq(
		testing_interactable.interaction_type,
		Interactable.InteractionType.ITEM
	)
	assert_eq(testing_interactable.prompt_text, "Test Device")

	testing_interactable.interact()
	assert_eq(_last_interactable, testing_interactable)
	assert_eq(_last_interaction_type, Interactable.InteractionType.ITEM)

	var checkout_interactable: Interactable = _root.get_node_or_null(
		"ServiceCounter/Interactable"
	) as Interactable
	assert_not_null(
		checkout_interactable,
		"ServiceCounter should expose a checkout Interactable node"
	)
	assert_eq(
		checkout_interactable.interaction_type,
		Interactable.InteractionType.REGISTER
	)
	assert_eq(checkout_interactable.prompt_text, "Checkout")

	checkout_interactable.interact()
	assert_eq(_last_interactable, checkout_interactable)
	assert_eq(_last_interaction_type, Interactable.InteractionType.REGISTER)


func test_entry_spawn_lighting_groups_and_environment_contract() -> void:
	var spawn: Marker3D = _root.get_node_or_null(
		"PlayerEntrySpawn"
	) as Marker3D
	assert_not_null(spawn, "PlayerEntrySpawn should exist")
	assert_gt(
		spawn.global_position.z,
		2.5,
		"PlayerEntrySpawn should sit at the storefront entrance"
	)

	var overheads: Node = _root.get_node("LightingRig/FluorescentOverheads")
	assert_eq(
		overheads.find_children("*", "OmniLight3D", false, false).size(),
		5,
		"FluorescentOverheads should group exactly five OmniLight3D nodes"
	)
	for light: OmniLight3D in overheads.find_children(
		"*", "OmniLight3D", false, false
	):
		assert_gte(
			light.light_color.b,
			light.light_color.r,
			"%s should stay cool white" % light.name
		)

	var screen_glow: Node = _root.get_node("LightingRig/KioskScreenGlow")
	assert_eq(
		screen_glow.find_children("*", "OmniLight3D", false, false).size(),
		3,
		"KioskScreenGlow should group exactly three blue OmniLight3D nodes"
	)
	for light: OmniLight3D in screen_glow.find_children(
		"*", "OmniLight3D", false, false
	):
		assert_gt(light.light_color.b, light.light_color.r)
		assert_lte(light.omni_range, 1.5)

	assert_eq(
		_root.find_children("*", "WorldEnvironment", true, false).size(),
		0,
		"Consumer Electronics should not define its own WorldEnvironment"
	)


func _on_interactable_interacted(
	target: Interactable, interaction_type: int
) -> void:
	_last_interactable = target
	_last_interaction_type = interaction_type
