## Unit tests for ElectronicsLifecycleManager phase transitions and demo degradation.
extends GutTest


var _manager: ElectronicsLifecycleManager
var _phase_changed_args: Array[Dictionary] = []
var _decline_item_ids: Array[String] = []
var _clearance_item_ids: Array[String] = []


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


func _on_product_entered_decline(item_id: String) -> void:
	_decline_item_ids.append(item_id)


func _on_product_entered_clearance(item_id: String) -> void:
	_clearance_item_ids.append(item_id)


func before_each() -> void:
	_manager = ElectronicsLifecycleManager.new()
	_phase_changed_args.clear()
	_decline_item_ids.clear()
	_clearance_item_ids.clear()
	EventBus.electronics_phase_changed.connect(_on_phase_changed)
	EventBus.product_entered_decline.connect(_on_product_entered_decline)
	EventBus.product_entered_clearance.connect(_on_product_entered_clearance)


func after_each() -> void:
	if EventBus.electronics_phase_changed.is_connected(_on_phase_changed):
		EventBus.electronics_phase_changed.disconnect(_on_phase_changed)
	if EventBus.product_entered_decline.is_connected(_on_product_entered_decline):
		EventBus.product_entered_decline.disconnect(_on_product_entered_decline)
	if EventBus.product_entered_clearance.is_connected(_on_product_entered_clearance):
		EventBus.product_entered_clearance.disconnect(_on_product_entered_clearance)


func test_initialize_sets_peak_phase() -> void:
	var def: ItemDefinition = _make_definition("phone", 1, 1)
	var items: Array[ItemDefinition] = [def]
	_manager.initialize(items, 1)

	var phase: String = _manager.get_phase_name(def, 1)

	assert_eq(phase, "peak", "Item should be in peak phase on day 1")


func test_phase_transitions_to_decline_after_threshold() -> void:
	var def: ItemDefinition = _make_definition("phone", 1, 1)
	var items: Array[ItemDefinition] = [def]
	_manager.initialize(items, 1)

	var day: int = 1 + ElectronicsLifecycleManager.PEAK_END_DAY + 1
	var phase: String = _manager.get_phase_name(def, day)

	assert_eq(phase, "decline", "Item should be in decline after the threshold day")


func test_clearance_phase_after_decline_threshold() -> void:
	var def: ItemDefinition = _make_definition("phone", 1, 1)
	var items: Array[ItemDefinition] = [def]
	_manager.initialize(items, 1)

	var day: int = 1 + ElectronicsLifecycleManager.MATURE_END_DAY + 1
	var phase: String = _manager.get_phase_name(def, day)

	assert_eq(
		phase, "clearance",
		"Item should be in clearance phase after the decline threshold"
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

	var decline_day: int = 1 + ElectronicsLifecycleManager.PEAK_END_DAY + 1
	_manager.check_phase_transitions(items, decline_day)

	assert_eq(
		_phase_changed_args.size(), 1,
		"Crossing the phase boundary should emit one generic phase change"
	)
	assert_eq(
		_phase_changed_args[0]["item_id"], def.id,
		"Signal should carry the correct item_id"
	)
	assert_eq(
		_phase_changed_args[0]["old_phase"], "peak",
		"Signal should carry old phase"
	)
	assert_eq(
		_phase_changed_args[0]["new_phase"], "decline",
		"Signal should carry new phase"
	)
	assert_eq(
		_decline_item_ids,
		[def.id],
		"product_entered_decline should fire when the item enters decline"
	)
	assert_eq(
		_clearance_item_ids.size(),
		0,
		"clearance signal should not fire on a decline transition"
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
