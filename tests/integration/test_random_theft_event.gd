## Integration test: random theft event chain — shoplifting event fires →
## item removed from InventorySystem → signals emitted correctly.
extends GutTest


var _random_event_system: RandomEventSystem
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem
var _saved_store_id: StringName

var _items_removed: Array[Dictionary] = []
var _items_lost: Array[Dictionary] = []
var _transactions: Array[Dictionary] = []

const STORE_ID: StringName = &"retro_games"
const STARTING_CASH: float = 1000.0


func _make_theft_def(overrides: Dictionary = {}) -> RandomEventDefinition:
	var d := RandomEventDefinition.new()
	d.id = overrides.get("id", "theft")
	d.name = overrides.get("name", "Shoplifting Incident")
	d.description = overrides.get("description", "A theft occurs")
	d.effect_type = "shoplifting"
	d.duration_days = overrides.get("duration_days", 0)
	d.severity = overrides.get("severity", "medium")
	d.cooldown_days = overrides.get("cooldown_days", 0)
	d.probability_weight = overrides.get("probability_weight", 100.0)
	d.notification_text = overrides.get(
		"notification_text", "A shoplifter stole %s!"
	)
	d.resolution_text = ""
	d.toast_message = overrides.get("toast_message", "Theft Detected")
	d.time_window_start = -1
	d.time_window_end = -1
	return d


func _make_item_def(id: String = "test_cartridge") -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = "Test Cartridge"
	def.category = "cartridges"
	def.store_type = "retro_games"
	def.base_price = 25.0
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good"])
	return def


func _make_shelf_item(
	item_def: ItemDefinition = null
) -> ItemInstance:
	if not item_def:
		item_def = _make_item_def()
	var inst := ItemInstance.create(item_def, "good", 0, item_def.base_price)
	inst.current_location = "shelf:0"
	return inst


func _put_item_on_shelf(item: ItemInstance) -> void:
	_inventory_system._items[item.instance_id] = item
	_inventory_system._shelf_cache_dirty = true


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	GameManager.current_store_id = STORE_ID

	var data_loader := DataLoader.new()
	data_loader.load_all_content()

	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(data_loader)

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(STARTING_CASH)

	_reputation_system = ReputationSystem.new()
	_reputation_system.auto_connect_bus = false
	add_child_autofree(_reputation_system)
	_reputation_system.initialize_store("retro_games")

	_random_event_system = RandomEventSystem.new()
	add_child_autofree(_random_event_system)
	_random_event_system._effects = RandomEventEffects.new()
	_random_event_system._effects.initialize(
		_inventory_system, _reputation_system, _economy_system
	)

	_items_removed = []
	_items_lost = []
	_transactions = []
	EventBus.inventory_item_removed.connect(_on_item_removed)
	EventBus.item_lost.connect(_on_item_lost)
	EventBus.transaction_completed.connect(_on_transaction_completed)


func after_each() -> void:
	GameManager.current_store_id = _saved_store_id
	if EventBus.inventory_item_removed.is_connected(_on_item_removed):
		EventBus.inventory_item_removed.disconnect(_on_item_removed)
	if EventBus.item_lost.is_connected(_on_item_lost):
		EventBus.item_lost.disconnect(_on_item_lost)
	if EventBus.transaction_completed.is_connected(
		_on_transaction_completed
	):
		EventBus.transaction_completed.disconnect(
			_on_transaction_completed
		)


func _on_item_removed(
	item_id: StringName, store_id: StringName, reason: StringName
) -> void:
	_items_removed.append({
		"item_id": item_id, "store_id": store_id, "reason": reason,
	})


func _on_item_lost(item_id: String, reason: String) -> void:
	_items_lost.append({"item_id": item_id, "reason": reason})


func _on_transaction_completed(
	amount: float, success: bool, message: String
) -> void:
	_transactions.append({
		"amount": amount, "success": success, "message": message,
	})


# --- Scenario: theft event removes item and records signals ---


func test_theft_removes_exactly_one_item_from_inventory() -> void:
	for i: int in range(3):
		_put_item_on_shelf(
			_make_shelf_item(_make_item_def("cart_%d" % i))
		)
	assert_eq(
		_inventory_system.get_shelf_items().size(), 3,
		"Setup: 3 items on shelf"
	)

	var def := _make_theft_def()
	_random_event_system._event_definitions = [def]
	_random_event_system._active_event = {}
	_random_event_system._cooldowns = {}
	_random_event_system._daily_rolled = false
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_inventory_system.get_shelf_items().size(), 2,
		"Theft removes exactly one item"
	)


func test_theft_emits_inventory_item_removed_with_shoplifting_reason() -> void:
	var item := _make_shelf_item()
	_put_item_on_shelf(item)

	var def := _make_theft_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_items_removed.size(), 1,
		"inventory_item_removed fires once"
	)
	assert_eq(
		_items_removed[0]["store_id"], STORE_ID,
		"store_id matches active store"
	)
	assert_eq(
		_items_removed[0]["reason"], &"shoplifting",
		"reason is shoplifting"
	)


