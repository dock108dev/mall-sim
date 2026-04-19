## Verifies ISSUE-140 Video Rental store scene acceptance criteria.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/video_rental.tscn"
const SCRIPT_PATH: String = "res://game/scripts/stores/video_rental_store_controller.gd"
const GENRE_SECTION_NAMES: Array[String] = [
	"ActionSection",
	"ComedySection",
	"HorrorSection",
	"DramaSection",
	"SciFiSection",
]

var _root: Node3D = null
var _last_interactable: Interactable = null
var _last_interaction_type: int = -1


func before_each() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Video Rental scene should load")
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
	assert_eq(_root.name, "VideoRental")
	assert_eq(_root.get_script().resource_path, SCRIPT_PATH)

	for child_name: String in [
		"Geometry",
		"ShelfZones",
		"ReturnDesk",
		"ViewingAlcove",
		"LightingRig",
		"PlayerEntrySpawn",
		"InteractionPoints",
	]:
		assert_not_null(
			_root.get_node_or_null(child_name),
			"Scene should include %s" % child_name
		)


func test_genre_sections_have_distinct_spatial_positions() -> void:
	var positions: Array[Vector3] = []
	for section_name: String in GENRE_SECTION_NAMES:
		var section: Node3D = _root.get_node_or_null(
			"ShelfZones/%s" % section_name
		) as Node3D
		assert_not_null(section, "%s should exist" % section_name)
		positions.append(section.global_position)
		assert_not_null(
			section.get_node_or_null("ShelfMesh"),
			"%s should include shelf placeholder geometry" % section_name
		)

	for i: int in range(positions.size()):
		for j: int in range(i + 1, positions.size()):
			assert_gt(
				positions[i].distance_to(positions[j]),
				1.25,
				"Genre sections should not collapse into one room blob"
			)


func test_new_releases_wall_is_high_visibility_and_backlit() -> void:
	var wall: Node3D = _root.get_node_or_null(
		"ShelfZones/NewReleasesWall"
	) as Node3D
	assert_not_null(wall, "NewReleasesWall should exist")
	assert_not_null(
		wall.get_node_or_null("DisplayMesh"),
		"NewReleasesWall should include display geometry"
	)

	var backlight: SpotLight3D = wall.get_node_or_null(
		"Backlight"
	) as SpotLight3D
	assert_not_null(backlight, "NewReleasesWall should have a backlight")
	assert_gt(
		backlight.light_energy,
		1.0,
		"NewReleasesWall backlight should be brighter than shelf ambience"
	)


func test_return_desk_interactable_emits_returns_bin_event() -> void:
	var returns_bin: ReturnsBin = _root.get_node_or_null(
		"ReturnDesk/Interactable"
	) as ReturnsBin
	assert_not_null(
		returns_bin,
		"ReturnDesk should expose an Interactable returns bin"
	)
	assert_eq(
		returns_bin.interaction_type,
		Interactable.InteractionType.RETURNS_BIN
	)

	returns_bin.interact()

	assert_eq(_last_interactable, returns_bin)
	assert_eq(
		_last_interaction_type,
		Interactable.InteractionType.RETURNS_BIN
	)


func test_entry_spawn_and_interaction_points_match_layout() -> void:
	var spawn: Marker3D = _root.get_node_or_null(
		"PlayerEntrySpawn"
	) as Marker3D
	assert_not_null(spawn, "PlayerEntrySpawn should exist")
	assert_gt(
		spawn.global_position.z,
		2.5,
		"PlayerEntrySpawn should sit at the storefront entrance"
	)

	var points: Node = _root.get_node("InteractionPoints")
	for point_name: String in [
		"NewReleasesPoint",
		"ActionPoint",
		"ComedyPoint",
		"HorrorPoint",
		"DramaPoint",
		"SciFiPoint",
		"ReturnDeskPoint",
	]:
		assert_not_null(
			points.get_node_or_null(point_name),
			"InteractionPoints should include %s" % point_name
		)


func test_lighting_budget_and_environment_contract() -> void:
	var halogens: Node = _root.get_node_or_null(
		"LightingRig/OverheadHalogens"
	)
	assert_not_null(
		halogens,
		"LightingRig should group four overhead halogens"
	)
	assert_eq(
		halogens.find_children("*", "OmniLight3D", false, false).size(),
		4,
		"OverheadHalogens should contain exactly four OmniLight3D nodes"
	)
	assert_not_null(
		_root.get_node_or_null("LightingRig/NeonSignAccent"),
		"LightingRig should include a neon accent light"
	)

	var omni_lights: Array[Node] = _root.find_children(
		"*", "OmniLight3D", true, false
	)
	var world_environments: Array[Node] = _root.find_children(
		"*", "WorldEnvironment", true, false
	)

	assert_lte(
		omni_lights.size(),
		6,
		"Video Rental should use no more than six OmniLight3D nodes"
	)
	assert_eq(
		world_environments.size(),
		0,
		"EnvironmentManager owns WorldEnvironment, not store scenes"
	)


func _on_interactable_interacted(
	target: Interactable, interaction_type: int
) -> void:
	_last_interactable = target
	_last_interaction_type = interaction_type
