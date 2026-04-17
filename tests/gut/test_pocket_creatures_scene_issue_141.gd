## Verifies ISSUE-141 PocketCreatures store scene acceptance criteria.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/pocket_creatures.tscn"
const SCRIPT_PATH: String = (
	"res://game/scripts/stores/pocket_creatures_store_controller.gd"
)

var _root: Node3D = null
var _last_interactable: Interactable = null
var _last_interaction_type: int = -1


func before_each() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "PocketCreatures scene should load")
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
	assert_eq(_root.name, "PocketCreatures")
	assert_eq(_root.get_script().resource_path, SCRIPT_PATH)

	for child_name: String in [
		"Geometry",
		"DisplayCases",
		"BinderStations",
		"SealedProductWall",
		"TournamentArea",
		"ServiceCounter",
		"LightingRig",
		"PlayerEntrySpawn",
		"InteractionPoints",
	]:
		assert_not_null(
			_root.get_node_or_null(child_name),
			"Scene should include %s" % child_name
		)


func test_display_case_row_has_four_cases_and_four_spotlights() -> void:
	var cases: Node3D = _root.get_node("DisplayCases") as Node3D
	var spotlights: Node = _root.get_node(
		"LightingRig/DisplaySpotlights"
	)
	assert_eq(
		cases.find_children("DisplayCase_*", "Node3D", false, false).size(),
		4,
		"DisplayCases should contain exactly four display cases"
	)
	assert_eq(
		spotlights.find_children("*", "SpotLight3D", false, false).size(),
		4,
		"DisplaySpotlights should contain exactly four spotlights"
	)

	for case_name: String in [
		"DisplayCase_A",
		"DisplayCase_B",
		"DisplayCase_C",
		"DisplayCase_D",
	]:
		var display_case: Node3D = cases.get_node(case_name) as Node3D
		assert_not_null(
			display_case.get_node_or_null("CaseMesh"),
			"%s should include case geometry" % case_name
		)
		assert_gt(
			display_case.global_position.z,
			0.5,
			"%s should remain in the front display row" % case_name
		)


func test_binder_stations_and_tournament_tables_stay_in_their_zones() -> void:
	var binder_stations: Node3D = _root.get_node("BinderStations") as Node3D
	var tournament_area: Node3D = _root.get_node("TournamentArea") as Node3D
	var station_names: Array[String] = [
		"BinderStation_A",
		"BinderStation_B",
		"BinderStation_C",
		"BinderStation_D",
	]

	assert_eq(
		binder_stations.find_children("BinderStation_*", "Node3D", false, false).size(),
		4,
		"BinderStations should contain exactly four lecterns"
	)

	for station_name: String in station_names:
		var station: Node3D = binder_stations.get_node(
			station_name
		) as Node3D
		assert_not_null(
			station.get_node_or_null("LecternMesh"),
			"%s should include a lectern prop" % station_name
		)
		assert_gt(
			station.global_position.z,
			-1.0,
			"%s should remain in the middle browsing zone" % station_name
		)
		assert_lt(
			station.global_position.z,
			0.1,
			"%s should not drift into the front display row" % station_name
		)

	for table_name: String in ["TournamentTable_A", "TournamentTable_B"]:
		var table: MeshInstance3D = tournament_area.get_node_or_null(
			table_name
		) as MeshInstance3D
		assert_not_null(table, "%s should exist" % table_name)
		assert_lt(
			table.global_position.z,
			-1.5,
			"%s should sit in the back tournament zone" % table_name
		)

	assert_not_null(
		tournament_area.get_node_or_null("TournamentBanner"),
		"TournamentArea should include a banner prop"
	)


func test_service_counter_exposes_pack_opening_interactable() -> void:
	var pack_opening: Interactable = _root.get_node_or_null(
		"ServiceCounter/Interactable"
	) as Interactable
	assert_not_null(
		pack_opening,
		"ServiceCounter should expose an Interactable node"
	)
	assert_eq(
		pack_opening.prompt_text,
		"Open Packs",
		"Pack opening interactable should use an explicit pack-opening prompt"
	)

	pack_opening.interact()

	assert_eq(_last_interactable, pack_opening)
	assert_eq(
		_last_interaction_type,
		Interactable.InteractionType.REGISTER
	)


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

	var overheads: Node = _root.get_node(
		"LightingRig/FluorescentOverheads"
	)
	assert_eq(
		overheads.find_children("*", "OmniLight3D", false, false).size(),
		6,
		"FluorescentOverheads should group exactly six OmniLight3D nodes"
	)

	for light: OmniLight3D in overheads.find_children(
		"*", "OmniLight3D", false, false
	):
		assert_gte(
			light.light_color.b,
			light.light_color.g,
			"%s should stay on the cool side of neutral" % light.name
		)
		assert_gt(
			light.light_energy,
			0.8,
			"%s should feel bright enough for the shop floor" % light.name
		)

	assert_eq(
		_root.find_children("*", "WorldEnvironment", true, false).size(),
		0,
		"PocketCreatures should not define its own WorldEnvironment"
	)


func _on_interactable_interacted(
	target: Interactable, interaction_type: int
) -> void:
	_last_interactable = target
	_last_interaction_type = interaction_type
