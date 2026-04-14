## Unit tests for MetaShiftSystem shift detection, demand modifiers, expiration, and signals.
extends GutTest


var _system: MetaShiftSystem


func before_each() -> void:
	_system = MetaShiftSystem.new()
	add_child_autofree(_system)


func _make_card_definition(
	id: String, set_tag: String = "base_set"
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = id.capitalize()
	def.store_type = MetaShiftSystem.STORE_TYPE
	def.category = MetaShiftSystem.CARD_CATEGORY
	def.tags = PackedStringArray([set_tag])
	def.base_price = 5.0
	return def


func _make_card_instance(
	id: String, set_tag: String = "base_set"
) -> ItemInstance:
	var def: ItemDefinition = _make_card_definition(id, set_tag)
	return ItemInstance.create_from_definition(def)


func _activate_shift_state(
	rising_id: String, rising_mult: float = 2.5
) -> void:
	var save_data: Dictionary = {
		"rising_cards": [
			{
				"item_id": rising_id,
				"name": rising_id.capitalize(),
				"multiplier": rising_mult,
				"set_tag": "base_set",
			}
		],
		"falling_cards": [
			{
				"item_id": "falling_card",
				"name": "Falling Card",
				"multiplier": MetaShiftSystem.DROP_MULT,
				"set_tag": "jungle",
			}
		],
		"active_day": 5,
		"announced_day": 3,
		"days_until_next_announcement": 8,
		"shift_active": true,
	}
	_system.load_save_data(save_data)


func test_no_active_shift_on_init() -> void:
	_system._apply_state({})
	assert_false(
		_system.is_shift_active(),
		"Fresh instance should have no active shift"
	)
	assert_eq(
		_system.get_rising_cards().size(), 0,
		"Fresh instance should have no rising cards"
	)
	assert_eq(
		_system.get_falling_cards().size(), 0,
		"Fresh instance should have no falling cards"
	)


func test_trigger_shift_marks_active() -> void:
	_activate_shift_state("hot_card")
	assert_true(
		_system.is_shift_active(),
		"Shift should be active after loading active state"
	)
	assert_gt(
		_system.get_rising_cards().size(), 0,
		"Should have at least one rising card"
	)


func test_active_shift_returns_modifier() -> void:
	var mult: float = 2.5
	_activate_shift_state("hot_card", mult)
	var item: ItemInstance = _make_card_instance("hot_card")
	var result: float = _system.get_meta_shift_multiplier(item)
	assert_almost_eq(
		result, mult, 0.01,
		"Rising card should return its assigned multiplier"
	)


func test_non_shifted_card_returns_base_modifier() -> void:
	_activate_shift_state("hot_card")
	var item: ItemInstance = _make_card_instance("unrelated_card", "fossil")
	var result: float = _system.get_meta_shift_multiplier(item)
	assert_almost_eq(
		result, 1.0, 0.01,
		"Non-shifted card should return base modifier of 1.0"
	)


func test_shift_expires_after_duration() -> void:
	var save_data: Dictionary = {
		"rising_cards": [
			{
				"item_id": "hot_card",
				"name": "Hot Card",
				"multiplier": 2.5,
				"set_tag": "base_set",
			}
		],
		"falling_cards": [],
		"active_day": 5,
		"announced_day": 3,
		"days_until_next_announcement": 1,
		"shift_active": true,
	}
	_system.load_save_data(save_data)
	assert_true(
		_system.is_shift_active(),
		"Shift should be active before expiration"
	)
	_system._on_day_started(10)
	assert_false(
		_system.is_shift_active(),
		"Shift should expire when a new announcement triggers"
	)
	assert_eq(
		_system.get_rising_cards().size(), 0,
		"Rising cards should be cleared after expiration"
	)


func test_meta_shift_started_signal() -> void:
	var save_data: Dictionary = {
		"rising_cards": [
			{
				"item_id": "hot_card",
				"name": "Hot Card",
				"multiplier": 2.5,
				"set_tag": "base_set",
			}
		],
		"falling_cards": [
			{
				"item_id": "cold_card",
				"name": "Cold Card",
				"multiplier": MetaShiftSystem.DROP_MULT,
				"set_tag": "jungle",
			}
		],
		"active_day": 5,
		"announced_day": 3,
		"days_until_next_announcement": 99,
		"shift_active": false,
	}
	_system.load_save_data(save_data)
	watch_signals(EventBus)
	_system._on_day_started(5)
	assert_signal_emitted(
		EventBus, "meta_shift_activated",
		"meta_shift_activated should fire when shift activates"
	)
	var params: Array = get_signal_parameters(
		EventBus, "meta_shift_activated"
	)
	assert_eq(
		(params[0] as Array).size(), 1,
		"Signal should carry rising card names"
	)
	assert_eq(
		(params[1] as Array).size(), 1,
		"Signal should carry falling card names"
	)


func test_meta_shift_ended_signal() -> void:
	var save_data: Dictionary = {
		"rising_cards": [
			{
				"item_id": "hot_card",
				"name": "Hot Card",
				"multiplier": 2.5,
				"set_tag": "base_set",
			}
		],
		"falling_cards": [],
		"active_day": 5,
		"announced_day": 3,
		"days_until_next_announcement": 1,
		"shift_active": true,
	}
	_system.load_save_data(save_data)
	watch_signals(EventBus)
	_system._on_day_started(10)
	assert_signal_emitted(
		EventBus, "meta_shift_ended",
		"meta_shift_ended should fire when shift expires"
	)
