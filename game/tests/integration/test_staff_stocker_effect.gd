## Integration test: Staff stocker role — hire → auto-restock timer fires and staff_restocked_shelf emitted.
extends GutTest

const STORE_ID: String = "test_stocker_effect_store"
const STORE_TYPE: String = "test_stocker_effect_store"
const ITEM_DEF_ID: String = "item_stocker_effect_test_001"
const FLOAT_EPSILON: float = 0.05

var _staff: StaffSystem
var _inventory: InventorySystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _item_def: ItemDefinition


func before_each() -> void:
	_register_store_in_content_registry()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)
	_reputation.add_reputation(STORE_ID, 50.0)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_data()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, _inventory, _data_loader)

	GameManager.current_store_id = &STORE_ID


func after_each() -> void:
	GameManager.current_store_id = &""
	_unregister_store_from_content_registry()


# ── Scenario A — skill 1 stocker: timer interval = 90s ───────────────────────


func test_scenario_a_skill1_stocker_timer_interval_is_90s() -> void:
	var result: Dictionary = _staff.hire_staff("test_stocker_sk1", STORE_ID)
	assert_false(result.is_empty(), "Precondition: hire_staff must succeed for skill 1 stocker")

	var timer: Timer = _get_stocker_timer()
	assert_not_null(timer, "Restock timer must exist after hiring a skill 1 stocker")
	# StockerBehavior.SKILL_BASE_INTERVALS[1] = 90.0; morale=1.0 gives perf_mult=1.0
	assert_almost_eq(
		timer.wait_time,
		90.0,
		FLOAT_EPSILON,
		"Skill 1 stocker timer interval must be 90s (BASE_INTERVAL[1] / perf_mult=1.0)"
	)


# ── Scenario B — skill 2 stocker: timer interval = 60s ───────────────────────


func test_scenario_b_skill2_stocker_timer_interval_is_60s() -> void:
	var result: Dictionary = _staff.hire_staff("test_stocker_sk2", STORE_ID)
	assert_false(result.is_empty(), "Precondition: hire_staff must succeed for skill 2 stocker")

	var timer: Timer = _get_stocker_timer()
	assert_not_null(timer, "Restock timer must exist after hiring a skill 2 stocker")
	# StockerBehavior.SKILL_BASE_INTERVALS[2] = 60.0; morale=1.0 gives perf_mult=1.0
	assert_almost_eq(
		timer.wait_time,
		60.0,
		FLOAT_EPSILON,
		"Skill 2 stocker timer interval must be 60s (BASE_INTERVAL[2] / perf_mult=1.0)"
	)


# ── Scenario C — skill 3 stocker: timer interval = 45s ───────────────────────


func test_scenario_c_skill3_stocker_timer_interval_is_45s() -> void:
	var result: Dictionary = _staff.hire_staff("test_stocker_sk3", STORE_ID)
	assert_false(result.is_empty(), "Precondition: hire_staff must succeed for skill 3 stocker")

	var timer: Timer = _get_stocker_timer()
	assert_not_null(timer, "Restock timer must exist after hiring a skill 3 stocker")
	# StockerBehavior.SKILL_BASE_INTERVALS[3] = 45.0; morale=1.0 gives perf_mult=1.0
	assert_almost_eq(
		timer.wait_time,
		45.0,
		FLOAT_EPSILON,
		"Skill 3 stocker timer interval must be 45s (BASE_INTERVAL[3] / perf_mult=1.0)"
	)


# ── Scenario D — restock timer fires → staff_restocked_shelf emitted ─────────


func test_scenario_d_restock_emits_staff_restocked_shelf() -> void:
	watch_signals(EventBus)
	_seed_backroom_with_item()
	var result: Dictionary = _staff.hire_staff("test_stocker_sk1", STORE_ID)
	assert_false(result.is_empty(), "Precondition: hire must succeed")

	_fire_restock_timer()

	assert_signal_emitted(
		EventBus,
		"staff_restocked_shelf",
		"staff_restocked_shelf must fire after timer cycle with backroom stock available"
	)


func test_scenario_d_restock_signal_carries_correct_staff_id() -> void:
	watch_signals(EventBus)
	_seed_backroom_with_item()
	var result: Dictionary = _staff.hire_staff("test_stocker_sk1", STORE_ID)
	var expected_id: String = result.get("instance_id", "")

	_fire_restock_timer()

	var params: Array = get_signal_parameters(EventBus, "staff_restocked_shelf")
	assert_eq(
		params[0] as String,
		expected_id,
		"staff_restocked_shelf first param must be the stocker's instance_id"
	)


func test_scenario_d_restock_signal_carries_valid_item_id() -> void:
	watch_signals(EventBus)
	_seed_backroom_with_item()
	_staff.hire_staff("test_stocker_sk1", STORE_ID)

	_fire_restock_timer()

	var params: Array = get_signal_parameters(EventBus, "staff_restocked_shelf")
	assert_eq(
		params[1] as String,
		ITEM_DEF_ID,
		"staff_restocked_shelf second param must be a valid item_id from the store's inventory"
	)


# ── Scenario E — no stocker assigned: no auto-restock timer running ───────────


func test_scenario_e_no_stocker_assigned_no_timer_running() -> void:
	var stocker_behavior: StockerBehavior = _staff._stocker_behavior
	assert_false(
		stocker_behavior._timers.has(STORE_ID),
		"No restock timer must exist when no stocker has been assigned to the store"
	)


func test_scenario_e_no_signal_when_no_stocker_assigned() -> void:
	watch_signals(EventBus)
	_seed_backroom_with_item()

	_fire_restock_timer()

	assert_signal_not_emitted(
		EventBus,
		"staff_restocked_shelf",
		"staff_restocked_shelf must not fire when no stocker is assigned"
	)


