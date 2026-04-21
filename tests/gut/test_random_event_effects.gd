## Tests for RandomEventEffects — effect type dispatch, magnitude application,
## and EventBus signal contracts.
extends GutTest


var _effects: RandomEventEffects
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _reputation_system: ReputationSystem
var _notifications: Array[String] = []
var _items_removed: Array[Dictionary] = []
var _items_lost: Array[Dictionary] = []


func _make_def(overrides: Dictionary = {}) -> RandomEventDefinition:
	var d := RandomEventDefinition.new()
	d.id = overrides.get("id", "test_event")
	d.name = overrides.get("name", "Test Event")
	d.description = overrides.get("description", "A test")
	d.effect_type = overrides.get("effect_type", "shoplifting")
	d.duration_days = overrides.get("duration_days", 1)
	d.severity = overrides.get("severity", "low")
	d.cooldown_days = overrides.get("cooldown_days", 5)
	d.probability_weight = overrides.get("probability_weight", 1.0)
	d.notification_text = overrides.get("notification_text", "Event: %s")
	d.resolution_text = overrides.get("resolution_text", "")
	d.toast_message = overrides.get("toast_message", "Toast")
	d.time_window_start = overrides.get("time_window_start", -1)
	d.time_window_end = overrides.get("time_window_end", -1)
	d.bulk_order_quantity = overrides.get("bulk_order_quantity", 3)
	d.bulk_order_price_multiplier = overrides.get(
		"bulk_order_price_multiplier", 1.2
	)
	return d


func _make_item_def(id: String = "test_widget") -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = "Test Widget"
	def.category = "cartridges"
	def.store_type = "retro_games"
	def.base_price = 10.0
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good"])
	return def


func _make_shelf_item(item_def: ItemDefinition = null) -> ItemInstance:
	if not item_def:
		item_def = _make_item_def()
	var inst := ItemInstance.create(item_def, "good", 0, item_def.base_price)
	inst.current_location = "shelf:0"
	return inst


func _put_item_on_shelf(item: ItemInstance) -> void:
	_inventory_system._items[item.instance_id] = item
	_inventory_system._shelf_cache_dirty = true


func before_each() -> void:
	var data_loader := DataLoader.new()
	data_loader.load_all_content()

	GameManager.current_store_id = &"retro_games"

	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(data_loader)

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(1000.0)

	_reputation_system = ReputationSystem.new()
	add_child_autofree(_reputation_system)
	_reputation_system.initialize_store("retro_games")

	_effects = RandomEventEffects.new()
	_effects.initialize(_inventory_system, _reputation_system, _economy_system)

	_notifications = []
	_items_removed = []
	_items_lost = []
	EventBus.notification_requested.connect(_on_notification)
	EventBus.inventory_item_removed.connect(_on_item_removed)
	EventBus.item_lost.connect(_on_item_lost)


func after_each() -> void:
	GameManager.current_store_id = &""
	if EventBus.notification_requested.is_connected(_on_notification):
		EventBus.notification_requested.disconnect(_on_notification)
	if EventBus.inventory_item_removed.is_connected(_on_item_removed):
		EventBus.inventory_item_removed.disconnect(_on_item_removed)
	if EventBus.item_lost.is_connected(_on_item_lost):
		EventBus.item_lost.disconnect(_on_item_lost)


func _on_notification(message: String) -> void:
	_notifications.append(message)


func _on_item_removed(
	item_id: StringName, store_id: StringName, reason: StringName
) -> void:
	_items_removed.append({
		"item_id": item_id, "store_id": store_id, "reason": reason,
	})


func _on_item_lost(item_id: String, reason: String) -> void:
	_items_lost.append({"item_id": item_id, "reason": reason})


# --- apply_shoplifting ---


func test_shoplifting_removes_item_and_returns_name() -> void:
	var item_def := _make_item_def()
	item_def.item_name = "Rare Cartridge"
	var item := _make_shelf_item(item_def)
	_put_item_on_shelf(item)
	var def := _make_def({
		"effect_type": "shoplifting",
		"notification_text": "Theft: %s taken!",
	})
	var name_returned: String = _effects.apply_shoplifting(def)
	assert_eq(name_returned, "Rare Cartridge")
	assert_null(_inventory_system.get_item(item.instance_id))


