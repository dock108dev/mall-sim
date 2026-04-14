## Tests that GameWorld scene contains all required systems in correct
## dependency-tier order with proper script assignments.
extends GutTest


const GAME_WORLD_SCENE: PackedScene = preload(
	"res://game/scenes/world/game_world.tscn"
)

const TIER_1_SYSTEMS: Array[StringName] = [
	&"TimeSystem",
	&"EconomySystem",
]

const TIER_2_SYSTEMS: Array[StringName] = [
	&"InventorySystem",
	&"StoreStateManager",
	&"TrendSystem",
	&"MarketEventSystem",
	&"SeasonalEventSystem",
	&"MarketValueSystem",
]

const TIER_3_SYSTEMS: Array[StringName] = [
	&"CustomerSystem",
	&"MallCustomerSpawner",
	&"NPCSpawnerSystem",
	&"HaggleSystem",
	&"CheckoutSystem",
	&"ProgressionSystem",
	&"OrderSystem",
	&"StaffSystem",
]

const TIER_4_SYSTEMS: Array[StringName] = [
	&"StoreSelectorSystem",
	&"BuildModeSystem",
	&"FixturePlacementSystem",
	&"TournamentSystem",
	&"MetaShiftSystem",
]

const TIER_5_SYSTEMS: Array[StringName] = [
	&"TutorialSystem",
	&"PerformanceManager",
	&"PerformanceReportSystem",
	&"RandomEventSystem",
	&"SecretThreadManager",
	&"SecretThreadSystem",
	&"AmbientMomentsSystem",
	&"EndingEvaluatorSystem",
	&"StoreUpgradeSystem",
	&"CompletionTracker",
	&"SaveManager",
]

var _all_tiers: Array[Array] = []


func before_all() -> void:
	_all_tiers = [
		TIER_1_SYSTEMS, TIER_2_SYSTEMS, TIER_3_SYSTEMS,
		TIER_4_SYSTEMS, TIER_5_SYSTEMS,
	]


func test_scene_contains_all_systems() -> void:
	var scene_state: SceneState = GAME_WORLD_SCENE.get_state()
	var node_names: Array[StringName] = []
	for i: int in range(scene_state.get_node_count()):
		node_names.append(scene_state.get_node_name(i))

	for tier: Array in _all_tiers:
		for system_name: StringName in tier:
			assert_true(
				system_name in node_names,
				"System '%s' must be a child node in game_world.tscn"
				% system_name
			)


func test_systems_ordered_by_tier() -> void:
	var scene_state: SceneState = GAME_WORLD_SCENE.get_state()
	var node_names: Array[StringName] = []
	for i: int in range(scene_state.get_node_count()):
		node_names.append(scene_state.get_node_name(i))

	var last_index: int = -1
	for tier_idx: int in range(_all_tiers.size()):
		for system_name: StringName in _all_tiers[tier_idx]:
			var idx: int = node_names.find(system_name)
			if idx < 0:
				continue
			assert_gt(
				idx,
				last_index,
				"Tier %d system '%s' (index %d) must come after "
				% [tier_idx + 1, system_name, idx]
				+ "previous tier systems (last index %d)"
				% last_index
			)
			last_index = idx


func test_all_system_nodes_have_scripts() -> void:
	var scene_state: SceneState = GAME_WORLD_SCENE.get_state()
	var node_names: Array[StringName] = []
	for i: int in range(scene_state.get_node_count()):
		node_names.append(scene_state.get_node_name(i))

	for tier: Array in _all_tiers:
		for system_name: StringName in tier:
			var idx: int = node_names.find(system_name)
			if idx < 0:
				continue
			var has_script: bool = false
			for prop_idx: int in range(
				scene_state.get_node_property_count(idx)
			):
				if scene_state.get_node_property_name(
					idx, prop_idx
				) == &"script":
					has_script = true
					break
			assert_true(
				has_script,
				"System node '%s' must have a script assigned"
				% system_name
			)


func test_game_world_has_initialize_systems_method() -> void:
	var scene_state: SceneState = GAME_WORLD_SCENE.get_state()
	var script_path: String = ""
	for prop_idx: int in range(
		scene_state.get_node_property_count(0)
	):
		if scene_state.get_node_property_name(
			0, prop_idx
		) == &"script":
			var res: Resource = scene_state.get_node_property_value(
				0, prop_idx
			)
			if res:
				script_path = res.resource_path
			break

	assert_ne(script_path, "", "GameWorld root must have a script")
	var gd_script: GDScript = load(script_path) as GDScript
	assert_not_null(gd_script, "GameWorld script must be loadable")
	var methods: Array[Dictionary] = gd_script.get_script_method_list()
	var has_init: bool = false
	for m: Dictionary in methods:
		if m.get("name", "") == "initialize_systems":
			has_init = true
			break
	assert_true(
		has_init,
		"GameWorld must expose initialize_systems() method"
	)


func test_total_system_count() -> void:
	var total: int = 0
	for tier: Array in _all_tiers:
		total += tier.size()
	assert_gte(
		total,
		32,
		"Expected at least 32 systems across all tiers, got %d" % total
	)


func test_no_system_ready_uses_await() -> void:
	var scene_state: SceneState = GAME_WORLD_SCENE.get_state()
	for tier: Array in _all_tiers:
		for system_name: StringName in tier:
			var idx: int = -1
			for i: int in range(scene_state.get_node_count()):
				if scene_state.get_node_name(i) == system_name:
					idx = i
					break
			if idx < 0:
				continue
			var script_res: GDScript = null
			for prop_idx: int in range(
				scene_state.get_node_property_count(idx)
			):
				if scene_state.get_node_property_name(
					idx, prop_idx
				) == &"script":
					script_res = scene_state.get_node_property_value(
						idx, prop_idx
					) as GDScript
					break
			if not script_res:
				continue
			var source: String = script_res.source_code
			var in_ready: bool = false
			for line: String in source.split("\n"):
				var stripped: String = line.strip_edges()
				if stripped.begins_with("func _ready("):
					in_ready = true
					continue
				if in_ready and stripped.begins_with("func "):
					break
				if in_ready and stripped.begins_with("await "):
					fail_test(
						"System '%s' uses await in _ready()"
						% system_name
					)
					break


func test_intra_tier_order_matches_scene() -> void:
	var scene_state: SceneState = GAME_WORLD_SCENE.get_state()
	var node_names: Array[StringName] = []
	for i: int in range(scene_state.get_node_count()):
		node_names.append(scene_state.get_node_name(i))

	for tier_idx: int in range(_all_tiers.size()):
		var prev_idx: int = -1
		for system_name: StringName in _all_tiers[tier_idx]:
			var idx: int = node_names.find(system_name)
			if idx < 0:
				continue
			if prev_idx >= 0:
				assert_gt(
					idx,
					prev_idx,
					"Tier %d: '%s' must come after previous system "
					% [tier_idx + 1, system_name]
					+ "in scene tree"
				)
			prev_idx = idx
