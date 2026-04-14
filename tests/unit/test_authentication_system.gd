## Tests AuthenticationSystem: eligibility, threshold, authentication, and signals.
extends GutTest


var _auth: AuthenticationSystem
var _inventory: InventorySystem
var _economy: EconomySystem


func _make_definition(
	base_price: float, store_type: String = "sports"
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "test_sports_item"
	def.item_name = "Test Sports Item"
	def.store_type = store_type
	def.base_price = base_price
	return def


func _make_item(
	def: ItemDefinition, location: String = "backroom"
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create_from_definition(def)
	item.current_location = location
	return item


func _register_item(item: ItemInstance) -> void:
	_inventory._items[item.instance_id] = item


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)
	_auth = AuthenticationSystem.new()
	_auth.initialize(_inventory, _economy)


func after_each() -> void:
	if EventBus.price_set.is_connected(_auth._on_price_set):
		EventBus.price_set.disconnect(_auth._on_price_set)


# --- test_authenticate_success ---


func test_authenticate_success() -> void:
	var def: ItemDefinition = _make_definition(150.0)
	var item: ItemInstance = _make_item(def)
	_register_item(item)

	var completed_ids: Array[String] = []
	var completed_success: Array[bool] = []
	var completed_msgs: Array[String] = []
	var capture: Callable = func(
		id: String, success: bool, msg: String
	) -> void:
		completed_ids.append(id)
		completed_success.append(success)
		completed_msgs.append(msg)
	EventBus.authentication_completed.connect(capture)

	var result: bool = _auth.authenticate(item.instance_id)

	EventBus.authentication_completed.disconnect(capture)
	assert_true(result, "authenticate should return true")
	assert_eq(
		completed_ids.size(), 1,
		"authentication_completed should fire once"
	)
	assert_true(
		completed_success[0],
		"Signal should carry success=true"
	)
	assert_eq(
		item.authentication_status, "authenticated",
		"Item status should be 'authenticated'"
	)


# --- test_insufficient_funds ---


func test_insufficient_funds() -> void:
	_economy.initialize(1.0)
	var def: ItemDefinition = _make_definition(150.0)
	var item: ItemInstance = _make_item(def)
	_register_item(item)

	var completed_success: Array[bool] = []
	var completed_msgs: Array[String] = []
	var capture: Callable = func(
		_id: String, success: bool, msg: String
	) -> void:
		completed_success.append(success)
		completed_msgs.append(msg)
	EventBus.authentication_completed.connect(capture)

	var result: bool = _auth.authenticate(item.instance_id)

	EventBus.authentication_completed.disconnect(capture)
	assert_false(
		result,
		"authenticate should return false with insufficient funds"
	)
	assert_eq(
		completed_success.size(), 1,
		"authentication_completed should fire once"
	)
	assert_false(
		completed_success[0],
		"Signal should carry success=false"
	)
	assert_true(
		completed_msgs[0].containsn("insufficient"),
		"Message should mention insufficient funds"
	)
	assert_eq(
		item.authentication_status, "none",
		"Item status should remain 'none'"
	)


# --- test_ineligible_store_type ---


func test_ineligible_store_type() -> void:
	var def: ItemDefinition = _make_definition(150.0, "retro_games")
	var item: ItemInstance = _make_item(def)
	_register_item(item)

	watch_signals(EventBus)
	var result: bool = _auth.authenticate(item.instance_id)

	assert_false(
		result,
		"authenticate should return false for non-sports item"
	)


# --- test_double_authenticate_no_op ---


func test_double_authenticate_no_op() -> void:
	var def: ItemDefinition = _make_definition(150.0)
	var item: ItemInstance = _make_item(def)
	_register_item(item)

	var first: bool = _auth.authenticate(item.instance_id)
	assert_true(first, "First authentication should succeed")

	var completed_count: Array = [0]
	var capture: Callable = func(
		_id: String, success: bool, _msg: String
	) -> void:
		completed_count[0] += 1
		if not success:
			completed_count[0] += 10
	EventBus.authentication_completed.connect(capture)

	var second: bool = _auth.authenticate(item.instance_id)

	EventBus.authentication_completed.disconnect(capture)
	assert_false(
		second,
		"Second authentication should return false"
	)


# --- test_needs_authentication_threshold ---


func test_needs_authentication_threshold() -> void:
	var def: ItemDefinition = _make_definition(150.0)
	var item: ItemInstance = _make_item(def)

	assert_true(
		_auth.needs_authentication(item, 150.0),
		"Should need auth when price > threshold"
	)
	assert_false(
		_auth.needs_authentication(item, 50.0),
		"Should not need auth when price <= threshold"
	)
	assert_false(
		_auth.needs_authentication(item, 100.0),
		"Should not need auth when price == threshold"
	)


# --- test_price_set_triggers_dialog_request ---


func test_price_set_triggers_dialog_request() -> void:
	var def: ItemDefinition = _make_definition(150.0)
	var item: ItemInstance = _make_item(def)
	_register_item(item)

	var requested_ids: Array[String] = []
	var capture: Callable = func(id: String) -> void:
		requested_ids.append(id)
	EventBus.authentication_dialog_requested.connect(capture)

	EventBus.price_set.emit(item.instance_id, 150.0)

	EventBus.authentication_dialog_requested.disconnect(capture)
	assert_eq(
		requested_ids.size(), 1,
		"Dialog should be requested once"
	)
	assert_eq(
		requested_ids[0], item.instance_id,
		"Dialog should be requested for the correct item"
	)


# --- test_price_set_below_threshold_no_dialog ---


func test_price_set_below_threshold_no_dialog() -> void:
	var def: ItemDefinition = _make_definition(50.0)
	var item: ItemInstance = _make_item(def)
	_register_item(item)

	var requested_ids: Array[String] = []
	var capture: Callable = func(id: String) -> void:
		requested_ids.append(id)
	EventBus.authentication_dialog_requested.connect(capture)

	EventBus.price_set.emit(item.instance_id, 50.0)

	EventBus.authentication_dialog_requested.disconnect(capture)
	assert_eq(
		requested_ids.size(), 0,
		"No dialog should be requested below threshold"
	)


# --- test_signals_use_canonical_ids ---


func test_signals_use_canonical_ids() -> void:
	var def: ItemDefinition = _make_definition(150.0)
	var item: ItemInstance = _make_item(def)
	_register_item(item)

	var emitted_ids: Array[String] = []
	var capture_started: Callable = func(
		id: String, _cost: float
	) -> void:
		emitted_ids.append(id)
	var capture_completed: Callable = func(
		id: String, _success: bool, _msg: String
	) -> void:
		emitted_ids.append(id)
	EventBus.authentication_started.connect(capture_started)
	EventBus.authentication_completed.connect(capture_completed)

	_auth.authenticate(item.instance_id)

	EventBus.authentication_started.disconnect(capture_started)
	EventBus.authentication_completed.disconnect(capture_completed)

	assert_eq(
		emitted_ids.size(), 2,
		"Should have started and completed signals"
	)
	for emitted_id: String in emitted_ids:
		assert_eq(
			emitted_id, item.instance_id,
			"Emitted ID should match the item's instance_id"
		)
		assert_false(
			emitted_id.is_empty(),
			"Emitted ID should not be empty"
		)