func test_shoplifting_emits_correct_signals() -> void:
	var item := _make_shelf_item()
	_put_item_on_shelf(item)
	var def := _make_def({
		"effect_type": "shoplifting",
		"notification_text": "Theft: %s taken!",
	})
	_effects.apply_shoplifting(def)
	assert_eq(_notifications.size(), 1, "notification_requested fires once")
	assert_eq(_items_removed.size(), 1, "inventory_item_removed fires once")
	assert_eq(_items_removed[0]["reason"], &"shoplifting")
	assert_eq(_items_lost.size(), 1, "item_lost fires once")
	assert_eq(_items_lost[0]["reason"], "shoplifting")


func test_shoplifting_uses_def_notification_text() -> void:
	var item := _make_shelf_item()
	_put_item_on_shelf(item)
	var def := _make_def({
		"effect_type": "shoplifting",
		"notification_text": "Custom theft: %s gone!",
	})
	_effects.apply_shoplifting(def)
	assert_true(
		_notifications[0].begins_with("Custom theft:"),
		"Notification must come from def.notification_text, not a hardcoded string"
	)


# --- apply_shoplifting on empty inventory (guard clause) ---


func test_shoplifting_empty_inventory_returns_empty_and_no_item_signals() -> void:
	var def := _make_def({
		"effect_type": "shoplifting",
		"notification_text": "Theft: %s taken!",
	})
	var result: String = _effects.apply_shoplifting(def)
	assert_eq(result, "", "Empty shelf returns empty string")
	assert_eq(_items_removed.size(), 0, "No inventory_item_removed when shelf empty")
	assert_eq(_items_lost.size(), 0, "No item_lost when shelf empty")
	assert_eq(_notifications.size(), 1, "Graceful notification still fires")
	assert_true(
		_notifications[0].to_lower().contains("nothing"),
		"Graceful message should note nothing was stolen"
	)


# --- apply_bulk_order ---


func test_bulk_order_credits_economy_based_on_shelf_items() -> void:
	var item_def := _make_item_def("bulk_widget")
	for i: int in range(5):
		_put_item_on_shelf(_make_shelf_item(item_def))
	var initial_cash: float = _economy_system.player_cash
	var def := _make_def({
		"effect_type": "bulk_order",
		"notification_text": "Bulk order: $%.0f received!",
		"bulk_order_quantity": 3,
		"bulk_order_price_multiplier": 1.2,
	})
	var amount: float = _effects.apply_bulk_order(def)
	assert_gt(
		_economy_system.player_cash, initial_cash, "Cash should increase"
	)
	assert_gt(amount, 0.0, "Amount should be positive")
	assert_eq(
		_inventory_system.get_shelf_items().size(), 2,
		"3 items removed from shelf"
	)


func test_bulk_order_emits_notification_using_def_text() -> void:
	var item_def := _make_item_def("bulk_notif_item")
	for i: int in range(3):
		_put_item_on_shelf(_make_shelf_item(item_def))
	var def := _make_def({
		"effect_type": "bulk_order",
		"notification_text": "Custom bulk: $%.0f in!",
	})
	_effects.apply_bulk_order(def)
	assert_eq(
		_notifications.size(), 1,
		"notification_requested fires once"
	)
	assert_true(
		_notifications[0].begins_with("Custom bulk:"),
		"Notification text comes from def.notification_text"
	)


# --- apply_competitor_sale ---


func test_competitor_sale_emits_notification_and_no_inventory_changes() -> void:
	var def := _make_def({
		"effect_type": "competitor_sale",
		"notification_text": "Competitor is having a sale!",
	})
	_effects.apply_competitor_sale(def)
	assert_eq(_notifications.size(), 1, "notification_requested fires once")
	assert_eq(_notifications[0], "Competitor is having a sale!")
	assert_eq(_items_removed.size(), 0, "No inventory changes for competitor_sale")


# --- apply_rainy_day ---


