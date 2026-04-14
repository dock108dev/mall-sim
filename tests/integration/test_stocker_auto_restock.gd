## Integration test: STOCKER auto-restock loop — assign stocker → empty shelf → restock timer → shelf filled.
extends GutTest

const STORE_ID: String = "test_stocker_store"
const STORE_TYPE: String = "test_stocker_store"
const ITEM_DEF_ID: String = "item_retro_game_001"

var _staff: StaffSystem
var _inventory: InventorySystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _stocker_def: StaffDefinition
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

	GameManager.current_store_id = &"test_stocker_store"


func after_each() -> void:
	GameManager.current_store_id = &""
	_unregister_store_from_content_registry()


# ── Scenario A — stocker restocks one empty slot per timer cycle ──────────────


func test_scenario_a_timer_starts_after_stocker_hired() -> void:
	_seed_backroom_with_item()

	var result: Dictionary = _staff.hire_staff("test_stocker_001", STORE_ID)
	assert_false(result.is_empty(), "hire_staff must return non-empty dict for a valid STOCKER")

	var timer: Timer = _get_stocker_timer()
	assert_not_null(timer, "A restock timer must be created when a STOCKER is assigned")
	assert_false(
		timer.is_stopped(),
		"Restock timer must be running immediately after STOCKER hire"
	)


func test_scenario_a_restock_emits_staff_restocked_shelf() -> void:
	watch_signals(EventBus)
	_seed_backroom_with_item()
	var result: Dictionary = _staff.hire_staff("test_stocker_001", STORE_ID)
	assert_false(result.is_empty(), "Precondition: hire must succeed")

	_fire_restock_timer()

	assert_signal_emitted(
		EventBus,
		"staff_restocked_shelf",
		"staff_restocked_shelf must fire after one timer cycle with backroom stock available"
	)


func test_scenario_a_restock_signal_carries_correct_staff_id() -> void:
	watch_signals(EventBus)
	_seed_backroom_with_item()
	var result: Dictionary = _staff.hire_staff("test_stocker_001", STORE_ID)
	var expected_staff_id: String = result.get("instance_id", "")

	_fire_restock_timer()

	var params: Array = get_signal_parameters(EventBus, "staff_restocked_shelf")
	assert_eq(
		params[0] as String,
		expected_staff_id,
		"staff_restocked_shelf first param must be the hired stocker's instance_id"
	)


func test_scenario_a_restock_signal_carries_correct_item_id() -> void:
	watch_signals(EventBus)
	_seed_backroom_with_item()
	_staff.hire_staff("test_stocker_001", STORE_ID)

	_fire_restock_timer()

	var params: Array = get_signal_parameters(EventBus, "staff_restocked_shelf")
	assert_eq(
		params[1] as String,
		ITEM_DEF_ID,
		"staff_restocked_shelf second param must be the restocked item definition id"
	)


func test_scenario_a_shelf_slot_populated_after_restock() -> void:
	var item: ItemInstance = _seed_backroom_with_item()
	_staff.hire_staff("test_stocker_001", STORE_ID)

	_fire_restock_timer()

	var shelf_items: Array[ItemInstance] = _inventory.get_shelf_items_for_store(STORE_TYPE)
	assert_eq(shelf_items.size(), 1, "Shelf must have exactly one item after stocker restock")
	assert_eq(
		shelf_items[0].instance_id,
		item.instance_id,
		"Shelf item must be the same instance that was in the backroom"
	)


func test_scenario_a_backroom_count_decremented_after_restock() -> void:
	_seed_backroom_with_item()
	_staff.hire_staff("test_stocker_001", STORE_ID)

	_fire_restock_timer()

	var backroom: Array[ItemInstance] = _inventory.get_backroom_items_for_store(STORE_TYPE)
	assert_eq(
		backroom.size(),
		0,
		"Backroom count must be 0 after the stocker moves the only item to the shelf"
	)


# ── Scenario B — stocker does not restock when backroom is empty ──────────────


func test_scenario_b_no_signal_when_backroom_empty() -> void:
	_staff.hire_staff("test_stocker_001", STORE_ID)
	watch_signals(EventBus)

	_fire_restock_timer()

	assert_signal_not_emitted(
		EventBus,
		"staff_restocked_shelf",
		"staff_restocked_shelf must not fire when backroom has zero stock"
	)


func test_scenario_b_shelf_remains_empty_when_backroom_empty() -> void:
	_staff.hire_staff("test_stocker_001", STORE_ID)

	_fire_restock_timer()

	var shelf_items: Array[ItemInstance] = _inventory.get_shelf_items_for_store(STORE_TYPE)
	assert_eq(
		shelf_items.size(),
		0,
		"Shelf must remain empty when there is nothing in the backroom to restock"
	)


# ── Scenario C — restock timer stops when stocker is fired ───────────────────


func test_scenario_c_timer_stopped_after_stocker_fired() -> void:
	_staff.hire_staff("test_stocker_001", STORE_ID)
	var timer_before: Timer = _get_stocker_timer()
	assert_not_null(timer_before, "Precondition: timer must exist after hire")
	assert_false(timer_before.is_stopped(), "Precondition: timer must be running before fire")

	var staff_entries: Array[Dictionary] = _staff.get_staff_for_store(STORE_ID)
	assert_eq(staff_entries.size(), 1, "Precondition: one staff member must be hired")
	var staff_id: String = staff_entries[0].get("instance_id", "")

	_staff.fire_staff(staff_id, STORE_ID)

	var stocker_behavior: StockerBehavior = _staff._stocker_behavior
	assert_false(
		stocker_behavior._timers.has(STORE_ID),
		"Restock timer must be stopped and removed when the stocker is fired"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _seed_backroom_with_item() -> ItemInstance:
	var item: ItemInstance = ItemInstance.create(_item_def, "good", 0, 5.0)
	item.current_location = "backroom"
	_inventory.register_item(item)
	return item


func _fire_restock_timer() -> void:
	var stocker_behavior: StockerBehavior = _staff._stocker_behavior
	stocker_behavior._on_timer_fire(STORE_ID)


func _get_stocker_timer() -> Timer:
	var stocker_behavior: StockerBehavior = _staff._stocker_behavior
	return stocker_behavior._timers.get(STORE_ID) as Timer


func _register_test_data() -> void:
	_stocker_def = StaffDefinition.new()
	_stocker_def.staff_id = "test_stocker_001"
	_stocker_def.display_name = "Test Stocker"
	_stocker_def.role = StaffDefinition.StaffRole.STOCKER
	_stocker_def.skill_level = 2
	_stocker_def.morale = 1.0
	_stocker_def.daily_wage = 30.0
	_data_loader._staff_definitions["test_stocker_001"] = _stocker_def

	_item_def = ItemDefinition.new()
	_item_def.id = ITEM_DEF_ID
	_item_def.item_name = "Test Retro Game"
	_item_def.store_type = STORE_TYPE
	_item_def.base_price = 5.0
	_item_def.rarity = "common"
	_item_def.condition_range = PackedStringArray(["poor", "fair", "good"])
	_data_loader._items[ITEM_DEF_ID] = _item_def

	var store_def := StoreDefinition.new()
	store_def.id = STORE_ID
	store_def.store_name = "Test Stocker Store"
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
			"name": "Test Stocker Store",
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