func test_theft_emits_item_lost_with_shoplifting_reason() -> void:
	var item := _make_shelf_item()
	_put_item_on_shelf(item)
	var instance_id: String = item.instance_id

	var def := _make_theft_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(_items_lost.size(), 1, "item_lost fires once")
	assert_eq(
		_items_lost[0]["item_id"], instance_id,
		"item_lost carries correct instance_id"
	)
	assert_eq(
		_items_lost[0]["reason"], "shoplifting",
		"item_lost reason is shoplifting"
	)


func test_theft_emits_random_event_started_and_triggered() -> void:
	_put_item_on_shelf(_make_shelf_item())
	watch_signals(EventBus)

	var def := _make_theft_def()
	_random_event_system._activate_event(def, 1)

	assert_signal_emitted(EventBus, "random_event_started")
	assert_signal_emitted(EventBus, "random_event_triggered")

	var params: Array = get_signal_parameters(
		EventBus, "random_event_triggered"
	)
	assert_eq(
		params[0], StringName("theft"),
		"Triggered event_id is theft"
	)
	assert_eq(
		params[1], STORE_ID,
		"Triggered store_id matches active store"
	)
	var effect: Dictionary = params[2]
	assert_eq(effect["type"], "shoplifting", "Effect type is shoplifting")
	assert_true(
		effect.has("stolen_item"),
		"Effect dictionary contains stolen_item key"
	)


func test_theft_does_not_change_player_cash() -> void:
	_put_item_on_shelf(_make_shelf_item())
	var initial_cash: float = _economy_system.get_cash()

	var def := _make_theft_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_economy_system.get_cash(), initial_cash,
		"Theft does not change player cash"
	)


func test_theft_does_not_emit_transaction_completed() -> void:
	_put_item_on_shelf(_make_shelf_item())

	var def := _make_theft_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_transactions.size(), 0,
		"No transaction_completed for theft — loss tracked via signals"
	)


func test_stolen_item_no_longer_in_inventory() -> void:
	var item := _make_shelf_item()
	_put_item_on_shelf(item)
	var instance_id: String = item.instance_id

	var def := _make_theft_def()
	_random_event_system._activate_event(def, 1)

	assert_null(
		_inventory_system.get_item(instance_id),
		"Stolen item no longer exists in inventory"
	)


func test_theft_is_instant_event_clears_active() -> void:
	_put_item_on_shelf(_make_shelf_item())
	watch_signals(EventBus)

	var def := _make_theft_def()
	_random_event_system._activate_event(def, 1)

	assert_false(
		_random_event_system.has_active_event(),
		"Shoplifting is instant — no lingering active event"
	)
	assert_signal_emitted(EventBus, "random_event_ended")


# --- Scenario: theft cannot reduce quantity below zero ---


func test_theft_on_empty_shelf_does_not_crash() -> void:
	var def := _make_theft_def()
	_random_event_system._activate_event(def, 1)

	assert_eq(
		_inventory_system.get_shelf_items().size(), 0,
		"Shelf remains empty"
	)
	assert_eq(
		_items_removed.size(), 0,
		"No inventory_item_removed when shelf is empty"
	)
	assert_eq(
		_items_lost.size(), 0,
		"No item_lost when shelf is empty"
	)


func test_repeated_theft_does_not_go_below_zero() -> void:
	_put_item_on_shelf(_make_shelf_item(_make_item_def("solo_item")))
	assert_eq(
		_inventory_system.get_shelf_items().size(), 1,
		"Setup: 1 item on shelf"
	)

	var def := _make_theft_def({"cooldown_days": 0})
	for i: int in range(3):
		_random_event_system._active_event = {}
		_random_event_system._cooldowns = {}
		_random_event_system._activate_event(def, i + 1)

	assert_eq(
		_inventory_system.get_shelf_items().size(), 0,
		"Quantity never goes below 0"
	)
	assert_eq(
		_items_removed.size(), 1,
		"Only 1 removal — subsequent thefts find empty shelf"
	)


func test_repeated_theft_subsequent_events_graceful() -> void:
	_put_item_on_shelf(_make_shelf_item(_make_item_def("single")))

	var def := _make_theft_def({"cooldown_days": 0})
	_random_event_system._activate_event(def, 1)
	_random_event_system._active_event = {}
	_random_event_system._cooldowns = {}
	_random_event_system._activate_event(def, 2)

	assert_eq(
		_items_removed.size(), 1,
		"Second theft on empty shelf does not remove anything"
	)
	assert_eq(
		_items_lost.size(), 1,
		"Second theft on empty shelf does not emit item_lost"
	)