func test_rainy_day_emits_notification_from_def() -> void:
	var def := _make_def({
		"effect_type": "rainy_day",
		"notification_text": "It is raining outside!",
	})
	_effects.apply_rainy_day(def)
	assert_eq(_notifications.size(), 1)
	assert_eq(_notifications[0], "It is raining outside!")


# --- apply_health_inspection ---


func test_health_inspection_pass_when_shelves_stocked() -> void:
	for i: int in range(6):
		_put_item_on_shelf(_make_shelf_item(_make_item_def("w_%d" % i)))
	var def := _make_def({
		"effect_type": "health_inspection",
		"notification_text": "Inspection underway!",
	})
	var passed: bool = _effects.apply_health_inspection(def)
	assert_true(passed, "Inspection passes when shelves are stocked")


func test_health_inspection_fail_when_no_items() -> void:
	var def := _make_def({
		"effect_type": "health_inspection",
		"notification_text": "Inspection underway!",
	})
	var passed: bool = _effects.apply_health_inspection(def)
	assert_false(passed, "Inspection fails when inventory is empty")


func test_health_inspection_pass_applies_positive_reputation_from_constant() -> void:
	for i: int in range(6):
		_put_item_on_shelf(_make_shelf_item(_make_item_def("w_%d" % i)))
	var initial_rep: float = _reputation_system.get_reputation("retro_games")
	var def := _make_def({
		"effect_type": "health_inspection",
		"notification_text": "Inspection!",
	})
	_effects.apply_health_inspection(def)
	var delta: float = _reputation_system.get_reputation("retro_games") - initial_rep
	assert_almost_eq(
		delta, RandomEventEffects.HEALTH_INSPECTION_PASS_REP, 0.01,
		"Pass grants exactly HEALTH_INSPECTION_PASS_REP — not a hardcoded value"
	)


func test_health_inspection_fail_applies_negative_reputation_from_constant() -> void:
	var initial_rep: float = _reputation_system.get_reputation("retro_games")
	var def := _make_def({
		"effect_type": "health_inspection",
		"notification_text": "Inspection!",
	})
	_effects.apply_health_inspection(def)
	var delta: float = _reputation_system.get_reputation("retro_games") - initial_rep
	assert_almost_eq(
		delta, RandomEventEffects.HEALTH_INSPECTION_FAIL_REP, 0.01,
		"Fail applies exactly HEALTH_INSPECTION_FAIL_REP — not a hardcoded value"
	)


func test_health_inspection_emits_at_least_two_notifications() -> void:
	var def := _make_def({
		"effect_type": "health_inspection",
		"notification_text": "Inspection!",
	})
	_effects.apply_health_inspection(def)
	assert_gte(
		_notifications.size(), 2,
		"health_inspection should emit initial notification plus pass/fail result"
	)


# --- apply_supply_shortage ---


func test_supply_shortage_sets_target_category_and_emits_notification() -> void:
	var active_event: Dictionary = {}
	var def := _make_def({
		"effect_type": "supply_shortage",
		"notification_text": "Shortage of %s for %d days!",
		"duration_days": 2,
	})
	_effects.apply_supply_shortage(def, active_event)
	assert_true(active_event.has("target_category"))
	assert_false(
		String(active_event["target_category"]).is_empty(),
		"target_category must be a non-empty string"
	)
	assert_eq(_notifications.size(), 1, "notification_requested fires once")


# --- apply_viral_trend ---


func test_viral_trend_empty_shelf_emits_notification_without_crash() -> void:
	var active_event: Dictionary = {}
	var def := _make_def({
		"effect_type": "viral_trend",
		"notification_text": "%s is viral for %d days!",
		"duration_days": 2,
	})
	_effects.apply_viral_trend(def, active_event)
	assert_eq(_notifications.size(), 1, "Notification fires even on empty shelf")


func test_viral_trend_nonempty_shelf_sets_target_item_id() -> void:
	var item := _make_shelf_item()
	_put_item_on_shelf(item)
	var active_event: Dictionary = {}
	var def := _make_def({
		"effect_type": "viral_trend",
		"notification_text": "%s is viral for %d days!",
		"duration_days": 2,
	})
	_effects.apply_viral_trend(def, active_event)
	assert_true(active_event.has("target_item_id"))
	assert_false(
		String(active_event.get("target_item_id", "")).is_empty(),
		"target_item_id should point to a shelf item"
	)