# ── Scenario F — fire stocker: timer stops; no further emissions ──────────────


func test_scenario_f_fire_stocker_timer_removed() -> void:
	_staff.hire_staff("test_stocker_sk1", STORE_ID)
	assert_not_null(_get_stocker_timer(), "Precondition: timer must exist after hire")

	var staff_entries: Array[Dictionary] = _staff.get_staff_for_store(STORE_ID)
	assert_eq(staff_entries.size(), 1, "Precondition: exactly one staff member hired")
	var staff_id: String = staff_entries[0].get("instance_id", "")
	_staff.fire_staff(staff_id, STORE_ID)

	var stocker_behavior: StockerBehavior = _staff._stocker_behavior
	assert_false(
		stocker_behavior._timers.has(STORE_ID),
		"Restock timer must be removed immediately after stocker is fired"
	)


func test_scenario_f_no_restock_signal_after_stocker_fired() -> void:
	_seed_backroom_with_item()
	_staff.hire_staff("test_stocker_sk1", STORE_ID)

	var staff_entries: Array[Dictionary] = _staff.get_staff_for_store(STORE_ID)
	var staff_id: String = staff_entries[0].get("instance_id", "")
	_staff.fire_staff(staff_id, STORE_ID)

	watch_signals(EventBus)
	# Direct invocation after firing: _on_timer_fire exits early because
	# _active_stockers no longer has STORE_ID, so no signal is emitted.
	_fire_restock_timer()

	assert_signal_not_emitted(
		EventBus,
		"staff_restocked_shelf",
		"staff_restocked_shelf must not fire after the stocker has been fired"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _seed_backroom_with_item() -> ItemInstance:
	var item: ItemInstance = ItemInstance.create(_item_def, "good", 0, 5.0)
	item.current_location = "backroom"
	_inventory.register_item(item)
	return item


func _fire_restock_timer() -> void:
	# Direct method invocation avoids real-time Timer delays in tests.
	var stocker_behavior: StockerBehavior = _staff._stocker_behavior
	stocker_behavior._on_timer_fire(STORE_ID)


func _get_stocker_timer() -> Timer:
	var stocker_behavior: StockerBehavior = _staff._stocker_behavior
	return stocker_behavior._timers.get(STORE_ID) as Timer


func _register_test_data() -> void:
	var sk1_def: StaffDefinition = StaffDefinition.new()
	sk1_def.staff_id = "test_stocker_sk1"
	sk1_def.display_name = "Test Stocker Skill 1"
	sk1_def.role = StaffDefinition.StaffRole.STOCKER
	sk1_def.skill_level = 1
	sk1_def.morale = 1.0
	sk1_def.daily_wage = 20.0
	_data_loader._staff_definitions["test_stocker_sk1"] = sk1_def

	var sk2_def: StaffDefinition = StaffDefinition.new()
	sk2_def.staff_id = "test_stocker_sk2"
	sk2_def.display_name = "Test Stocker Skill 2"
	sk2_def.role = StaffDefinition.StaffRole.STOCKER
	sk2_def.skill_level = 2
	sk2_def.morale = 1.0
	sk2_def.daily_wage = 25.0
	_data_loader._staff_definitions["test_stocker_sk2"] = sk2_def

	var sk3_def: StaffDefinition = StaffDefinition.new()
	sk3_def.staff_id = "test_stocker_sk3"
	sk3_def.display_name = "Test Stocker Skill 3"
	sk3_def.role = StaffDefinition.StaffRole.STOCKER
	sk3_def.skill_level = 3
	sk3_def.morale = 1.0
	sk3_def.daily_wage = 30.0
	_data_loader._staff_definitions["test_stocker_sk3"] = sk3_def

	_item_def = ItemDefinition.new()
	_item_def.id = ITEM_DEF_ID
	_item_def.item_name = "Test Stocker Effect Item"
	_item_def.store_type = STORE_TYPE
	_item_def.base_price = 5.0
	_item_def.rarity = "common"
	_item_def.condition_range = PackedStringArray(["poor", "fair", "good"])
	_data_loader._items[ITEM_DEF_ID] = _item_def

	var store_def: StoreDefinition = StoreDefinition.new()
	store_def.id = STORE_ID
	store_def.store_name = "Test Stocker Effect Store"
	store_def.store_type = STORE_TYPE
	store_def.shelf_capacity = 10
	store_def.backroom_capacity = 20
	_data_loader._stores[STORE_ID] = store_def


func _register_store_in_content_registry() -> void:
	if ContentRegistry.exists(STORE_TYPE):
		return
	ContentRegistry.register_entry(
		{
			"id": STORE_TYPE,
			"name": "Test Stocker Effect Store",
			"scene_path": "",
			"backroom_capacity": 20,
		},
		"store"
	)


func _unregister_store_from_content_registry() -> void:
	if not ContentRegistry.exists(STORE_TYPE):
		return
	var entries: Dictionary = ContentRegistry._entries
	var aliases: Dictionary = ContentRegistry._aliases
	var types: Dictionary = ContentRegistry._types
	var display_names: Dictionary = ContentRegistry._display_names
	var scene_map: Dictionary = ContentRegistry._scene_map
	entries.erase(StringName(STORE_TYPE))
	types.erase(StringName(STORE_TYPE))
	display_names.erase(StringName(STORE_TYPE))
	scene_map.erase(StringName(STORE_TYPE))
	var canonical_key: StringName = StringName(STORE_TYPE)
	for key: StringName in aliases.keys():
		if aliases[key] == canonical_key:
			aliases.erase(key)
