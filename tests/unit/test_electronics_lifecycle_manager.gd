## Unit tests for ElectronicsLifecycleManager phase transitions and demo degradation.
extends GutTest


var _manager: ElectronicsLifecycleManager
var _phase_changed_args: Array[Dictionary] = []


func _make_definition(
	product_line: String = "test_phone",
	generation: int = 1,
	launch_day: int = 1
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "%s_gen%d" % [product_line, generation]
	def.item_name = "Test Electronics Item"
	def.store_type = "consumer_electronics"
	def.base_price = 100.0
	def.product_line = product_line
	def.generation = generation
	def.launch_day = launch_day
	return def


func _make_instance(
	def: ItemDefinition, cond: String = "mint"
) -> ItemInstance:
	return ItemInstance.create_from_definition(def, cond)


func _on_phase_changed(
	item_id: String, old_phase: String, new_phase: String
) -> void:
	_phase_changed_args.append({
		"item_id": item_id,
		"old_phase": old_phase,
		"new_phase": new_phase,
	})


func before_each() -> void:
	_manager = ElectronicsLifecycleManager.new()
	_phase_changed_args.clear()
	EventBus.electronics_phase_changed.connect(_on_phase_changed)


func after_each() -> void:
	if EventBus.electronics_phase_changed.is_connected(_on_phase_changed):
		EventBus.electronics_phase_changed.disconnect(_on_phase_changed)


func test_initialize_sets_launch_phase() -> void:
	var def: ItemDefinition = _make_definition("phone", 1, 1)
	var items: Array[ItemDefinition] = [def]
	_manager.initialize(items, 1)

	var phase: String = _manager.get_phase_name(def, 1)

	assert_eq(phase, "launch", "Item should be in launch phase on day 1")


func test_phase_transitions_to_peak_after_launch() -> void:
	var def: ItemDefinition = _make_definition("phone", 1, 1)
	var items: Array[ItemDefinition] = [def]
	_manager.initialize(items, 1)

	var day: int = 1 + ElectronicsLifecycleManager.LAUNCH_END_DAY + 1
	var phase: String = _manager.get_phase_name(def, day)

	assert_eq(phase, "peak", "Item should be in peak phase after launch ends")


func test_phase_transitions_to_mature_after_peak() -> void:
	var def: ItemDefinition = _make_definition("phone", 1, 1)
	var items: Array[ItemDefinition] = [def]
	_manager.initialize(items, 1)

	var day: int = 1 + ElectronicsLifecycleManager.PEAK_END_DAY + 1
	var phase: String = _manager.get_phase_name(def, day)

	assert_eq(
		phase, "mature",
		"Item should be in mature phase after peak threshold"
	)


func test_clearance_phase_after_mature_threshold() -> void:
	var def: ItemDefinition = _make_definition("phone", 1, 1)
	var items: Array[ItemDefinition] = [def]
	_manager.initialize(items, 1)

	var day: int = 1 + ElectronicsLifecycleManager.MATURE_END_DAY + 1
	var phase: String = _manager.get_phase_name(def, day)

	assert_eq(
		phase, "clearance",
		"Item should be in clearance phase after mature threshold"
	)


func test_check_phase_transitions_emits_event() -> void:
	var def: ItemDefinition = _make_definition("phone", 1, 1)
	var items: Array[ItemDefinition] = [def]
	_manager.initialize(items, 1)

	_manager.check_phase_transitions(items, 1)
	assert_eq(
		_phase_changed_args.size(), 0,
		"First call seeds phase tracking — no signal expected"
	)

	var clearance_day: int = 1 + ElectronicsLifecycleManager.MATURE_END_DAY + 1
	_manager.check_phase_transitions(items, clearance_day)

	assert_eq(
		_phase_changed_args.size(), 1,
		"Phase change from launch to clearance should emit one signal"
	)
	assert_eq(
		_phase_changed_args[0]["item_id"], def.id,
		"Signal should carry the correct item_id"
	)
	assert_eq(
		_phase_changed_args[0]["old_phase"], "launch",
		"Signal should carry old phase"
	)
	assert_eq(
		_phase_changed_args[0]["new_phase"], "clearance",
		"Signal should carry new phase"
	)


func test_demo_unit_condition_degrades() -> void:
	var def: ItemDefinition = _make_definition()
	var item: ItemInstance = _make_instance(def, "mint")

	var result: String = _manager.degrade_demo_unit(item)

	assert_eq(result, "near_mint", "Degraded mint should become near_mint")
	assert_eq(
		item.condition, "near_mint",
		"Item condition should be updated in place"
	)


func test_already_poor_demo_unit_not_degraded_further() -> void:
	var def: ItemDefinition = _make_definition()
	var item: ItemInstance = _make_instance(def, "poor")

	var result: String = _manager.degrade_demo_unit(item)

	assert_eq(result, "poor", "Poor condition should not degrade further")
	assert_eq(
		item.condition, "poor",
		"Item condition should remain poor"
	)