# --- apply_estate_sale ---


func test_estate_sale_returns_default_when_shelf_empty() -> void:
	var def := _make_def({
		"effect_type": "estate_sale",
		"notification_text": "Estate find: %s!",
	})
	var result: String = _effects.apply_estate_sale(def)
	assert_eq(result, "a rare find")


func test_estate_sale_returns_item_name_from_shelf_and_emits_notification() -> void:
	var item_def := _make_item_def()
	item_def.item_name = "Rare Console"
	_put_item_on_shelf(_make_shelf_item(item_def))
	var def := _make_def({
		"effect_type": "estate_sale",
		"notification_text": "Estate find: %s!",
	})
	var result: String = _effects.apply_estate_sale(def)
	assert_eq(result, "Rare Console")
	assert_eq(_notifications.size(), 1)


# --- Cooldown prevents double-application (guard via RandomEventSystem) ---


func test_cooldown_blocks_event_until_expired() -> void:
	var system := RandomEventSystem.new()
	add_child_autofree(system)
	var def := _make_def({
		"id": "competitor_sale",
		"effect_type": "competitor_sale",
		"probability_weight": 100.0,
		"cooldown_days": 3,
		"notification_text": "Competitor sale!",
	})
	system._event_definitions = [def]
	system._cooldowns = {"competitor_sale": 3}
	system._active_event = {}
	system._daily_rolled = false
	var fired: Array[StringName] = system.evaluate_daily_events(2)
	assert_eq(fired.size(), 0, "Event must not fire while on cooldown")


func test_daily_rolled_flag_prevents_same_day_double_apply() -> void:
	var system := RandomEventSystem.new()
	add_child_autofree(system)
	var def := _make_def({
		"id": "rainy_day",
		"effect_type": "rainy_day",
		"probability_weight": 100.0,
		"cooldown_days": 0,
		"notification_text": "Rainy!",
	})
	system._event_definitions = [def]
	system._active_event = {}
	system._cooldowns = {}
	system._daily_rolled = false
	system.evaluate_daily_events(1)
	system._active_event = {}
	var second: Array[StringName] = system.evaluate_daily_events(1)
	assert_eq(
		second.size(), 0,
		"_daily_rolled flag prevents firing the same event twice on day 1"
	)


# --- Active effects query ---


func test_get_active_event_returns_empty_with_no_active_event() -> void:
	var system := RandomEventSystem.new()
	add_child_autofree(system)
	system._active_event = {}
	assert_true(system.get_active_event().is_empty())


func test_get_active_event_reflects_triggered_event() -> void:
	var system := RandomEventSystem.new()
	add_child_autofree(system)
	var def := _make_def({
		"id": "rainy_day",
		"effect_type": "rainy_day",
		"probability_weight": 100.0,
		"cooldown_days": 5,
		"notification_text": "Rainy!",
	})
	system._event_definitions = [def]
	system._active_event = {}
	system._cooldowns = {}
	system._daily_rolled = false
	system.evaluate_daily_events(1)
	var active: Dictionary = system.get_active_event()
	assert_false(active.is_empty(), "Active event dict should be populated")
	var active_def := active.get("definition") as RandomEventDefinition
	assert_not_null(active_def)
	assert_eq(active_def.effect_type, "rainy_day")


func test_instant_event_clears_active_event_after_application() -> void:
	var system := RandomEventSystem.new()
	add_child_autofree(system)
	var def := _make_def({
		"id": "bulk_order",
		"effect_type": "bulk_order",
		"probability_weight": 100.0,
		"cooldown_days": 1,
		"notification_text": "Order: $%.0f",
		"time_window_start": -1,
		"time_window_end": -1,
	})
	system._event_definitions = [def]
	system._active_event = {}
	system._cooldowns = {}
	system._daily_rolled = false
	system.evaluate_daily_events(1)
	assert_false(
		system.has_active_event(),
		"Instant events (bulk_order) must not remain active after application"
	)
