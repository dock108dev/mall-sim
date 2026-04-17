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
	&"QueueSystem",
	&"ProgressionSystem",
	&"MilestoneSystem",
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
	&"DayCycleController",
	&"SaveManager",
]

var _all_tiers: Array[Array] = []
var _expected_script_paths: Dictionary = {}


func before_all() -> void:
	_all_tiers = [
		TIER_1_SYSTEMS, TIER_2_SYSTEMS, TIER_3_SYSTEMS,
		TIER_4_SYSTEMS, TIER_5_SYSTEMS,
	]
	_expected_script_paths = {
		&"TimeSystem": "res://game/scripts/systems/time_system.gd",
		&"EconomySystem": "res://game/scripts/systems/economy_system.gd",
		&"InventorySystem": "res://game/scripts/systems/inventory_system.gd",
		&"StoreStateManager": "res://game/scripts/systems/store_state_manager.gd",
		&"TrendSystem": "res://game/scripts/systems/trend_system.gd",
		&"MarketEventSystem": "res://game/scripts/systems/market_event_system.gd",
		&"SeasonalEventSystem": "res://game/scripts/systems/seasonal_event_system.gd",
		&"MarketValueSystem": "res://game/scripts/systems/market_value_system.gd",
		&"CustomerSystem": "res://game/scripts/systems/customer_system.gd",
		&"MallCustomerSpawner": "res://game/scripts/systems/mall_customer_spawner.gd",
		&"NPCSpawnerSystem": "res://game/scripts/systems/npc_spawner_system.gd",
		&"HaggleSystem": "res://game/scripts/systems/haggle_system.gd",
		&"CheckoutSystem": "res://game/scripts/systems/checkout_system.gd",
		&"QueueSystem": "res://game/scripts/systems/queue_system.gd",
		&"ProgressionSystem": "res://game/scripts/systems/progression_system.gd",
		&"MilestoneSystem": "res://game/scripts/systems/milestone_system.gd",
		&"OrderSystem": "res://game/scripts/systems/order_system.gd",
		&"StaffSystem": "res://game/scripts/systems/staff_system.gd",
		&"StoreSelectorSystem": "res://game/scripts/systems/store_selector_system.gd",
		&"BuildModeSystem": "res://game/scripts/systems/build_mode_system.gd",
		&"FixturePlacementSystem": "res://game/scripts/systems/fixture_placement_system.gd",
		&"TournamentSystem": "res://game/scripts/systems/tournament_system.gd",
		&"MetaShiftSystem": "res://game/scripts/systems/meta_shift_system.gd",
		&"TutorialSystem": "res://game/scripts/systems/tutorial_system.gd",
		&"PerformanceManager": "res://game/scripts/systems/performance_manager.gd",
		&"PerformanceReportSystem": "res://game/scripts/systems/performance_report_system.gd",
		&"RandomEventSystem": "res://game/scripts/systems/random_event_system.gd",
		&"SecretThreadManager": "res://game/scripts/systems/secret_thread_manager.gd",
		&"SecretThreadSystem": "res://game/scripts/systems/secret_thread_system.gd",
		&"AmbientMomentsSystem": "res://game/scripts/systems/ambient_moments_system.gd",
		&"EndingEvaluatorSystem": "res://game/scripts/systems/ending_evaluator.gd",
		&"StoreUpgradeSystem": "res://game/scripts/systems/store_upgrade_system.gd",
		&"CompletionTracker": "res://game/scripts/systems/completion_tracker.gd",
		&"DayCycleController": "res://game/scripts/systems/day_cycle_controller.gd",
		&"SaveManager": "res://game/scripts/core/save_manager.gd",
	}


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


func test_system_scripts_match_expected_paths() -> void:
	var scene_state: SceneState = GAME_WORLD_SCENE.get_state()
	var node_names: Array[StringName] = []
	for i: int in range(scene_state.get_node_count()):
		node_names.append(scene_state.get_node_name(i))

	for system_name: StringName in _expected_script_paths.keys():
		var idx: int = node_names.find(system_name)
		assert_ne(idx, -1, "System '%s' must exist in game_world.tscn" % system_name)
		var script_path: String = ""
		for prop_idx: int in range(scene_state.get_node_property_count(idx)):
			if scene_state.get_node_property_name(idx, prop_idx) == &"script":
				var script_res: GDScript = scene_state.get_node_property_value(
					idx, prop_idx
				) as GDScript
				if script_res:
					script_path = script_res.resource_path
				break
		assert_eq(
			script_path,
			_expected_script_paths[system_name],
			"System '%s' must point at the expected script" % system_name
		)


func test_game_world_has_initialize_systems_method() -> void:
	var scene_state: SceneState = GAME_WORLD_SCENE.get_state()
	var script_path: Array = [""]
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
				script_path[0] = res.resource_path
			break

	assert_ne(script_path[0], "", "GameWorld root must have a script")
	var gd_script: GDScript = load(script_path[0]) as GDScript
	assert_not_null(gd_script, "GameWorld script must be loadable")
	var methods: Array[Dictionary] = gd_script.get_script_method_list()
	var has_init: Array = [false]
	for m: Dictionary in methods:
		if m.get("name", "") == "initialize_systems":
			has_init[0] = true
			break
	assert_true(
		has_init[0],
		"GameWorld must expose initialize_systems() method"
	)


func test_total_system_count() -> void:
	var total: Array = [0]
	for tier: Array in _all_tiers:
		total[0] += tier.size()
	assert_eq(
		total[0],
		35,
		"Expected 35 system nodes across all tiers, got %d" % total[0]
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
			var found_await: bool = false
			for line: String in source.split("\n"):
				var stripped: String = line.strip_edges()
				if stripped.begins_with("func _ready("):
					in_ready = true
					continue
				if in_ready and stripped.begins_with("func "):
					break
				if in_ready and stripped.begins_with("await "):
					found_await = true
					break
			assert_false(
				found_await,
				"System '%s' uses await in _ready()" % system_name
			)


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
